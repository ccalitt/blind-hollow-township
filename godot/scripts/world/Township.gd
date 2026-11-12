class_name Township
extends Node3D
## Township — Harrow's Crossing, built in code (WORLD_STATE §5, GRAPHICS.md).
##
## Lays out the five zones, the standing structures (mill, cabins, manager's post,
## the incomplete structure, the old ridge watchtower), the forest that is growing
## back, and the western hollow. Shows the people where they work by day and where
## they are posted by night, the buildings the player places, and — at night — what
## the day summoned: Hollow Walkers stepping in from the west, lamps that go out at
## the stores, a figure measuring the far boundary.
##
## Layout (+X east, +Z south). Zone 4 sits between the Common and the hollow, so
## building toward the structure reads as building toward the hollow.
##
##          river ─────────────────────────────
##               [ zone_1  Mill Quarter ]
##   hollow | [ zone_4 ]  [ zone_2 Common ]  [ zone_3 Eastern Ridge ]
##   zone_5 | structure        road
##
## Pillar 3: placement is logistics UI and nothing else. The ghost is pale when a
## cell will take a building and red when it will not. No reason is ever given.

const CELL := 3.0
const WORLD_HALF := 70.0
const HOLLOW_X := -27.0
## South of the Common is cut-over ground: stumps, and the road in. The forest stands back.
const SOUTH_EDGE := 36.0
const ZONE_RECTS := {
	"zone_1": Rect2(-9, -25, 23, 17),
	"zone_2": Rect2(-9, -7, 19, 17),
	"zone_3": Rect2(12, -7, 19, 20),
	"zone_4": Rect2(-24, -7, 13, 18),
}
const ZONE_CENTERS := {
	"zone_1": Vector3(2, 0, -13), "zone_2": Vector3(0, 0, 1), "zone_3": Vector3(21, 0, 3),
	"zone_4": Vector3(-16, 0, 4), "zone_5": Vector3(-30, 0, 2),
}
const POST_POS := {
	"post_ridge": Vector3(23.5, 0, -1.0), "post_west": Vector3(-25.0, 0, 2.0),
	"post_structure": Vector3(-14.0, 0, 3.5), "post_mill": Vector3(-3.5, 0, -12.5),
	"post_common": Vector3(1.5, 0, 2.5), "post_ledger": Vector3(6.0, 0, 6.5),
	"post_road": Vector3(0.5, 0, 12.5), "post_race": Vector3(11.0, 0, -22.0),
	"post_eastcut": Vector3(29.0, 0, 8.0), "post_stumps": Vector3(-17.0, 0, 11.5),
}
const LEDGER_POS := Vector3(7.5, 0, 4.2)
const BOARD_POS := Vector3(-4.5, 0, -2.5)
const ROAD_END := Vector3(0.5, 0, 14.0)
const REP_POS := {"compact": Vector3(-1.5, 0, -3.5), "association": Vector3(2.5, 0, -4.0), "dix": Vector3(4.5, 0, -1.0)}
## Cells the standing structures already occupy (cell = round(world / CELL)).
const BLOCKED_CELLS := [
	Vector2i(0, -6), Vector2i(1, -6), Vector2i(-1, -6), Vector2i(0, -5), Vector2i(1, -5), Vector2i(-1, -5), Vector2i(2, -6), Vector2i(2, -5),
	Vector2i(-2, 2), Vector2i(-2, -1), Vector2i(-1, 3), Vector2i(2, 1), Vector2i(3, 1), Vector2i(2, 2), Vector2i(3, 2), Vector2i(0, 0), Vector2i(0, 1),
	Vector2i(8, 0), Vector2i(-6, 0), Vector2i(-6, 1), Vector2i(-5, 0), Vector2i(-5, 1), Vector2i(-7, 0), Vector2i(-7, 1),
	Vector2i(0, 4), Vector2i(0, 3), Vector2i(-2, -1), Vector2i(-1, -1),
]
## The boundary walk: down the eastern cut line, along the near bank of the river,
## to the edge of the hollow. Open ground the whole way; never closer than this.
const SURVEYOR_PATH := [Vector3(31.5, 0, 10), Vector3(31.5, 0, -20), Vector3(26, 0, -25.6), Vector3(-21, 0, -25.6),
	Vector3(-26.0, 0, -20), Vector3(-26.0, 0, 1.0)]

var _ground_tex: ImageTexture
var _figures := {}            # id -> Figure
var _objects := {}            # id -> { pos, radius, height, label:Label3D }
var _building_nodes := {}     # building id -> Node3D
var _building_states := {}    # building id -> state string rendered
var _walker_nodes := {}       # walker id -> Node3D
var _lamp_nodes: Array = []
var _hover_id := ""
var _placing := false
var _place_type := ""
var _ghost: MeshInstance3D
var _mill_wheel: Node3D
var _fire_light: OmniLight3D
var _wall4: MeshInstance3D
var _trench: MeshInstance3D
var _creep_trees: MultiMeshInstance3D
var _creep_trunks: MultiMeshInstance3D
var _creep_count := 0
var _surveyor: MeshInstance3D
var _surveyor_mat: StandardMaterial3D
var _surveyor_state := ""
var _surveyor_t := 0.0
var _static_root: Node3D
var _dynamic_root: Node3D
var _people_root: Node3D
var _flicker_t := 0.0
var _drift_t := 2.0
var _flicker_next := 0.0
var _mill_lamps: Array = []
var _window_mats: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("township")
	_static_root = Node3D.new()
	add_child(_static_root)
	_dynamic_root = Node3D.new()
	add_child(_dynamic_root)
	_people_root = Node3D.new()
	add_child(_people_root)
	_build_ground()
	_build_forest()
	_build_mill()
	_build_common()
	_build_ridge()
	_build_structure()
	_build_ghost()
	_build_surveyor()
	_build_zone_names()
	EventBus.session_started.connect(_on_session_started)
	EventBus.world_changed.connect(_sync)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.building_type_selected.connect(_on_building_type_selected)
	EventBus.placement_cancelled.connect(_cancel_placement)
	EventBus.night_event_fired.connect(_on_night_event)
	EventBus.night_roster_lock_warning.connect(_on_roster_warning)
	_sync()


# ═══════════════════════════════════════════════════════════════════════════
# Geometry helpers
# ═══════════════════════════════════════════════════════════════════════════

static func zone_at(world: Vector3) -> String:
	if world.x < HOLLOW_X:
		return "zone_5"
	for zone_id in ZONE_RECTS:
		var r: Rect2 = ZONE_RECTS[zone_id]
		if r.has_point(Vector2(world.x, world.z)):
			return zone_id
	return ""


static func world_to_cell(world: Vector3) -> Vector2i:
	return Vector2i(roundi(world.x / CELL), roundi(world.z / CELL))


static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0.0, cell.y * CELL)


func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, radius_top: float, radius_bottom: float, height: float, pos: Vector3, material: Material, sides: int = 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_top
	mesh.bottom_radius = radius_bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


## A pitched roof as a three-sided prism lying along X.
func _roof(parent: Node3D, width: float, depth: float, height: float, pos: Vector3, material: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = Vector3(depth, height, width)
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation.y = rot_y + PI * 0.5
	parent.add_child(mi)
	return mi


func _cabin(parent: Node3D, pos: Vector3, size: Vector3, rot_y: float, wall: Color, lit_window: bool = true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)
	_box(root, size, Vector3(0, size.y * 0.5, 0), Art.mat(wall))
	_roof(root, size.x + 0.5, size.z + 0.6, size.y * 0.55, Vector3(0, size.y + size.y * 0.275, 0), Art.mat(Color(0.20, 0.17, 0.15)))
	_box(root, Vector3(0.8, 1.5, 0.08), Vector3(-size.x * 0.2, 0.75, size.z * 0.5 + 0.03), Art.mat(Color(0.16, 0.12, 0.10)))
	if lit_window:
		var wm := Art.mat(Color(0.16, 0.16, 0.18), 0.6, Color(1.0, 0.72, 0.36), 0.01)
		_window_mats.append(wm)
		_box(root, Vector3(0.7, 0.6, 0.08), Vector3(size.x * 0.22, size.y * 0.6, size.z * 0.5 + 0.03), wm)
	return root


func _label_for(text: String, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = 30
	l.outline_size = 8
	l.modulate = Color(0.93, 0.93, 0.95)
	l.outline_modulate = Color(0.05, 0.05, 0.06, 0.9)
	l.position = pos
	l.visible = false
	add_child(l)
	return l


## Place names, faint, so "Eastern Ridge" in a task list is a place the player can find.
func _build_zone_names() -> void:
	const AT := {"zone_1": Vector3(9.5, 0, -10.5), "zone_2": Vector3(4.0, 0, -5.5), "zone_3": Vector3(21, 0, 11.6),
		"zone_4": Vector3(-17.5, 0, 9.0), "zone_5": Vector3(-33.0, 0, 6.0)}
	for zone_id in AT:
		var l := Label3D.new()
		l.text = GameState.zone_name(zone_id).to_upper()
		l.rotation.x = -PI * 0.5
		l.pixel_size = 0.018
		l.font_size = 48
		l.outline_size = 0
		l.shaded = true
		l.modulate = Color(1.0, 0.98, 0.92, 0.40) if zone_id != "zone_5" else Color(0.75, 0.82, 0.80, 0.36)
		l.position = AT[zone_id] + Vector3(0, 0.06, 0)
		_static_root.add_child(l)


func _register_object(id: String, shown: String, pos: Vector3, radius: float, height: float) -> void:
	_objects[id] = {"pos": pos, "radius": radius, "height": height,
		"label": _label_for(shown, pos + Vector3(0, height + 0.4, 0))}


# ═══════════════════════════════════════════════════════════════════════════
# The standing world
# ═══════════════════════════════════════════════════════════════════════════

func _build_ground() -> void:
	var paths := [
		[Vector2(0.5, 30), Vector2(0.5, 4)], [Vector2(0.5, 2), Vector2(1, -10)],
		[Vector2(1, 1), Vector2(21, 1)], [Vector2(0, 2), Vector2(-15, 4)],
		[Vector2(-15, 4), Vector2(-24, 3)], [Vector2(1, -10), Vector2(10, -19)],
	]
	_ground_tex = Art.ground(280, WORLD_HALF, Township.zone_at, paths)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(WORLD_HALF * 2.0, WORLD_HALF * 2.0)
	plane.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_texture = _ground_tex
	m.roughness = 1.0
	plane.material_override = m
	_static_root.add_child(plane)
	# The river, north of the mill.
	var water := Art.mat(Color(0.20, 0.27, 0.31), 0.25)
	water.metallic = 0.2
	_box(_static_root, Vector3(WORLD_HALF * 2.0, 0.05, 4.0), Vector3(0, 0.02, -29.0), water)
	_box(_static_root, Vector3(WORLD_HALF * 2.0, 0.3, 0.6), Vector3(0, 0.05, -26.8), Art.mat(Color(0.30, 0.29, 0.25)))


func _in_clearing(x: float, z: float, margin: float) -> bool:
	return x > HOLLOW_X - margin and x < 33.0 + margin and z > -26.5 - margin and z < SOUTH_EDGE + margin


func _build_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4111
	var forest: Array = []
	var hollow: Array = []
	var creep: Array = []
	var gx := -WORLD_HALF
	while gx < WORLD_HALF:
		var gz := -WORLD_HALF
		while gz < WORLD_HALF:
			var x := gx + rng.randf_range(-1.6, 1.6)
			var z := gz + rng.randf_range(-1.6, 1.6)
			gz += 3.6
			if z > -31.5 and z < -26.5:
				continue  # the river
			if absf(x - 0.5) < 3.0 and z > 12.0:
				continue  # the road in
			var scale := rng.randf_range(0.8, 1.5)
			if x < HOLLOW_X and z > -26.0 and z < 15.0:
				# The western hollow: old growth, close together, taller than the rest.
				hollow.append([Vector3(x, 0, z), scale * 1.5, rng.randf()])
				if rng.randf() < 0.6:
					hollow.append([Vector3(x + rng.randf_range(-1.5, 1.5), 0, z + rng.randf_range(-1.5, 1.5)), scale * 1.2, rng.randf()])
			elif not _in_clearing(x, z, 0.0):
				forest.append([Vector3(x, 0, z), scale, rng.randf()])
			elif not _in_clearing(x, z, -4.2) and zone_at(Vector3(x, 0, z)) == "":
				# Inside the cut line: where the trees come back as the treeline moves.
				if z > 15.0 and x > -20.0:
					continue
				var depth := minf(minf(x - HOLLOW_X, 33.0 - x), minf(z + 26.5, SOUTH_EDGE - z))
				var west_bias := 0.0 if x < -20.0 else 1.5
				creep.append([Vector3(x, 0, z), scale * 0.75, rng.randf(), depth + west_bias])
		gx += 3.6
	_multimesh_trees(forest, Color(0.16, 0.25, 0.17), Color(0.22, 0.17, 0.13), false)
	_multimesh_trees(hollow, Color(0.07, 0.12, 0.10), Color(0.10, 0.09, 0.08), false)
	creep.sort_custom(func(a, b): return float(a[3]) < float(b[3]))
	var mm := _multimesh_trees(creep, Color(0.18, 0.27, 0.18), Color(0.22, 0.17, 0.13), true)
	_creep_trees = mm[0]
	_creep_trunks = mm[1]
	_creep_count = creep.size()
	# Stumps older than the oldest resident.
	for i in 150:
		var sx := rng.randf_range(HOLLOW_X + 0.5, 32.0)
		var sz := rng.randf_range(-25.5, SOUTH_EDGE - 1.0)
		if absf(sx - 0.5) < 2.0 and sz > 10.0:
			continue
		if zone_at(Vector3(sx, 0, sz)) in ["", "zone_3", "zone_4"]:
			var r := rng.randf_range(0.22, 0.38)
			_cyl(_static_root, r, r * 1.2, 0.34, Vector3(sx, 0.17, sz), Art.mat(Color(0.33, 0.27, 0.20)), 7)
			_cyl(_static_root, r * 0.9, r * 0.9, 0.02, Vector3(sx, 0.35, sz), Art.mat(Color(0.52, 0.44, 0.31)), 7)


func _multimesh_trees(list: Array, canopy: Color, trunk: Color, hidden: bool) -> Array:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.5
	cone.height = 5.2
	cone.radial_segments = 7
	cone.rings = 1
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.3
	trunk_mesh.height = 2.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	var out: Array = []
	for pass_i in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = cone if pass_i == 0 else trunk_mesh
		mm.instance_count = list.size()
		for i in list.size():
			var p: Vector3 = list[i][0]
			var s: float = list[i][1]
			var y := (1.6 + 2.6) * s if pass_i == 0 else 1.0 * s
			var b := Basis().scaled(Vector3(s, s, s))
			mm.set_instance_transform(i, Transform3D(b, Vector3(p.x, y, p.z)))
			var v: float = 0.82 + float(list[i][2]) * 0.36
			mm.set_instance_color(i, Color(v, v, v))
		if hidden:
			mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var m := Art.mat(canopy if pass_i == 0 else trunk)
		m.vertex_color_use_as_albedo = true
		mmi.material_override = m
		_static_root.add_child(mmi)
		out.append(mmi)
	return out


func _build_mill() -> void:
	var wood := Art.mat(Color(0.36, 0.28, 0.20))
	var dark := Art.mat(Color(0.20, 0.17, 0.15))
	var root := Node3D.new()
	root.position = Vector3(1.5, 0, -16.5)
	_static_root.add_child(root)
	_box(root, Vector3(9.5, 4.0, 5.2), Vector3(0, 2.0, 0), wood)
	_roof(root, 10.2, 6.0, 2.2, Vector3(0, 5.1, 0), dark)
	_box(root, Vector3(3.0, 2.6, 0.1), Vector3(-1.5, 1.3, 2.62), Art.mat(Color(0.10, 0.09, 0.08)))
	# Secondary processing lean-to.
	_box(root, Vector3(4.2, 2.4, 3.4), Vector3(6.6, 1.2, 0.6), Art.mat(Color(0.33, 0.27, 0.20)))
	_box(root, Vector3(4.6, 0.15, 3.9), Vector3(6.6, 2.5, 0.6), dark)
	# The wheel, on the river side.
	_mill_wheel = Node3D.new()
	_mill_wheel.position = Vector3(-1.0, 2.2, -3.4)
	root.add_child(_mill_wheel)
	for i in 8:
		var spoke := _box(_mill_wheel, Vector3(0.14, 4.2, 0.5), Vector3.ZERO, dark)
		spoke.rotation.z = float(i) * PI / 8.0
	var rim := _cyl(_mill_wheel, 2.1, 2.1, 0.5, Vector3.ZERO, Art.mat(Color(0.26, 0.21, 0.16)), 16)
	rim.rotation.x = PI * 0.5
	# The race that feeds it.
	_box(_static_root, Vector3(1.4, 0.06, 7.5), Vector3(0.5, 0.03, -23.4), Art.mat(Color(0.20, 0.27, 0.31), 0.3))
	# Cordwood and saw logs.
	for i in 5:
		var log := _cyl(_static_root, 0.3, 0.3, 4.0, Vector3(-5.5 + float(i) * 0.65, 0.3, -11.0), Art.mat(Color(0.42, 0.32, 0.22)), 7)
		log.rotation.x = PI * 0.5
	for i in 3:
		var log2 := _cyl(_static_root, 0.3, 0.3, 4.0, Vector3(-5.2 + float(i) * 0.65, 0.85, -11.0), Art.mat(Color(0.40, 0.30, 0.20)), 7)
		log2.rotation.x = PI * 0.5
	# Stores door lamps (the ones that go out).
	for off in [Vector3(-4.2, 2.4, -13.6), Vector3(4.0, 2.4, -13.6)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.70, 0.36)
		lamp.omni_range = 6.5
		lamp.light_energy = 0.0
		lamp.position = off
		_static_root.add_child(lamp)
		_mill_lamps.append(lamp)
		_box(_static_root, Vector3(0.16, 0.24, 0.16), off, Art.mat(Color(0.2, 0.18, 0.15), 0.5, Color(1.0, 0.72, 0.36), 0.01))


func _build_common() -> void:
	var wall := Color(0.40, 0.33, 0.25)
	_cabin(_static_root, Vector3(-6.2, 0, 5.5), Vector3(4.2, 2.5, 3.2), 0.25, wall)
	_cabin(_static_root, Vector3(-2.2, 0, 8.2), Vector3(4.2, 2.5, 3.2), -0.1, wall.darkened(0.08))
	_cabin(_static_root, Vector3(-6.0, 0, -2.6), Vector3(3.8, 2.6, 3.4), 0.0, Color(0.50, 0.47, 0.42))  # infirmary
	# The manager's post: one room, open front, facing the incomplete structure.
	var post := Node3D.new()
	post.position = Vector3(7.5, 0, 4.2)
	post.rotation.y = -PI * 0.5
	_static_root.add_child(post)
	var pm := Art.mat(Color(0.38, 0.32, 0.25))
	_box(post, Vector3(4.0, 2.6, 0.2), Vector3(0, 1.3, -1.6), pm)
	_box(post, Vector3(0.2, 2.6, 3.2), Vector3(-2.0, 1.3, 0), pm)
	_box(post, Vector3(0.2, 2.6, 3.2), Vector3(2.0, 1.3, 0), pm)
	_box(post, Vector3(4.6, 0.18, 4.0), Vector3(0, 2.7, 0.1), Art.mat(Color(0.20, 0.17, 0.15)))
	_box(post, Vector3(1.8, 0.1, 1.0), Vector3(0, 0.95, 0.1), Art.mat(Color(0.30, 0.24, 0.18)))
	_box(post, Vector3(0.12, 0.95, 0.12), Vector3(-0.8, 0.47, 0.4), pm)
	_box(post, Vector3(0.12, 0.95, 0.12), Vector3(0.8, 0.47, 0.4), pm)
	# The handover ledger, on the table.
	_box(post, Vector3(0.7, 0.1, 0.5), Vector3(0, 1.06, 0.1), Art.mat(Color(0.48, 0.16, 0.13)))
	_box(post, Vector3(0.6, 0.02, 0.42), Vector3(0, 1.12, 0.1), Art.mat(Color(0.88, 0.85, 0.76)))
	_register_object("obj_ledger", "The handover ledger", LEDGER_POS, 1.6, 1.4)
	# The township board.
	_box(_static_root, Vector3(0.14, 2.0, 0.14), BOARD_POS + Vector3(-0.8, 1.0, 0), Art.mat(Color(0.26, 0.21, 0.16)))
	_box(_static_root, Vector3(0.14, 2.0, 0.14), BOARD_POS + Vector3(0.8, 1.0, 0), Art.mat(Color(0.26, 0.21, 0.16)))
	_box(_static_root, Vector3(1.9, 1.1, 0.08), BOARD_POS + Vector3(0, 1.45, 0), Art.mat(Color(0.34, 0.28, 0.21)))
	_box(_static_root, Vector3(0.4, 0.5, 0.02), BOARD_POS + Vector3(-0.4, 1.5, 0.05), Art.mat(Color(0.86, 0.83, 0.74)))
	_box(_static_root, Vector3(0.4, 0.4, 0.02), BOARD_POS + Vector3(0.3, 1.4, 0.05), Art.mat(Color(0.80, 0.78, 0.70)))
	_register_object("obj_board", "The township board", BOARD_POS, 1.3, 2.0)
	# The fire in the Common.
	var fire_pos := Vector3(0.5, 0, 0.8)
	for i in 6:
		var a := float(i) * TAU / 6.0
		_box(_static_root, Vector3(0.3, 0.2, 0.3), fire_pos + Vector3(cos(a) * 0.6, 0.1, sin(a) * 0.6), Art.mat(Color(0.34, 0.33, 0.32)))
	_cyl(_static_root, 0.0, 0.28, 0.55, fire_pos + Vector3(0, 0.3, 0), Art.mat(Color(0.9, 0.5, 0.2), 0.5, Color(1.0, 0.55, 0.2), 1.6), 6)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.62, 0.30)
	_fire_light.omni_range = 9.0
	_fire_light.light_energy = 0.4
	_fire_light.position = fire_pos + Vector3(0, 1.0, 0)
	_static_root.add_child(_fire_light)
	# Road-end marker: two posts where the road stops being a road.
	_box(_static_root, Vector3(0.18, 1.3, 0.18), ROAD_END + Vector3(-1.6, 0.65, 0.5), Art.mat(Color(0.28, 0.23, 0.18)))
	_box(_static_root, Vector3(0.18, 1.3, 0.18), ROAD_END + Vector3(1.6, 0.65, 0.5), Art.mat(Color(0.28, 0.23, 0.18)))


func _tower(parent: Node3D, pos: Vector3, height: float, wood: Color) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var m := Art.mat(wood)
	for sx in [-0.9, 0.9]:
		for sz in [-0.9, 0.9]:
			_box(root, Vector3(0.2, height, 0.2), Vector3(sx, height * 0.5, sz), m)
	_box(root, Vector3(2.4, 0.16, 2.4), Vector3(0, height, 0), m)
	_box(root, Vector3(2.4, 0.5, 0.1), Vector3(0, height + 0.35, 1.15), m)
	_box(root, Vector3(2.4, 0.5, 0.1), Vector3(0, height + 0.35, -1.15), m)
	_box(root, Vector3(0.1, 0.5, 2.4), Vector3(1.15, height + 0.35, 0), m)
	_box(root, Vector3(0.1, 0.5, 2.4), Vector3(-1.15, height + 0.35, 0), m)
	_box(root, Vector3(2.8, 0.14, 2.8), Vector3(0, height + 1.9, 0), Art.mat(Color(0.20, 0.17, 0.15)))
	for sx in [-0.9, 0.9]:
		_box(root, Vector3(0.12, 1.9, 0.12), Vector3(sx, height + 0.95, -0.9), m)
		_box(root, Vector3(0.12, 1.9, 0.12), Vector3(sx, height + 0.95, 0.9), m)
	var brace := _box(root, Vector3(0.1, height * 1.15, 0.1), Vector3(0, height * 0.5, 0.9), m)
	brace.rotation.z = 0.5
	return root


func _build_ridge() -> void:
	# A low rise: the eastern ridge, the one place that faces away from the hollow.
	var rise := _cyl(_static_root, 7.5, 10.5, 0.9, Vector3(25.0, 0.2, -1.5), Art.mat(Color(0.37, 0.40, 0.33)), 14)
	rise.scale = Vector3(1.0, 1.0, 1.35)
	_tower(_static_root, Vector3(25.0, 0.6, -1.5), 4.2, Color(0.30, 0.25, 0.20))
	for p in [Vector3(18, 0, 9), Vector3(28, 0, 10.5), Vector3(15, 0, -5), Vector3(29.5, 0, -5.5)]:
		var rock := _box(_static_root, Vector3(1.4, 0.9, 1.1), p + Vector3(0, 0.35, 0), Art.mat(Color(0.40, 0.40, 0.39)))
		rock.rotation = Vector3(0.2, p.x, 0.15)


func _build_structure() -> void:
	# The incomplete building: a frame, three walls standing. The open side faces west.
	var root := Node3D.new()
	root.position = Vector3(-17.5, 0, 0.5)
	_static_root.add_child(root)
	var frame := Art.mat(Color(0.52, 0.42, 0.28))
	var wall := Art.mat(Color(0.46, 0.38, 0.27))
	var w := 7.0
	var d := 5.5
	var h := 3.6
	for sx in [-w * 0.5, 0.0, w * 0.5]:
		for sz in [-d * 0.5, d * 0.5]:
			_box(root, Vector3(0.22, h, 0.22), Vector3(sx, h * 0.5, sz), frame)
	_box(root, Vector3(w, 0.2, 0.2), Vector3(0, h, -d * 0.5), frame)
	_box(root, Vector3(w, 0.2, 0.2), Vector3(0, h, d * 0.5), frame)
	_box(root, Vector3(0.2, 0.2, d), Vector3(-w * 0.5, h, 0), frame)
	_box(root, Vector3(0.2, 0.2, d), Vector3(w * 0.5, h, 0), frame)
	_box(root, Vector3(0.2, 0.2, d), Vector3(0, h, 0), frame)
	_box(root, Vector3(w, h - 0.2, 0.12), Vector3(0, (h - 0.2) * 0.5, -d * 0.5), wall)   # north
	_box(root, Vector3(w, h - 0.2, 0.12), Vector3(0, (h - 0.2) * 0.5, d * 0.5), wall)    # south
	_box(root, Vector3(0.12, h - 0.2, d), Vector3(w * 0.5, (h - 0.2) * 0.5, 0), wall)    # east
	# The fourth wall (west), raised by the crew.
	_wall4 = _box(root, Vector3(0.12, h - 0.2, d), Vector3(-w * 0.5, (h - 0.2) * 0.5, 0), Art.mat(Color(0.56, 0.47, 0.32)))
	_wall4.visible = false
	# The foundation trench, once it is dug.
	_trench = _box(root, Vector3(1.4, 0.06, d + 1.0), Vector3(-w * 0.5 - 1.3, 0.04, 0), Art.mat(Color(0.05, 0.05, 0.05)))
	_trench.visible = false
	# Sawhorses and stacked boards.
	_box(_static_root, Vector3(2.6, 0.5, 1.0), Vector3(-12.2, 0.25, 6.2), Art.mat(Color(0.55, 0.46, 0.32)))
	_box(_static_root, Vector3(1.6, 0.1, 0.4), Vector3(-13.0, 0.9, 8.0), frame)
	_box(_static_root, Vector3(0.1, 0.9, 0.4), Vector3(-13.6, 0.45, 8.0), frame)
	_box(_static_root, Vector3(0.1, 0.9, 0.4), Vector3(-12.4, 0.45, 8.0), frame)
	# The cut line: stakes along the western perimeter.
	for i in 9:
		_box(_static_root, Vector3(0.1, 0.8, 0.1), Vector3(HOLLOW_X + 1.2, 0.4, -6.0 + float(i) * 2.2), Art.mat(Color(0.74, 0.70, 0.60)))


# ═══════════════════════════════════════════════════════════════════════════
# Placed buildings
# ═══════════════════════════════════════════════════════════════════════════

func _make_building(b: Dictionary) -> Node3D:
	var root := Node3D.new()
	var cell := Vector2i(int(b["cell"][0]), int(b["cell"][1]))
	root.position = cell_to_world(cell)
	root.rotation.y = float((cell.x * 7 + cell.y * 13) % 4) * 0.12 - 0.18
	var state := str(b["state"])
	var wood := Color(0.50, 0.41, 0.28)
	if state == "damaged":
		wood = wood.darkened(0.25)
	if state == "destroyed":
		# The boards are stacked. No one stacked them.
		for i in 5:
			_box(root, Vector3(2.2, 0.12, 0.5), Vector3(0, 0.08 + float(i) * 0.13, -0.6 + float(i % 2) * 0.1), Art.mat(wood.darkened(0.3)))
		for i in 4:
			_box(root, Vector3(0.5, 0.12, 2.0), Vector3(0.9, 0.08 + float(i) * 0.13, 0.5), Art.mat(wood.darkened(0.35)))
		return root
	match str(b["building_type"]):
		"Watchtower":
			_tower(root, Vector3.ZERO, 3.4, wood)
		"Secondary Processing Shed":
			_box(root, Vector3(2.6, 1.9, 2.2), Vector3(0, 0.95, 0), Art.mat(wood))
			var r := _box(root, Vector3(2.9, 0.14, 2.6), Vector3(0, 2.05, 0), Art.mat(Color(0.20, 0.17, 0.15)))
			r.rotation.x = 0.16
			_box(root, Vector3(1.0, 1.4, 0.08), Vector3(0, 0.7, 1.12), Art.mat(Color(0.10, 0.09, 0.08)))
		"Storehouse":
			_box(root, Vector3(2.4, 2.2, 2.4), Vector3(0, 1.1, 0), Art.mat(wood.darkened(0.08)))
			_roof(root, 2.7, 2.8, 1.2, Vector3(0, 2.8, 0), Art.mat(Color(0.20, 0.17, 0.15)))
			_box(root, Vector3(0.9, 1.5, 0.08), Vector3(0, 0.75, 1.22), Art.mat(Color(0.16, 0.12, 0.10)))
		_:
			_box(root, Vector3(2.7, 1.9, 2.1), Vector3(0, 0.95, 0), Art.mat(wood.lightened(0.05)))
			_roof(root, 3.0, 2.5, 1.0, Vector3(0, 2.4, 0), Art.mat(Color(0.20, 0.17, 0.15)))
			var wm := Art.mat(Color(0.16, 0.16, 0.18), 0.6, Color(1.0, 0.72, 0.36), 0.01)
			_window_mats.append(wm)
			_box(root, Vector3(0.6, 0.5, 0.08), Vector3(0.6, 1.2, 1.07), wm)
			_box(root, Vector3(0.7, 1.4, 0.08), Vector3(-0.5, 0.7, 1.07), Art.mat(Color(0.16, 0.12, 0.10)))
	if state == "damaged":
		# A wall staved in. The timbers are bowed.
		root.rotation.z = 0.07
		root.rotation.x = -0.05
		var plank := _box(root, Vector3(0.2, 2.6, 0.5), Vector3(1.5, 1.0, 0.3), Art.mat(wood.darkened(0.2)))
		plank.rotation.z = -0.5
	return root


func _sync_buildings() -> void:
	for b in GameState.buildings:
		var bid := str(b["id"])
		var state := str(b["state"])
		if _building_nodes.has(bid) and _building_states.get(bid, "") == state:
			continue
		var fresh := not _building_nodes.has(bid)
		if not fresh:
			_building_nodes[bid].queue_free()
		var node := _make_building(b)
		_dynamic_root.add_child(node)
		_building_nodes[bid] = node
		_building_states[bid] = state
		if fresh and int(b["day_placed"]) == GameState.current_day and GameState.current_phase == "day":
			# The building is there. That is the feedback (INTERACTION_MODEL §2).
			node.scale = Vector3(1, 0.02, 1)
			var tw := create_tween()
			tw.tween_property(node, "scale", Vector3.ONE, 1.0).set_trans(Tween.TRANS_SINE)
	for bid in _building_nodes.keys():
		if GameState.building_by_id(str(bid)).is_empty():
			_building_nodes[bid].queue_free()
			_building_nodes.erase(bid)
			_building_states.erase(bid)


func building_position(building_id: String) -> Vector3:
	var b: Dictionary = GameState.building_by_id(building_id)
	if b.is_empty():
		return Vector3.ZERO
	return cell_to_world(Vector2i(int(b["cell"][0]), int(b["cell"][1])))


func post_position(post_id: String) -> Vector3:
	if POST_POS.has(post_id):
		return POST_POS[post_id]
	if post_id.begins_with("post_b"):
		return building_position(post_id.substr(5)) + Vector3(1.9, 0, 1.6)
	return ZONE_CENTERS["zone_2"]


## Where the camera should look for a night event's `focus` key.
func focus_position(key: String) -> Vector3:
	if key == "surveyor":
		return _surveyor.position if _surveyor.visible else Vector3(-20, 0, -20)
	if key.begins_with("post_"):
		return post_position(key)
	if ZONE_CENTERS.has(key):
		if key == "zone_5":
			return Vector3(HOLLOW_X + 2.0, 0, 2.0)
		return ZONE_CENTERS[key]
	return Vector3.ZERO


# ═══════════════════════════════════════════════════════════════════════════
# People
# ═══════════════════════════════════════════════════════════════════════════

func _spot(zone_id: String, index: int) -> Vector3:
	var c: Vector3 = ZONE_CENTERS.get(zone_id, ZONE_CENTERS["zone_2"])
	var a := float(index) * 2.399963 + float(zone_id.hash() % 7)
	var r := 1.6 + float(index % 3) * 1.1
	return c + Vector3(cos(a) * r, 0, sin(a) * r * 0.8)


func _ensure_figure(id: String, look: String, shown: String, spawn: Vector3) -> Figure:
	if _figures.has(id):
		return _figures[id]
	var f := Figure.new()
	_people_root.add_child(f)
	f.setup(id, look, shown)
	f.go_to(spawn, true)
	_figures[id] = f
	return f


func _sync_people(instant: bool = false) -> void:
	var phase := GameState.current_phase
	var night: bool = phase == "night"
	var lit: Dictionary = NightSim.lit_posts()[0] if (night or phase == "dusk") else {}
	var wanted := {}
	var zone_counts := {}
	var ids: Array = GameState.npc_states.keys()
	ids.sort()
	for id in ids:
		var n: Dictionary = GameState.npc_states[id]
		if bool(n["gone"]):
			continue
		wanted[id] = true
		var f := _ensure_figure(str(id), str(id), str(n["name"]), ROAD_END + Vector3(0, 0, 3.0))
		f.set_emotion(str(n["emotion"]) if str(n["arc_state"]) != "broken" else "corrupted" if str(n["emotion"]) == "corrupted" else "afraid")
		var post_id := GameState.post_of(str(id))
		var dest := Vector3.ZERO
		var show := true
		if (night or phase == "dusk") and post_id != "":
			dest = post_position(post_id)
		elif night:
			# In the bunks. The zone they left is undefended.
			dest = Vector3(-4.0, 0, 6.5)
			show = false
		elif str(n["arc_state"]) == "broken" and bool(n["is_arrival"]):
			dest = ROAD_END + Vector3(float(str(id).hash() % 3) - 1.0, 0, -0.5)
		elif bool(n["is_arrival"]) and str(n.get("stage", "done")) == "housing":
			dest = ROAD_END + Vector3(0, 0, -2.5)
		elif str(id) == "constance":
			dest = Vector3(5.0, 0, 6.2) if GameState.has_flag("constance_window") else Vector3(-4.2, 0, 3.4)
		else:
			var z := str(n["zone"])
			var k := int(zone_counts.get(z, 0))
			zone_counts[z] = k + 1
			dest = _spot(z, k)
		if not f.has_meta("home") or (f.get_meta("home") as Vector3).distance_to(dest) > 0.01:
			f.go_to(dest, instant)
		if str(n["arc_state"]) == "broken" or str(id) == "constance" or phase != "day":
			f.remove_meta("home")
			f.go_to(dest, instant)
		else:
			f.set_meta("home", dest)
		f.visible = show or not f.at_rest()
		f.set_meta("hide_at_rest", not show)
		var tint := Color(1, 1, 1)
		if night:
			tint = Color(0.95, 0.80, 0.62) if lit.has(post_id) else Color(0.34, 0.38, 0.50)
		elif phase == "dusk":
			tint = Color(0.80, 0.72, 0.68)
		elif phase == "dawn":
			tint = Color(0.82, 0.82, 0.86)
		f.set_tint(tint)
	# Faction representatives stand in the Common during their active moments.
	for fid in ["compact", "association", "dix"]:
		var rid: String = "rep_" + str(fid)
		if Chapter.rep_present(fid):
			wanted[rid] = true
			var rf := _ensure_figure(rid, rid, str(GameState.factions[fid]["rep"]), ROAD_END)
			rf.go_to(REP_POS[fid], instant)
			rf.visible = true
			rf.set_tint(Color(1, 1, 1))
		elif _figures.has(rid):
			# They walk away. They respond in behaviour, not in further dialogue.
			wanted[rid] = true
			var leaving: Figure = _figures[rid]
			leaving.go_to(ROAD_END + Vector3(0, 0, 6.0))
			leaving.set_meta("hide_at_rest", true)
	for id in _figures.keys():
		if not wanted.has(id):
			_figures[id].queue_free()
			_figures.erase(id)
			if _hover_id == id:
				_hover_id = ""


# ═══════════════════════════════════════════════════════════════════════════
# Walkers, lamps, the Surveyor
# ═══════════════════════════════════════════════════════════════════════════

func _make_walker() -> Node3D:
	# Something that was a tree. No face. Albedo near black, no emission.
	var root := Node3D.new()
	var m := Art.mat(Color(0.10, 0.10, 0.10))
	var trunk := _cyl(root, 0.16, 0.42, 5.4, Vector3(0, 2.7, 0), m, 6)
	trunk.rotation.z = 0.06
	var limbs := [[Vector3(0.6, 3.6, 0.1), 0.9, 2.2], [Vector3(-0.7, 4.2, -0.2), -1.0, 2.6],
		[Vector3(0.3, 4.9, 0.4), 0.5, 1.8], [Vector3(-0.2, 2.6, 0.5), -0.7, 1.4]]
	for l in limbs:
		var limb := _cyl(root, 0.03, 0.12, float(l[2]), l[0], m, 5)
		limb.rotation.z = float(l[1])
		limb.rotation.y = float(l[1]) * 1.7
	# Two roots it stands on.
	for sx in [-0.35, 0.35]:
		var r := _cyl(root, 0.14, 0.05, 1.2, Vector3(sx, 0.5, 0.15), m, 5)
		r.rotation.z = sx * 0.9
	# Not a glow: the ground around it is a little colder than the ground elsewhere.
	var cold := OmniLight3D.new()
	cold.light_color = Color(0.55, 0.66, 0.80)
	cold.light_energy = 0.55
	cold.omni_range = 5.5
	cold.position = Vector3(1.2, 2.4, 1.6)
	root.add_child(cold)
	return root


func _walker_stand_pos(zone_id: String, index: int) -> Vector3:
	if zone_id == "zone_5":
		return Vector3(HOLLOW_X + 1.6, 0, -3.0 + float(index) * 2.6)
	var c: Vector3 = ZONE_CENTERS.get(zone_id, ZONE_CENTERS["zone_2"])
	var target_post := str(GameState.night_result.get("walker_target", ""))
	if target_post != "" and Chapter.post_zone(target_post) == zone_id and target_post.begins_with("post_b"):
		return building_position(target_post.substr(5)) + Vector3(-2.0 - float(index) * 0.9, 0, -0.8 + float(index % 2) * 1.6)
	if zone_id == "zone_4":
		return Vector3(-22.0, 0, 0.5) + Vector3(float(index % 2) * 1.2, 0, float(index) * 1.5 - 1.5)
	return c + Vector3(-3.5 + float(index) * 1.3, 0, 3.0 - float(index % 2) * 1.5)


func _sync_walkers() -> void:
	# By day (and at dawn) they simply stand where they stopped.
	if GameState.current_phase == "night":
		return
	var wanted := {}
	var per_zone := {}
	for w in GameState.walkers:
		if bool(w["cleared"]):
			continue
		var wid := str(w["id"])
		wanted[wid] = true
		var z := str(w["zone_id"])
		var k := int(per_zone.get(z, 0))
		per_zone[z] = k + 1
		if not _walker_nodes.has(wid):
			var node := _make_walker()
			_dynamic_root.add_child(node)
			_walker_nodes[wid] = node
			node.rotation.y = float(wid.hash() % 100) * 0.06
		_walker_nodes[wid].position = _walker_stand_pos(z, k)
		_walker_nodes[wid].visible = true
	for wid in _walker_nodes.keys():
		if not wanted.has(wid):
			_walker_nodes[wid].queue_free()
			_walker_nodes.erase(wid)


func _begin_night_visuals() -> void:
	# Lamps at every staffed post that has oil.
	for l in _lamp_nodes:
		l.queue_free()
	_lamp_nodes = []
	var lit: Dictionary = GameState.night_result.get("lit", {})
	for post_id in lit:
		var pos := post_position(str(post_id)) + Vector3(0.7, 0, 0)
		var holder := Node3D.new()
		holder.position = pos
		_dynamic_root.add_child(holder)
		_box(holder, Vector3(0.08, 1.5, 0.08), Vector3(0, 0.75, 0), Art.mat(Color(0.2, 0.17, 0.14)))
		_box(holder, Vector3(0.2, 0.28, 0.2), Vector3(0, 1.6, 0), Art.mat(Color(0.9, 0.6, 0.3), 0.5, Color(1.0, 0.70, 0.34), 2.2))
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.68, 0.34)
		lamp.omni_range = 6.0
		lamp.light_energy = 1.5
		lamp.position = Vector3(0, 1.8, 0)
		holder.add_child(lamp)
		_lamp_nodes.append(holder)
	# Walker nodes for tonight, at their starting places.
	var paths: Array = GameState.night_result.get("walker_paths", [])
	var wanted := {}
	for p in paths:
		var wid := str(p["id"])
		wanted[wid] = true
		if not _walker_nodes.has(wid):
			var node := _make_walker()
			_dynamic_root.add_child(node)
			_walker_nodes[wid] = node
			node.rotation.y = float(wid.hash() % 100) * 0.06
			node.position = Vector3(HOLLOW_X - 4.0, 0, float(wid.hash() % 9) - 4.0)
			node.visible = false
	for wid in _walker_nodes.keys():
		if not wanted.has(wid):
			_walker_nodes[wid].queue_free()
			_walker_nodes.erase(wid)


func _update_walkers_night(hour: float) -> void:
	var paths: Array = GameState.night_result.get("walker_paths", [])
	var per_zone := {}
	for p in paths:
		var wid := str(p["id"])
		if not _walker_nodes.has(wid):
			continue
		var node: Node3D = _walker_nodes[wid]
		var path: Array = p["path"]
		var start_hour := float(path[0][1])
		if hour < start_hour - 0.6 and str(path[0][0]) == "zone_5" and wid.begins_with("w%d_" % GameState.current_day):
			node.visible = false
			continue
		node.visible = true
		# One zone per hour of night: each leg is walked in the hour before arrival.
		var seg := 0
		for i in path.size():
			if hour >= float(path[i][1]):
				seg = i
		var z_from := str(path[seg][0])
		var k := int(per_zone.get(wid, wid.hash() % 3))
		var from_pos := _walker_stand_pos(z_from, k)
		var pos := from_pos
		if seg + 1 < path.size():
			var arrive := float(path[seg + 1][1])
			var t := clampf((hour - (arrive - 1.0)) / 1.0, 0.0, 1.0)
			# Lean-then-displace: it is never seen mid-stride. It is here, then nearer.
			var stepped := floorf(t * 6.0) / 6.0
			pos = from_pos.lerp(_walker_stand_pos(str(path[seg + 1][0]), k), stepped)
			node.rotation.z = sin(t * 6.0 * PI) * 0.05
		elif seg == 0 and str(path[0][0]) == "zone_5" and hour < start_hour:
			pos = from_pos + Vector3(-3.0, 0, 0)
		node.position = pos


func _build_surveyor() -> void:
	_surveyor = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(Art.W, Art.H) * 0.085
	_surveyor.mesh = quad
	_surveyor_mat = StandardMaterial3D.new()
	_surveyor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_surveyor_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_surveyor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_surveyor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_surveyor_mat.albedo_texture = Art.surveyor("walk0")
	_surveyor_mat.disable_fog = true
	_surveyor.material_override = _surveyor_mat
	_surveyor.visible = false
	add_child(_surveyor)
	# The figure itself gives off nothing. The ground it stands on is colder.
	var cold := OmniLight3D.new()
	cold.light_color = Color(0.60, 0.70, 0.90)
	cold.light_energy = 1.1
	cold.omni_range = 7.5
	cold.position = Vector3(0, 0.6, 2.2)
	_surveyor.add_child(cold)


func _path_point(u: float) -> Vector3:
	var total := 0.0
	var lens: Array = []
	for i in range(SURVEYOR_PATH.size() - 1):
		var l: float = SURVEYOR_PATH[i].distance_to(SURVEYOR_PATH[i + 1])
		lens.append(l)
		total += l
	var d := clampf(u, 0.0, 1.0) * total
	for i in lens.size():
		if d <= float(lens[i]):
			return SURVEYOR_PATH[i].lerp(SURVEYOR_PATH[i + 1], d / float(lens[i]))
		d -= float(lens[i])
	return SURVEYOR_PATH[SURVEYOR_PATH.size() - 1]


func _update_surveyor(hour: float) -> void:
	var day := GameState.current_day
	if day < 4 or not TimeManager.is_night():
		_surveyor.visible = false
		return
	# It walks the boundary between the ridge and the hollow. Never closer.
	var paused: bool = bool(GameState.night_result.get("surveyor", {}).get("paused", false))
	var marked: bool = bool(GameState.night_result.get("surveyor", {}).get("marked", false))
	var u := clampf((hour - 5.2) / 2.8, 0.0, 1.0)
	var pos := _path_point(u)
	var alpha := clampf((hour - 5.2) / 0.4, 0.0, 1.0)
	var frame := "walk0" if int(hour * 9.0) % 2 == 0 else "walk1"
	# Every forty paces it stops. It is measuring.
	if fmod(u * 11.0, 1.0) < 0.22 and u < 1.0:
		frame = "measure"
	if u >= 1.0:
		var after := hour - 8.0
		if day == 4:
			if paused and after < 1.0:
				frame = "measure"
			else:
				var leave := after - (1.0 if paused else 0.0)
				pos += Vector3(-leave * 5.0, 0, leave * 3.0)
				alpha = clampf(1.0 - leave / 0.7, 0.0, 1.0)
		else:
			if marked:
				if after < 0.7:
					frame = "mark"
				else:
					pos += Vector3(-(after - 0.7) * 6.0, 0, 0)
					alpha = clampf(1.0 - (after - 0.7) / 0.6, 0.0, 1.0)
			else:
				alpha = clampf(1.0 - after / 0.35, 0.0, 1.0)
	_surveyor.visible = alpha > 0.01 and hour >= 5.2
	_surveyor.position = pos + Vector3(0, Art.H * 0.085 * 0.5, 0)
	_surveyor_mat.albedo_color = Color(1, 1, 1, alpha)
	if _surveyor_state != frame:
		_surveyor_state = frame
		_surveyor_mat.albedo_texture = Art.surveyor(frame)


# ═══════════════════════════════════════════════════════════════════════════
# Sync / signals
# ═══════════════════════════════════════════════════════════════════════════

func _on_session_started() -> void:
	for id in _figures.keys():
		_figures[id].queue_free()
	_figures = {}
	for bid in _building_nodes.keys():
		_building_nodes[bid].queue_free()
	_building_nodes = {}
	_building_states = {}
	for wid in _walker_nodes.keys():
		_walker_nodes[wid].queue_free()
	_walker_nodes = {}
	for l in _lamp_nodes:
		l.queue_free()
	_lamp_nodes = []
	_cancel_placement()
	_sync(true)
	if GameState.current_phase == "night":
		_begin_night_visuals()


func _sync(instant: bool = false) -> void:
	_sync_buildings()
	_sync_people(instant)
	_sync_walkers()
	# The fourth wall: half-height while the crew is on it, full when it closes.
	_wall4.visible = GameState.wall_progress >= 1.0 or GameState.structure_walls >= 4
	if _wall4.visible:
		var full: bool = GameState.structure_walls >= 4
		_wall4.scale.y = 1.0 if full else 0.5
		_wall4.position.y = 1.7 if full else 0.85
		_wall4.rotation.x = 0.05 if GameState.has_flag("structure_damaged") else 0.0
	_trench.visible = GameState.peder_foundation_excavated
	# The treeline is nearer than it was. No UI says so.
	var shown := clampi(int(float(GameState.treeline_advance) * 2.2), 0, _creep_count)
	if GameState.season == "turning":
		shown = maxi(shown, int(_creep_count * 0.25))
	elif GameState.season == "deep_winter":
		shown = maxi(shown, int(_creep_count * 0.6))
	_creep_trees.multimesh.visible_instance_count = shown
	_creep_trunks.multimesh.visible_instance_count = shown


func _on_phase_changed(new_phase: int, _day: int) -> void:
	match new_phase:
		TimeManager.Phase.NIGHT:
			_begin_night_visuals()
		TimeManager.Phase.DAY:
			for l in _lamp_nodes:
				l.queue_free()
			_lamp_nodes = []
		TimeManager.Phase.DUSK:
			_cancel_placement()
	_sync()


func _on_roster_warning() -> void:
	# The fire dims. That is the whole warning.
	var tw := create_tween()
	tw.tween_property(_fire_light, "light_energy", 0.5, 2.0)


func _on_night_event(e: Dictionary) -> void:
	if str(e.get("creature", "")) == "ledger_watcher":
		_flicker_next = 0.0
		set_meta("watcher_active", true)


func _process(delta: float) -> void:
	var phase := TimeManager.current_phase
	var night: bool = phase == TimeManager.Phase.NIGHT and TimeManager.is_running()
	if phase == TimeManager.Phase.DAY and TimeManager.is_running():
		_mill_wheel.rotation.z += delta * 0.7
	# Fire and windows follow the light.
	var fire_target := 0.35
	var window_target := 0.01
	var mill_target := 0.0
	match phase:
		TimeManager.Phase.DUSK:
			fire_target = 1.6
			window_target = 1.2
			mill_target = 0.8
		TimeManager.Phase.NIGHT:
			fire_target = 1.1
			window_target = 0.9
			mill_target = 0.9
		TimeManager.Phase.DAWN:
			fire_target = 0.5
			window_target = 0.2
	if not TimeManager.is_running():
		fire_target = 1.4
		window_target = 1.0
		mill_target = 0.6
	_fire_light.light_energy = move_toward(_fire_light.light_energy, fire_target + sin(Time.get_ticks_msec() * 0.011) * 0.08, delta * 0.4)
	for wm in _window_mats:
		wm.emission_energy_multiplier = move_toward(wm.emission_energy_multiplier, window_target, delta * 0.5)
	# The Watchers have no body. A lamp goes out. It comes back. Irregular, never rhythmic.
	var flicker := 1.0
	if night and bool(get_meta("watcher_active", false)):
		_flicker_t += delta
		if _flicker_t >= _flicker_next:
			_flicker_t = 0.0
			_flicker_next = _rng.randf_range(0.3, 1.8)
			set_meta("flicker_off", not bool(get_meta("flicker_off", false)))
		flicker = 0.0 if bool(get_meta("flicker_off", false)) else 1.0
	elif not night:
		set_meta("watcher_active", false)
	for lamp in _mill_lamps:
		lamp.light_energy = move_toward(lamp.light_energy, mill_target * flicker, delta * (9.0 if flicker == 0.0 else 0.6))
	if night:
		var hour := TimeManager.phase_progress() * float(NightSim.NIGHT_HOURS)
		_update_walkers_night(hour)
		_update_surveyor(hour)
	elif _surveyor.visible:
		_surveyor.visible = false
	for id in _figures:
		var f: Figure = _figures[id]
		if bool(f.get_meta("hide_at_rest", false)) and f.at_rest() and f.visible:
			f.visible = false
	# By day people move about their work, a few steps at a time.
	if phase == TimeManager.Phase.DAY and TimeManager.is_running():
		_drift_t -= delta
		if _drift_t <= 0.0:
			_drift_t = _rng.randf_range(1.2, 2.6)
			var keys: Array = _figures.keys()
			if not keys.is_empty():
				var fid: String = str(keys[_rng.randi() % keys.size()])
				var fig: Figure = _figures[fid]
				if fig.at_rest() and fig.has_meta("home") and not bool(fig.get_meta("hide_at_rest", false)) and fid != _hover_id:
					var home: Vector3 = fig.get_meta("home")
					fig.go_to(home + Vector3(_rng.randf_range(-1.3, 1.3), 0, _rng.randf_range(-1.0, 1.0)))
	if _placing:
		_update_ghost()


# ═══════════════════════════════════════════════════════════════════════════
# Cursor: Observe mode and Place mode (INTERACTION_MODEL §1)
# ═══════════════════════════════════════════════════════════════════════════

func _ray() -> Array:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return []
	var mouse := get_viewport().get_mouse_position()
	return [cam.project_ray_origin(mouse), cam.project_ray_normal(mouse)]


func _ground_under_cursor() -> Variant:
	var ray := _ray()
	if ray.is_empty():
		return null
	var origin: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	if absf(dir.y) < 0.0001:
		return null
	var t := -origin.y / dir.y
	if t < 0.0:
		return null
	return origin + dir * t


## Distance from a ray to a vertical segment standing at `base` — cheap picking
## that needs no physics bodies.
func _ray_hits(origin: Vector3, dir: Vector3, base: Vector3, radius: float, height: float) -> float:
	var best := -1.0
	for i in 4:
		var p := base + Vector3(0, height * (float(i) + 0.5) / 4.0, 0)
		var t := (p - origin).dot(dir)
		if t <= 0.0:
			continue
		var d := (origin + dir * t).distance_to(p)
		if d <= radius and (best < 0.0 or t < best):
			best = t
	return best


func pick() -> String:
	var ray := _ray()
	if ray.is_empty():
		return ""
	var origin: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	var best_id := ""
	var best_t := 1e9
	for id in _figures:
		var f: Figure = _figures[id]
		if not f.visible:
			continue
		var t := _ray_hits(origin, dir, f.position, f.pick_radius, f.pick_height)
		if t > 0.0 and t < best_t:
			best_t = t
			best_id = str(id)
	for id in _objects:
		var o: Dictionary = _objects[id]
		var t2 := _ray_hits(origin, dir, o["pos"], float(o["radius"]), float(o["height"]))
		if t2 > 0.0 and t2 < best_t:
			best_t = t2
			best_id = str(id)
	return best_id


func _set_hover(id: String) -> void:
	if id == _hover_id:
		return
	if _figures.has(_hover_id):
		_figures[_hover_id].set_hover(false)
	if _objects.has(_hover_id):
		_objects[_hover_id]["label"].visible = false
	_hover_id = id
	if _figures.has(id):
		_figures[id].set_hover(true)
	if _objects.has(id):
		_objects[id]["label"].visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not TimeManager.is_running():
		return
	if event is InputEventMouseMotion and not _placing:
		_set_hover(pick())
	if _placing:
		if event.is_action_pressed("cancel"):
			_cancel_placement()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("select"):
			_try_place()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("select"):
		var id := pick()
		if id != "":
			EventBus.target_selected.emit(id)
		else:
			EventBus.selection_cleared.emit()


# ── Place mode ──────────────────────────────────────────────────────────────

func _build_ghost() -> void:
	_ghost = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL * 0.86, 2.2, CELL * 0.86)
	_ghost.mesh = mesh
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 0.85, 0.80, 0.42)
	_ghost.material_override = m
	_ghost.visible = false
	add_child(_ghost)


func _on_building_type_selected(building_type: String) -> void:
	if GameState.current_phase != "day":
		return
	_placing = true
	_place_type = building_type
	_set_hover("")


func _cancel_placement() -> void:
	_placing = false
	_place_type = ""
	if _ghost:
		_ghost.visible = false


func cell_valid(cell: Vector2i) -> bool:
	var pos := cell_to_world(cell)
	var zone_id := zone_at(pos)
	if zone_id == "" or zone_id == "zone_5":
		return false
	# The whole footprint must sit inside the zone.
	var r: Rect2 = ZONE_RECTS[zone_id]
	if not r.grow(-1.2).has_point(Vector2(pos.x, pos.z)):
		return false
	if BLOCKED_CELLS.has(cell):
		return false
	for b in GameState.buildings:
		if int(b["cell"][0]) == cell.x and int(b["cell"][1]) == cell.y:
			return false
	for post_id in POST_POS:
		if (POST_POS[post_id] as Vector3).distance_to(pos) < 1.8:
			return false
	return Chapter.can_place(_place_type, zone_id)


func _update_ghost() -> void:
	if GameState.current_phase != "day":
		_cancel_placement()
		return
	var hit: Variant = _ground_under_cursor()
	if hit == null:
		_ghost.visible = false
		return
	var cell := world_to_cell(hit)
	var pos := cell_to_world(cell)
	_ghost.visible = true
	_ghost.position = Vector3(pos.x, 1.1, pos.z)
	var m := _ghost.material_override as StandardMaterial3D
	# Red means no. No tooltip. No explanation.
	m.albedo_color = Color(0.85, 0.85, 0.80, 0.42) if cell_valid(cell) else Color(0.80, 0.22, 0.20, 0.50)


func _try_place() -> void:
	var hit: Variant = _ground_under_cursor()
	if hit == null:
		return
	var cell := world_to_cell(hit)
	if not cell_valid(cell):
		return
	var zone_id := zone_at(cell_to_world(cell))
	var placed := Chapter.place_building(_place_type, zone_id, cell)
	if not placed.is_empty():
		_cancel_placement()
		EventBus.build_menu_toggled.emit(false)
		EventBus.world_changed.emit()
