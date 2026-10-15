extends Node
## Skirmishes: rare fights, played one round at a time. Each round the house gives an order
## (hold, press, pray, or withdraw) and the exchange is worked out with the oracle.
## Brothers who are struck leave the line; the house can lose them for good.

const PATH := "res://data/skirmish/encounters.json"
## Multipliers on our strength and on the enemy's, per stance.
const STANCE := {
	"hold": {"ours": 0.8, "theirs": 0.7},
	"press": {"ours": 1.3, "theirs": 1.3},
	"pray": {"ours": 1.0, "theirs": 1.0},
}
const STANCE_ORDER := ["hold", "press", "pray"]

var encounters: Dictionary = {}
## The fight in progress, or {} when none.
var active: Dictionary = {}
## How the last fight ended: victory, defeat or withdraw.
var last_outcome := ""


func _ready() -> void:
	load_data()


## Reads the data again, so a language change takes effect.
func load_data() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(Strings.data(PATH)))
	if data is Dictionary:
		encounters = data
	else:
		push_error("Could not read %s" % PATH)


func is_active() -> bool:
	return not active.is_empty()


## Starts a fight. With no fighters given, the three best brothers at home go out.
func start(id: String, fighter_ids: Array = [], node_id: String = "") -> bool:
	if is_active() or not encounters.has(id):
		return false
	var ids := fighter_ids
	if ids.is_empty():
		ids = _best_at_home(3)
	var fighters := []
	for fid in ids:
		var m := WorldState.get_monk(int(fid))
		if WorldState.is_living(m):
			fighters.append({"id": int(fid), "power": _power(m)})
	if fighters.is_empty():
		return false
	var enc: Dictionary = encounters[id]
	active = {
		"id": id,
		"node": node_id,
		"hp": int(enc["strength"]),
		"max": int(enc["strength"]),
		"rounds": int(enc["rounds"]),
		"round": 1,
		"unbreakable": bool(enc.get("unbreakable", false)),
		"fighters": fighters,
		"first": int(fighters[0]["id"]),
		"log": [],
	}
	EventBus.event_presented.emit(current_view())
	return true


func current_view() -> Dictionary:
	if not is_active():
		return {}
	var enc: Dictionary = encounters[active["id"]]
	var node := Road.node_name(str(active["node"]))
	var text := ""
	if active["log"].is_empty():
		text = Chronicle.format(str(enc["intro"]), {"node": node})
	else:
		text = "\n".join(active["log"])
	var names := []
	for f in active["fighters"]:
		names.append(WorldState.display_name(WorldState.get_monk(int(f["id"]))))
	text += "\n\n" + tr("skirm.status") % [
		enc["enemy"], int(active["hp"]), int(active["max"]), int(active["round"]), int(active["rounds"]),
		", ".join(names)]
	return {
		"title": str(enc["title"]),
		"text": text,
		"choices": [
			{"label": tr("skirm.hold"), "enabled": true, "requires": {}},
			{"label": tr("skirm.press"), "enabled": true, "requires": {}},
			{"label": tr("skirm.pray"), "enabled": true, "requires": {}},
			{"label": tr("skirm.withdraw"), "enabled": true, "requires": {}},
		],
	}


## index 0-2 is a stance, 3 is withdraw.
func choose(index: int) -> void:
	if not is_active():
		return
	active["log"] = []
	if index == 3:
		if Oracle.chance(0.6):
			_finish("withdraw")
			return
		active["log"].append("The brothers could not get clear, and the riders pressed in.")
		_strike_back()
	else:
		_exchange(STANCE_ORDER[clampi(index, 0, 2)])
	if not is_active():
		return
	if active["fighters"].is_empty():
		_finish("defeat")
		return
	active["round"] = int(active["round"]) + 1
	if int(active["round"]) > int(active["rounds"]):
		_finish("withdraw")
		return
	EventBus.event_presented.emit(current_view())


func _exchange(stance: String) -> void:
	var mult: Dictionary = STANCE[stance]
	var our_power := 0.0
	for f in active["fighters"]:
		our_power += int(f["power"])
	var ours: float = our_power * float(mult["ours"]) + Oracle.range_int(0, 3) + (1 if stance == "pray" else 0)
	var theirs: float = float(active["hp"]) * float(mult["theirs"]) + Oracle.range_int(0, 3)
	if ours > theirs:
		var dmg := 1
		if stance == "press" and ours - theirs >= 3:
			dmg = 2
		active["hp"] = int(active["hp"]) - dmg
		active["log"].append("We drove them back%s." % (" hard" if dmg > 1 else ""))
	else:
		_strike_back()
	if int(active["hp"]) <= 0:
		_finish("victory")
		return
	if not bool(active["unbreakable"]) and int(active["hp"]) <= int(active["max"]) / 2 and Oracle.chance(0.3):
		active["log"].append("Their line broke, and the riders ran for the glen.")
		_finish("victory")


func _strike_back() -> void:
	var f: Dictionary = Oracle.pick(active["fighters"])
	var m := WorldState.get_monk(int(f["id"]))
	var name := WorldState.display_name(m)
	f["power"] = int(f["power"]) - 1
	if int(f["power"]) > 0:
		active["log"].append(tr("skirm.hurt") % name)
		return
	active["fighters"].erase(f)
	if int(m["health"]) <= 1 and Oracle.chance(0.5):
		WorldState.kill_monk(m, "a skirmish")
		active["log"].append(tr("skirm.down") % name)
	else:
		WorldState.change_health(m, -1)
		active["log"].append(tr("skirm.wounded") % name)


func _finish(outcome: String) -> void:
	var enc: Dictionary = encounters[active["id"]]
	var data: Dictionary = enc[outcome]
	last_outcome = outcome
	# Effects that name a brother ("monk_dies", "monk_health") fall on the first of the party.
	var bind := {"monk": int(active["first"])}
	var lines := [str(data["chronicle"])]
	EventEngine._apply(data.get("effects", {}), bind, lines)
	var ctx := {"node": Road.node_name(str(active["node"]))}
	Chronicle.add(" ".join(lines), "skirmish", ctx)
	active = {}


## A fighter's strength: the better of Might with Melee, or Hand with Ranged, halved.
func _power(m: Dictionary) -> int:
	var best := maxi(Skills.stat(m, "might") + Skills.level(m, "melee"), Skills.stat(m, "hand") + Skills.level(m, "ranged"))
	var p := int(round(best / 2.0))
	if WorldState.monk_has(m, "brave"):
		p += 1
	if int(m["health"]) == 2:
		p -= 1
	return maxi(1, p)


func _best_at_home(count: int) -> Array:
	var pool := WorldState.home_monks().filter(func(m): return int(m["id"]) != WorldState.abbot_id)
	pool.sort_custom(func(a, b): return _power(a) > _power(b))
	var ids := []
	for i in mini(count, pool.size()):
		ids.append(int(pool[i]["id"]))
	return ids


func to_dict() -> Dictionary:
	return active.duplicate(true)


func from_dict(d: Dictionary) -> void:
	active = {}
	if d.is_empty() or not encounters.has(str(d.get("id", ""))):
		return
	active = d.duplicate(true)
	for k in ["hp", "max", "rounds", "round", "first"]:
		active[k] = int(active[k])
	for f in active["fighters"]:
		f["id"] = int(f["id"])
		f["power"] = int(f["power"])
