extends Node
## TimeManager — the phase clock (Autoload singleton), per TIME_SYSTEM.md.
##
## Drives Day -> Dusk -> Night -> Dawn. Everything else subscribes to its signals
## (relayed through EventBus). Nothing else manages time.
##
## Pillar 4 (Day/Night as Structural Argument): this clock IS the mechanical
## implementation of RELIEF (day) -> UNEASE (night) -> COMPULSION (dawn).
##
## PAUSE MODEL (CRITICAL_GAPS_PLAN.md Gap 5): pause is permitted. It freezes the
## clock and stops *pending* events from arriving, but it does NOT undo anything
## already seen and it does NOT make the night safe. We implement this by gating
## elapsed-time accumulation on `_paused`; the world stays fully visible.
##
## SLICE NOTE: TIME_SYSTEM.md specifies 45-minute real cycles (DAY 1500s, DUSK 180s,
## NIGHT 900s, DAWN 120s). For a playable/inspectable vertical slice those are far
## too long to sit through, so SLICE_DURATIONS are compressed by ~20x. The real
## spec values are kept in SPEC_DURATIONS for reference and the ratio between phases
## is preserved. Press F1 (debug_skip_phase) to advance instantly. Documented in README.

enum Phase { DAY, DUSK, NIGHT, DAWN }
enum Season { LATE_SUMMER, TURNING, DEEP_WINTER, THAW }

# Real spec (TIME_SYSTEM.md) — not used to time the slice, kept for fidelity.
const SPEC_DURATIONS := {
	Phase.DAY: 1500.0,
	Phase.DUSK: 180.0,
	Phase.NIGHT: 900.0,
	Phase.DAWN: 120.0,
}

# Compressed durations actually used by the slice (~20x faster), same phase ratio.
const SLICE_DURATIONS := {
	Phase.DAY: 75.0,
	Phase.DUSK: 9.0,
	Phase.NIGHT: 45.0,
	Phase.DAWN: 8.0,
}

# In-game hours per phase (for the sun/hour tick) — unchanged from spec.
const PHASE_INGAME_HOURS := {
	Phase.DAY: 18,
	Phase.DUSK: 2,
	Phase.NIGHT: 10,
	Phase.DAWN: 2,
}

# Season tempo multipliers (TIME_SYSTEM.md). debt_tempo scales clock speed.
const SEASON_TEMPO := {
	Season.LATE_SUMMER: 0.8,
	Season.TURNING: 1.0,
	Season.DEEP_WINTER: 1.3,
	Season.THAW: 0.9,
}

# Dawn delay before the consequence thread is delivered (TIME_SYSTEM: 60s in spec).
# Compressed for the slice so the player isn't staring at a frozen dawn.
const DAWN_THREAD_DELAY := 3.0

const LAST_CHAPTER_DAY := 5

# Direct, non-EventBus signals (some systems prefer to bind these directly).
signal phase_changed(new_phase: int)
signal hour_ticked(current_hour: int, phase: int)
signal night_roster_lock_warning()
signal dawn_consequence_ready()
signal season_changed(new_season: int, severity: float)

var current_phase: int = Phase.DAY
var current_day: int = 1
var current_season: int = Season.LATE_SUMMER
var debt_tempo: float = 0.8
var elapsed_in_phase: float = 0.0

var _paused: bool = false
var _running: bool = false
var _last_emitted_hour: int = -1
var _warned_for_dusk: bool = false


func _ready() -> void:
	EventBus.pause_toggled.connect(_on_pause_toggled)


## Begin the clock. Called by Main once the world + UI are wired.
func start() -> void:
	_running = true
	current_phase = Phase.DAY
	current_day = 1
	GameState.current_day = current_day
	GameState.current_phase = "day"
	_emit_phase()


func _process(delta: float) -> void:
	if not _running or _paused:
		return
	elapsed_in_phase += delta * debt_tempo
	_tick_hour()

	# Single "night is coming" cue 60 spec-seconds (scaled) before dusk closes.
	if current_phase == Phase.DUSK and not _warned_for_dusk:
		var warn_at := SLICE_DURATIONS[Phase.DUSK] * 0.5
		if elapsed_in_phase >= warn_at:
			_warned_for_dusk = true
			night_roster_lock_warning.emit()
			EventBus.night_roster_lock_warning.emit()

	if elapsed_in_phase >= SLICE_DURATIONS[current_phase]:
		_advance_phase()


# ── Phase advance ───────────────────────────────────────────────────────────

func _advance_phase() -> void:
	elapsed_in_phase = 0.0
	_last_emitted_hour = -1
	match current_phase:
		Phase.DAY:
			current_phase = Phase.DUSK
			_on_dusk_begin()
		Phase.DUSK:
			current_phase = Phase.NIGHT
			_on_night_begin()
		Phase.NIGHT:
			current_phase = Phase.DAWN
			_on_dawn_begin()
		Phase.DAWN:
			# Dawn rolls into the next Day.
			if current_day >= LAST_CHAPTER_DAY:
				_running = false
				current_phase = Phase.DAWN  # hold on final dawn — chapter end
				_emit_phase()
				return
			current_phase = Phase.DAY
			current_day += 1
			_on_day_begin()
	_emit_phase()


func _emit_phase() -> void:
	GameState.current_phase = _phase_name(current_phase)
	GameState.current_day = current_day
	phase_changed.emit(current_phase)
	EventBus.phase_changed.emit(current_phase, current_day)


# ── Phase handlers ────────────────────────────────────────────────────────────

func _on_dusk_begin() -> void:
	# Dusk: roster opens. In the slice, the day's choices are frozen into the roster.
	_warned_for_dusk = false
	GameState.current_phase = "dusk"


func _on_night_begin() -> void:
	# Night: lock assignments, run gossip + select authored night events, observe-only.
	GameState.current_phase = "night"
	GameState.night_roster = _build_night_roster()
	# Systems node (Main child) listens for phase_changed==NIGHT to run the passes.


func _on_dawn_begin() -> void:
	# Dawn: night freezes, significance + consequence thread run, then deliver after delay.
	GameState.current_phase = "dawn"
	# The systems layer runs significance/thread on phase_changed==DAWN, then we
	# deliver the thread after the (compressed) consequence delay.
	_deliver_dawn_thread_after_delay()


func _on_day_begin() -> void:
	GameState.current_phase = "day"
	# Re-evaluate season at each new day (DEBT-driven, TIME_SYSTEM.md).
	_evaluate_season()


func _deliver_dawn_thread_after_delay() -> void:
	await get_tree().create_timer(DAWN_THREAD_DELAY).timeout
	if current_phase != Phase.DAWN:
		return
	dawn_consequence_ready.emit()
	# The systems layer assembled GameState's thread entries; broadcast them.
	EventBus.dawn_thread_ready.emit(GameState.get_meta("dawn_thread_entries", []))


# ── Roster: freeze each NPC's current assignment as the night roster ────────

func _build_night_roster() -> Dictionary:
	var roster: Dictionary = {}
	for npc_id in GameState.npc_states:
		roster[npc_id] = GameState.npc_states[npc_id].get("zone", "zone_2")
	return roster


# ── Season evaluation (TIME_SYSTEM.md SeasonManager) ────────────────────────

func _evaluate_season() -> void:
	var debt := GameState.get_debt_level()
	var target := _compute_target_season(current_day, debt)
	if target != current_season:
		current_season = target
		var severity := clampf(debt, 0.0, 1.0)
		debt_tempo = SEASON_TEMPO[target]
		GameState.season = _season_name(target)
		season_changed.emit(target, severity)
	else:
		debt_tempo = SEASON_TEMPO[current_season]


func _compute_target_season(day: int, debt: float) -> int:
	# Thresholds per TIME_SYSTEM.md SEASON_THRESHOLDS (5-day arc). Turning can arrive
	# from Day 3 on the high-DEBT path; Deep Winter only Night 5 at high DEBT.
	if day >= 5 and debt >= 0.70:
		return Season.DEEP_WINTER
	if day >= 3 and debt >= 0.40:
		return Season.TURNING
	return Season.LATE_SUMMER


# ── Hour tick (drives sun position / light lerp in the world) ───────────────

func _tick_hour() -> void:
	var dur: float = SLICE_DURATIONS[current_phase]
	var progress := elapsed_in_phase / dur if dur > 0.0 else 0.0
	var hours: int = PHASE_INGAME_HOURS[current_phase]
	var hour := int(progress * hours)
	if hour != _last_emitted_hour:
		_last_emitted_hour = hour
		hour_ticked.emit(hour, current_phase)
		EventBus.hour_ticked.emit(hour, current_phase)


# ── Pause (Gap 5) ───────────────────────────────────────────────────────────

func _on_pause_toggled(paused: bool) -> void:
	_paused = paused


func is_paused() -> bool:
	return _paused


# ── Debug skip (F1) — advance the current phase instantly ───────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_skip_phase") and _running:
		elapsed_in_phase = SLICE_DURATIONS[current_phase]


# ── Progress accessors (0..1 within current phase) for UI/lighting ──────────

func phase_progress() -> float:
	var dur: float = SLICE_DURATIONS[current_phase]
	return clampf(elapsed_in_phase / dur, 0.0, 1.0) if dur > 0.0 else 0.0


func is_running() -> bool:
	return _running


# ── Name helpers ────────────────────────────────────────────────────────────

func _phase_name(p: int) -> String:
	match p:
		Phase.DAY: return "day"
		Phase.DUSK: return "dusk"
		Phase.NIGHT: return "night"
		Phase.DAWN: return "dawn"
	return "day"


func _season_name(s: int) -> String:
	match s:
		Season.LATE_SUMMER: return "late_summer"
		Season.TURNING: return "turning"
		Season.DEEP_WINTER: return "deep_winter"
		Season.THAW: return "thaw"
	return "late_summer"
