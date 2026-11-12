extends Node
## EventBus — global signal hub (Autoload singleton).
##
## Decouples systems: the clock, the rule passes, the world and the UI talk through
## these signals rather than holding references to each other ("TimeManager emits,
## everything subscribes" — TIME_SYSTEM.md).
##
## Pillar 4 (Day/Night as Structural Argument): the phase signals here are the
## mechanical spine of RELIEF -> UNEASE -> COMPULSION.

# --- Phase / time -----------------------------------------------------------
signal phase_changed(new_phase: int, day: int)
signal hour_ticked(current_hour: int, phase: int)
## The single "night is coming" cue before the roster locks. No countdown exists.
signal night_roster_lock_warning()
signal season_changed(season: String, severity: float)
## Fired once, when the fifth dawn has finished saying what it has to say.
signal chapter_ended()
## A new session began or a saved one was restored; everything should rebuild.
signal session_started()

# --- Selection / interaction ------------------------------------------------
## Something in the world was clicked. target is an npc id, "rep_<faction>",
## "obj_ledger" or "obj_board".
signal target_selected(target: String)
signal selection_cleared()
signal roster_requested()

# --- Choices (logistics-as-moral, Pillar 3) ---------------------------------
signal choice_made(choice: Dictionary)
signal build_menu_toggled(open: bool)
signal building_type_selected(building_type: String)
signal building_placed(building_type: String, zone_id: String, cell: Vector2i)
signal placement_cancelled()
## Any state the world or panels render from has changed.
signal world_changed()
signal arrival_spawned(npc_id: String)

# --- Narrative log ----------------------------------------------------------
signal log_line(text: String, kind: String)

# --- Night / dawn -----------------------------------------------------------
signal night_began(day: int)
signal night_event_fired(event: Dictionary)
signal dawn_thread_ready(entries: Array)

# --- Pause (Gap 5) ----------------------------------------------------------
signal pause_toggled(paused: bool)
