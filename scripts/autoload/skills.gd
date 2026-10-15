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
const JOB_SKILL := {"fields": "labour", "woods": "labour", "hunt": "hunting", "kitchen": "cookery", "infirmary": "medicine", "scriptorium": "scribing", "chapel": "devotion", "confessional": "counsel", "gate": "holding_gate", "guesthouse": "hospitality"}
const JOB_DIFFICULTY := {"fields": 1, "woods": 1, "hunt": 2, "kitchen": 2, "infirmary": 3, "scriptorium": 3, "chapel": 1, "confessional": 2, "gate": 2, "guesthouse": 1}
## Food a successful hunt brings in, and more on a critical success.
const HUNT_FOOD := 3
const HUNT_FOOD_CRITICAL := 5
## Practice points for one level, multiplied by the level being reached (12, 24, 36, 48, 60).
const POINTS_PER_LEVEL := 12.0
const TRAINING_WEEKS := 4
const TRAINING_POINTS := 3.0
## A teacher must hold the skill at this level or above.
const TEACHER_LEVEL := 3
## Until a brother's path is known, he can grow his skills only to this level.
const GENERALIST_CAP := 3
## The path each job tests at the year's review. Monks, priests, soldiers and pilgrims have no job here.
const JOB_PATH := {"fields": "householder", "woods": "builder", "hunt": "hunter", "kitchen": "cook", "infirmary": "healer", "scriptorium": "scribe", "chapel": "monk", "confessional": "priest", "gate": "soldier", "guesthouse": "pilgrim"}
## A hidden brother's progress at one job. At HINT_WEEKS he gets a hint of his path (a shortlist
## that always holds the true path). At REVEAL_WEEKS, if his job is his path, the path is revealed.
## Work at level EXPERIENCED_LEVEL or more adds double progress, so skilled brothers are reviewed sooner.
const HINT_WEEKS := 52.0
const REVEAL_WEEKS := 104.0
const EXPERIENCED_LEVEL := 3

var stat_ids: Array = []
var stat_names := {}
var skill_ids_by_stat := {}
var skill_names := {}
var stat_of_skill := {}


func _ready() -> void:
	load_data()


## Reads the data again, so a language change takes effect.
func load_data() -> void:
	stat_ids.clear()
	var data = JSON.parse_string(FileAccess.get_file_as_string(Strings.data(DATA_PATH)))
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
	if not m.has("path"):
		Paths.assign(m, true)
	m["path_known"] = bool(m.get("path_known", false))
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


## The highest level a brother can reach in a skill, given his path.
## Hidden path: the generalist cap. Known path: the top level if the skill is on it, otherwise
## the level he already has (off-path skills stop growing).
func growth_cap(m: Dictionary, kid: String) -> int:
	if not bool(m.get("path_known", false)):
		return GENERALIST_CAP
	if Paths.grows(str(m.get("path", "")), kid):
		return MAX_LEVEL
	return level(m, kid)


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
	var cap := growth_cap(m, kid)
	if lvl >= cap:
		m["practice"][kid] = 0.0
		return gained
	var pool := float(m["practice"].get(kid, 0.0)) + amount
	while lvl < cap and pool >= points_to_next(lvl):
		pool -= points_to_next(lvl)
		lvl += 1
		gained.append({"skill": kid, "level": lvl})
	if lvl >= cap:
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


## The year at a job. A brother with a hidden path who has worked one job for a year learns whether
## his calling is that work, in degrees. A hint names a shortlist of paths; a job that is not his path
## is ruled out and not counted again. Reveal comes later, only if the job is his path.
## Only the jobs in JOB_PATH are reviewed; monks, priests, soldiers and pilgrims are revealed by events alone.
## Returns this week's hints and reveals, each with its brother and job.
func weekly_reviews() -> Array:
	var reviews := []
	for m in WorldState.home_monks():
		if bool(m.get("path_known", false)) or not training_of(m).is_empty() or int(m["health"]) < 2:
			continue
		var job := WorldState.job_of(m)
		if not JOB_PATH.has(job) or WorldState.job_blocked(job) or job in _ruled_out(m):
			continue
		# Work at a job adds progress; work already at level three or more adds twice as much.
		var skill := str(JOB_SKILL[job])
		m["job_weeks"] = float(m.get("job_weeks", 0.0)) + (2.0 if level(m, skill) >= EXPERIENCED_LEVEL else 1.0)
		var matches := str(JOB_PATH[job]) == str(m.get("path", ""))
		if not bool(m.get("hinted", false)) and float(m["job_weeks"]) >= HINT_WEEKS:
			m["hinted"] = true
			m["candidates"] = _candidates(m, job, matches)
			if not matches:
				_ruled_out(m).append(job)
			reviews.append({"monk": m, "job": job, "hint": true, "candidates": m["candidates"]})
		if matches and float(m["job_weeks"]) >= REVEAL_WEEKS:
			Paths.reveal(m)
			reviews.append({"monk": m, "job": job, "reveal": true})
	return reviews


## A hint names the true path with two others. A brother whose job is not his path also has
## that job left out of the hint, so the hint never names the job he is ruled out from.
func _candidates(m: Dictionary, job: String, matches: bool) -> Array:
	var true_path := str(m.get("path", ""))
	var pool := []
	for id in Paths._order:
		if id != true_path and (matches or id != str(JOB_PATH[job])):
			pool.append(id)
	var out := [true_path]
	for i in 2:
		if pool.is_empty():
			break
		out.append(pool.pop_at(Oracle.range_int(0, pool.size() - 1)))
	var shuffled := []
	while not out.is_empty():
		shuffled.append(out.pop_at(Oracle.range_int(0, out.size() - 1)))
	return shuffled


func _ruled_out(m: Dictionary) -> Array:
	if not m.has("ruled_out"):
		m["ruled_out"] = []
	return m["ruled_out"]


# --- Uses of the skills -------------------------------------------------

## How much a brother's work counts for: a success counts in full, a critical success
## counts half again as much, and a failure counts half.
func work_multiplier(m: Dictionary, stat_id: String, skill_id: String, difficulty: int) -> float:
	var r := check(m, stat_id, skill_id, difficulty)
	if not r["success"]:
		return 0.5
	return 1.5 if r["critical"] else 1.0


## Food the hunters bring in this week: a Hand and Hunting check per hunter, harder in winter.
func hunt_food(winter: bool) -> int:
	var food := 0
	var difficulty := HARD if winter else EASY
	for m in WorldState.working_on("hunt"):
		var r := check(m, "hand", "hunting", difficulty)
		if r["success"]:
			food += HUNT_FOOD_CRITICAL if r["critical"] else HUNT_FOOD
	return food


## A check's difficulty in words, for the player.
func difficulty_word(d: int) -> String:
	if d <= EASY:
		return "easy"
	if d <= HARD:
		return "hard"
	return "very hard"


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
	if bool(m.get("path_known", false)) and not Paths.grows(str(m.get("path", "")), kid):
		return "That is not the path he is set on."
	if level(m, kid) >= growth_cap(m, kid):
		return "He has nothing more to learn in that yet."
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
