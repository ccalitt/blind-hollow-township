extends Node3D
## WorldLighting — day/night WorldEnvironment + DirectionalLight per GRAPHICS.md.
##
## Drives the palette/fog/light shift across phases (the player reads the clock from
## the light, not a UI number — TIME_SYSTEM.md "The Clock the Player Sees"). The 2.5s
## transition is narrative punctuation: night arrives, it does not cut.
##
## Pillar 4: day looks warm and falsely safe; night strips saturation and raises fog.

@onready var _sun: DirectionalLight3D = $Sun
@onready var _env: WorldEnvironment = $WorldEnvironment

# Day vs night light/fog targets (GRAPHICS.md color palette + fog).
const DAY_LIGHT := Color(0.91, 0.78, 0.60)
const NIGHT_LIGHT := Color(0.42, 0.48, 0.60)
const DAY_ENERGY := 1.4
const NIGHT_ENERGY := 0.5
const DAY_FOG := 0.015
const NIGHT_FOG := 0.06
const DAY_BG := Color(0.55, 0.58, 0.62)
const NIGHT_BG := Color(0.10, 0.12, 0.17)


func _ready() -> void:
	_apply_day(true)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.hour_ticked.connect(_on_hour_ticked)


func _on_phase_changed(new_phase: int, _day: int) -> void:
	match new_phase:
		TimeManager.Phase.NIGHT:
			_transition(NIGHT_LIGHT, NIGHT_ENERGY, NIGHT_FOG, NIGHT_BG, 2.5)
		TimeManager.Phase.DAWN:
			_transition(Color(0.78, 0.74, 0.70), 0.8, 0.03, Color(0.45, 0.44, 0.46), 2.5)
		TimeManager.Phase.DAY:
			_transition(DAY_LIGHT, DAY_ENERGY, DAY_FOG, DAY_BG, 2.5)


func _apply_day(_instant: bool) -> void:
	_sun.light_color = DAY_LIGHT
	_sun.light_energy = DAY_ENERGY
	var env := _env.environment
	if env:
		env.fog_enabled = true
		env.fog_density = DAY_FOG
		env.background_color = DAY_BG


func _transition(light_color: Color, energy: float, fog: float, bg: Color, dur: float) -> void:
	var env := _env.environment
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_sun, "light_color", light_color, dur)
	tween.tween_property(_sun, "light_energy", energy, dur)
	if env:
		tween.tween_property(env, "fog_density", fog, dur)
		tween.tween_property(env, "background_color", bg, dur)


func _on_hour_ticked(hour: int, phase: int) -> void:
	# Move the sun across the sky as a within-phase progress cue (no numbers shown).
	if phase == TimeManager.Phase.DAY:
		var t := float(hour) / 18.0
		_sun.rotation_degrees = Vector3(-lerpf(20.0, 70.0, t), -40.0 + t * 80.0, 0.0)
