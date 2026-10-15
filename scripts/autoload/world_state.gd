extends Node
## Single source of truth: calendar, resources, brothers and world tags.

const SEASONS := ["spring", "summer", "autumn", "winter"]
const WEEKS_PER_SEASON := 12
const WEEKS_PER_YEAR := 48
const RESOURCES := ["food", "firewood", "medicine", "books", "goodwill"]
const VOCATIONS := {
	"scribe": "scribe",
	"farmer": "farmer",
	"healer": "healer",
	"builder": "builder",
	"cook": "cook",
	"soldier": "former soldier",
}
const VIRTUES := ["devout", "patient", "gentle", "learned", "brave", "generous", "cheerful"]
const FLAWS := ["proud", "wrathful", "doubting", "gluttonous", "stubborn", "restless", "melancholy"]
const HEALTH_WORDS := ["dead", "gravely ill", "unwell", "well"]

var patron := ""
var place := ""
var week := 0
var resources := {}
var monks: Array = []
## tag -> week it expires (-1 = permanent)
var tags := {}
var abbot_id := -1
var abbot_since_year := 1
var next_monk_id := 1
var fallen := false

var _name_pool: Array = []
var _patrons: Array = []
var _places: Array = []


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/names.json"))
	if data is Dictionary:
		_name_pool = data.get("monks", [])
		_patrons = data.get("patrons", [])
		_places = data.get("places", [])
	else:
		push_error("Could not read res://data/names.json")


# --- New game -----------------------------------------------------------

func new_game() -> void:
	week = 0
	resources = {"food": 120, "firewood": 30, "medicine": 4, "books": 2, "goodwill": 3}
	monks = []
	tags = {}
	next_monk_id = 1
	fallen = false
	patron = str(Oracle.pick(_patrons))
	place = str(Oracle.pick(_places))
	var first_abbot := generate_monk(Oracle.pick(["scribe", "healer", "farmer"]), ["devout"], 48, 62)
	abbot_id = first_abbot["id"]
	abbot_since_year = 1
	for voc in ["farmer", "farmer", "healer", "scribe", "builder", "cook", "soldier"]:
		generate_monk(voc, [], 19, 58)


func house_name() -> String:
	return "%s's" % patron


func full_house_name() -> String:
	return "%s's at %s" % [patron, place]


# --- Calendar -----------------------------------------------------------

func year() -> int:
	return int(week / float(WEEKS_PER_YEAR)) + 1


func season_index() -> int:
	return int(week / float(WEEKS_PER_SEASON)) % 4


func season() -> String:
	return SEASONS[season_index()]


func week_in_season() -> int:
	return week % WEEKS_PER_SEASON + 1


# --- Brothers -----------------------------------------------------------

func generate_monk(vocation = "", traits: Array = [], age_min: int = 18, age_max: int = 50) -> Dictionary:
	if vocation == null or str(vocation) == "":
		vocation = Oracle.pick(VOCATIONS.keys())
	var t: Array = traits.duplicate()
	if not t.any(func(x): return x in VIRTUES):
		t.append(Oracle.pick(VIRTUES))
	if not t.any(func(x): return x in FLAWS):
		t.append(Oracle.pick(FLAWS))
	var m := {
		"id": next_monk_id,
		"name": _new_name(),
		"vocation": str(vocation),
		"traits": t,
		"tags": [],
		"age": Oracle.range_int(age_min, age_max),
		"health": 3,
		"status": "home",
		"away_weeks": 0,
		"joined": year(),
	}
	next_monk_id += 1
	monks.append(m)
	return m


func _new_name() -> String:
	var taken := []
	for m in living_monks():
		taken.append(m["name"])
	var free := _name_pool.filter(func(n): return not n in taken)
	if free.is_empty():
		return "Brother %d" % next_monk_id
	return str(Oracle.pick(free))


func get_monk(id) -> Dictionary:
	if id == null:
		return {}
	for m in monks:
		if int(m["id"]) == int(id):
			return m
	return {}


func is_living(m: Dictionary) -> bool:
	return m.get("status", "") in ["home", "away"]


func living_monks() -> Array:
	return monks.filter(func(m): return is_living(m))


func home_monks() -> Array:
	return monks.filter(func(m): return m["status"] == "home")


func abbot() -> Dictionary:
	return get_monk(abbot_id)


func monk_has(m: Dictionary, tag: String) -> bool:
	return tag in m.get("traits", []) or tag in m.get("tags", [])


func display_name(m: Dictionary) -> String:
	if m.is_empty():
		return "no one"
	if int(m["id"]) == abbot_id and is_living(m):
		return "Abbot %s" % m["name"]
	return "Brother %s" % m["name"]


func vocation_name(m: Dictionary) -> String:
	return VOCATIONS.get(m.get("vocation", ""), str(m.get("vocation", "")))


func count_home(vocation: String) -> int:
	return home_monks().filter(func(m): return m["vocation"] == vocation and int(m["health"]) >= 2).size()


func change_health(m: Dictionary, delta: int) -> void:
	m["health"] = clampi(int(m["health"]) + delta, 1, 3)


func kill_monk(m: Dictionary, cause: String = "") -> void:
	if not is_living(m):
		return
	m["status"] = "dead"
	m["died"] = year()
	m["cause"] = cause
	EventBus.monk_died.emit(m)


func depart_monk(m: Dictionary) -> void:
	if not is_living(m):
		return
	m["status"] = "departed"
	m["left"] = year()


# --- Tags ---------------------------------------------------------------

func has_tag(t: String) -> bool:
	if not tags.has(t):
		return false
	var expiry := int(tags[t])
	return expiry < 0 or expiry > week


func add_tag(t: String, weeks: int = -1) -> void:
	tags[t] = -1 if weeks < 0 else week + weeks


func remove_tag(t: String) -> void:
	tags.erase(t)


func expire_tags() -> void:
	for k in tags.keys():
		var expiry := int(tags[k])
		if expiry >= 0 and expiry <= week:
			tags.erase(k)


# --- Resources ----------------------------------------------------------

## Storage limits until Phase 2 adds the granary, woodshed and infirmary.
const CAPS := {"food": 320, "firewood": 120, "medicine": 20}


func change_resource(r: String, delta: int) -> void:
	set_resource(r, int(resources.get(r, 0)) + delta)


func set_resource(r: String, value: int) -> void:
	resources[r] = clampi(value, 0, int(CAPS.get(r, 1 << 30)))


func res(r: String) -> int:
	return int(resources.get(r, 0))


# --- Save ---------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"patron": patron,
		"place": place,
		"week": week,
		"resources": resources,
		"monks": monks,
		"tags": tags,
		"abbot_id": abbot_id,
		"abbot_since_year": abbot_since_year,
		"next_monk_id": next_monk_id,
		"fallen": fallen,
	}


func from_dict(d: Dictionary) -> void:
	patron = d.get("patron", "")
	place = d.get("place", "")
	week = int(d.get("week", 0))
	resources = {}
	for r in d.get("resources", {}):
		resources[r] = int(d["resources"][r])
	monks = []
	for m in d.get("monks", []):
		for key in ["id", "age", "health", "away_weeks", "joined", "died", "left"]:
			if m.has(key):
				m[key] = int(m[key])
		monks.append(m)
	tags = {}
	for t in d.get("tags", {}):
		tags[t] = int(d["tags"][t])
	abbot_id = int(d.get("abbot_id", -1))
	abbot_since_year = int(d.get("abbot_since_year", 1))
	next_monk_id = int(d.get("next_monk_id", 1))
	fallen = bool(d.get("fallen", false))
