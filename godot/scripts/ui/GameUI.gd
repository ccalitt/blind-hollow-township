class_name GameUI
extends CanvasLayer
## GameUI — the logistics surface (INTERACTION_MODEL.md, GRAPHICS.md UI rules).
##
## Grey-and-white. No icons. No moral colour-coding. No confirmation dialogs. No
## post-choice summary. No clock, no day counter, no season label, no meters.
##
##   * Narrative log, bottom-left. Night events and the dawn consequence thread
##     land here in the same register, with no visual distinction between them
##     (REVEAL_MECHANIC §2).
##   * Context panel, right. Name, current assignment, one line of behavioral
##     state, and a plain text list of what can be done. Clicking an option is the
##     decision; the panel closes.
##   * Build list (B) and Night watch roster (R), bottom centre.
##   * Pause (Space / P): the world freezes. Nothing is drawn over it but one word.
##
## Pillar 3: this UI must make moral choices feel entirely like logistics. It never
## labels an option as dangerous, costly, or good, and it never says why not.

signal leave_requested()

const LOG_W := 560.0
const PANEL_W := 372.0

var _root: Control
var _log_scroll: ScrollContainer
var _log_box: VBoxContainer
var _context: PanelContainer
var _context_box: VBoxContainer
var _context_target := ""
var _build_panel: PanelContainer
var _roster: PanelContainer
var _roster_posts: VBoxContainer
var _roster_people: VBoxContainer
var _roster_confirm: Button
var _roster_selected := ""
var _bar: HBoxContainer
var _pause_label: Label
var _end_card: Control
var _fade: ColorRect
var _pending: Array = []        # [{text, kind, wait}]
var _pending_t := 0.0
var _ending := false
var _serif: Font
var _theme: Theme


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_theme()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme
	add_child(_root)
	_build_log()
	_build_context()
	_build_bar()
	_build_build_menu()
	_build_roster()
	_build_pause()
	_build_end_card()
	EventBus.log_line.connect(_on_log_line)
	EventBus.target_selected.connect(_on_target_selected)
	EventBus.selection_cleared.connect(_close_context)
	EventBus.world_changed.connect(_on_world_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.dawn_thread_ready.connect(_on_dawn_thread)
	EventBus.build_menu_toggled.connect(func(open): _build_panel.visible = open and GameState.current_phase == "day")
	EventBus.session_started.connect(_on_session_started)
	EventBus.chapter_ended.connect(func(): _ending = true)
	EventBus.roster_requested.connect(_open_roster)
	hide_game()


# ═══════════════════════════════════════════════════════════════════════════
# Look
# ═══════════════════════════════════════════════════════════════════════════

func _build_theme() -> void:
	_theme = Theme.new()
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Iowan Old Style", "Palatino Linotype", "DejaVu Serif", "Liberation Serif", "serif"])
	_serif = serif
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.075, 0.08, 0.088, 0.90)
	panel.border_color = Color(0.80, 0.80, 0.82, 0.22)
	panel.set_border_width_all(1)
	panel.set_content_margin_all(16)
	_theme.set_stylebox("panel", "PanelContainer", panel)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(1, 1, 1, 0.0)
	flat.set_content_margin_all(6)
	flat.content_margin_left = 8
	var hover := flat.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 1, 1, 0.09)
	var pressed := flat.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(1, 1, 1, 0.16)
	_theme.set_stylebox("normal", "Button", flat)
	_theme.set_stylebox("hover", "Button", hover)
	_theme.set_stylebox("pressed", "Button", pressed)
	_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	_theme.set_stylebox("disabled", "Button", flat)
	_theme.set_color("font_color", "Button", Color(0.86, 0.86, 0.88))
	_theme.set_color("font_hover_color", "Button", Color(1, 1, 1))
	_theme.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	_theme.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.52))
	_theme.set_font_size("font_size", "Button", 16)
	_theme.set_font_size("font_size", "Label", 16)
	_theme.set_color("font_color", "Label", Color(0.88, 0.88, 0.90))
	var edit := StyleBoxFlat.new()
	edit.bg_color = Color(0, 0, 0, 0.35)
	edit.border_color = Color(0.8, 0.8, 0.82, 0.35)
	edit.border_width_bottom = 1
	edit.set_content_margin_all(8)
	_theme.set_stylebox("normal", "LineEdit", edit)
	_theme.set_stylebox("focus", "LineEdit", edit)
	_theme.set_font_size("font_size", "LineEdit", 18)


func theme() -> Theme:
	return _theme


func serif() -> Font:
	return _serif


func _label(text: String, size: int = 16, color: Color = Color(0.88, 0.88, 0.90), use_serif: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if use_serif:
		l.add_theme_font_override("font", _serif)
	return l


func _option(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Audio.play_cue("tick", 0.25)
		cb.call())
	parent.add_child(b)
	return b


func _gap(parent: Control, h: float = 8.0) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)


# ═══════════════════════════════════════════════════════════════════════════
# Narrative log
# ═══════════════════════════════════════════════════════════════════════════

func _build_log() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.035, 0.04, 0.0))
	grad.set_color(1, Color(0.03, 0.035, 0.04, 0.72))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(1.0, 0.0)
	gt.fill_to = Vector2(0.25, 0.75)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.anchor_top = 1.0
	tr.anchor_bottom = 1.0
	tr.offset_top = -330
	tr.offset_right = LOG_W + 150.0
	_root.add_child(tr)
	_log_scroll = ScrollContainer.new()
	_log_scroll.anchor_top = 1.0
	_log_scroll.anchor_bottom = 1.0
	_log_scroll.offset_left = 22
	_log_scroll.offset_right = 22 + LOG_W
	_log_scroll.offset_top = -292
	_log_scroll.offset_bottom = -20
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_log_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_log_scroll)
	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_box.add_theme_constant_override("separation", 7)
	_log_scroll.add_child(_log_box)


func _add_log_label(text: String, kind: String, instant: bool) -> void:
	var color := Color(0.92, 0.92, 0.93)
	var size := 17
	match kind:
		"dim":
			color = Color(0.66, 0.67, 0.70)
		"day":
			color = Color(0.70, 0.70, 0.72)
			size = 14
		"dusk":
			color = Color(0.78, 0.74, 0.70)
		"voice":
			color = Color(0.90, 0.87, 0.80)
	if kind == "day" and _log_box.get_child_count() > 0:
		_gap(_log_box, 10)
	var l := _label(text.to_upper() if kind == "day" else text, size, color, true)
	l.custom_minimum_size = Vector2(LOG_W - 12.0, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_box.add_child(l)
	if not instant:
		l.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 0.9)
	while _log_box.get_child_count() > 90:
		var old := _log_box.get_child(0)
		_log_box.remove_child(old)
		old.queue_free()
	_scroll_log_down()


func _scroll_log_down() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_log_scroll):
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


func _on_log_line(text: String, kind: String) -> void:
	_add_log_label(text, kind, false)


func _rebuild_log() -> void:
	for c in _log_box.get_children():
		c.queue_free()
	var lines: Array = GameState.log_lines
	var from := maxi(0, lines.size() - 40)
	for i in range(from, lines.size()):
		_add_log_label(str(lines[i]["text"]), str(lines[i]["kind"]), true)


## Dawn: the thread lands line by line before input is accepted. Same register as
## the night log. No heading, no icon, no label.
func _on_dawn_thread(entries: Array) -> void:
	var day := GameState.current_day
	if GameState.has_flag("dawn_logged_%d" % day):
		return
	GameState.set_flag("dawn_logged_%d" % day)
	for e in entries:
		_pending.append({"text": str(e["sentence_1"]), "kind": "plain", "wait": 1.5})
		_pending.append({"text": str(e["sentence_2"]), "kind": "plain", "wait": 2.3})
	if day >= Chapter.LAST_DAY:
		for l in DawnThread.closing_lines():
			_pending.append({"text": str(l), "kind": "dim", "wait": 2.4})


# ═══════════════════════════════════════════════════════════════════════════
# Context panel
# ═══════════════════════════════════════════════════════════════════════════

func _build_context() -> void:
	_context = PanelContainer.new()
	_context.anchor_left = 1.0
	_context.anchor_right = 1.0
	_context.offset_left = -PANEL_W - 22
	_context.offset_right = -22
	_context.offset_top = 22
	_context.visible = false
	_root.add_child(_context)
	_context_box = VBoxContainer.new()
	_context_box.add_theme_constant_override("separation", 3)
	_context.add_child(_context_box)


func _close_context() -> void:
	_context.visible = false
	_context_target = ""


func _on_target_selected(target: String) -> void:
	if TimeManager.input_locked:
		return
	_roster.visible = false
	_build_panel.visible = false
	_show_panel(target)


func _show_panel(target: String) -> void:
	var p: Dictionary = Chapter.panel(target) if target != "desk" else _desk_panel()
	if p.is_empty():
		_close_context()
		return
	_context_target = target
	for c in _context_box.get_children():
		_context_box.remove_child(c)
		c.queue_free()
	_context_box.add_child(_label(str(p["title"]), 22, Color(0.96, 0.96, 0.97), true))
	if str(p.get("subtitle", "")) != "":
		_context_box.add_child(_label(str(p["subtitle"]), 13, Color(0.60, 0.61, 0.64)))
	_gap(_context_box, 8)
	for line in p["lines"]:
		var dim: bool = bool(line["dim"])
		var l := _label(str(line["text"]), 14 if dim else 16, Color(0.64, 0.65, 0.68) if dim else Color(0.90, 0.90, 0.91), not dim)
		l.custom_minimum_size = Vector2(PANEL_W - 34.0, 0)
		_context_box.add_child(l)
		if not dim:
			_gap(_context_box, 4)
	var opts: Array = p["options"]
	if not opts.is_empty():
		_gap(_context_box, 8)
		var rule := ColorRect.new()
		rule.color = Color(1, 1, 1, 0.12)
		rule.custom_minimum_size = Vector2(0, 1)
		_context_box.add_child(rule)
		_gap(_context_box, 4)
		for o in opts:
			var b := _option(_context_box, str(o["text"]), _choose.bind(o))
			b.custom_minimum_size = Vector2(PANEL_W - 34.0, 0)
	_context.visible = true
	_fit_context()


## Wrapped labels report their height a frame late; shrink the panel once they have.
func _fit_context() -> void:
	_context.reset_size()
	await get_tree().process_frame
	if is_instance_valid(_context):
		_context.reset_size()
	await get_tree().process_frame
	if is_instance_valid(_context):
		_context.reset_size()


func _choose(opt: Dictionary) -> void:
	if str(opt.get("act", "")) == "desk":
		_desk_act(str(opt["id"]))
		return
	if TimeManager.input_locked or get_tree().paused:
		return
	var target := _context_target
	Chapter.choose(opt)
	# The panel closes on a decision. It stays only where the person answers.
	var act := str(opt.get("act", ""))
	var keeps: bool = act == "talk" or (act == "simple" and str(opt.get("id", "")) in ["peder_foundation_asked"])
	if keeps:
		_show_panel(target)
	else:
		_close_context()


func _on_world_changed() -> void:
	if _roster.visible:
		_refresh_roster()


## The manager's post: the only "menu" in play, and it is a context panel like any other.
func _desk_panel() -> Dictionary:
	var vol := int(round(float(SaveSystem.settings["volume"]) * 10.0))
	return {"title": "The manager's post", "subtitle": "Harrow's Crossing",
		"lines": [
			{"text": "Pan with W A S D or the arrow keys. Turn with Q and E. The wheel draws the view in and out.", "dim": true},
			{"text": "B opens the build list. R opens the night watch. Space holds the world where it is.", "dim": true},
			{"text": "Sound: %d of 10." % vol, "dim": true},
		],
		"options": [
			{"act": "desk", "id": "quieter", "text": "Quieter."},
			{"act": "desk", "id": "louder", "text": "Louder."},
			{"act": "desk", "id": "leave", "text": "Stop here for now."},
		]}


func _desk_act(id: String) -> void:
	match id:
		"quieter":
			SaveSystem.settings["volume"] = clampf(float(SaveSystem.settings["volume"]) - 0.1, 0.0, 1.0)
			SaveSystem.save_settings()
			_show_panel("desk")
		"louder":
			SaveSystem.settings["volume"] = clampf(float(SaveSystem.settings["volume"]) + 0.1, 0.0, 1.0)
			SaveSystem.save_settings()
			_show_panel("desk")
		"leave":
			_close_context()
			leave_requested.emit()


# ═══════════════════════════════════════════════════════════════════════════
# Bottom bar, build list
# ═══════════════════════════════════════════════════════════════════════════

func _build_bar() -> void:
	_bar = HBoxContainer.new()
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = -130
	_bar.offset_right = 130
	_bar.offset_top = -58
	_bar.offset_bottom = -20
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_theme_constant_override("separation", 10)
	_root.add_child(_bar)
	for item in [["Build", _toggle_build], ["Night watch", _toggle_roster]]:
		var holder := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.075, 0.08, 0.088, 0.86)
		sb.border_color = Color(0.8, 0.8, 0.82, 0.22)
		sb.set_border_width_all(1)
		sb.set_content_margin_all(2)
		holder.add_theme_stylebox_override("panel", sb)
		_bar.add_child(holder)
		var b := _option(holder, str(item[0]), item[1])
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(116, 30)


func _build_build_menu() -> void:
	_build_panel = PanelContainer.new()
	_build_panel.anchor_left = 0.5
	_build_panel.anchor_right = 0.5
	_build_panel.anchor_top = 1.0
	_build_panel.anchor_bottom = 1.0
	_build_panel.offset_left = -150
	_build_panel.offset_right = 150
	_build_panel.offset_top = -262
	_build_panel.offset_bottom = -70
	_build_panel.visible = false
	_root.add_child(_build_panel)
	var box := VBoxContainer.new()
	_build_panel.add_child(box)
	# Names only. No stats. No effects. The player does not know what a building
	# does to the world until it does it (INTERACTION_MODEL §2).
	for bt in Content.BUILD_ORDER:
		_option(box, str(bt), _pick_building.bind(str(bt)))


func _toggle_build() -> void:
	# At night the list does not open. Nothing says why.
	if GameState.current_phase != "day" or TimeManager.input_locked:
		return
	_roster.visible = false
	_close_context()
	_build_panel.visible = not _build_panel.visible
	if not _build_panel.visible:
		EventBus.placement_cancelled.emit()


func _pick_building(building_type: String) -> void:
	_build_panel.visible = false
	EventBus.building_type_selected.emit(building_type)


# ═══════════════════════════════════════════════════════════════════════════
# Night watch roster (NIGHT_SURVIVAL — the primary pre-night decision surface)
# ═══════════════════════════════════════════════════════════════════════════

func _build_roster() -> void:
	_roster = PanelContainer.new()
	_roster.anchor_left = 0.5
	_roster.anchor_right = 0.5
	_roster.anchor_top = 0.5
	_roster.anchor_bottom = 0.5
	_roster.offset_left = -480
	_roster.offset_right = 270
	_roster.offset_top = -330
	_roster.offset_bottom = 250
	_roster.visible = false
	_root.add_child(_roster)
	var outer := VBoxContainer.new()
	_roster.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var title := _label("Night watch", 22, Color(0.96, 0.96, 0.97), true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := _option(head, "Close", func(): _roster.visible = false)
	close.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gap(outer, 6)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(cols)
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(390, 450)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(left_scroll)
	_roster_posts = VBoxContainer.new()
	_roster_posts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_posts.add_theme_constant_override("separation", 0)
	left_scroll.add_child(_roster_posts)
	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(290, 450)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(right_scroll)
	_roster_people = VBoxContainer.new()
	_roster_people.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_people.add_theme_constant_override("separation", 0)
	right_scroll.add_child(_roster_people)
	_gap(outer, 6)
	_roster_confirm = _option(outer, "Post the watch.", _confirm_roster)
	_roster_confirm.alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _toggle_roster() -> void:
	if _roster.visible:
		_roster.visible = false
	else:
		_open_roster()


func _open_roster() -> void:
	# Once the watch is posted the roster cannot be reopened. Nothing says so.
	if not Chapter.roster_open() or TimeManager.input_locked:
		return
	_build_panel.visible = false
	EventBus.placement_cancelled.emit()
	_close_context()
	_roster_selected = ""
	_roster.visible = true
	_refresh_roster()


func _refresh_roster() -> void:
	var data: Dictionary = Chapter.roster_panel()
	for c in _roster_posts.get_children():
		_roster_posts.remove_child(c)
		c.queue_free()
	for c in _roster_people.get_children():
		_roster_people.remove_child(c)
		c.queue_free()
	for row in data["posts"]:
		var pid := str(row["post_id"])
		var text := "%s\n%s" % [str(row["name"]), str(row["status"])]
		if str(row["holder"]) != "":
			text += " — %s" % str(row["holder"])
		# Night 2+: one descriptor of what happened at this post last night. No explanation.
		if str(row["last"]) != "" and GameState.current_day >= 2:
			text += "\nLast night: %s" % str(row["last"])
		var b := _option(_roster_posts, text, _select_post.bind(pid))
		b.custom_minimum_size = Vector2(380, 0)
		if pid == _roster_selected:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1, 1, 1, 0.13)
			sb.set_content_margin_all(6)
			sb.content_margin_left = 8
			b.add_theme_stylebox_override("normal", sb)
	if _roster_selected == "":
		# Everyone who can stand a watch, and where they stand now.
		for person in data["people"]:
			var where := "in the bunks"
			if str(person["post_id"]) != "":
				where = "on %s" % Chapter.post_name(str(person["post_id"])).split(",")[0]
			var pl := _label("%s  —  %s\n%s" % [str(person["name"]), where, str(person["line"])], 14, Color(0.72, 0.73, 0.76))
			pl.custom_minimum_size = Vector2(280, 0)
			_roster_people.add_child(pl)
			_gap(_roster_people, 6)
	else:
		for person in data["people"]:
			var t := str(person["name"])
			if str(person["post_id"]) != "" and str(person["post_id"]) != _roster_selected:
				t += "  —  on %s" % Chapter.post_name(str(person["post_id"])).split(",")[0]
			t += "\n" + str(person["line"])
			var pb := _option(_roster_people, t, _assign_post.bind(_roster_selected, str(person["npc_id"])))
			pb.custom_minimum_size = Vector2(280, 0)
			pb.add_theme_font_size_override("font_size", 14)
		_gap(_roster_people, 6)
		_option(_roster_people, "Leave it empty.", _assign_post.bind(_roster_selected, ""))
	_roster_confirm.visible = GameState.current_phase == "dusk"


func _select_post(post_id: String) -> void:
	_roster_selected = post_id
	_refresh_roster()


func _assign_post(post_id: String, npc_id: String) -> void:
	if get_tree().paused:
		return
	Chapter.set_post(post_id, npc_id)
	_refresh_roster()


func _confirm_roster() -> void:
	_roster.visible = false
	TimeManager.confirm_roster()


# ═══════════════════════════════════════════════════════════════════════════
# Pause, end of chapter
# ═══════════════════════════════════════════════════════════════════════════

func _build_pause() -> void:
	_pause_label = _label("held", 14, Color(0.70, 0.70, 0.74))
	_pause_label.position = Vector2(24, 18)
	_pause_label.visible = false
	_root.add_child(_pause_label)


func _toggle_pause() -> void:
	if not TimeManager.is_running():
		return
	var p := not get_tree().paused
	get_tree().paused = p
	_pause_label.visible = p
	EventBus.pause_toggled.emit(p)


func _build_end_card() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.022, 0.026, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	_end_card = VBoxContainer.new()
	_end_card.set_anchors_preset(Control.PRESET_CENTER)
	_end_card.offset_left = -260
	_end_card.offset_right = 260
	_end_card.offset_top = -120
	_end_card.offset_bottom = 120
	(_end_card as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	_end_card.visible = false
	_root.add_child(_end_card)
	# It does not say what was chosen, and it does not say what it meant.
	for item in [["HOLLOW TOWNSHIP", 15, Color(0.6, 0.6, 0.63)], ["Chapter One ends here.", 30, Color(0.95, 0.95, 0.96)],
			["The record is kept. Chapter Two inherits it.", 16, Color(0.7, 0.7, 0.73)]]:
		var l := _label(str(item[0]), int(item[1]), item[2], true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_end_card.add_child(l)
		_gap(_end_card, 10)
	_gap(_end_card, 20)
	var leave := _option(_end_card, "Leave.", func():
		_end_card.visible = false
		_fade.color.a = 0.0
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		leave_requested.emit())
	leave.alignment = HORIZONTAL_ALIGNMENT_CENTER


func _show_end_card() -> void:
	_ending = false
	_bar.visible = false
	_close_context()
	_roster.visible = false
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_fade, "color:a", 0.93, 5.0)
	tw.tween_callback(func():
		_end_card.modulate.a = 0.0
		_end_card.visible = true)
	tw.tween_property(_end_card, "modulate:a", 1.0, 2.5)


# ═══════════════════════════════════════════════════════════════════════════
# Session / phase / input
# ═══════════════════════════════════════════════════════════════════════════

func show_game() -> void:
	_root.visible = true
	_bar.visible = true
	_end_card.visible = false
	_fade.color.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_label.visible = false


func hide_game() -> void:
	_root.visible = false
	_pending = []
	_ending = false


func _on_session_started() -> void:
	_pending = []
	_ending = false
	_close_context()
	_roster.visible = false
	_build_panel.visible = false
	_rebuild_log()
	if GameState.chapter_complete and not TimeManager.is_running():
		_show_end_card()


func _on_phase_changed(new_phase: int, _day: int) -> void:
	_build_panel.visible = false
	match new_phase:
		TimeManager.Phase.DUSK:
			# The roster opens by itself. It can be dismissed. Dusk does not wait.
			_close_context()
			_open_roster()
		TimeManager.Phase.NIGHT:
			_roster.visible = false
			_close_context()
		TimeManager.Phase.DAWN:
			_close_context()
		TimeManager.Phase.DAY:
			if _context.visible:
				_show_panel(_context_target)


func _process(delta: float) -> void:
	if not _root.visible:
		return
	# Pending lines are held while the world is held (Gap 5).
	if not get_tree().paused and not _pending.is_empty():
		_pending_t -= delta
		if _pending_t <= 0.0:
			var item: Dictionary = _pending.pop_front()
			GameState.add_log(str(item["text"]), str(item["kind"]))
			_pending_t = float(item["wait"])
	if _ending and _pending.is_empty() and _pending_t <= 0.0:
		_show_end_card()
	elif _pending.is_empty() and _pending_t > 0.0:
		_pending_t -= delta


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or _end_card.visible:
		return
	if event.is_action_pressed("toggle_pause"):
		_toggle_pause()
	elif event.is_action_pressed("toggle_build"):
		_toggle_build()
	elif event.is_action_pressed("toggle_roster"):
		_toggle_roster()
	elif event.is_action_pressed("cancel"):
		if _roster.visible:
			_roster.visible = false
		elif _build_panel.visible:
			_build_panel.visible = false
		elif _context.visible:
			_close_context()
		elif event is InputEventKey:
			_show_panel("desk")
