extends Node3D
## CameraRig — the player's presence (GRAPHICS.md: no avatar; the camera is the player).
##
## Node layout (matches GRAPHICS.md):
##   CameraRig (this, Node3D — pans over the township centroid)
##   └─ Pivot (Node3D — Y rotation)
##      └─ Arm (Node3D — zoom distance)
##         └─ Camera3D (pitch locked 35-45°)
##
## Day phase: full pan/zoom/rotate. Night phase: pan/zoom only (INTERACTION_MODEL §5)
## — rotation still allowed (it is camera freedom, not an order), but no world orders.
## Pause (Gap 5) does not disable the camera; the frozen township stays inspectable.

const PAN_SPEED := 12.0
const ROTATE_SPEED := 1.5
const ZOOM_STEP := 2.0
const ZOOM_MIN := 8.0
const ZOOM_MAX := 30.0
const PITCH_DAY_DEG := 40.0
const PITCH_NIGHT_DEG := 45.0
const PAN_BOUNDS := 40.0

@onready var _pivot: Node3D = $Pivot
@onready var _arm: Node3D = $Pivot/Arm
@onready var _camera: Camera3D = $Pivot/Arm/Camera3D

var _zoom := 18.0
var _target_pitch := PITCH_DAY_DEG


func _ready() -> void:
	_apply_zoom()
	_apply_pitch(PITCH_DAY_DEG)
	EventBus.phase_changed.connect(_on_phase_changed)


func _process(delta: float) -> void:
	_handle_pan(delta)
	_handle_rotate(delta)
	# Smoothly approach the target pitch (day/night withdrawal, GRAPHICS.md 2.5s).
	var cur := rad_to_deg(-_arm.rotation.x)
	var next := lerpf(cur, _target_pitch, clampf(delta * 1.5, 0.0, 1.0))
	_apply_pitch(next)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_zoom_in"):
		_zoom = clampf(_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		_apply_zoom()
	elif event.is_action_pressed("cam_zoom_out"):
		_zoom = clampf(_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		_apply_zoom()


func _handle_pan(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("cam_pan_right") - Input.get_action_strength("cam_pan_left"),
		Input.get_action_strength("cam_pan_down") - Input.get_action_strength("cam_pan_up")
	)
	if input == Vector2.ZERO:
		return
	# Pan relative to the pivot's Y rotation so WASD feels screen-aligned.
	var basis := Basis(Vector3.UP, _pivot.rotation.y)
	var move := basis * Vector3(input.x, 0.0, input.y) * PAN_SPEED * delta
	position += move
	position.x = clampf(position.x, -PAN_BOUNDS, PAN_BOUNDS)
	position.z = clampf(position.z, -PAN_BOUNDS, PAN_BOUNDS)


func _handle_rotate(delta: float) -> void:
	var rot := Input.get_action_strength("cam_rotate_right") - Input.get_action_strength("cam_rotate_left")
	if rot != 0.0:
		_pivot.rotation.y += rot * ROTATE_SPEED * delta


func _apply_zoom() -> void:
	_arm.position = Vector3(0, 0, _zoom)


func _apply_pitch(deg: float) -> void:
	# Arm tilts down toward the township; camera looks back along the arm.
	_arm.rotation.x = -deg_to_rad(deg)


func _on_phase_changed(new_phase: int, _day: int) -> void:
	match new_phase:
		TimeManager.Phase.NIGHT:
			_target_pitch = PITCH_NIGHT_DEG
			_zoom = clampf(_zoom + 2.0, ZOOM_MIN, ZOOM_MAX)  # slight withdrawal
			_apply_zoom()
		TimeManager.Phase.DAY:
			_target_pitch = PITCH_DAY_DEG
