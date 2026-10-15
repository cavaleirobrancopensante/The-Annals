extends Node
## The weekly turn: economy, jobs, health, travel, aging, succession, then events.

const EVENT_CHANCE := 0.55

## Brothers back from the road, waiting for their homecoming event.
var return_queue: Array = []


func new_game(seed_value: int = -1) -> void:
	Oracle.start(seed_value)
	WorldState.new_game()
	Chronicle.clear()
	EventEngine.reset()
	return_queue = []
	var brothers := WorldState.living_monks().size() - 1
	Chronicle.add_template("founding", {"brothers": Chronicle.number_word(brothers)}, "founding")
	EventBus.world_changed.emit()
	SaveSystem.save_game()


func advance_week() -> void:
	if WorldState.fallen or EventEngine.has_pending():
		return
	var old_season := WorldState.season()
	WorldState.week += 1
	if WorldState.season() != old_season:
		if WorldState.season() == "spring":
			_new_year()
		_season_change(old_season)
	_economy()
	_health()
	_travel()
	WorldState.expire_tags()
	_check_succession()
	if _check_fall():
		return
	if not return_queue.is_empty():
		var id = return_queue.pop_front()
		if not EventEngine.pick_event("return", int(id)):
			_generic_return(int(id))
	elif Oracle.chance(EVENT_CHANCE):
		EventEngine.pick_event("abbey")
	_after_change()
	EventBus.week_advanced.emit(WorldState.week)


## Runs weeks until a choice is needed, something is written, or the limit is hit.
func advance_until_something(max_weeks: int = 48) -> void:
	var start_entries := Chronicle.entries.size()
	for i in max_weeks:
		advance_week()
		if EventEngine.has_pending() or WorldState.fallen:
			return
		if Chronicle.entries.size() > start_entries:
			return


func choose(index: int) -> void:
	EventEngine.resolve(index)
	_after_change()


## Player actions on the estate. Each one saves and refreshes the screen.
func build(b: String) -> bool:
	if not WorldState.build(b):
		return false
	Chronicle.add_template("built_" + b, {}, "building")
	_after_change()
	return true


func set_job(m: Dictionary, job: String) -> void:
	WorldState.set_job(m, job)
	_after_change()


func _after_change() -> void:
	_check_succession()
	_check_fall()
	EventBus.world_changed.emit()
	SaveSystem.save_game()


# --- Economy ------------------------------------------------------------

## Food per field worker per week, by season.
func _field_yield(s: String) -> int:
	match s:
		"spring":
			return 4
		"summer":
			return 6
		"autumn":
			return 10
	return 0


func _economy() -> void:
	var s := WorldState.season()
	var home := WorldState.home_monks()
	var n := home.size()

	# Food: field workers produce, the kitchen stretches what is there, everyone eats.
	var produce := WorldState.count_working("fields") * _field_yield(s)
	if WorldState.has_tag("water_pump") and s in ["summer", "autumn"]:
		produce += 3
	if WorldState.has_tag("blight"):
		produce = int(produce * 0.5)
	var food := WorldState.res("food") + produce + WorldState.cooks_at_work() - n
	WorldState.set_resource("food", food)
	if food < 0:
		_hunger(home)

	# Firewood: woodcutters gather outside winter; the house burns more in winter.
	var per_wood := {"spring": 1, "summer": 2, "autumn": 3, "winter": 0}
	var gather := WorldState.count_working("woods") * int(per_wood[s])
	var burn := 0
	if s == "winter":
		burn = 2 + int(ceil(n / 4.0))
	elif s == "autumn":
		burn = 1
	var wood := WorldState.res("firewood") + gather - burn
	WorldState.set_resource("firewood", wood)
	if wood < 0 and s == "winter":
		_cold(home)

	var wis := WorldState.week_in_season()
	if s in ["spring", "summer"] and wis % 3 == 0:
		WorldState.change_resource("medicine", WorldState.count_working("infirmary"))
	# The scriptorium finishes a book at the end of summer and of winter.
	if wis == WorldState.WEEKS_PER_SEASON and s in ["summer", "winter"]:
		var books := WorldState.count_working("scriptorium")
		if WorldState.has_tag("lamp"):
			books *= 2
		WorldState.change_resource("books", books)


func _hunger(home: Array) -> void:
	if not WorldState.has_tag("hunger"):
		Chronicle.add_template("hunger", {}, "hardship")
	WorldState.add_tag("hunger", 4)
	for m in home:
		if Oracle.chance(0.1):
			WorldState.change_health(m, -1)


func _cold(home: Array) -> void:
	if not WorldState.has_tag("cold"):
		Chronicle.add_template("cold", {}, "hardship")
	WorldState.add_tag("cold", 4)
	for m in home:
		if Oracle.chance(0.15 if int(m["age"]) >= 50 else 0.04):
			WorldState.change_health(m, -1)


# --- Health, travel, time -----------------------------------------------

func _healer_ready() -> bool:
	return WorldState.count_working("infirmary") > 0 and WorldState.res("medicine") > 0


func _health() -> void:
	for m in WorldState.home_monks():
		var h := int(m["health"])
		if h == 2:
			if Oracle.chance(0.2):
				WorldState.change_health(m, 1)
			elif _healer_ready() and Oracle.chance(0.2):
				WorldState.change_resource("medicine", -1)
				WorldState.change_health(m, 1)
		elif h == 1:
			var healer := _healer_ready()
			if Oracle.chance(0.04 if healer else 0.08):
				var ctx := _death_ctx(m)
				WorldState.kill_monk(m, "illness")
				Chronicle.add_template("death_illness", ctx, "death")
			elif Oracle.chance(0.3 if healer else 0.15):
				if healer:
					WorldState.change_resource("medicine", -1)
				WorldState.change_health(m, 1)


## When the abbot himself dies, date the entry by his abbacy rather than
## writing "in the spring of Abbot X, Abbot X died".
func _death_ctx(m: Dictionary) -> Dictionary:
	var ctx := {"monk": WorldState.display_name(m)}
	if int(m["id"]) == WorldState.abbot_id:
		var n := WorldState.year() - WorldState.abbot_since_year + 1
		ctx["When"] = "In the %s %s of his abbacy" % [Chronicle.ordinal(n), WorldState.season()]
		ctx["when"] = ctx["When"].to_lower()
	return ctx


func _travel() -> void:
	for m in WorldState.living_monks():
		if m["status"] != "away":
			continue
		m["away_weeks"] = int(m["away_weeks"]) - 1
		if int(m["away_weeks"]) <= 0:
			m["status"] = "home"
			m["away_weeks"] = 0
			return_queue.append(int(m["id"]))


func _generic_return(id: int) -> void:
	var m := WorldState.get_monk(id)
	if m.is_empty() or not WorldState.is_living(m):
		return
	m["tags"] = m["tags"].filter(func(t): return not str(t).begins_with("on_"))
	Chronicle.add_template("return_generic", {"monk": WorldState.display_name(m)})


func _new_year() -> void:
	for m in WorldState.living_monks():
		m["age"] = int(m["age"]) + 1
		var age := int(m["age"])
		if age >= 60 and Oracle.chance((age - 58) * 0.012):
			var ctx := _death_ctx(m)
			ctx["age_words"] = Chronicle.number_word(age)
			WorldState.kill_monk(m, "old age")
			Chronicle.add_template("death_age", ctx, "death")


func _season_change(old_season: String) -> void:
	if old_season == "autumn":
		var food := WorldState.res("food")
		var cap := WorldState.cap("food")
		var key := "harvest_fair"
		if food >= int(cap * 0.75):
			key = "harvest_good"
		elif food < int(cap * 0.35):
			key = "harvest_poor"
		Chronicle.add_template(key, {}, "season")
	if WorldState.season() == "winter" and Oracle.chance(0.35):
		Chronicle.add_template("winter_begins", {}, "season")


# --- Succession and the end ---------------------------------------------

func _check_succession() -> void:
	var ab := WorldState.abbot()
	if not ab.is_empty() and WorldState.is_living(ab):
		return
	var cands := WorldState.home_monks()
	if cands.is_empty():
		cands = WorldState.living_monks()
	if cands.is_empty():
		return
	var weights := []
	for c in cands:
		var w := 1.0 + int(c["age"]) * 0.05
		for virtue in ["devout", "learned", "patient"]:
			if WorldState.monk_has(c, virtue):
				w += 2.0
		if WorldState.monk_has(c, "tested_faith") or WorldState.monk_has(c, "pilgrim"):
			w += 1.5
		weights.append(w)
	var chosen: Dictionary = cands[Oracle.pick_weighted_index(weights)]
	var key := "election_after_death" if ab.get("status", "dead") == "dead" else "election_after_departure"
	var ctx := {"old": "Abbot %s" % ab.get("name", ""), "new_name": chosen["name"]}
	WorldState.abbot_id = int(chosen["id"])
	WorldState.abbot_since_year = WorldState.year()
	Chronicle.add_template(key, ctx, "election")
	EventBus.abbot_changed.emit(chosen)


func _check_fall() -> bool:
	if WorldState.fallen:
		return true
	if not WorldState.living_monks().is_empty():
		return false
	WorldState.fallen = true
	Chronicle.add_template("house_fell", {}, "fall")
	EventBus.house_fell.emit()
	SaveSystem.save_game()
	return true


# --- Save ---------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"return_queue": return_queue}


func from_dict(d: Dictionary) -> void:
	return_queue = []
	for id in d.get("return_queue", []):
		return_queue.append(int(id))
