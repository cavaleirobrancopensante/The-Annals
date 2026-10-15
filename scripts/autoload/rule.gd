extends Node
## The Rule: the house's chosen customs, one option on each of four axes.
## Each option nudges the economy, and cards can read it with a "rule" condition.

const PATH := "res://data/rule/rule.json"

var axes: Array = []
## axis id -> option id
var chosen: Dictionary = {}


func _ready() -> void:
	load_data()
	new_game()


## Reads the data again, so a language change takes effect.
func load_data() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(Strings.data(PATH)))
	if data is Dictionary:
		axes = data.get("axes", [])
	else:
		push_error("Could not read %s" % PATH)


func new_game() -> void:
	chosen = {}
	for a in axes:
		chosen[str(a["id"])] = "ordinary"


func axis(axis_id: String) -> Dictionary:
	for a in axes:
		if str(a["id"]) == axis_id:
			return a
	return {}


func option(axis_id: String, option_id: String) -> Dictionary:
	for o in axis(axis_id).get("options", []):
		if str(o["id"]) == option_id:
			return o
	return {}


func current(axis_id: String) -> String:
	return str(chosen.get(axis_id, "ordinary"))


func current_option(axis_id: String) -> Dictionary:
	return option(axis_id, current(axis_id))


## Sum of one modifier over the four axes, e.g. value("field_pct").
func value(key: String) -> float:
	var total := 0.0
	for a in axes:
		total += float(current_option(str(a["id"])).get(key, 0))
	return total


## True when every axis named in the condition is on the given option.
func matches(cond: Dictionary) -> bool:
	for k in cond:
		if current(str(k)) != str(cond[k]):
			return false
	return true


func set_option(axis_id: String, option_id: String) -> bool:
	if option(axis_id, option_id).is_empty() or current(axis_id) == option_id:
		return false
	chosen[axis_id] = option_id
	return true


func to_dict() -> Dictionary:
	return {"chosen": chosen}


func from_dict(d: Dictionary) -> void:
	new_game()
	for k in d.get("chosen", {}):
		if chosen.has(k):
			chosen[k] = str(d["chosen"][k])
