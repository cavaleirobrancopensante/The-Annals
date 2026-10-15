extends Node
## Saves the whole house to user:// as JSON after every change.

const PATH := "user://annals_save.json"
const VERSION := 1

## Turned off by the headless simulation so tests never touch a real save.
var enabled := true


func save_game() -> void:
	if not enabled:
		return
	var data := {
		"version": VERSION,
		"oracle": Oracle.to_dict(),
		"world": WorldState.to_dict(),
		"chronicle": Chronicle.to_dict(),
		"events": EventEngine.to_dict(),
		"game": Game.to_dict(),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not write save file: %s" % PATH)
		return
	f.store_string(JSON.stringify(data))
	f.close()


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func load_game() -> bool:
	if not enabled or not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary or int(data.get("version", 0)) != VERSION:
		push_warning("Save file missing or from another version; starting a new house.")
		return false
	Oracle.from_dict(data.get("oracle", {}))
	WorldState.from_dict(data.get("world", {}))
	Chronicle.from_dict(data.get("chronicle", {}))
	EventEngine.from_dict(data.get("events", {}))
	Game.from_dict(data.get("game", {}))
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
