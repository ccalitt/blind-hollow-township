class_name GameDirector
extends Node
## GameDirector — the GDScript equivalent of backend/engine.py SessionEngine.
##
## Orchestrates the rule passes in the correct per-cycle order, driven by
## TimeManager phase signals (relayed through EventBus):
##
##   DAY  (player logs choices in real time)
##   NIGHT begin -> [1] GossipPass.run_pass  -> [2] NightDirector.select_events
##                  (events served, EventBus.night_event_fired per event)
##   DAWN begin  -> [3] SignificancePass.run_dawn_pass
##                  [4] ConsequenceThread.generate_thread
##                  [5] ConsequenceThread.compute_investment_anchor
##                  (thread stashed on GameState; TimeManager delivers it after the
##                   60s consequence delay via EventBus.dawn_thread_ready)
##
## Pillars 1 & 4: this node is where Day choices become Night horror and Dawn truth.

var _director: NightDirector


func _ready() -> void:
	_director = NightDirector.new()
	EventBus.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(new_phase: int, day: int) -> void:
	match new_phase:
		TimeManager.Phase.NIGHT:
			_run_night(day)
		TimeManager.Phase.DAWN:
			_run_dawn(day)


# ── Night begin: gossip + event selection ───────────────────────────────────

func _run_night(day: int) -> void:
	var todays_choices := GameState.choices_for_day(day)

	# [1] Gossip propagation (no prior-night events fed on the same-day transition,
	#     matching SessionEngine.end_day which passes night_events=[]).
	GossipPass.run_pass(day, todays_choices, [])

	# [2] Night event selection from the authored library — strictly traceable.
	var events := _director.select_events(day, todays_choices)
	GameState.last_night_events = []
	for e in events:
		var typed: Dictionary = e
		GameState.last_night_events.append(typed)

	# Serve events one at a time so the night log + camera-snap can sequence them.
	_serve_events(GameState.last_night_events)


func _serve_events(events: Array) -> void:
	# Stagger event delivery across the night. If paused, TimeManager halts time but
	# already-delivered events stay (Gap 5). We deliver immediately here and let the
	# night log present them; a fuller build would gate each on an in-game hour tick.
	for e in events:
		EventBus.night_event_fired.emit(e)
		# Apply the authored arc/emotion delta to the threatened NPC.
		_apply_arc_delta(e)


func _apply_arc_delta(event: Dictionary) -> void:
	var delta: Dictionary = event.get("arc_delta", {})
	if delta.is_empty():
		return
	for npc_id in event.get("threat_npc_ids", []):
		var nid := str(npc_id)
		if delta.has("emotion"):
			GameState.set_npc_emotion(nid, str(delta["emotion"]))
		if delta.has("arc_state"):
			GameState.set_npc_arc(nid, str(delta["arc_state"]))


# ── Dawn begin: significance + consequence thread + anchor ──────────────────

func _run_dawn(day: int) -> void:
	var night_events := GameState.last_night_events
	var full_log := GameState.choice_log
	var roster := GameState.night_roster

	# [3] Significance pass.
	SignificancePass.run_dawn_pass(night_events, roster, full_log, day)

	# [4] Consequence thread — quiet night yields an empty array (no manufacture).
	var entries := ConsequenceThread.generate_thread(GameState.choices_for_day(day), night_events)
	# If the only events were arc-driven (no same-day choice) the thread can be empty;
	# fall back to the full log so legitimately traceable multi-day chains still surface.
	if entries.is_empty() and not night_events.is_empty():
		entries = ConsequenceThread.generate_thread(full_log, night_events)
	GameState.set_meta("dawn_thread_entries", entries)

	# [5] Investment anchor (False Dawn anchor for Chapter 2).
	GameState.investment_anchor = ConsequenceThread.compute_investment_anchor(full_log)
