extends Node
## EventBus — global signal hub (Autoload singleton).
##
## Decouples systems: UI, world, time, and the rule passes all communicate
## through these signals rather than holding direct references to each other.
## Mirrors the "TimeManager emits, everything subscribes" model in TIME_SYSTEM.md
## and extends it to the whole slice.
##
## Pillar 4 (Day/Night as Structural Argument): the phase signals here are the
## mechanical spine of RELIEF -> UNEASE -> COMPULSION.

# --- Phase / time -----------------------------------------------------------
## Emitted whenever TimeManager advances to a new phase. phase is TimeManager.Phase.
signal phase_changed(new_phase: int, day: int)
## Fires once per in-game hour tick (for sun/light interpolation, ambience).
signal hour_ticked(current_hour: int, phase: int)
## Fires 60s before dusk closes — the single "night is coming" cue (no countdown UI).
signal night_roster_lock_warning()

# --- Selection / interaction ------------------------------------------------
## A world NPC was clicked. npc_id is the GameState key.
signal npc_selected(npc_id: String)
## A faction representative NPC was clicked.
signal faction_rep_selected(faction_id: String)
## Player clicked empty ground / pressed cancel — close any open context panel.
signal selection_cleared()

# --- Choices (logistics-as-moral, Pillar 3) ---------------------------------
## A choice was logged into GameState. payload mirrors backend ChoiceEntry fields.
signal choice_made(choice: Dictionary)
## Build menu toggled open/closed.
signal build_menu_toggled(open: bool)
## A building type was selected from the build menu (enters Place mode).
signal building_type_selected(building_type: String)
## A building was placed at a grid cell.
signal building_placed(building_type: String, zone_id: String, cell: Vector2i)

# --- Night / dawn -----------------------------------------------------------
## A pre-computed night event fired (served from the NightDirector queue).
signal night_event_fired(event: Dictionary)
## The dawn consequence thread is ready (after the first 60s of dawn).
## entries is an Array[Dictionary] of two-sentence threads (REVEAL_MECHANIC Option B).
signal dawn_thread_ready(entries: Array)

# --- Pause (Gap 5) ----------------------------------------------------------
## Pause state changed. When paused at night, the frozen township stays visible.
signal pause_toggled(paused: bool)
