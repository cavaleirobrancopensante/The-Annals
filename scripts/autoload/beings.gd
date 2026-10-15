extends Node
## Beings that can be allies or enemies of the house: the Marred (rational), a chimera nest, an engine of the
## old world, and the Hollow (the last three not rational). Each has an attitude from -5 to 5. Events move it
## with the "attitude" effect, and cards read it with attitude_min and attitude_max. Control is a check in the
## card: a rational being is moved by talk, a non-rational one by the skill that fits its nature.

const LIMIT := 5
## Allied at this attitude or above, hostile at this or below.
const ALLIED := 3
const HOSTILE := -3
const IDS := ["marred", "chimera", "engine", "hollow"]
const PATH := "res://data/beings/beings.json"
## Weekly chance of a card from the Hollow's deck while the Hollow is hostile.
const HOLLOW_CHANCE := 0.04

var attitudes := {}
var _last_state := {}


func new_game() -> void:
	attitudes = {}
	_last_state = {}
	for id in IDS:
		attitudes[id] = 0
		_last_state[id] = "neutral"


## The being's name, in the current language.
func name_of(id: String) -> String:
	var data = JSON.parse_string(FileAccess.get_file_as_string(Strings.data(PATH)))
	if data is Dictionary and data.get("beings", {}).has(id):
		return str(data["beings"][id].get("name", id))
	return id


func attitude(id: String) -> int:
	return int(attitudes.get(id, 0))


func state(id: String) -> String:
	var a := attitude(id)
	if a >= ALLIED:
		return "allied"
	if a <= HOSTILE:
		return "hostile"
	return "neutral"


## Moves a being's attitude. Crossing into or out of allied or hostile is written in the annals.
func change(id: String, delta: int) -> void:
	if not attitudes.has(id):
		push_warning("Unknown being '%s'" % id)
		return
	attitudes[id] = clampi(attitude(id) + delta, -LIMIT, LIMIT)
	var now := state(id)
	if now != str(_last_state.get(id, "neutral")):
		_last_state[id] = now
		Chronicle.add(tr("being." + now) % name_of(id), "being")


## Once a week: an allied engine turns the woodshed's wheel.
func weekly() -> void:
	if state("engine") == "allied":
		WorldState.change_resource("firewood", 1)


## Whether the Hollow's deck gets a turn this week: only while it is hostile.
func wants_hollow_event() -> bool:
	return state("hollow") == "hostile" and Oracle.chance(HOLLOW_CHANCE)


func to_dict() -> Dictionary:
	return {"attitudes": attitudes, "last_state": _last_state}


func from_dict(d: Dictionary) -> void:
	new_game()
	for id in d.get("attitudes", {}):
		if IDS.has(id):
			attitudes[id] = clampi(int(d["attitudes"][id]), -LIMIT, LIMIT)
	for id in d.get("last_state", {}):
		if IDS.has(id):
			_last_state[id] = str(d["last_state"][id])
