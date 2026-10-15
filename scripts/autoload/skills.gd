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
## The skill each job exercises, and how hard the work is (1 to 3).
const JOB_SKILL := {"fields": "labour", "woods": "labour", "kitchen": "cookery", "infirmary": "medicine", "scriptorium": "scribing"}
const JOB_DIFFICULTY := {"fields": 1, "woods": 1, "kitchen": 2, "infirmary": 3, "scriptorium": 3}
## Practice points for one level, multiplied by the level being reached (12, 24, 36, 48, 60).
const POINTS_PER_LEVEL := 12.0
const TRAINING_WEEKS := 4
const TRAINING_POINTS := 3.0
## A teacher must hold the skill at this level or above.
const TEACHER_LEVEL := 3

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
	m["practice"] = {}


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
	var practice := {}
	for kid in m.get("practice", {}):
		practice[kid] = float(m["practice"][kid])
	m["practice"] = practice


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


# --- Practice -----------------------------------------------------------

## Points needed to go from a level to the next.
func points_to_next(lvl: int) -> float:
	return POINTS_PER_LEVEL * (lvl + 1)


## Points a week's work earns. Work well below a brother's level earns little.
func work_points(lvl: int, difficulty: int) -> float:
	var gap := difficulty - lvl
	if gap >= 1:
		return 2.0
	if gap == 0:
		return 1.0
	return 0.25


## Adds practice points to a skill. Returns the levels gained as {"skill", "level"} entries.
func add_practice(m: Dictionary, kid: String, amount: float) -> Array:
	var gained := []
	if not m.has("practice"):
		m["practice"] = {}
	var lvl := level(m, kid)
	if lvl >= MAX_LEVEL:
		m["practice"][kid] = 0.0
		return gained
	var pool := float(m["practice"].get(kid, 0.0)) + amount
	while lvl < MAX_LEVEL and pool >= points_to_next(lvl):
		pool -= points_to_next(lvl)
		lvl += 1
		gained.append({"skill": kid, "level": lvl})
	if lvl >= MAX_LEVEL:
		pool = 0.0
	set_level(m, kid, lvl)
	m["practice"][kid] = pool
	return gained


## Every home brother at work earns practice in the skill his job uses.
## Brothers ill or training do not work. Returns the levels gained, each with its brother.
func weekly_practice() -> Array:
	var gained := []
	for m in WorldState.home_monks():
		if not training_of(m).is_empty() or int(m["health"]) < 2:
			continue
		var job := WorldState.job_of(m)
		if not JOB_SKILL.has(job) or WorldState.job_blocked(job):
			continue
		var kid: String = JOB_SKILL[job]
		var pts := work_points(level(m, kid), int(JOB_DIFFICULTY[job]))
		for g in add_practice(m, kid, pts):
			g["monk"] = m
			gained.append(g)
	return gained


# --- Training -----------------------------------------------------------

func training_of(m: Dictionary) -> Dictionary:
	return m.get("training", {})


## Sets a brother to learn a skill for a few weeks. Teacher -1 means learning alone.
## Returns "" on success, otherwise the reason.
func start_training(m: Dictionary, kid: String, teacher_id: int) -> String:
	if not stat_of_skill.has(kid):
		return "There is no such skill."
	if not WorldState.is_living(m) or m["status"] != "home":
		return "Only a brother at home can train."
	if int(m["health"]) < 2:
		return "He is too unwell to train."
	if not training_of(m).is_empty():
		return "He is already training."
	if level(m, kid) >= MAX_LEVEL:
		return "He has nothing more to learn in that."
	if teacher_id >= 0:
		var t := WorldState.get_monk(teacher_id)
		if t.is_empty() or int(t["id"]) == int(m["id"]) or t["status"] != "home" or level(t, kid) < TEACHER_LEVEL:
			return "No brother at home can teach that yet."
	m["training"] = {"skill": kid, "weeks": TRAINING_WEEKS, "teacher": teacher_id}
	return ""


## Each brother in training earns points, doubled with a teacher. Returns the levels gained
## and the brothers who finished their weeks.
func weekly_training() -> Dictionary:
	var gained := []
	var finished := []
	for m in WorldState.monks:
		var t := training_of(m)
		if t.is_empty():
			continue
		if m["status"] != "home" or not WorldState.is_living(m):
			m.erase("training")
			continue
		var kid := str(t["skill"])
		var pts := TRAINING_POINTS
		var teacher := WorldState.get_monk(int(t["teacher"]))
		if not teacher.is_empty() and WorldState.is_living(teacher) and level(teacher, kid) >= TEACHER_LEVEL:
			pts *= 2.0
		for g in add_practice(m, kid, pts):
			g["monk"] = m
			gained.append(g)
		t["weeks"] = int(t["weeks"]) - 1
		if int(t["weeks"]) <= 0:
			m.erase("training")
			finished.append({"monk": m, "skill": kid})
	return {"gained": gained, "finished": finished}
