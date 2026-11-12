class_name TitleScreen
extends CanvasLayer
## TitleScreen — begin, or continue the one record that exists.
##
## There are no save slots (Pillar 3 kills "choice systems that allow replaying for
## the optimal branch"). Beginning again discards the previous record; that one
## destructive act asks twice. Nothing inside the game ever does.
##
## The only thing the player is asked about themselves is the name of whoever they
## were driving back to (WORLD_STATE §7). It is optional. The game never uses the
## player's own name (TONE.md).

signal begin_requested(anchor_name: String)
signal continue_requested()

const PACE_ORDER := ["standard", "full", "brisk"]
const PACE_TEXT := {
	"standard": "Pace: standard. A little over an hour.",
	"full": "Pace: full length. Twenty-five minute days.",
	"brisk": "Pace: brisk. For a second visit.",
}

var _root: Control
var _menu: VBoxContainer
var _prompt: VBoxContainer
var _name_edit: LineEdit
var _armed := false
var _ui: GameUI


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = get_parent().get("ui") as GameUI
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _ui.theme()
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.022, 0.03, 0.42)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var col := VBoxContainer.new()
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = 90
	col.offset_right = 640
	col.offset_top = -210
	col.offset_bottom = 250
	_root.add_child(col)
	col.add_child(_text("HOLLOW TOWNSHIP", 46, Color(0.95, 0.95, 0.96)))
	col.add_child(_text("Chapter One  —  Harrow's Crossing", 18, Color(0.72, 0.72, 0.75)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 34)
	col.add_child(gap)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 2)
	col.add_child(_menu)
	_prompt = VBoxContainer.new()
	_prompt.visible = false
	col.add_child(_prompt)
	_prompt.add_child(_text("You were driving back to someone. Who?", 20, Color(0.92, 0.92, 0.93)))
	_prompt.add_child(_text("It can be left blank.", 14, Color(0.62, 0.63, 0.66)))
	var g2 := Control.new()
	g2.custom_minimum_size = Vector2(0, 10)
	_prompt.add_child(g2)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 24
	_name_edit.custom_minimum_size = Vector2(320, 0)
	_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_name_edit.text_submitted.connect(func(_t): _go())
	_prompt.add_child(_name_edit)
	var g3 := Control.new()
	g3.custom_minimum_size = Vector2(0, 10)
	_prompt.add_child(g3)
	_button(_prompt, "Go on.", _go)
	var g4 := Control.new()
	g4.custom_minimum_size = Vector2(0, 16)
	_prompt.add_child(g4)
	# The only instruction the game gives, and it gives it before the game begins.
	_prompt.add_child(_text("W A S D to look around. Click a person, the ledger, the board.", 14, Color(0.58, 0.59, 0.62)))
	_prompt.add_child(_text("Esc is the manager's post. Space holds the world where it is.", 14, Color(0.58, 0.59, 0.62)))
	var g5 := Control.new()
	g5.custom_minimum_size = Vector2(0, 8)
	_prompt.add_child(g5)
	_button(_prompt, "Back.", func():
		_prompt.visible = false
		_menu.visible = true)
	var foot := _text("Every right choice arrives already compromised.", 14, Color(0.55, 0.56, 0.59))
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 90
	foot.offset_right = 700
	foot.offset_top = -52
	foot.offset_bottom = -28
	_root.add_child(foot)


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", _ui.serif())
	return l


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size = Vector2(420, 0)
	b.pressed.connect(func():
		Audio.play_cue("tick", 0.25)
		cb.call())
	parent.add_child(b)
	return b


func _rebuild_menu() -> void:
	for c in _menu.get_children():
		_menu.remove_child(c)
		c.queue_free()
	var has := SaveSystem.has_save()
	var finished := has and SaveSystem.save_is_finished()
	if has and not finished:
		_button(_menu, "Continue.", func(): continue_requested.emit())
	if has:
		_button(_menu, "Begin again. The last record is not kept." if _armed else "Begin again.", _begin)
	else:
		_button(_menu, "Begin.", _begin)
	_button(_menu, str(PACE_TEXT.get(str(SaveSystem.settings["pace"]), PACE_TEXT["standard"])), _cycle_pace)
	_button(_menu, "Sound: %d of 10." % int(round(float(SaveSystem.settings["volume"]) * 10.0)), _cycle_volume)
	_button(_menu, "Fullscreen: %s." % ("on" if bool(SaveSystem.settings["fullscreen"]) else "off"), _toggle_fullscreen)
	if not OS.has_feature("web"):
		_button(_menu, "Leave.", func(): get_tree().quit())


func _begin() -> void:
	if SaveSystem.has_save() and not _armed:
		_armed = true
		_rebuild_menu()
		return
	_menu.visible = false
	_prompt.visible = true
	_name_edit.text = ""
	_name_edit.grab_focus()


func _go() -> void:
	begin_requested.emit(_name_edit.text)


func _cycle_pace() -> void:
	var i := PACE_ORDER.find(str(SaveSystem.settings["pace"]))
	SaveSystem.settings["pace"] = PACE_ORDER[(i + 1) % PACE_ORDER.size()]
	SaveSystem.save_settings()
	_rebuild_menu()


func _cycle_volume() -> void:
	var v := float(SaveSystem.settings["volume"]) + 0.2
	if v > 1.01:
		v = 0.0
	SaveSystem.settings["volume"] = v
	SaveSystem.save_settings()
	_rebuild_menu()


func _toggle_fullscreen() -> void:
	SaveSystem.settings["fullscreen"] = not bool(SaveSystem.settings["fullscreen"])
	SaveSystem.save_settings()
	_rebuild_menu()


func show_title() -> void:
	_armed = false
	_root.visible = true
	_menu.visible = true
	_prompt.visible = false
	_rebuild_menu()


func hide_title() -> void:
	_root.visible = false
