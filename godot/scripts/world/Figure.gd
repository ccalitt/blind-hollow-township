class_name Figure
extends Node3D
## Figure — one person in the township: a billboard pixel sprite in a 3D world
## (GRAPHICS.md "2D sprite in a 3D world"), with a name that shows only on hover
## (INTERACTION_MODEL §1: hover shows the name only — no stats, no labels).
##
## Sprites are unshaded so they stay readable; the day/night desaturation that
## GRAPHICS.md specifies as a shader uniform is applied here as a modulate tint.

const PIXEL := 0.052
const WALK_SPEED := 4.2

var id: String = ""
var look_id: String = ""
var display_name: String = ""
var pick_radius := 0.9
var pick_height := 2.6

var _sprite: Sprite3D
var _label: Label3D
var _target: Vector3
var _emotion := ""
var _phase_t := 0.0
var _tint_target := Color(1, 1, 1)
var _bob := 0.0


func setup(figure_id: String, look: String, shown_name: String) -> void:
	id = figure_id
	look_id = look
	display_name = shown_name
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.pixel_size = PIXEL
	_sprite.position = Vector3(0, Art.H * PIXEL * 0.5, 0)
	add_child(_sprite)
	_label = Label3D.new()
	_label.text = shown_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0011
	_label.font_size = 30
	_label.outline_size = 8
	_label.modulate = Color(0.93, 0.93, 0.95)
	_label.outline_modulate = Color(0.05, 0.05, 0.06, 0.9)
	_label.position = Vector3(0, Art.H * PIXEL + 0.45, 0)
	_label.visible = false
	add_child(_label)
	set_emotion("neutral")
	_target = position


func set_emotion(emotion: String) -> void:
	if emotion == _emotion:
		return
	_emotion = emotion
	_sprite.texture = Art.figure(look_id, emotion)


func set_hover(on: bool) -> void:
	_label.visible = on


func set_tint(c: Color) -> void:
	_tint_target = c


func go_to(pos: Vector3, instant: bool = false) -> void:
	_target = pos
	if instant:
		position = pos


func at_rest() -> bool:
	return position.distance_to(_target) < 0.05


func _process(delta: float) -> void:
	_sprite.modulate = _sprite.modulate.lerp(_tint_target, clampf(delta * 1.2, 0.0, 1.0))
	var to := _target - position
	var d := to.length()
	if d > 0.05:
		var step := minf(d, WALK_SPEED * delta)
		position += to / d * step
		_bob += delta * 11.0
		_sprite.position.y = Art.H * PIXEL * 0.5 + absf(sin(_bob)) * 0.10
		_sprite.flip_h = to.x < 0.0
	else:
		_phase_t += delta
		# A corrupted figure sways. Everyone else stands.
		var sway := sin(_phase_t * 0.9) * 0.03 if _emotion == "corrupted" else 0.0
		_sprite.position.y = Art.H * PIXEL * 0.5 + sway
