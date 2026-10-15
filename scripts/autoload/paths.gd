extends Node
## The paths a brother's life can take, like classes. A path is hidden until an event reveals it,
## and once revealed it decides which skills the brother can grow. See docs/SKILLS.md.

const DATA_PATH := "res://data/paths/paths.json"

var _paths := {}
var _order: Array = []


func _ready() -> void:
	load_data()


## Reads the data again, so a language change takes effect.
func load_data() -> void:
	_order.clear()
	var data = JSON.parse_string(FileAccess.get_file_as_string(Strings.data(DATA_PATH)))
	if not data is Dictionary:
		push_error("Could not read %s" % DATA_PATH)
		return
	for p in data.get("paths", []):
		_paths[str(p["id"])] = p
		_order.append(str(p["id"]))


func exists(id: String) -> bool:
	return _paths.has(id)


func name_of(id: String) -> String:
	if not _paths.has(id):
		return ""
	return str(_paths[id]["name"])


## The skill ids a path lets its brothers grow.
func growth_of(id: String) -> Array:
	if not _paths.has(id):
		return []
	return _paths[id].get("growth", [])


func grows(id: String, skill_id: String) -> bool:
	return skill_id in growth_of(id)


## Perks a brother has earned on his path: names of perks whose skill has reached the level.
func perks_of(m: Dictionary) -> Array:
	var out := []
	var id := str(m.get("path", ""))
	if not _paths.has(id) or not bool(m.get("path_known", false)):
		return out
	for p in _paths[id].get("perks", []):
		if Skills.level(m, str(p["skill"])) >= int(p["level"]):
			out.append(str(p["name"]))
	return out


## Each perk a brother has earned on a skill adds one to his checks on that skill.
## A hidden path gives no perks.
func perk_bonus(m: Dictionary, skill_id: String) -> int:
	var id := str(m.get("path", ""))
	if not _paths.has(id) or not bool(m.get("path_known", false)):
		return 0
	var n := 0
	for p in _paths[id].get("perks", []):
		if str(p["skill"]) == skill_id and Skills.level(m, skill_id) >= int(p["level"]):
			n += 1
	return n


## The tag a brother must have to take this path, or "" if it needs none.
func _needs_tag(id: String) -> String:
	return str(_paths.get(id, {}).get("needs_tag", ""))


## Draws a path at random, weighted by the data. Known paths are shown; hidden ones are not.
func assign(m: Dictionary, known: bool) -> void:
	if str(m.get("path", "")) == "":
		var weights := []
		for id in _order:
			# A path that needs a tag is never drawn: a brother must earn it in play.
			weights.append(0.0 if _needs_tag(id) != "" else float(_paths[id].get("weight", 1)))
		m["path"] = _order[Oracle.pick_weighted_index(weights)]
	m["path_known"] = known


## Reveals a brother's hidden path. Returns false if it was already known or there is none.
func reveal(m: Dictionary) -> bool:
	if bool(m.get("path_known", false)) or not _paths.has(str(m.get("path", ""))):
		return false
	m["path_known"] = true
	return true


## Moves a brother to another path (an exit and a new calling). The new path is known.
func set_path(m: Dictionary, id: String) -> bool:
	if not _paths.has(id):
		return false
	var tag := _needs_tag(id)
	if tag != "" and not WorldState.monk_has(m, tag):
		return false
	m["path"] = id
	m["path_known"] = true
	return true
