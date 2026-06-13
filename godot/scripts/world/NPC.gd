class_name NPCNode
extends Node3D
## NPC.gd — a billboard NPC in the 3D township (GRAPHICS.md: 2D sprite in a 3D world).
##
## DECISION (GRAPHICS.md offered Sprite3D vs AnimatedSprite3D): we use a single
## Sprite3D with billboard = BILLBOARD_ENABLED and swap its texture on emotion
## change. Animation frames are out of scope for the offline slice; the four
## emotional states (neutral/afraid/angry/corrupted) are the readability target
## (Gap 9). Textures are generated in code (Placeholder.gd) — no hand-drawn art.
##
## Clicking the NPC emits EventBus.npc_selected (Observe-mode interaction,
## INTERACTION_MODEL §3). Faction reps emit faction_rep_selected instead.

@export var npc_id: String = ""

var _sprite: Sprite3D
var _area: Area3D
var _name_label: Label3D
var _last_emotion := ""


func setup(id: String) -> void:
	npc_id = id


func _ready() -> void:
	_build_visual()
	_refresh()
	EventBus.choice_made.connect(_on_world_changed)
	EventBus.night_event_fired.connect(_on_world_changed)
	EventBus.dawn_thread_ready.connect(_on_world_changed)


func _build_visual() -> void:
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.pixel_size = 0.03
	_sprite.position = Vector3(0, 1.2, 0)
	add_child(_sprite)

	_name_label = Label3D.new()
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.position = Vector3(0, 2.6, 0)
	_name_label.font_size = 28
	_name_label.outline_size = 6
	_name_label.modulate = Color(0.9, 0.9, 0.92)
	_name_label.visible = false  # name shows only on hover (INTERACTION_MODEL §1)
	add_child(_name_label)

	# Click target.
	_area = Area3D.new()
	_area.input_ray_pickable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 2.4, 1.2)
	shape.shape = box
	shape.position = Vector3(0, 1.2, 0)
	_area.add_child(shape)
	add_child(_area)
	_area.input_event.connect(_on_area_input)
	_area.mouse_entered.connect(func(): _name_label.visible = true)
	_area.mouse_exited.connect(func(): _name_label.visible = false)


func _refresh() -> void:
	var npc: Dictionary = GameState.npc_states.get(npc_id, {})
	if npc.is_empty():
		return
	_name_label.text = npc.get("name", npc_id)
	var emotion: String = npc.get("emotion", "neutral")
	if emotion != _last_emotion:
		_last_emotion = emotion
		var accent := _role_accent(npc.get("domain", ""))
		_sprite.texture = Placeholder.npc_texture(emotion, accent)


func _role_accent(domain: String) -> Color:
	match domain:
		"construction": return Color(0.75, 0.55, 0.30)
		"medicine": return Color(0.85, 0.85, 0.88)
		"logistics": return Color(0.55, 0.70, 0.50)
		"observation": return Color(0.50, 0.60, 0.78)
		"social": return Color(0.80, 0.70, 0.45)
	return Color(0.6, 0.6, 0.62)


func _on_area_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var npc: Dictionary = GameState.npc_states.get(npc_id, {})
		if npc.get("is_faction_rep", false):
			EventBus.faction_rep_selected.emit(npc.get("faction_id", ""))
		else:
			EventBus.npc_selected.emit(npc_id)


func _on_world_changed(_arg = null) -> void:
	_refresh()
