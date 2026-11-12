extends Node
## TimeManager — the phase clock and the session director (Autoload singleton).
##
## Drives Day -> Dusk -> Night -> Dawn (TIME_SYSTEM.md) and, at each boundary, runs
## the same pass order as backend/engine.py SessionEngine through Chapter.gd:
##
##   DAY    Chapter.begin_day / tick_day      player choices land in the choice log
##   DUSK   Chapter.begin_dusk                roster open; one warning before it locks
##   NIGHT  Chapter.begin_night               crew + production resolve, gossip pass,
##                                            NightSim.plan -> the night queue
##          (queue served by in-game hour -> EventBus.night_event_fired)
##   DAWN   Chapter.begin_dawn                night committed, significance pass,
##                                            consequence thread, investment anchor
##
## Pillar 4: this clock IS the argument — RELIEF (day), UNEASE (night), COMPULSION (dawn).
##
## PAUSE (Gap 5): pausing freezes the SceneTree. This node is pausable, so the clock
## stops and pending night events are held; delivered text stays; the world stays
## visible. Nothing about a paused night is safe, and nothing is undone.
##
## PACE: the spec cycle is 25/3/15/2 real minutes (kept as "full"). The default
## "standard" pace compresses it for the amount of authored content this build has;
## phase ratios are preserved. There is no speed control in play (TIME_SYSTEM.md).
## Night length scales with the season (Late Summer -15%, Deep Winter +25%).

enum Phase { DAY, DUSK, NIGHT, DAWN }

const PACES := {
	"full": {Phase.DAY: 1500.0, Phase.DUSK: 180.0, Phase.NIGHT: 900.0, Phase.DAWN: 120.0},
	"standard": {Phase.DAY: 540.0, Phase.DUSK: 70.0, Phase.NIGHT: 300.0, Phase.DAWN: 50.0},
	"brisk": {Phase.DAY: 200.0, Phase.DUSK: 30.0, Phase.NIGHT: 110.0, Phase.DAWN: 26.0},
}
const PHASE_INGAME_HOURS := {Phase.DAY: 18, Phase.DUSK: 2, Phase.NIGHT: 10, Phase.DAWN: 2}
const PHASE_NAMES := ["day", "dusk", "night", "dawn"]

signal phase_changed(new_phase: int)
signal dawn_consequence_ready()

var pace: String = "standard"
var current_phase: int = Phase.DAY
var current_day: int = 1
var elapsed_in_phase: float = 0.0
## True while dawn is still delivering its thread: no input is accepted (REVEAL_MECHANIC §2).
var input_locked: bool = false

var _running: bool = false
var _last_hour: int = -1
var _warned: bool = false
var _night_cursor: int = 0
var _dawn_delivered: bool = false
var _dawn_entries: Array = []
var _ended: bool = false
var debug_keys: bool = false


func _ready() -> void:
	debug_keys = OS.has_feature("editor") or OS.get_cmdline_user_args().has("--debug-keys")


func is_running() -> bool:
	return _running


func is_night() -> bool:
	return current_phase == Phase.NIGHT


func duration(phase: int = -1) -> float:
	var p := current_phase if phase < 0 else phase
	var d: float = PACES.get(pace, PACES["standard"])[p]
	if p == Phase.NIGHT:
		d *= Chapter.night_length_multiplier()
	return d


func phase_progress() -> float:
	return clampf(elapsed_in_phase / duration(), 0.0, 1.0)


# ── Session start / resume ──────────────────────────────────────────────────

func begin_new(anchor_name: String = "") -> void:
	GameState.reset()
	if anchor_name.strip_edges() != "":
		GameState.anchor_name = anchor_name.strip_edges()
	current_day = 1
	current_phase = Phase.DAY
	elapsed_in_phase = 0.0
	_reset_cursors()
	_running = true
	_ended = false
	EventBus.session_started.emit()
	Chapter.begin_day(1)
	_emit_phase()


func to_dict() -> Dictionary:
	return {"day": current_day, "phase": current_phase, "elapsed": elapsed_in_phase,
		"night_cursor": _night_cursor, "pace": pace}


func from_dict(d: Dictionary) -> void:
	current_day = int(d.get("day", GameState.current_day))
	current_phase = int(d.get("phase", Phase.DAY))
	elapsed_in_phase = float(d.get("elapsed", 0.0))
	_reset_cursors()
	_night_cursor = int(d.get("night_cursor", 0))
	# A dawn is short and its thread is already on record: resume it from its start.
	if current_phase == Phase.DAWN:
		elapsed_in_phase = 0.0
		_dawn_entries = GameState.dawn_threads.get(current_day, [])
		input_locked = true


## Called after SaveSystem.load_game(): start the clock on the restored state.
func resume() -> void:
	_running = not GameState.chapter_complete or current_phase == Phase.DAWN
	_ended = false
	EventBus.session_started.emit()
	_emit_phase()


func stop() -> void:
	_running = false


func _reset_cursors() -> void:
	_last_hour = -1
	_warned = false
	_night_cursor = 0
	_dawn_delivered = false
	_dawn_entries = []
	input_locked = false


# ── Tick ────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _running:
		return
	elapsed_in_phase += delta
	_tick_hour()
	match current_phase:
		Phase.DAY:
			Chapter.tick_day(phase_progress())
		Phase.DUSK:
			# One cue, a third of the way from the end. No countdown anywhere.
			if not _warned and elapsed_in_phase >= duration() * 0.66:
				_warned = true
				EventBus.night_roster_lock_warning.emit()
		Phase.NIGHT:
			_serve_night(phase_progress() * float(NightSim.NIGHT_HOURS))
		Phase.DAWN:
			if not _dawn_delivered and elapsed_in_phase >= minf(4.0, duration() * 0.2):
				_dawn_delivered = true
				dawn_consequence_ready.emit()
				EventBus.dawn_thread_ready.emit(_dawn_entries)
			if input_locked and elapsed_in_phase >= duration() * 0.5:
				input_locked = false
	if elapsed_in_phase >= duration():
		_advance_phase()


func _serve_night(hour: float) -> void:
	var q: Array = GameState.night_queue
	while _night_cursor < q.size() and float(q[_night_cursor]["hour"]) <= hour:
		var e: Dictionary = q[_night_cursor]
		_night_cursor += 1
		GameState.add_log(str(e["event_text"]), "night")
		EventBus.night_event_fired.emit(e)


func _advance_phase() -> void:
	elapsed_in_phase = 0.0
	_last_hour = -1
	match current_phase:
		Phase.DAY:
			current_phase = Phase.DUSK
			_warned = false
			Chapter.begin_dusk()
		Phase.DUSK:
			current_phase = Phase.NIGHT
			_night_cursor = 0
			Chapter.begin_night()
			EventBus.night_began.emit(current_day)
		Phase.NIGHT:
			_serve_night(999.0)
			current_phase = Phase.DAWN
			_dawn_delivered = false
			input_locked = true
			_dawn_entries = Chapter.begin_dawn()
		Phase.DAWN:
			if not _dawn_delivered:
				_dawn_delivered = true
				EventBus.dawn_thread_ready.emit(_dawn_entries)
			input_locked = false
			if current_day >= Chapter.LAST_DAY:
				_end_chapter()
				return
			current_phase = Phase.DAY
			current_day += 1
			Chapter.begin_day(current_day)
	_emit_phase()


func _end_chapter() -> void:
	if _ended:
		return
	_ended = true
	_running = false
	GameState.chapter_complete = true
	SaveSystem.write_handoff()
	SaveSystem.enabled = SaveSystem.enabled
	EventBus.chapter_ended.emit()


func _emit_phase() -> void:
	GameState.current_phase = PHASE_NAMES[current_phase]
	GameState.current_day = current_day
	phase_changed.emit(current_phase)
	EventBus.phase_changed.emit(current_phase, current_day)
	EventBus.world_changed.emit()


## "Post the watch." — confirming the roster at dusk ends the dusk (NIGHT_SURVIVAL).
func confirm_roster() -> void:
	if _running and current_phase == Phase.DUSK:
		elapsed_in_phase = duration()


func _tick_hour() -> void:
	var hours: int = PHASE_INGAME_HOURS[current_phase]
	var hour := int(phase_progress() * hours)
	if hour != _last_hour:
		_last_hour = hour
		EventBus.hour_ticked.emit(hour, current_phase)


# ── Debug: F1 skips the current phase (editor builds or `-- --debug-keys`) ───

func _unhandled_input(event: InputEvent) -> void:
	if debug_keys and _running and event.is_action_pressed("debug_skip_phase"):
		elapsed_in_phase = duration()
