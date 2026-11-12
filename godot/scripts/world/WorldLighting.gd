class_name WorldLighting
extends Node3D
## WorldLighting — the clock the player sees (TIME_SYSTEM.md, GRAPHICS.md).
##
## There is no clock, no minute counter and no season label anywhere in the UI.
## The player reads time from this: the sun arcs east to west by day, the light
## goes warm then cold, a moon tracks the night, fog rises. The season is read the
## same way — saturation drains, the fog thickens, the key light turns blue.
##
## Pillar 4: day looks warm and falsely safe; night strips saturation and raises fog.

const DAY := {"key": Color(0.91, 0.78, 0.60), "energy": 1.45, "ambient": Color(0.66, 0.72, 0.78), "amb_e": 0.80,
	"bg": Color(0.60, 0.65, 0.68), "fog": Color(0.75, 0.75, 0.69), "fog_d": 0.0035, "sat": 0.88}
const DUSK := {"key": Color(0.98, 0.58, 0.36), "energy": 0.85, "ambient": Color(0.46, 0.42, 0.50), "amb_e": 0.45,
	"bg": Color(0.34, 0.27, 0.30), "fog": Color(0.42, 0.34, 0.36), "fog_d": 0.008, "sat": 0.80}
const NIGHT := {"key": Color(0.46, 0.54, 0.72), "energy": 0.62, "ambient": Color(0.20, 0.24, 0.36), "amb_e": 0.70,
	"bg": Color(0.06, 0.075, 0.115), "fog": Color(0.08, 0.10, 0.16), "fog_d": 0.006, "sat": 0.55}
const DAWN := {"key": Color(0.76, 0.76, 0.78), "energy": 0.75, "ambient": Color(0.52, 0.54, 0.60), "amb_e": 0.50,
	"bg": Color(0.44, 0.46, 0.50), "fog": Color(0.56, 0.58, 0.62), "fog_d": 0.011, "sat": 0.62}
const TITLE := {"key": Color(0.80, 0.52, 0.38), "energy": 0.6, "ambient": Color(0.30, 0.30, 0.40), "amb_e": 0.5,
	"bg": Color(0.16, 0.15, 0.20), "fog": Color(0.22, 0.20, 0.26), "fog_d": 0.013, "sat": 0.62}

var _sun: DirectionalLight3D
var _env: Environment
var _cur := {}


func _ready() -> void:
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 90.0
	_sun.shadow_bias = 0.06
	_sun.shadow_opacity = 0.62
	add_child(_sun)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.adjustment_enabled = true
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_cur = TITLE.duplicate()
	_apply(_cur)
	_sun.rotation_degrees = Vector3(-24.0, -60.0, 0.0)


func _target() -> Dictionary:
	if not TimeManager.is_running() and not GameState.chapter_complete:
		return TITLE
	var t := {}
	var base: Dictionary = DAY
	var p := TimeManager.phase_progress()
	match TimeManager.current_phase:
		TimeManager.Phase.DAY:
			# The last stretch of day already leans toward dusk.
			base = _mix(DAY, DUSK, clampf((p - 0.82) / 0.18, 0.0, 1.0) * 0.6)
		TimeManager.Phase.DUSK:
			base = _mix(DUSK, NIGHT, clampf((p - 0.55) / 0.45, 0.0, 1.0) * 0.7)
		TimeManager.Phase.NIGHT:
			base = _mix(NIGHT, DAWN, clampf((p - 0.93) / 0.07, 0.0, 1.0) * 0.5)
		TimeManager.Phase.DAWN:
			base = _mix(DAWN, DAY, clampf((p - 0.6) / 0.4, 0.0, 1.0) * 0.7)
	t = base.duplicate()
	# Season: read from the light, never from a label.
	match GameState.season:
		"turning":
			t["fog_d"] = float(t["fog_d"]) * 1.5
			t["sat"] = float(t["sat"]) * 0.82
			t["key"] = (t["key"] as Color).lerp(Color(0.80, 0.74, 0.56), 0.35)
		"deep_winter":
			t["fog_d"] = float(t["fog_d"]) * 2.0
			t["sat"] = float(t["sat"]) * 0.58
			t["key"] = (t["key"] as Color).lerp(Color(0.55, 0.60, 0.75), 0.6)
			t["energy"] = float(t["energy"]) * 0.85
	return t


func _mix(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var out := {}
	for k in a:
		if a[k] is Color:
			out[k] = (a[k] as Color).lerp(b[k], w)
		else:
			out[k] = lerpf(float(a[k]), float(b[k]), w)
	return out


func _apply(s: Dictionary) -> void:
	_sun.light_color = s["key"]
	_sun.light_energy = float(s["energy"])
	_env.ambient_light_color = s["ambient"]
	_env.ambient_light_energy = float(s["amb_e"])
	_env.background_color = s["bg"]
	_env.fog_light_color = s["fog"]
	_env.fog_density = float(s["fog_d"])
	_env.adjustment_saturation = float(s["sat"])


func _process(delta: float) -> void:
	# The transition is punctuation: night arrives over a few seconds, it does not cut.
	_cur = _mix(_cur, _target(), clampf(delta * 0.9, 0.0, 1.0))
	_apply(_cur)
	if not TimeManager.is_running():
		return
	var p := TimeManager.phase_progress()
	var goal := _sun.rotation_degrees
	match TimeManager.current_phase:
		TimeManager.Phase.DAY:
			goal = Vector3(-lerpf(22.0, 62.0, sin(p * PI)), lerpf(-78.0, 78.0, p), 0.0)
		TimeManager.Phase.DUSK:
			goal = Vector3(-lerpf(22.0, 12.0, p), 80.0, 0.0)
		TimeManager.Phase.NIGHT:
			# The moon rises and tracks.
			goal = Vector3(-lerpf(28.0, 58.0, sin(p * PI)), lerpf(-250.0, -110.0, p), 0.0)
		TimeManager.Phase.DAWN:
			goal = Vector3(-lerpf(10.0, 22.0, p), -80.0, 0.0)
	_sun.rotation_degrees = _sun.rotation_degrees.lerp(goal, clampf(delta * 0.8, 0.0, 1.0))
