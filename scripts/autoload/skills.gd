extends Node
## Eight stats, each with three skills. Every brother carries his stats and skill levels,
## and every check is 2d6 + stat + skill against a difficulty. See docs/SKILLS.md.

const DATA_PATH := "res://data/skills/skills.json"
const MAX_LEVEL := 5
## Stats a brother starts with; they are set by his origin, not his vocation.
const START_STAT_MIN := 1
const START_STAT_MAX := 3
const EASY := 7
const HARD := 10
const VERY_HARD := 13

var stat_ids: Array = []
var stat_names := {}
var skill_ids_by_stat := {}
var skill_names := {}
var stat_of_skill := {}


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not data is Dictionary:
		push_error("Could not read %s" % DATA_PATH)
		return
	for s in data.get("stats", []):
		var sid := str(s["id"])
		stat_ids.append(sid)
		stat_names[sid] = str(s["name"])
		skill_ids_by_stat[sid] = []
		for k in s["skills"]:
			var kid := str(k["id"])
			skill_ids_by_stat[sid].append(kid)
			skill_names[kid] = str(k["name"])
			stat_of_skill[kid] = sid


# --- Brothers -----------------------------------------------------------

## Gives a new brother his starting stats (1 to 3 each) and no skills yet.
func init_monk(m: Dictionary) -> void:
	var stats := {}
	for sid in stat_ids:
		stats[sid] = Oracle.range_int(START_STAT_MIN, START_STAT_MAX)
	m["stats"] = stats
	m["skills"] = {}


## Makes a brother loaded from a save match the current shape: whole numbers, and stats present.
func normalise(m: Dictionary) -> void:
	if not m.has("stats"):
		init_monk(m)
	var stats := {}
	for sid in stat_ids:
		stats[sid] = int(m["stats"].get(sid, START_STAT_MIN))
	m["stats"] = stats
	var skills := {}
	for kid in m.get("skills", {}):
		skills[kid] = int(m["skills"][kid])
	m["skills"] = skills


func stat(m: Dictionary, sid: String) -> int:
	return int(m.get("stats", {}).get(sid, 0))


func level(m: Dictionary, kid: String) -> int:
	return int(m.get("skills", {}).get(kid, 0))


func set_level(m: Dictionary, kid: String, value: int) -> void:
	if not m.has("skills"):
		m["skills"] = {}
	m["skills"][kid] = clampi(value, 0, MAX_LEVEL)


func set_stat(m: Dictionary, sid: String, value: int) -> void:
	if not m.has("stats"):
		init_monk(m)
	m["stats"][sid] = clampi(value, 1, MAX_LEVEL)


# --- Checks -------------------------------------------------------------

## Rolls 2d6 and adds the brother's stat and skill. A check with an empty skill id uses the stat alone.
func check(m: Dictionary, stat_id: String, skill_id: String, difficulty: int) -> Dictionary:
	var a := Oracle.range_int(1, 6)
	var b := Oracle.range_int(1, 6)
	var bonus := stat(m, stat_id) + level(m, skill_id)
	var total := a + b + bonus
	return {
		"dice": [a, b],
		"bonus": bonus,
		"total": total,
		"difficulty": difficulty,
		"success": total >= difficulty,
		"margin": total - difficulty,
		"critical": a == b,
	}
