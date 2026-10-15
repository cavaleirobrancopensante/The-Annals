extends Node
## Single source of truth: calendar, resources, brothers, buildings and world tags.

## A season of the house is about thirteen weeks; a year about fifty-two (the house year is the calendar's, 365 days).
const WEEKS_PER_SEASON := 13
const WEEKS_PER_YEAR := 52
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


## A brother's health in words, in the player's language.
func health_word(h: int) -> String:
	return tr("health.%d" % clampi(h, 0, 3))


func job_name(job: String) -> String:
	return tr("job." + job)


func building_name(b: String) -> String:
	return tr("building.%s.name" % b)


func building_desc(b: String) -> String:
	return tr("building.%s.desc" % b)

## Jobs a brother can be given. Only brothers at home and well enough can work.
const JOB_ORDER := ["fields", "woods", "hunt", "kitchen", "infirmary", "scriptorium", "rest"]
const JOB_NAMES := {
	"fields": "Fields",
	"woods": "Woodcutting",
	"hunt": "Hunting",
	"kitchen": "Kitchen",
	"infirmary": "Infirmary",
	"scriptorium": "Scriptorium",
	"rest": "Rest",
}
## Jobs that need a building before anyone can work them.
const JOB_NEEDS := {"infirmary": "infirmary", "scriptorium": "scriptorium"}
const DEFAULT_JOB := {
	"farmer": "fields",
	"builder": "woods",
	"healer": "infirmary",
	"scribe": "scriptorium",
	"cook": "kitchen",
	"soldier": "woods",
}

## Buildings are built once, by a builder at home. Each raises a storage cap or unlocks a job.
const BUILDINGS := {
	"granary": {"name": "Granary", "cost": {"firewood": 10}, "desc": "Food stores up to 320 instead of 120."},
	"woodshed": {"name": "Woodshed", "cost": {"firewood": 6}, "desc": "Firewood stores up to 120 instead of 40."},
	"infirmary": {"name": "Infirmary", "cost": {"firewood": 12, "food": 10}, "desc": "Healers can work; medicine stores up to 20."},
	"scriptorium": {"name": "Scriptorium", "cost": {"firewood": 8}, "desc": "Scribes can copy books."},
}
const BASE_CAPS := {"food": 120, "firewood": 40, "medicine": 4}
const BUILDING_CAPS := {
	"granary": {"food": 320},
	"woodshed": {"firewood": 120},
	"infirmary": {"medicine": 20},
}

var patron := ""
var place := ""
## Days since the house's clock began (Michaelmas, Anno Domini 2500).
var day := 0
## The economy's week: day / 7. Tags and road journeys count in these.
var week := 0
## The calendar date of today.
var cal_year := 2500
var cal_month := 9
var cal_day := 29
## Days since the current season of the house began.
var season_day := 0
## Years of the house: turns on the first of March, when the spring begins.
var house_year := 1
var resources := {}
var monks: Array = []
## tag -> week it expires (-1 = permanent)
var tags := {}
## building id -> true once built
var buildings := {}
var abbot_id := -1
var abbot_since_year := 1
var next_monk_id := 1
var fallen := false
## Daughter houses raised on the road: [{"node", "since"}].
var priories: Array = []
## Brothers acclaimed as saints: [{"name", "year"}].
var saints: Array = []
## Which cohort of brothers the house is in. Starts at 1.
var generation := 1
var generation_year := 1
const GENERATION_YEARS := 15

var _name_pool: Array = []
var _patrons: Array = []
var _places: Array = []


func _ready() -> void:
	load_data()


## Reads the data again, so a language change takes effect.
func load_data() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(Strings.data("res://data/names.json")))
	if data is Dictionary:
		_name_pool = data.get("monks", [])
		_patrons = data.get("patrons", [])
		_places = data.get("places", [])
	else:
		push_error("Could not read res://data/names.json")


# --- New game -----------------------------------------------------------

func new_game() -> void:
	day = 0
	week = 0
	cal_year = Calendar.START_YEAR
	cal_month = Calendar.START_MONTH
	cal_day = Calendar.START_DAY
	season_day = Calendar.days_into_season(cal_year, cal_month, cal_day)
	house_year = 1
	resources = {"food": 120, "firewood": 30, "medicine": 4, "books": 2, "goodwill": 3}
	monks = []
	tags = {}
	buildings = {}
	next_monk_id = 1
	fallen = false
	priories = []
	saints = []
	generation = 1
	generation_year = 1
	patron = str(Oracle.pick(_patrons))
	place = str(Oracle.pick(_places))
	var first_abbot := generate_monk(Oracle.pick(["scribe", "healer", "farmer"]), ["devout"], 48, 62)
	abbot_id = first_abbot["id"]
	abbot_since_year = 1
	for voc in ["farmer", "farmer", "healer", "scribe", "builder", "cook", "soldier"]:
		generate_monk(voc, [], 19, 58)
	# The founders have set their paths already; only novices come with hidden ones.
	for m in monks:
		Paths.reveal(m)


func house_name() -> String:
	return "%s's" % patron


func full_house_name() -> String:
	return "%s's at %s" % [patron, place]


# --- Calendar -----------------------------------------------------------

func year() -> int:
	return house_year


func season() -> String:
	return Calendar.season_of(cal_month)


## Which week of the season today falls in, counting from 1.
func week_in_season() -> int:
	return mini(season_day / 7 + 1, WEEKS_PER_SEASON)


## Moves the clock one day. Game runs whatever the day brings.
func advance_day() -> void:
	var before := season()
	day += 1
	week = day / 7
	var nx: Array = Calendar.next_date(cal_year, cal_month, cal_day)
	cal_year = nx[0]
	cal_month = nx[1]
	cal_day = nx[2]
	season_day = 0 if season() != before else season_day + 1


func date_text() -> String:
	return Calendar.long_date(cal_year, cal_month, cal_day)


# --- Brothers -----------------------------------------------------------

func generate_monk(vocation = "", traits: Array = [], age_min: int = 18, age_max: int = 50, joining := false) -> Dictionary:
	if vocation == null or str(vocation) == "":
		vocation = Oracle.pick(VOCATIONS.keys())
	# A generation lasts about fifteen years. The first newcomer after that starts the next one.
	if joining and not monks.is_empty() and year() - generation_year >= GENERATION_YEARS:
		generation += 1
		generation_year = year()
		Chronicle.add_template("generation_turns", {"gen_ordinal": Chronicle.ordinal(generation)}, "generation")
	var t: Array = traits.duplicate()
	if not t.any(func(x): return x in VIRTUES):
		t.append(Oracle.pick(VIRTUES))
	if not t.any(func(x): return x in FLAWS):
		t.append(Oracle.pick(FLAWS))
	var m := {
		"id": next_monk_id,
		"name": _new_name(),
		"vocation": str(vocation),
		"job": default_job_for(str(vocation)),
		"traits": t,
		"tags": [],
		"age": Oracle.range_int(age_min, age_max),
		"health": 3,
		"status": "home",
		"away_weeks": 0,
		"joined": year(),
		"gen": generation,
	}
	Skills.init_monk(m)
	Paths.assign(m, false)
	next_monk_id += 1
	monks.append(m)
	return m


func has_priory(node_id: String) -> bool:
	for pr in priories:
		if str(pr["node"]) == node_id:
			return true
	return false


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


func default_job_for(vocation: String) -> String:
	return DEFAULT_JOB.get(vocation, "fields")


func job_of(m: Dictionary) -> String:
	return str(m.get("job", default_job_for(str(m.get("vocation", "")))))


func set_job(m: Dictionary, job: String) -> void:
	if job in JOB_ORDER and is_living(m):
		if job != str(m.get("job", "")):
			m["job_weeks"] = 0
			m["hinted"] = false
			m["candidates"] = []
		m["job"] = job


## A job is blocked until its building stands.
func job_blocked(job: String) -> bool:
	return JOB_NEEDS.has(job) and not has_building(JOB_NEEDS[job])


## Brothers at home, well enough to work, on this job. Zero if the job is blocked.
func count_working(job: String) -> int:
	return working_on(job).size()


## The brothers at home, well enough, and not training, who are on this job.
func working_on(job: String) -> Array:
	if job_blocked(job):
		return []
	return home_monks().filter(func(m): return job_of(m) == job and int(m["health"]) >= 2 and training_free(m))


## A brother learning a skill is not at his job.
func training_free(m: Dictionary) -> bool:
	return m.get("training", {}).is_empty()


func cooks_at_work() -> int:
	return count_working("kitchen")


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


# --- Buildings ----------------------------------------------------------

func has_building(b: String) -> bool:
	return bool(buildings.get(b, false))


func has_builder_at_home() -> bool:
	return home_monks().any(func(m): return m["vocation"] == "builder" and int(m["health"]) >= 2)


func can_build(b: String) -> bool:
	if not BUILDINGS.has(b) or has_building(b) or not has_builder_at_home():
		return false
	for r in BUILDINGS[b]["cost"]:
		if res(r) < int(BUILDINGS[b]["cost"][r]):
			return false
	return true


func build(b: String) -> bool:
	if not can_build(b):
		return false
	for r in BUILDINGS[b]["cost"]:
		change_resource(r, -int(BUILDINGS[b]["cost"][r]))
	buildings[b] = true
	return true


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

func cap(r: String) -> int:
	var c: int = int(BASE_CAPS.get(r, 1 << 30))
	for b in buildings:
		if has_building(b) and BUILDING_CAPS.has(b) and BUILDING_CAPS[b].has(r):
			c = int(BUILDING_CAPS[b][r])
	return c


func change_resource(r: String, delta: int) -> void:
	set_resource(r, int(resources.get(r, 0)) + delta)


func set_resource(r: String, value: int) -> void:
	resources[r] = clampi(value, 0, cap(r))


func res(r: String) -> int:
	return int(resources.get(r, 0))


# --- Winter forecast ----------------------------------------------------

const WINTER_WEEKS := 13

## Food and firewood a winter of the current household will need.
func winter_food_need() -> int:
	return home_monks().size() * WINTER_WEEKS


func winter_wood_need() -> int:
	return (2 + int(ceil(home_monks().size() / 4.0))) * WINTER_WEEKS


# --- Save ---------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"patron": patron,
		"place": place,
		"day": day,
		"week": week,
		"cal_year": cal_year,
		"cal_month": cal_month,
		"cal_day": cal_day,
		"season_day": season_day,
		"house_year": house_year,
		"resources": resources,
		"monks": monks,
		"tags": tags,
		"buildings": buildings,
		"abbot_id": abbot_id,
		"abbot_since_year": abbot_since_year,
		"next_monk_id": next_monk_id,
		"fallen": fallen,
		"priories": priories,
		"saints": saints,
		"generation": generation,
		"generation_year": generation_year,
	}


func from_dict(d: Dictionary) -> void:
	patron = d.get("patron", "")
	place = d.get("place", "")
	day = int(d.get("day", 0))
	week = int(d.get("week", 0))
	cal_year = int(d.get("cal_year", Calendar.START_YEAR))
	cal_month = int(d.get("cal_month", Calendar.START_MONTH))
	cal_day = int(d.get("cal_day", Calendar.START_DAY))
	season_day = int(d.get("season_day", 0))
	house_year = int(d.get("house_year", 1))
	resources = {}
	for r in d.get("resources", {}):
		resources[r] = int(d["resources"][r])
	monks = []
	for m in d.get("monks", []):
		for key in ["id", "age", "health", "away_weeks", "joined", "died", "left", "gen", "party"]:
			if m.has(key):
				m[key] = int(m[key])
		if not m.has("job"):
			m["job"] = default_job_for(str(m.get("vocation", "")))
		Skills.normalise(m)
		monks.append(m)
	tags = {}
	for t in d.get("tags", {}):
		tags[t] = int(d["tags"][t])
	buildings = {}
	for b in d.get("buildings", {}):
		buildings[b] = bool(d["buildings"][b])
	abbot_id = int(d.get("abbot_id", -1))
	abbot_since_year = int(d.get("abbot_since_year", 1))
	next_monk_id = int(d.get("next_monk_id", 1))
	fallen = bool(d.get("fallen", false))
	priories = []
	for pr in d.get("priories", []):
		priories.append({"node": str(pr["node"]), "since": int(pr["since"])})
	saints = []
	for sa in d.get("saints", []):
		saints.append({"name": str(sa["name"]), "year": int(sa["year"])})
	generation = int(d.get("generation", 1))
	generation_year = int(d.get("generation_year", 1))
