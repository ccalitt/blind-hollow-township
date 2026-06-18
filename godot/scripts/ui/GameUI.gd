class_name GameUI
extends CanvasLayer
## GameUI — the whole HUD for the slice, built in code on a CanvasLayer.
##
## Implements the interaction model exactly (INTERACTION_MODEL.md):
##  - Build menu: single button bottom of screen + B hotkey. Icon-and-name list,
##    no stats, no effects (§2).
##  - NPC context panel (right side): name, current assignment, available
##    assignments as a plain TEXT LIST (not a dialogue tree), one behavioral state
##    line, plus the Day-1 first-conversation / bond options where applicable (§3).
##  - Faction panel (right side): text-list options, no moral framing (§4).
##  - Night phase: clicking an NPC shows name + state only, NO assignment options (§5).
##  - Dawn thread + night log: bottom-left narrative log, same register (REVEAL_MECHANIC).
##  - Pause indicator (Gap 5): the frozen township stays visible; we only show a faint
##    "[paused]" marker — not a menu, not a black screen.
##
## The UI never confirms, warns, labels weight, or summarizes (§6).

const ZONES := ["zone_1", "zone_2", "zone_3", "zone_4"]  # buildable zones for assignment
# Authored Day-1 build menu (icon-and-name only, no effects shown).
const BUILD_TYPES := ["Watchtower", "Secondary Processing Shed", "Storehouse", "Bunkhouse"]

var _context_panel: PanelContainer
var _context_box: VBoxContainer
var _build_panel: PanelContainer
var _build_box: VBoxContainer
var _log_box: VBoxContainer
var _log_scroll: ScrollContainer
var _phase_label: Label
var _pause_label: Label
var _build_button: Button

var _paused := false


func _ready() -> void:
	_build_phase_readout()
	_build_log()
	_build_build_menu()
	_build_context_panel()

	_log_line("Harrow's Crossing. Morning. The mill is running.", false)
	_log_line("The handover ledger is on the table. Fourteen names.", true)
	_log_line("Click an NPC to assign them. WASD to pan. Scroll to zoom.", true)

	EventBus.npc_selected.connect(_on_npc_selected)
	EventBus.faction_rep_selected.connect(_on_faction_rep_selected)
	EventBus.selection_cleared.connect(_hide_context)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.night_event_fired.connect(_on_night_event)
	EventBus.dawn_thread_ready.connect(_on_dawn_thread)
	EventBus.build_menu_toggled.connect(_set_build_menu_visible)
	EventBus.choice_made.connect(_on_choice_made)
	EventBus.night_roster_lock_warning.connect(_on_roster_warning)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_build"):
		_set_build_menu_visible(not _build_panel.visible)
	elif event.is_action_pressed("toggle_pause"):
		_toggle_pause()
	elif event.is_action_pressed("cancel"):
		_hide_context()


# ── Phase readout (sun/phase cue; the spec hides numbers, we show phase name) ─

func _build_phase_readout() -> void:
	_phase_label = Label.new()
	_phase_label.position = Vector2(16, 12)
	_phase_label.add_theme_font_size_override("font_size", 20)
	add_child(_phase_label)

	_pause_label = Label.new()
	_pause_label.position = Vector2(16, 40)
	_pause_label.text = "[paused — the world is still here]"
	_pause_label.modulate = Color(0.7, 0.7, 0.75)
	_pause_label.visible = false
	add_child(_pause_label)
	_update_phase_label()


func _update_phase_label() -> void:
	var phase: String = GameState.current_phase
	_phase_label.text = "Harrow's Crossing — Day %d — %s" % [GameState.current_day, phase.capitalize()]


# ── Narrative log (bottom-left) ─────────────────────────────────────────────

func _build_log() -> void:
	_log_scroll = ScrollContainer.new()
	_log_scroll.position = Vector2(16, 0)
	_log_scroll.size = Vector2(520, 220)
	_log_scroll.anchor_top = 1.0
	_log_scroll.anchor_bottom = 1.0
	_log_scroll.offset_top = -236
	_log_scroll.offset_bottom = -16
	add_child(_log_scroll)
	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_box)


func _log_line(text: String, dim: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(500, 0)
	label.modulate = Color(0.7, 0.7, 0.74) if dim else Color(0.9, 0.9, 0.92)
	_log_box.add_child(label)
	await get_tree().process_frame
	_log_scroll.scroll_vertical = int(_log_box.size.y)


# ── Build menu ──────────────────────────────────────────────────────────────

func _build_build_menu() -> void:
	_build_button = Button.new()
	_build_button.text = "Build  (B)"
	_build_button.anchor_top = 1.0
	_build_button.anchor_bottom = 1.0
	_build_button.anchor_left = 0.5
	_build_button.anchor_right = 0.5
	_build_button.offset_left = -60
	_build_button.offset_right = 60
	_build_button.offset_top = -52
	_build_button.offset_bottom = -16
	_build_button.pressed.connect(func(): _set_build_menu_visible(not _build_panel.visible))
	add_child(_build_button)

	_build_panel = PanelContainer.new()
	_build_panel.anchor_top = 1.0
	_build_panel.anchor_bottom = 1.0
	_build_panel.anchor_left = 0.5
	_build_panel.anchor_right = 0.5
	_build_panel.offset_left = -130
	_build_panel.offset_right = 130
	_build_panel.offset_top = -240
	_build_panel.offset_bottom = -60
	_build_panel.visible = false
	add_child(_build_panel)
	_build_box = VBoxContainer.new()
	_build_panel.add_child(_build_box)
	for bt in BUILD_TYPES:
		var btn := Button.new()
		btn.text = bt   # name only — no stats, no effects (INTERACTION_MODEL §2)
		btn.pressed.connect(_on_build_type_pressed.bind(bt))
		_build_box.add_child(btn)


func _set_build_menu_visible(v: bool) -> void:
	# Building is a day-phase action only.
	if v and TimeManager.current_phase != TimeManager.Phase.DAY:
		return
	_build_panel.visible = v


func _on_build_type_pressed(building_type: String) -> void:
	_build_panel.visible = false
	EventBus.building_type_selected.emit(building_type)


# ── Context panel (right side) — NPC and faction ────────────────────────────

func _build_context_panel() -> void:
	_context_panel = PanelContainer.new()
	_context_panel.anchor_left = 1.0
	_context_panel.anchor_right = 1.0
	_context_panel.anchor_top = 0.0
	_context_panel.anchor_bottom = 1.0
	_context_panel.offset_left = -360
	_context_panel.offset_right = -16
	_context_panel.offset_top = 16
	_context_panel.offset_bottom = -16
	_context_panel.visible = false
	add_child(_context_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	_context_panel.add_child(margin)
	_context_box = VBoxContainer.new()
	margin.add_child(_context_box)


func _clear_context() -> void:
	for c in _context_box.get_children():
		c.queue_free()


func _hide_context(_arg = null) -> void:
	_context_panel.visible = false
	_clear_context()


func _heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	_context_box.add_child(l)


func _line(text: String, dim: bool = true) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	l.modulate = Color(0.72, 0.72, 0.76) if dim else Color(0.92, 0.92, 0.95)
	_context_box.add_child(l)


func _option(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(320, 0)
	b.pressed.connect(cb)
	_context_box.add_child(b)


func _spacer() -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, 10)
	_context_box.add_child(s)


# ── NPC selection ───────────────────────────────────────────────────────────

func _on_npc_selected(npc_id: String) -> void:
	var npc: Dictionary = GameState.npc_states.get(npc_id, {})
	if npc.is_empty():
		return
	_context_panel.visible = true
	_clear_context()
	_heading(npc.get("name", npc_id))
	_line(npc.get("role", ""), true)
	_line("Currently: %s" % GameState.zones.get(npc.get("zone", ""), {}).get("name", "—"))
	_spacer()
	# One behavioral state line in the NPC's register (INTERACTION_MODEL §3).
	_line(_behavioral_line(npc_id), false)
	_spacer()

	# Night phase: name + state only, NO assignment options (INTERACTION_MODEL §5).
	if TimeManager.current_phase == TimeManager.Phase.NIGHT or TimeManager.current_phase == TimeManager.Phase.DUSK:
		_line("(no assignment available)", true)
		return

	# Day phase: available assignments as a plain text list.
	for zone_id in ZONES:
		var zone_name: String = GameState.zones.get(zone_id, {}).get("name", zone_id)
		_option(zone_name, _assign.bind(npc_id, zone_id))

	# Elias treeline-report option (CHAPTER_ONE Day 1 micro choice).
	if npc_id == "elias":
		_spacer()
		_option("Log the treeline report.", _elias_log.bind(npc_id))
		_option("Leave it unlogged.", _elias_ignore.bind(npc_id))

	# Peder foundation order (Hour 1:00 Day 1 — gives him an order).
	if npc_id == "peder":
		_spacer()
		_option("Send the crew to finish the fourth wall.", _peder_order.bind("peder_crew_zone4_fourth_wall", "zone_4"))
		_option("Reinforce the Mill Quarter instead.", _peder_order.bind("peder_crew_zone1_reinforce", "zone_1"))
		_option("Survey the western hollow perimeter.", _peder_order.bind("peder_crew_zone5_survey", "zone_5"))

	# Bond acknowledgment (Day 3+, co-assigned 2 days) — surfaced if eligible.
	var partner: String = npc.get("bond_partner", "")
	if GameState.current_day >= 3 and partner != "":
		_spacer()
		_option("Keep them working together.", _bond_ack.bind(npc_id, partner))


func _behavioral_line(npc_id: String) -> String:
	# Behavioral state line generated by the (offline) rule layer from arc + emotion +
	# significance. In production this is the NPC Behavior Agent. Here: authored register.
	var npc: Dictionary = GameState.npc_states[npc_id]
	var emotion: String = npc.get("emotion", "neutral")
	var sig: Dictionary = SignificancePass.significance_summary(npc_id)
	var carrying := false
	for z in sig.get("zone_modifiers", {}).values():
		if z == "weighted" or z == "carrying":
			carrying = true
	match npc_id:
		"elias":
			if emotion == "afraid": return "Stops mid-sentence. Starts again from the treeline."
			return "Sparse. Asks if the survey will be logged this time."
		"maren":
			if emotion == "afraid": return "Does not finish the sentence about the stockpiles."
			return "Fast. Wants to know how carefully you read."
		"thomas":
			if emotion == "afraid": return "Over-explains a cause that no one asked about."
			return "Precise. Deferential. Watching for cover."
		"ruth":
			return "Declarative. Watches your hands. Says nothing about the ledger yet."
		"peder":
			return "Talks about weight and load. Does not mention the foundation."
		"constance":
			return "Formal. Refers to a year, not an event. Waits."
	return "Carrying something." if carrying else "Working."


# ── Faction selection ───────────────────────────────────────────────────────

func _on_faction_rep_selected(faction_id: String) -> void:
	if TimeManager.current_phase != TimeManager.Phase.DAY:
		return
	var faction: Dictionary = GameState.factions.get(faction_id, {})
	if faction.is_empty():
		return
	_context_panel.visible = true
	_clear_context()
	_heading(faction.get("name", faction_id))
	_spacer()
	match faction_id:
		"association":
			# Hour 1:45 mid-weight choice (INTERACTION_MODEL §4 / WORLD_STATE §4).
			_line("The representative asks for the stockpile ledger.", false)
			_spacer()
			_option("Provide it unedited.", _assoc_choice.bind("association_ledger_unedited", -0.10, "Ledger provided unedited."))
			_option("Provide an edited version.", _assoc_choice.bind("association_ledger_edited", 0.15, "Edited ledger entered into record."))
			_option("Acknowledge the discrepancy without the document.", _assoc_choice.bind("association_ledger_acknowledge", 0.0, "Discrepancy acknowledged, no document."))
		"dix":
			_line("Dix requests a site inspection of the western hollow.", false)
			_spacer()
			_option("Approve the inspection.", _dix_choice.bind("dix_inspection_approved", -0.05, "Inspection approved."))
			_option("Delay the inspection. Safety conditions.", _dix_choice.bind("dix_inspection_delayed", 0.0, "Inspection delayed."))
			_option("Deny the request.", _dix_choice.bind("dix_inspection_denied", 0.10, "Inspection denied."))
		"compact":
			_line("The Compact has prepared a formal reception.", false)
			_spacer()
			_option("Accept the offered surplus.", _compact_choice.bind("compact_surplus_accepted", 0.20, "Compact surplus accepted."))
			_option("Thank them. Take nothing yet.", _compact_choice.bind("compact_surplus_declined", 0.0, "Surplus declined for now."))


# ── Choice callbacks (each logs into GameState; panel closes; no confirmation) ─

func _assign(npc_id: String, zone_id: String) -> void:
	GameState.assign_npc(npc_id, zone_id)
	GameState.log_choice("assign_npc", "micro", [npc_id], {"zone_id": zone_id})
	_hide_context()


func _elias_log(npc_id: String) -> void:
	GameState.log_choice("elias_report_logged", "micro", [npc_id], {"zone_id": "zone_3"})
	_hide_context()


func _elias_ignore(npc_id: String) -> void:
	GameState.set_npc_arc("elias", GameState.ARC_FRAGILE)
	GameState.log_choice("elias_report_ignored", "micro", [npc_id], {"zone_id": "zone_3"})
	_hide_context()


func _peder_order(action_type: String, zone_id: String) -> void:
	if zone_id == "zone_5":
		# Peder refuses the hollow survey (WORLD_STATE opening scene). Dix grateful.
		GameState.adjust_faction("dix", 0.15, "Hollow survey offered.")
		GameState.adjust_faction("compact", -0.10, "Manager pointed at the hollow.")
		GameState.log_choice(action_type, "micro", ["peder"], {"zone_id": zone_id})
		await _log_line("Peder declines, quietly. \"Ground's not right for it.\" He does not explain.", true)
	else:
		GameState.assign_npc("peder", zone_id)
		var debt := 0.10 if zone_id == "zone_4" else 0.0
		GameState.log_choice(action_type, "micro", ["peder"], {"zone_id": zone_id}, debt)
	_hide_context()


func _bond_ack(a: String, b: String) -> void:
	GameState.set_bond(a, b, GameState.npc_states[a].get("bond_depth", 0) + 1)
	GameState.log_choice("bond_acknowledge", "mid", [a, b], {})
	_hide_context()


func _assoc_choice(action_type: String, debt_delta: float, note: String) -> void:
	if action_type == "association_ledger_unedited":
		GameState.discrepancy_disclosed = true
		GameState.adjust_faction("association", 0.25, "Ledger disclosed.")
	elif action_type == "association_ledger_edited":
		GameState.adjust_faction("association", -0.10, "Edited ledger (undetected).")
	GameState.log_choice(action_type, "mid", ["maren"], {}, debt_delta)
	await _log_line(note, true)
	_hide_context()


func _dix_choice(action_type: String, debt_delta: float, note: String) -> void:
	if action_type == "dix_inspection_approved":
		GameState.dix_approved = true
		GameState.adjust_faction("dix", 0.20, "Inspection approved.")
		GameState.adjust_faction("compact", -0.15, "County will know within the day.")
	elif action_type == "dix_inspection_denied":
		GameState.adjust_faction("compact", 0.10, "Compact briefly grateful.")
	GameState.log_choice(action_type, "mid", ["constance"], {"zone_id": "zone_5"}, debt_delta)
	await _log_line(note, true)
	_hide_context()


func _compact_choice(action_type: String, debt_delta: float, note: String) -> void:
	if action_type == "compact_surplus_accepted":
		GameState.adjust_faction("compact", 0.20, "Surplus accepted.")
	GameState.log_choice(action_type, "mid", ["ruth"], {"zone_id": "zone_1"}, debt_delta)
	await _log_line(note, true)
	_hide_context()


# ── Phase / event / dawn handlers ───────────────────────────────────────────

func _on_phase_changed(new_phase: int, _day: int) -> void:
	_update_phase_label()
	_build_button.disabled = new_phase != TimeManager.Phase.DAY
	if new_phase != TimeManager.Phase.DAY:
		_build_panel.visible = false
	match new_phase:
		TimeManager.Phase.DUSK:
			_log_line("Dusk. The night watch roster opens. Confirm assignments.", true)
		TimeManager.Phase.NIGHT:
			_log_line("Night. The Debt arrives. You can only watch.", true)
		TimeManager.Phase.DAWN:
			_log_line("Dawn.", true)
		TimeManager.Phase.DAY:
			_log_line("— Day %d —" % GameState.current_day, false)


func _on_night_event(event: Dictionary) -> void:
	# Night event text in the NPC's register (no icon, no system tone).
	_log_line(str(event.get("event_text", "")), false)


func _on_dawn_thread(entries: Array) -> void:
	# Dawn consequence thread (REVEAL_MECHANIC Option B): two sentences per entry,
	# same register as the night log, no label marking it as a "consequence thread".
	if entries.is_empty():
		# Quiet night: the absence is information. We do not manufacture a thread.
		_log_line("The night was quiet. You do not know if that is safety.", true)
	else:
		for e in entries:
			_log_line(str(e.get("sentence1", "")), false)
			_log_line(str(e.get("sentence2", "")), false)
	if not TimeManager.is_running() and GameState.current_day >= TimeManager.LAST_CHAPTER_DAY:
		_log_line("— Chapter 1 holds, or it doesn't. (anchor: %s) —" % GameState.investment_anchor, true)


func _on_roster_warning() -> void:
	_log_line("The fire dims at the edges. Dusk is not patient.", true)


func _on_choice_made(_choice: Dictionary) -> void:
	pass  # placement/assignment feedback is in-world; the UI does not editorialize.


# ── Pause (Gap 5) ───────────────────────────────────────────────────────────

func _toggle_pause() -> void:
	_paused = not _paused
	_pause_label.visible = _paused
	EventBus.pause_toggled.emit(_paused)
