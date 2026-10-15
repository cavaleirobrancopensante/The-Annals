extends Node
## Saves each house to its own slot in user:// as JSON, after every change.
## Ten slots. Each file opens with a short summary, so the menu can list the houses without loading them.

const SLOT_COUNT := 10
const VERSION := 7
const LEGACY_PATH := "user://annals_save.json"

## Slot files are prefix + number + ".json". Tests point these elsewhere.
var prefix := "user://annals_slot_"
var legacy_path := LEGACY_PATH
## The slot of the house being played; 0 when no house is open.
var slot := 0
## Turned off by the headless simulation and UI tests so they never touch a real save.
var enabled := true


func slot_path(n: int) -> String:
	return "%s%d.json" % [prefix, n]


func has_slot(n: int) -> bool:
	return FileAccess.file_exists(slot_path(n))


func build_data() -> Dictionary:
	return {
		"version": VERSION,
		"summary": _summary_now(),
		"oracle": Oracle.to_dict(),
		"world": WorldState.to_dict(),
		"chronicle": Chronicle.to_dict(),
		"events": EventEngine.to_dict(),
		"game": Game.to_dict(),
		"road": Road.to_dict(),
		"village": Village.to_dict(),
		"rule": Rule.to_dict(),
		"skirmish": Skirmish.to_dict(),
		"tutorial": Tutorial.to_dict(),
	}


func save_game() -> void:
	if not enabled or slot == 0:
		return
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("Could not write save file: %s" % slot_path(slot))
		return
	f.store_string(JSON.stringify(build_data()))
	f.close()


func _summary_now() -> Dictionary:
	return {
		"house": WorldState.full_house_name(),
		"date": WorldState.date_text(),
		"year": WorldState.year(),
		"brothers": WorldState.living_monks().size(),
		"fallen": WorldState.fallen,
		"saved": Time.get_datetime_string_from_system(true).substr(0, 16),
	}


## What the menu shows for a slot. Files from before summaries get a plain stand-in.
func summary(n: int) -> Dictionary:
	var data = _read(slot_path(n))
	if data == null:
		return {}
	if data.has("summary"):
		return data["summary"]
	return {"house": "A house from an earlier save", "date": "", "year": 0, "brothers": 0, "fallen": false, "saved": ""}


## Makes slot n the open house. The caller then starts a new house, which saves into it.
func new_slot(n: int) -> void:
	slot = n
	Settings.set_last_slot(n)


## Loads the house in slot n and makes it the open one. Returns false if it cannot be read.
func open_slot(n: int) -> bool:
	if not enabled or not has_slot(n):
		return false
	var data = _read(slot_path(n))
	if data == null or int(data.get("version", 0)) != VERSION:
		push_warning("Save in slot %d is missing or from another version." % n)
		return false
	Oracle.from_dict(data.get("oracle", {}))
	WorldState.from_dict(data.get("world", {}))
	Chronicle.from_dict(data.get("chronicle", {}))
	EventEngine.from_dict(data.get("events", {}))
	Game.from_dict(data.get("game", {}))
	Road.from_dict(data.get("road", {}))
	Village.from_dict(data.get("village", {}))
	Rule.from_dict(data.get("rule", {}))
	Skirmish.from_dict(data.get("skirmish", {}))
	# Houses saved before the walk-through existed are never offered it.
	Tutorial.from_dict(data.get("tutorial", {"state": "done"}))
	slot = n
	Settings.set_last_slot(n)
	if not data.has("summary"):
		save_game()
	return true


func delete_slot(n: int) -> void:
	if not has_slot(n):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(n)))
	if slot == n:
		slot = 0
	if Settings.last_slot == n:
		Settings.set_last_slot(0)


## Moves a save from the single-file era into the first empty slot.
func migrate_legacy() -> void:
	if not FileAccess.file_exists(legacy_path):
		return
	for n in range(1, SLOT_COUNT + 1):
		if not has_slot(n):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(legacy_path), ProjectSettings.globalize_path(slot_path(n)))
			return


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else null
