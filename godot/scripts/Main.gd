extends Node3D
## Main — root of the game. Builds the world, the camera and the UI in code, and
## owns the flow between the title, a session, and the end of the chapter.
##
##   GameState (autoload)   session state: choice log, people, factions, township
##   TimeManager (autoload) phase clock + pass ordering (mirrors SessionEngine)
##   EventBus (autoload)    signals connecting everything
##   SaveSystem (autoload)  one continuous record; no slots, no reloads of a choice
##   Audio (autoload)       procedural sound bed
##   Township (child)       the world: zones, people, placed buildings, what comes at night
##   GameUI (child)         log, context panel, build menu, night watch roster
##   TitleScreen (child)    begin / continue

var township: Township
var camera_rig: CameraRig
var lighting: WorldLighting
var ui: GameUI
var title: TitleScreen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	lighting = WorldLighting.new()
	lighting.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(lighting)
	township = Township.new()
	township.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(township)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	ui = GameUI.new()
	add_child(ui)
	title = TitleScreen.new()
	add_child(title)
	title.begin_requested.connect(start_new)
	title.continue_requested.connect(continue_game)
	ui.leave_requested.connect(to_title)
	to_title()


func start_new(anchor_name: String) -> void:
	get_tree().paused = false
	SaveSystem.delete_save()
	title.hide_title()
	ui.show_game()
	TimeManager.begin_new(anchor_name)
	camera_rig.set_mode(CameraRig.Mode.PLAYER)


func continue_game() -> void:
	if not SaveSystem.load_game():
		return
	get_tree().paused = false
	title.hide_title()
	ui.show_game()
	TimeManager.resume()
	camera_rig.set_mode(CameraRig.Mode.PLAYER)


func to_title() -> void:
	get_tree().paused = false
	SaveSystem.save()
	TimeManager.stop()
	ui.hide_game()
	camera_rig.set_mode(CameraRig.Mode.TITLE)
	Audio.set_bed("title")
	title.show_title()
