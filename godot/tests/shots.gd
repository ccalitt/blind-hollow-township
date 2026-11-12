extends Node
## Dev tool: drives the real game through a scripted session and saves screenshots.
##   xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/Shots.tscn -- --out=/some/dir
## Not part of the shipped flow; used to check the presentation layer renders.

var out_dir := "user://shots"
var main: Node
var scenario := "full"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		if a.begins_with("--scenario="):
			scenario = a.substr(11)
	DirAccess.make_dir_recursive_absolute(out_dir)
	SaveSystem.enabled = false
	SaveSystem.settings["pace"] = "brisk"
	TimeManager.pace = "brisk"
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	if scenario == "creatures":
		await _run_creatures()
	elif scenario == "input":
		await _run_input()
	else:
		await _run()
	get_tree().quit()


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, shot_name])
	print("shot ", shot_name)


func skip_to_phase_end() -> void:
	TimeManager.elapsed_in_phase = TimeManager.duration() - 0.05
	await wait(0.4)


func set_progress(p: float) -> void:
	TimeManager.elapsed_in_phase = TimeManager.duration() * p
	await wait(0.6)


func pick(target: String, key: String) -> void:
	var p: Dictionary = Chapter.panel(target)
	for o in p.get("options", []):
		if str(o.get("id", "")) == key or str(o.get("text", "")).contains(key):
			Chapter.choose(o)
			return


func _run() -> void:
	await wait(1.5)
	await shot("01_title")
	main.start_new("Mara")
	await wait(2.5)
	await shot("02_day1_open")
	EventBus.target_selected.emit("ruth")
	await wait(0.5)
	await shot("03_panel_ruth")
	EventBus.target_selected.emit("peder")
	await wait(0.5)
	await shot("04_panel_peder")
	pick("peder", "crew_fourth_wall")
	pick("elias", "elias_report_unlogged")
	pick("obj_ledger", "ledger_carried_forward")
	Chapter.place_building("Watchtower", "zone_4", Vector2i(-7, 3))
	Chapter.place_building("Storehouse", "zone_2", Vector2i(-1, 1))
	EventBus.world_changed.emit()
	EventBus.target_selected.emit("obj_ledger")
	await wait(1.5)
	await shot("05_ledger_buildings")
	EventBus.selection_cleared.emit()
	EventBus.building_type_selected.emit("Bunkhouse")
	Input.warp_mouse(Vector2(520, 330))
	await wait(0.6)
	await shot("06_place_mode")
	EventBus.placement_cancelled.emit()
	await skip_to_phase_end()
	await wait(1.0)
	Chapter.set_post("post_b1", "thomas")
	Chapter.set_post("post_structure", "maren")
	EventBus.world_changed.emit()
	await wait(0.6)
	await shot("07_dusk_roster")
	TimeManager.confirm_roster()
	await wait(4.0)
	await set_progress(0.35)
	await wait(3.0)
	await shot("08_night1")
	await set_progress(0.72)
	await wait(5.0)
	await shot("09_night1_late")
	await skip_to_phase_end()
	await wait(9.0)
	await shot("10_dawn1")
	await skip_to_phase_end()
	await wait(2.0)
	await set_progress(0.2)
	await shot("11_day2_arrival")
	for id in GameState.arrival_order:
		EventBus.target_selected.emit(id)
	await wait(0.5)
	await shot("12_arrival_panel")
	pick("rep_compact", "compact_surplus_accepted")
	# Fast-forward through days 2-3 on the compounding path.
	for d in [2, 3]:
		pick("peder", "crew_fourth_wall")
		await set_progress(0.6)
		pick("rep_compact", "compact_surplus_accepted")
		pick("rep_association", "association_ledger_edited")
		pick("rep_dix", "dix_inspection_denied")
		pick("rep_compact", "compact_ratification_signed")
		await skip_to_phase_end()      # -> dusk
		await skip_to_phase_end()      # -> night
		await skip_to_phase_end()      # -> dawn
		await wait(1.0)
		await skip_to_phase_end()      # -> day
		await wait(0.5)
	pick("peder", "crew_fourth_wall")
	await set_progress(0.3)
	EventBus.target_selected.emit("rep_association")
	await wait(0.5)
	await shot("13_day4_ask")
	await skip_to_phase_end()
	await skip_to_phase_end()
	await wait(3.0)
	await set_progress(0.66)
	await wait(4.0)
	await shot("14_night4_surveyor")
	await set_progress(0.85)
	await wait(2.0)
	await shot("15_night4_pause")
	await skip_to_phase_end()
	await wait(1.0)
	await skip_to_phase_end()
	await wait(1.0)
	await set_progress(0.55)
	EventBus.target_selected.emit("rep_dix")
	await wait(0.5)
	await shot("16_day5_macro")
	pick("rep_dix", "macro_cosign")
	await skip_to_phase_end()
	await skip_to_phase_end()
	await wait(2.0)
	await set_progress(0.83)
	await wait(3.0)
	await shot("17_night5_mark")
	await skip_to_phase_end()
	await wait(14.0)
	await shot("18_final_dawn")
	await skip_to_phase_end()
	await wait(45.0)
	await shot("19_end_card")


## Close looks at what comes at night: a Walker mid-walk, and the Surveyor.
func _run_creatures() -> void:
	await wait(1.0)
	main.start_new("")
	await wait(1.0)
	var cam: CameraRig = main.camera_rig
	for d in [1, 2, 3]:
		pick("peder", "crew_fourth_wall")
		if d == 1:
			Chapter.place_building("Storehouse", "zone_2", Vector2i(-1, 1))
			pick("obj_ledger", "ledger_carried_forward")
		await set_progress(0.6)
		pick("rep_compact", "compact_surplus_accepted")
		pick("rep_association", "association_ledger_edited")
		pick("rep_dix", "dix_inspection_denied")
		pick("rep_compact", "compact_ratification_signed")
		await skip_to_phase_end()
		Chapter.set_post("post_structure", "maren")
		await skip_to_phase_end()
		await wait(2.0)
		if d == 2:
			await set_progress(0.38)
			cam.mode = CameraRig.Mode.PLAYER
			cam.position = Vector3(-18, 0, 2)
			cam._zoom_target = 17.0
			await wait(2.5)
			await shot("c1_walker_structure")
		if d == 3:
			await set_progress(0.62)
			cam.mode = CameraRig.Mode.PLAYER
			cam.position = Vector3(-6, 0, 2)
			cam._zoom_target = 20.0
			await wait(2.5)
			await shot("c2_walker_common")
			print("walkers: ", GameState.night_result.get("walker_paths", []))
		await skip_to_phase_end()
		await wait(0.6)
		await skip_to_phase_end()
		await wait(0.6)
		if d == 3:
			cam.mode = CameraRig.Mode.PLAYER
			cam.position = Vector3(-10, 0, 0)
			cam._zoom_target = 24.0
			await wait(2.0)
			await shot("c3_day4_standing")
	await skip_to_phase_end()
	await skip_to_phase_end()
	await wait(2.0)
	await set_progress(0.66)
	cam.mode = CameraRig.Mode.PLAYER
	cam.position = Vector3(0, 0, -20)
	cam._zoom_target = 22.0
	await wait(2.5)
	print("surveyor: ", main.township._surveyor.visible, " ", main.township._surveyor.position)
	await shot("c4_surveyor_walk")
	await set_progress(0.86)
	cam.mode = CameraRig.Mode.PLAYER
	cam.position = Vector3(-18, 0, -4)
	cam._zoom_target = 20.0
	await wait(2.5)
	print("surveyor: ", main.township._surveyor.visible, " ", main.township._surveyor.position)
	await shot("c5_surveyor_pause")


# ── Real input: mouse picking, panel buttons, placement, roster, pause ───────

var _fails := 0

func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		_fails += 1


func mouse_move(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	Input.warp_mouse(pos)
	await wait(0.15)


func click(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	await mouse_move(pos)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = button
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await wait(0.08)
	await wait(0.25)


func key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await wait(0.06)
	await wait(0.25)


func screen_of(world: Vector3) -> Vector2:
	return get_viewport().get_camera_3d().unproject_position(world)


func find_button(root: Node, text: String) -> Button:
	if root is Button and (root as Button).is_visible_in_tree() and (root as Button).text.contains(text):
		return root
	for c in root.get_children():
		var b := find_button(c, text)
		if b != null:
			return b
	return null


func click_button(text: String) -> bool:
	var b := find_button(main.ui, text)
	if b == null:
		b = find_button(main.title, text)
	if b == null:
		return false
	await click(b.global_position + b.size * 0.5)
	return true


func _run_input() -> void:
	await wait(1.0)
	check(await click_button("Begin"), "title: Begin is clickable")
	await wait(0.4)
	check(await click_button("Go on"), "title: name prompt, Go on")
	await wait(2.5)
	check(TimeManager.is_running() and GameState.current_phase == "day", "session started on Day 1")
	var ui: GameUI = main.ui
	var town: Township = main.township
	# Hover + click a person in the world.
	var ruth: Figure = town._figures["ruth"]
	await mouse_move(screen_of(ruth.position + Vector3(0, 1.3, 0)))
	check(town._hover_id == "ruth", "hover shows Ruth's name (hover id '%s')" % town._hover_id)
	await click(screen_of(ruth.position + Vector3(0, 1.3, 0)))
	check(ui._context.visible and ui._context_target == "ruth", "clicking Ruth opens her context panel")
	var before := GameState.choice_log.size()
	check(await click_button("Eastern Ridge, treeline watch"), "assignment option is clickable")
	check(GameState.choice_log.size() == before + 1 and str(GameState.npc_states["ruth"]["zone"]) == "zone_3", "assignment logged, Ruth reassigned")
	check(not ui._context.visible, "panel closes on assignment (no confirmation)")
	# The ledger object.
	await click(screen_of(Township.LEDGER_POS + Vector3(0, 1.0, 0)))
	check(ui._context_target == "obj_ledger", "clicking the ledger opens it (target '%s')" % ui._context_target)
	check(await click_button("Enter the counted figures"), "ledger option clickable")
	check(GameState.has_choice("ledger_counted_entered"), "ledger choice logged")
	# Peder: crew order.
	var peder: Figure = town._figures["peder"]
	await click(screen_of(peder.position + Vector3(0, 1.3, 0)))
	check(ui._context_target == "peder", "clicking Peder opens his panel")
	check(await click_button("Finish the incomplete structure"), "crew order clickable")
	check(str(GameState.crew_order.get("action", "")) == "crew_fourth_wall", "crew order set")
	# Empty ground closes the panel.
	await click(screen_of(peder.position + Vector3(0, 1.3, 0)))
	await click(screen_of(Vector3(12, 0, 6)))
	check(not ui._context.visible, "clicking empty ground clears the selection")
	# Build: B, pick a type, red cell in the hollow, valid cell in the Common.
	await key(KEY_B)
	check(ui._build_panel.visible, "B opens the build list")
	check(await click_button("Watchtower"), "building type clickable")
	check(town._placing, "place mode entered")
	var n_before := GameState.buildings.size()
	await click(screen_of(Vector3(-33, 0, 3)))
	check(GameState.buildings.size() == n_before and town._placing, "clicking inside the hollow places nothing (red means no)")
	await click(screen_of(Vector3(3, 0, -3)))
	check(GameState.buildings.size() == n_before + 1, "valid cell places the building")
	check(not town._placing, "place mode ends after placement")
	await key(KEY_B)
	await click_button("Storehouse")
	await click(screen_of(Vector3(12, 0, 6)), MOUSE_BUTTON_RIGHT)
	check(not town._placing, "right-click cancels placement")
	# Roster: R, select a post, assign a person.
	await key(KEY_R)
	check(ui._roster.visible, "R opens the night watch roster")
	check(await click_button("Western perimeter"), "post row clickable")
	check(await click_button("Thomas Vael"), "person row clickable")
	check(str(GameState.night_posts.get("post_west", "")) == "thomas", "Thomas posted to the western perimeter")
	await key(KEY_ESCAPE)
	check(not ui._roster.visible, "Esc closes the roster")
	# Pause holds the clock.
	await key(KEY_SPACE)
	var t0 := TimeManager.elapsed_in_phase
	await wait(1.0)
	check(get_tree().paused and absf(TimeManager.elapsed_in_phase - t0) < 0.001, "Space holds the world (clock stopped)")
	await key(KEY_SPACE)
	await wait(0.5)
	check(not get_tree().paused and TimeManager.elapsed_in_phase > t0, "Space releases it")
	# Dusk opens the roster by itself; night locks everything.
	await skip_to_phase_end()
	await wait(0.8)
	check(GameState.current_phase == "dusk" and ui._roster.visible, "dusk opens the roster automatically")
	check(await click_button("Post the watch"), "Post the watch is clickable at dusk")
	await wait(1.0)
	check(GameState.current_phase == "night", "posting the watch ends dusk")
	await key(KEY_R)
	check(not ui._roster.visible, "the roster does not reopen at night")
	await key(KEY_B)
	check(not ui._build_panel.visible, "the build list does not open at night")
	var thomas: Figure = town._figures["thomas"]
	await wait(4.0)
	main.camera_rig.mode = CameraRig.Mode.PLAYER
	main.camera_rig.position = Vector3(-20, 0, 2)
	await wait(1.5)
	await click(screen_of(thomas.position + Vector3(0, 1.3, 0)))
	check(ui._context_target == "thomas", "a posted person can be clicked at night")
	check(Chapter.panel("thomas")["options"].is_empty(), "…and has no options: the orders are locked")
	await shot("i1_night_locked")
	# Esc with nothing open: the manager's post panel; Stop here returns to the title.
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	check(ui._context_target == "desk", "Esc opens the manager's post panel")
	check(await click_button("Stop here for now"), "Stop here is clickable")
	await wait(1.0)
	check(not TimeManager.is_running() and main.title._root.visible, "back at the title")
	print("INPUT FAILS: %d" % _fails)
