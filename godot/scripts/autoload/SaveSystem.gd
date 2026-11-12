extends Node
## SaveSystem — one continuous record per session, plus player settings.
##
## There are no save slots and no manual save. The session is written whenever a
## choice is logged and at every phase change, and "Continue" resumes that record.
## Pillar 3 kills "choice systems that allow replaying for the optimal branch":
## a choice is made when it is clicked, and it is on disk a moment later.
##
## At the end of Chapter 1 the state Chapter 2 inherits is written beside it
## (CHAPTER_ONE "Required Output" — silent, never shown to the player).

var save_path := "user://chapter1.save"
var handoff_path := "user://chapter1_handoff.json"
const SETTINGS_PATH := "user://settings.cfg"
const VERSION := 3

var settings := {"volume": 0.8, "pace": "standard", "fullscreen": false}
var enabled := true
var _dirty := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	EventBus.choice_made.connect(func(_c): _dirty = true)
	EventBus.phase_changed.connect(func(_p, _d): _dirty = true)
	EventBus.world_changed.connect(func(): _dirty = true)


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_is_finished() -> bool:
	var d := _read()
	return bool(d.get("state", {}).get("chapter_complete", false))


func save() -> void:
	if not enabled or not TimeManager.is_running():
		return
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_var({"version": VERSION, "state": GameState.to_dict(), "clock": TimeManager.to_dict()})
	f.close()


func _read() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var()
	f.close()
	if typeof(v) != TYPE_DICTIONARY or int(v.get("version", 0)) != VERSION:
		return {}
	return v


## Restore the saved session into GameState + TimeManager. Returns false if there is none.
func load_game() -> bool:
	var d := _read()
	if d.is_empty():
		return false
	GameState.from_dict(d["state"])
	TimeManager.from_dict(d.get("clock", {}))
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func write_handoff() -> void:
	if not enabled:
		return
	var f := FileAccess.open(handoff_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(Chapter.handoff(), "  "))
		f.close()


# ── Settings ────────────────────────────────────────────────────────────────

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in settings:
			settings[k] = cfg.get_value("settings", k, settings[k])
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)
	apply_settings()


func apply_settings() -> void:
	Audio.set_master_volume(float(settings["volume"]))
	TimeManager.pace = str(settings["pace"])
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
