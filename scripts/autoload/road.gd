extends Node
## The road: the map of places, faction standing, and parties of brothers travelling.
## Game drives time; this holds the state and the rules for sending a party.

const MAP_PATH := "res://data/road/map.json"
const MAX_PARTY := 3
const MAX_PARTIES := 3
const HOSTILE := -3
const STANDING_LIMIT := 5

var factions: Dictionary = {}
var nodes: Array = []
var node_by_id: Dictionary = {}
## Where the house stands on the map, in the same 0-1 units as the places.
var house_pos := Vector2(0.03, 0.5)

## faction id -> standing with the house, -5 (enemy) to 5 (friend)
var standings: Dictionary = {}
## {"id", "node", "members": [monk ids], "out": weeks to arrive, "back": weeks to return, "arrived": bool}
var parties: Array = []
var next_party_id := 1


func _ready() -> void:
	load_data()


## Reads the data again, so a language change takes effect.
func load_data() -> void:
	node_by_id.clear()
	var data = JSON.parse_string(FileAccess.get_file_as_string(Strings.data(MAP_PATH)))
	if data is Dictionary:
		factions = data.get("factions", {})
		nodes = data.get("nodes", [])
		for n in nodes:
			node_by_id[n["id"]] = n
		var h: Dictionary = data.get("house", {})
		house_pos = Vector2(float(h.get("x", 0.03)), float(h.get("y", 0.5)))
	else:
		push_error("Could not read %s" % MAP_PATH)


func new_game() -> void:
	standings = {}
	for f in factions:
		standings[f] = 0
	parties = []
	next_party_id = 1


# --- Places and factions ------------------------------------------------

func node(id: String) -> Dictionary:
	return node_by_id.get(id, {})


func node_name(id: String) -> String:
	return str(node(id).get("name", ""))


func node_kind(id: String) -> String:
	return str(node(id).get("kind", ""))


func faction_name(f: String) -> String:
	return str(factions.get(f, {}).get("name", f))


func standing(f: String) -> int:
	return int(standings.get(f, 0))


func change_standing(f: String, delta: int) -> void:
	if not factions.has(f):
		push_warning("Unknown faction '%s'" % f)
		return
	standings[f] = clampi(standing(f) + delta, -STANDING_LIMIT, STANDING_LIMIT)


## A place is closed when its faction is hostile, or a being that holds it is hostile.
func is_hostile(node_id: String) -> bool:
	return standing(str(node(node_id).get("faction", ""))) <= HOSTILE or being_holds(node_id)


## The being that holds this place, or "" if none does.
func being_at(node_id: String) -> String:
	return str(node(node_id).get("being", ""))


## True when a being at this place is hostile to the house.
func being_holds(node_id: String) -> bool:
	var b := being_at(node_id)
	return b != "" and Beings.state(b) == "hostile"


func weeks_one_way(node_id: String) -> int:
	var d := int(node(node_id).get("distance", 3))
	return d * 2 if WorldState.season() == "winter" else d


# --- Sending parties ----------------------------------------------------

## Empty if the party may leave, otherwise the reason it may not.
func refusal(node_id: String, member_ids: Array) -> String:
	if node(node_id).is_empty():
		return "There is no such place."
	if parties.size() >= MAX_PARTIES:
		return "Three parties are already on the road."
	if member_ids.is_empty() or member_ids.size() > MAX_PARTY:
		return "A party is one to three brothers."
	if being_holds(node_id):
		return tr("road.held_by_being") % Beings.name_of(being_at(node_id))
	if standing(str(node(node_id).get("faction", ""))) <= HOSTILE:
		return "%s will not receive the house." % faction_name(str(node(node_id).get("faction", "")))
	for id in member_ids:
		var m := WorldState.get_monk(id)
		if m.is_empty() or m["status"] != "home":
			return "Only brothers at home can go."
		if int(m["health"]) < 2:
			return "%s is too unwell to travel." % m["name"]
	return ""


## Sends brothers to a place. Returns the new party, or {} if refused.
func dispatch(node_id: String, member_ids: Array) -> Dictionary:
	if refusal(node_id, member_ids) != "":
		return {}
	var p := {
		"id": next_party_id,
		"node": node_id,
		"members": member_ids.duplicate(),
		"out": weeks_one_way(node_id),
		"back": weeks_one_way(node_id),
		"arrived": false,
	}
	next_party_id += 1
	parties.append(p)
	for id in member_ids:
		var m := WorldState.get_monk(id)
		m["status"] = "away"
		m["away_weeks"] = 0
		m["party"] = int(p["id"])
		if not "on_road" in m["tags"]:
			m["tags"].append("on_road")
	return p


func drop_party(pid: int) -> void:
	parties = parties.filter(func(p): return int(p["id"]) != pid)


func party_of(m: Dictionary) -> Dictionary:
	var pid := int(m.get("party", 0))
	for p in parties:
		if int(p["id"]) == pid:
			return p
	return {}


func party_names(p: Dictionary) -> String:
	var names := []
	for id in p["members"]:
		var m := WorldState.get_monk(id)
		if not m.is_empty() and WorldState.is_living(m):
			names.append(WorldState.display_name(m))
	if names.size() <= 1:
		return names[0] if names.size() == 1 else "no one"
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


## Moves every party one week. Returns the parties that reached their place
## this week and the parties whose brothers came home. Game turns these into events.
func tick() -> Dictionary:
	var arrived := []
	var returned := []
	for p in parties:
		if not p["arrived"]:
			p["out"] = int(p["out"]) - 1
			if int(p["out"]) <= 0:
				p["arrived"] = true
				for id in p["members"]:
					var m := WorldState.get_monk(id)
					if not m.is_empty() and WorldState.is_living(m):
						m["status"] = "away"
				arrived.append(p.duplicate(true))
		else:
			p["back"] = int(p["back"]) - 1
			if int(p["back"]) <= 0:
				returned.append(p.duplicate(true))
	for p in returned:
		parties.erase(_find(int(p["id"])))
		for id in p["members"]:
			var m := WorldState.get_monk(id)
			if m.is_empty() or not WorldState.is_living(m):
				continue
			m["party"] = 0
			m["status"] = "home"
	return {"arrived": arrived, "returned": returned}


func _find(pid: int) -> Dictionary:
	for p in parties:
		if int(p["id"]) == pid:
			return p
	return {}


# --- Save ---------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"standings": standings, "parties": parties, "next_party_id": next_party_id}


func from_dict(d: Dictionary) -> void:
	standings = {}
	for f in d.get("standings", {}):
		standings[f] = int(d["standings"][f])
	parties = []
	for p in d.get("parties", []):
		p["id"] = int(p["id"])
		p["out"] = int(p["out"])
		p["back"] = int(p["back"])
		p["members"] = p["members"].map(func(x): return int(x))
		parties.append(p)
	next_party_id = int(d.get("next_party_id", 1))
