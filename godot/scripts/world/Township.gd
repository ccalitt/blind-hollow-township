class_name Township
extends Node3D
## Township.gd — the map. Lays out the five zones (WORLD_STATE §5) as colored ground
## tiles on a grid, spawns the six named NPCs into their opening zones, and handles
## grid-snap building placement (Place mode, INTERACTION_MODEL §2).
##
## Spatial layout (top-down, +X east, +Z south), one zone per region:
##   zone_3 Eastern Ridge (east)      zone_5 Western Hollow (west, not buildable)
##   zone_1 Mill Quarter (north)      zone_2 Settlement Common (center)
##   zone_4 Incomplete Structure (between Common and the hollow — the hollow-facing site)
##
## Pillar 3: placement is pure logistics UI — no labels, no confirmation. The red
## ghost on an invalid cell is the only feedback ("Red means no").

const CELL := 4.0   # world units per grid cell

# Zone -> { origin(Vector3 of zone center), color, cells(Array[Vector2i] grid coords) }
var _zone_centers := {
	"zone_1": Vector3(0, 0, -18),
	"zone_2": Vector3(0, 0, 0),
	"zone_3": Vector3(20, 0, 0),
	"zone_4": Vector3(0, 0, 14),
	"zone_5": Vector3(-22, 0, 0),
}

const ZONE_COLORS := {
	"zone_1": Color(0.42, 0.40, 0.34),
	"zone_2": Color(0.46, 0.45, 0.42),
	"zone_3": Color(0.38, 0.44, 0.40),
	"zone_4": Color(0.48, 0.43, 0.34),
	"zone_5": Color(0.22, 0.26, 0.24),   # the hollow — darker, wrong
}

const NPC_SCENE := preload("res://scenes/NPC.tscn")
var _placing: bool = false
var _place_type: String = ""
var _ghost: MeshInstance3D
var _occupied: Dictionary = {}   # Vector2i -> true
var _buildings_root: Node3D
var _ground_root: Node3D
var _npc_root: Node3D


func _ready() -> void:
	_ground_root = Node3D.new()
	_ground_root.name = "Ground"
	add_child(_ground_root)
	_buildings_root = Node3D.new()
	_buildings_root.name = "Buildings"
	add_child(_buildings_root)
	_npc_root = Node3D.new()
	_npc_root.name = "NPCs"
	add_child(_npc_root)

	_build_zones()
	_spawn_npcs()
	_build_ghost()

	EventBus.building_type_selected.connect(_on_building_type_selected)
	EventBus.selection_cleared.connect(_cancel_placement)


# ── Zone tiles ──────────────────────────────────────────────────────────────

func _build_zones() -> void:
	for zone_id in _zone_centers:
		var center: Vector3 = _zone_centers[zone_id]
		var color: Color = ZONE_COLORS[zone_id]
		var plane := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(CELL * 3.0, CELL * 3.0)
		plane.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 1.0
		plane.material_override = mat
		plane.position = center
		_ground_root.add_child(plane)

		var label := Label3D.new()
		label.text = GameState.zones.get(zone_id, {}).get("name", zone_id)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = center + Vector3(0, 0.5, 0)
		label.font_size = 22
		label.outline_size = 5
		label.modulate = Color(0.85, 0.85, 0.88, 0.8)
		_ground_root.add_child(label)


# ── NPC spawning ────────────────────────────────────────────────────────────

func _spawn_npcs() -> void:
	for npc_id in GameState.npc_states:
		var npc: Dictionary = GameState.npc_states[npc_id]
		var node := NPC_SCENE.instantiate() as NPCNode
		node.name = "NPC_" + npc_id
		node.setup(npc_id)
		_npc_root.add_child(node)
		node.global_position = _zone_centers.get(npc.get("zone", "zone_2"), Vector3.ZERO) \
			+ _scatter(npc_id)
	# Reposition when assignments change so the world reflects the roster.
	EventBus.choice_made.connect(_reposition_npcs)


func _scatter(seed_str: String) -> Vector3:
	var h := seed_str.hash()
	var x := float((h % 7) - 3)
	var z := float(((h / 7) % 7) - 3)
	return Vector3(x, 0, z)


func _reposition_npcs(_choice: Dictionary) -> void:
	for child in _npc_root.get_children():
		var node := child as NPCNode
		if node == null:
			continue
		var zone: String = GameState.npc_states.get(node.npc_id, {}).get("zone", "zone_2")
		node.global_position = _zone_centers.get(zone, Vector3.ZERO) + _scatter(node.npc_id)


# ── Building placement (Place mode) ─────────────────────────────────────────

func _build_ghost() -> void:
	_ghost = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL * 0.8, 2.0, CELL * 0.8)
	_ghost.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.6, 0.8, 0.6, 0.5)
	_ghost.material_override = mat
	_ghost.visible = false
	add_child(_ghost)


func _on_building_type_selected(building_type: String) -> void:
	_placing = true
	_place_type = building_type
	_ghost.visible = true


func _cancel_placement() -> void:
	_placing = false
	_place_type = ""
	_ghost.visible = false


func _process(_delta: float) -> void:
	if not _placing:
		return
	# Only place during the Day phase (INTERACTION_MODEL §5: no building at night).
	if TimeManager.current_phase != TimeManager.Phase.DAY:
		_cancel_placement()
		return
	var hit: Variant = _ground_under_cursor()
	if hit == null:
		_ghost.visible = false
		return
	_ghost.visible = true
	var cell := _world_to_cell(hit)
	var snapped_pos := _cell_to_world(cell)
	_ghost.position = Vector3(snapped_pos.x, 1.0, snapped_pos.z)
	var zone_id := _zone_at(snapped_pos)
	var valid := _is_valid_cell(cell, zone_id)
	_set_ghost_valid(valid)


func _unhandled_input(event: InputEvent) -> void:
	if not _placing:
		return
	if event.is_action_pressed("cancel"):
		_cancel_placement()
		EventBus.build_menu_toggled.emit(false)
		return
	if event.is_action_pressed("select"):
		var hit: Variant = _ground_under_cursor()
		if hit == null:
			return
		var cell := _world_to_cell(hit)
		var snapped_pos := _cell_to_world(cell)
		var zone_id := _zone_at(snapped_pos)
		if not _is_valid_cell(cell, zone_id):
			return  # red means no — no tooltip, no explanation
		_place_building(cell, snapped_pos, zone_id)


func _place_building(cell: Vector2i, pos: Vector3, zone_id: String) -> void:
	_occupied[cell] = true
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL * 0.8, 2.0, CELL * 0.8)
	inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.28, 0.24)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.0
	inst.material_override = mat
	inst.position = Vector3(pos.x, 1.0, pos.z)
	_buildings_root.add_child(inst)
	# Building fades in over 1s (INTERACTION_MODEL §2). No notification.
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 1.0, 1.0)

	# Record the building and log the choice (logistics-as-moral, Pillar 3).
	GameState.buildings.append({
		"building_type": _place_type, "zone_id": zone_id,
		"cell": cell, "day_placed": GameState.current_day,
	})
	# DEBT delta: building adjacent to / facing the hollow feeds the Debt
	# (+0.10 per Zone-5 adjacency, TIME_SYSTEM.md DEBT model).
	var zone: Dictionary = GameState.zones.get(zone_id, {})
	var debt_delta := 0.10 if (zone.get("hollow_adjacent", false) or zone_id == "zone_4") else 0.0
	# Attribute the placement to whoever is assigned to that zone, so the dawn
	# consequence thread has a named NPC (Reveal Test gate 1). If no one is assigned,
	# the building still feeds the Debt but produces no thread (legitimate quiet edge).
	var assigned_npc := _named_npc_in_zone(zone_id)
	var npc_ids: Array = [assigned_npc] if assigned_npc != "" else []
	GameState.log_choice("place_building", "micro", npc_ids,
		{"zone_id": zone_id, "building_type": _place_type}, debt_delta)
	EventBus.building_placed.emit(_place_type, zone_id, cell)

	_cancel_placement()
	EventBus.build_menu_toggled.emit(false)


# ── Cursor / grid helpers ───────────────────────────────────────────────────

func _ground_under_cursor() -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	# Intersect with the y=0 ground plane.
	if absf(dir.y) < 0.0001:
		return null
	var t := -origin.y / dir.y
	if t < 0.0:
		return null
	return origin + dir * t


func _world_to_cell(world: Vector3) -> Vector2i:
	return Vector2i(roundi(world.x / CELL), roundi(world.z / CELL))


func _cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0.0, cell.y * CELL)


func _named_npc_in_zone(zone_id: String) -> String:
	# A real (non-faction-rep) NPC currently assigned to this zone.
	for npc_id in GameState.npc_states:
		var npc: Dictionary = GameState.npc_states[npc_id]
		if npc.get("is_faction_rep", false):
			continue
		if str(npc.get("zone", "")) == zone_id:
			return str(npc_id)
	return ""


func _zone_at(world: Vector3) -> String:
	var best := ""
	var best_d := 1e9
	for zone_id in _zone_centers:
		var d: float = world.distance_to(_zone_centers[zone_id])
		if d < best_d:
			best_d = d
			best = zone_id
	return best


func _is_valid_cell(cell: Vector2i, zone_id: String) -> bool:
	if _occupied.has(cell):
		return false
	var zone: Dictionary = GameState.zones.get(zone_id, {})
	# Cannot build in the hollow (Zone 5 has no build UI, WORLD_STATE §5).
	if not zone.get("buildable", true):
		return false
	return true


func _set_ghost_valid(valid: bool) -> void:
	var mat := _ghost.material_override as StandardMaterial3D
	mat.albedo_color = Color(0.6, 0.8, 0.6, 0.5) if valid else Color(0.85, 0.3, 0.3, 0.55)
