class_name CameraRig
extends Node3D
## CameraRig — the player's presence (GRAPHICS.md: no avatar; the camera is the player).
##
##   CameraRig (pans over the township)
##   └─ Pivot (Y rotation)
##      └─ Arm (zoom distance, pitch 35–45°)
##         └─ Camera3D (perspective, fov 70)
##
## Day: pan / zoom / rotate. Night: the same — the camera is the only freedom the
## player keeps (INTERACTION_MODEL §5). When something is logged at night the rig
## takes the camera to it while the text lands, then hands it back (GRAPHICS.md);
## the Surveyor holds it for eight seconds. This is a MODE, not disabled input, so
## pause still works and the frozen township stays inspectable (Gap 5).

enum Mode { PLAYER, SCRIPTED, RETURNING, TITLE }

const PAN_SPEED := 16.0
const ROTATE_SPEED := 1.5
const ZOOM_STEP := 2.0
const ZOOM_MIN := 8.0
const ZOOM_MAX := 34.0
const PITCH_DAY := 40.0
const PITCH_NIGHT := 45.0
const BOUNDS := Rect2(-34, -32, 72, 52)

var mode: int = Mode.TITLE
var _pivot: Node3D
var _arm: Node3D
var _camera: Camera3D
var _zoom := 27.0
var _zoom_target := 27.0
var _pitch := PITCH_DAY
var _pitch_target := PITCH_DAY
var _focus := Vector3.ZERO
var _focus_left := 0.0
var _return_pos := Vector3.ZERO
var _return_zoom := 27.0
var _day_zoom := -1.0
var _dragging := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pivot = Node3D.new()
	add_child(_pivot)
	_arm = Node3D.new()
	_pivot.add_child(_arm)
	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.far = 260.0
	_arm.add_child(_camera)
	_camera.make_current()
	position = Vector3(1.0, 0, -3.0)
	_apply()
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.night_event_fired.connect(_on_night_event)
	EventBus.session_started.connect(func(): set_mode(Mode.PLAYER))


func set_mode(m: int) -> void:
	mode = m
	if m == Mode.TITLE:
		_zoom_target = 30.0
		_pitch_target = 32.0
		position = Vector3(-4.0, 0, -2.0)
	elif m == Mode.PLAYER:
		_zoom_target = 30.0
		_pitch_target = PITCH_NIGHT if TimeManager.is_night() else PITCH_DAY
		position = Vector3(0.5, 0, -6.0)
		_pivot.rotation.y = 0.0


func _process(delta: float) -> void:
	match mode:
		Mode.TITLE:
			_pivot.rotation.y += delta * 0.035
		Mode.SCRIPTED:
			position = position.lerp(_focus, clampf(delta * 2.2, 0.0, 1.0))
			# The pause freezes the world; it also holds the camera where it was taken.
			if not get_tree().paused:
				_focus_left -= delta
			if _focus_left <= 0.0:
				mode = Mode.RETURNING
		Mode.RETURNING:
			# Hand the camera back where it was taken from. Any input takes it sooner.
			position = position.lerp(_return_pos, clampf(delta * 2.6, 0.0, 1.0))
			_zoom_target = _return_zoom
			var moving := Input.get_action_strength("cam_pan_right") + Input.get_action_strength("cam_pan_left") \
				+ Input.get_action_strength("cam_pan_up") + Input.get_action_strength("cam_pan_down")
			if position.distance_to(_return_pos) < 0.3 or moving > 0.0:
				mode = Mode.PLAYER
		Mode.PLAYER:
			_handle_pan(delta)
			_handle_rotate(delta)
	_zoom = lerpf(_zoom, _zoom_target, clampf(delta * 8.0, 0.0, 1.0))
	_pitch = lerpf(_pitch, _pitch_target, clampf(delta * 1.5, 0.0, 1.0))
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.TITLE:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_target = clampf(_zoom_target - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_target = clampf(_zoom_target + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		_pivot.rotation.y -= (event as InputEventMouseMotion).relative.x * 0.006
	elif event.is_action_pressed("cam_zoom_in"):
		_zoom_target = clampf(_zoom_target - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
	elif event.is_action_pressed("cam_zoom_out"):
		_zoom_target = clampf(_zoom_target + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)


func _handle_pan(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("cam_pan_right") - Input.get_action_strength("cam_pan_left"),
		Input.get_action_strength("cam_pan_down") - Input.get_action_strength("cam_pan_up"))
	if input == Vector2.ZERO:
		return
	var b := Basis(Vector3.UP, _pivot.rotation.y)
	position += b * Vector3(input.x, 0.0, input.y) * PAN_SPEED * (0.5 + _zoom / 40.0) * delta
	position.x = clampf(position.x, BOUNDS.position.x, BOUNDS.end.x)
	position.z = clampf(position.z, BOUNDS.position.y, BOUNDS.end.y)


func _handle_rotate(delta: float) -> void:
	var rot := Input.get_action_strength("cam_rotate_right") - Input.get_action_strength("cam_rotate_left")
	if rot != 0.0:
		_pivot.rotation.y += rot * ROTATE_SPEED * delta


func _apply() -> void:
	var p := deg_to_rad(_pitch)
	_arm.position = Vector3(0, _zoom * sin(p), _zoom * cos(p))
	_arm.rotation.x = -p


## Take the camera to a point for `seconds`, then hand it back.
func focus_on(point: Vector3, seconds: float) -> void:
	if mode == Mode.TITLE:
		return
	if mode == Mode.PLAYER:
		_return_pos = position
		_return_zoom = _zoom_target
	_focus = Vector3(clampf(point.x, BOUNDS.position.x, BOUNDS.end.x), 0, clampf(point.z, BOUNDS.position.y, BOUNDS.end.y))
	_focus_left = seconds
	mode = Mode.SCRIPTED


func _on_night_event(e: Dictionary) -> void:
	var key := str(e.get("focus", ""))
	if key == "":
		return
	var town := get_tree().get_first_node_in_group("township") as Township
	if town == null:
		return
	if key == "surveyor":
		# It is seen at the edge of visibility. Control returns after eight seconds.
		_zoom_target = ZOOM_MAX
		focus_on(Vector3(2.0, 0, -16.0) if str(e.get("surveyor", "")) == "walk" else Vector3(-16.0, 0, -8.0), 8.0)
	else:
		focus_on(town.focus_position(key), 4.5)


func _on_phase_changed(new_phase: int, _day: int) -> void:
	match new_phase:
		TimeManager.Phase.NIGHT:
			# Slight withdrawal: night is watched from further back.
			_pitch_target = PITCH_NIGHT
			_day_zoom = _zoom_target
			_zoom_target = clampf(_zoom_target + 3.0, ZOOM_MIN, ZOOM_MAX)
		TimeManager.Phase.DAWN:
			_pitch_target = PITCH_DAY
			if _day_zoom > 0.0:
				_zoom_target = _day_zoom
				_day_zoom = -1.0
