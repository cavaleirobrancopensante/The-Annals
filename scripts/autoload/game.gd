extends Node
## The weekly turn: economy, jobs, health, travel, aging, succession, then events.

const EVENT_CHANCE := 0.55

## Brothers back from the road, waiting for their homecoming event.
var return_queue: Array = []


func new_game(seed_value: int = -1) -> void:
	Tutorial.start_offer()
	Oracle.start(seed_value)
	WorldState.new_game()
	Chronicle.clear()
	EventEngine.reset()
	Road.new_game()
	Village.new_game()
	Rule.new_game()
	return_queue = []
	var brothers := WorldState.living_monks().size() - 1
	Chronicle.add_template("founding", {"brothers": Chronicle.number_word(brothers)}, "founding")
	EventBus.world_changed.emit()
	SaveSystem.save_game()


## One day of the house's clock. Seasons, feasts and the week's turn fall on their days.
func advance_day() -> void:
	if WorldState.fallen or waiting():
		return
	var old_season := WorldState.season()
	WorldState.advance_day()
	if WorldState.season() != old_season:
		if WorldState.season() == "spring":
			_new_year()
		_season_change(old_season)
	_feast_today()
	if WorldState.day % 7 == 0:
		_weekly_turn()
	_after_change()


## Runs days up to the week's turn: the economy, the road, and any event it brings.
func advance_week() -> void:
	while not WorldState.fallen and not waiting():
		advance_day()
		if WorldState.day % 7 == 0:
			return


## Runs days until a choice is needed, a feast is kept (written into the annals), or the limit is hit.
func advance_until_something(max_days: int = 365) -> void:
	var start_entries := Chronicle.entries.size()
	for i in max_days:
		advance_day()
		if waiting() or WorldState.fallen:
			return
		if Chronicle.entries.size() > start_entries:
			return


## True while the house is waiting on a choice: an event card or a skirmish order.
func waiting() -> bool:
	return EventEngine.has_pending() or Skirmish.is_active()


func current_view() -> Dictionary:
	if Skirmish.is_active():
		return Skirmish.current_view()
	return EventEngine.current_view()


func choose(index: int) -> void:
	if Skirmish.is_active():
		Skirmish.choose(index)
	else:
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


## Sends brothers down the road. Returns false if the road refuses them.
func dispatch_party(node_id: String, member_ids: Array) -> bool:
	var p := Road.dispatch(node_id, member_ids)
	if p.is_empty():
		return false
	Chronicle.add_template("road_departure", {
		"party": Road.party_names(p),
		"node": Road.node_name(node_id),
	}, "road")
	_after_change()
	return true


## The economy, the road and the house's events, once a week.
func _weekly_turn() -> void:
	_economy()
	_practice()
	_health()
	Village.weekly()
	_travel()
	_road()
	WorldState.expire_tags()
	_check_succession()
	if _check_fall():
		return
	# One thing at a time: a waiting choice (an arrival, say) holds back the rest.
	if waiting():
		pass
	elif not return_queue.is_empty():
		var id = return_queue.pop_front()
		if not EventEngine.pick_event("return", int(id)):
			_generic_return(int(id))
	elif Village.wants_event() and EventEngine.pick_event("village"):
		pass
	elif Oracle.chance(EVENT_CHANCE):
		EventEngine.pick_event("abbey")
	EventBus.week_advanced.emit(WorldState.week)


## A great feast is kept by the whole house and written into the annals; it stops the clock.
func _feast_today() -> void:
	var f := Calendar.great_feast(WorldState.cal_year, WorldState.cal_month, WorldState.cal_day)
	if f.is_empty():
		return
	Chronicle.add_template("feast_kept", {"feast": f["name"]}, "feast")


## Work and training teach the brothers; the annals note a skill once it reaches level three.
func _practice() -> void:
	for g in Skills.weekly_practice():
		_note_level(g)
	for r in Skills.weekly_reviews():
		var name := WorldState.display_name(r["monk"])
		if r.has("reveal"):
			Chronicle.add(tr("review.reveal") % [name, Paths.name_of(str(r["monk"]["path"]))], "review")
		else:
			var names := []
			for id in r["candidates"]:
				names.append(Paths.name_of(str(id)))
			Chronicle.add(tr("review.hint") % [WorldState.job_name(str(r["job"])), name, ", ".join(names)], "review")
	var t := Skills.weekly_training()
	for g in t["gained"]:
		_note_level(g)
	for f in t["finished"]:
		Chronicle.add_template("training_done", {
			"monk": WorldState.display_name(f["monk"]),
			"skill": str(Skills.skill_names[f["skill"]]).to_lower(),
		}, "training")


func _note_level(g: Dictionary) -> void:
	if int(g["level"]) < 3:
		return
	Chronicle.add_template("skill_rose", {
		"monk": WorldState.display_name(g["monk"]),
		"skill": str(Skills.skill_names[g["skill"]]).to_lower(),
		"level": Chronicle.number_word(int(g["level"])),
	}, "skill")


## Sets a brother to learn a skill, from a teacher at home or alone. Returns "" or the reason.
func start_training(monk_id: int, kid: String, teacher_id: int = -1) -> String:
	var m := WorldState.get_monk(monk_id)
	var reason := Skills.start_training(m, kid, teacher_id)
	if reason != "":
		return reason
	var skill := str(Skills.skill_names[kid]).to_lower()
	if teacher_id >= 0:
		Chronicle.add_template("training_begun", {
			"monk": WorldState.display_name(m),
			"skill": skill,
			"teacher": WorldState.display_name(WorldState.get_monk(teacher_id)),
		}, "training")
	else:
		Chronicle.add_template("training_alone", {"monk": WorldState.display_name(m), "skill": skill}, "training")
	_after_change()
	return ""


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
	var field_work := 0.0
	for m in WorldState.working_on("fields"):
		field_work += Skills.work_multiplier(m, "might", "labour", Skills.EASY)
	var produce := int(round(field_work * _field_yield(s)))
	produce += Skills.hunt_food(s == "winter")
	produce += Village.labour_food(s)
	if WorldState.has_tag("water_pump") and s in ["summer", "autumn"]:
		produce += 3
	if WorldState.has_tag("blight"):
		produce = int(produce * 0.5)
	produce = int(round(produce * (100.0 + Rule.value("field_pct")) / 100.0))
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
		WorldState.change_resource("medicine", WorldState.count_working("infirmary") + int(Rule.value("medicine_bonus")))


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
				_check_saint(m)
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


## Moves the parties on the road. Arrivals meet a place; returns queue their brothers.
func _road() -> void:
	var t := Road.tick()
	for p in t["returned"]:
		for id in p["members"]:
			return_queue.append(int(id))
	for p in t["arrived"]:
		if p.get("purpose", "") == "colony":
			_found_priory(p)
			continue
		var living := _living_ids(p)
		if not waiting() and _ambushed(p, living):
			continue
		if waiting() or not EventEngine.pick_event("node", living[0] if not living.is_empty() else -1, p["node"]):
			Chronicle.add_template("road_arrival_generic", {
				"party": Road.party_names(p),
				"node": Road.node_name(p["node"]),
			}, "road")


func _living_ids(p: Dictionary) -> Array:
	var ids := []
	for id in p["members"]:
		if WorldState.is_living(WorldState.get_monk(int(id))):
			ids.append(int(id))
	return ids


func _travel() -> void:
	for m in WorldState.living_monks():
		# Brothers on a party's road are moved by Road, not by the monk_away timer.
		if m["status"] != "away" or int(m.get("party", 0)) > 0:
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
	WorldState.house_year += 1
	for m in WorldState.living_monks():
		m["age"] = int(m["age"]) + 1
		var age := int(m["age"])
		if age >= 60 and Oracle.chance((age - 58) * 0.012):
			var ctx := _death_ctx(m)
			ctx["age_words"] = Chronicle.number_word(age)
			WorldState.kill_monk(m, "old age")
			Chronicle.add_template("death_age", ctx, "death")
			_check_saint(m)
	WorldState.change_resource("goodwill", int(Rule.value("goodwill_per_year")))
	WorldState.change_resource("food", int(Rule.value("food_per_year")))
	var novice_chance := maxf(0.0, 0.5 + Rule.value("novice_pct") / 100.0)
	if WorldState.living_monks().size() < 16 and Oracle.chance(novice_chance):
		_novice()


## The scriptorium finishes a book at the end of summer and of winter.
func _finish_books() -> void:
	var books := 0.0
	for m in WorldState.working_on("scriptorium"):
		books += Skills.work_multiplier(m, "wit", "scribing", Skills.EASY)
	if WorldState.has_tag("lamp"):
		books *= 2
	WorldState.change_resource("books", int(round(books * (100.0 + Rule.value("book_pct")) / 100.0)))


func _season_change(old_season: String) -> void:
	if old_season in ["summer", "winter"]:
		_finish_books()
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
	if WorldState.season() == "autumn":
		_tithe_priories()


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


## Sends three brothers to found a daughter house. Returns "" on success, otherwise the reason.
func send_colony(node_id: String, member_ids: Array) -> String:
	if member_ids.size() != 3:
		return "A colony is three brothers."
	if WorldState.has_priory(node_id):
		return "A daughter house already stands at %s." % Road.node_name(node_id)
	if Road.node_kind(node_id) == "town":
		return "A daughter house cannot be raised in a town."
	if WorldState.living_monks().size() < 12:
		return "The house is too small to spare three brothers."
	var reason := Road.refusal(node_id, member_ids)
	if reason != "":
		return reason
	var p := Road.dispatch(node_id, member_ids)
	p["purpose"] = "colony"
	Chronicle.add_template("colony_departure", {
		"party": Road.party_names(p),
		"node": Road.node_name(node_id),
	}, "road")
	_after_change()
	return ""


func set_rule(axis_id: String, option_id: String) -> bool:
	if not Rule.set_option(axis_id, option_id):
		return false
	if WorldState.res("goodwill") > 0:
		WorldState.change_resource("goodwill", -1)
	Chronicle.add_template("rule_changed", {
		"option": str(Rule.option(axis_id, option_id)["name"]).to_lower(),
		"axis": str(Rule.axis(axis_id)["name"]).to_lower(),
	}, "rule")
	_after_change()
	return true


## The colony arrives: its brothers stay as the daughter house and leave the roster.
func _found_priory(p: Dictionary) -> void:
	var who := Road.party_names(p)
	var node_id := str(p["node"])
	Road.drop_party(int(p["id"]))
	for id in p["members"]:
		var m := WorldState.get_monk(int(id))
		if WorldState.is_living(m):
			m["tags"] = m["tags"].filter(func(t): return not str(t).begins_with("on_"))
			m["party"] = 0
			WorldState.depart_monk(m)
	WorldState.priories.append({"node": node_id, "since": WorldState.year()})
	WorldState.add_tag("priory_founded")
	Chronicle.add_template("priory_founded", {"party": who, "node": Road.node_name(node_id), "patron": WorldState.patron}, "road")
	_after_change()


## Each autumn a daughter house pays its tithe, or is lost if its people have closed their doors.
func _tithe_priories() -> void:
	for pr in WorldState.priories.duplicate():
		var node_id := str(pr["node"])
		if Road.is_hostile(node_id):
			WorldState.priories.erase(pr)
			Chronicle.add_template("priory_lost", {"node": Road.node_name(node_id)}, "road")
			continue
		var f := str(Road.node(node_id).get("faction", ""))
		var tithe := clampi(3 + Road.standing(f), 1, 9)
		WorldState.change_resource("food", tithe)
		Chronicle.add_template("priory_tithe", {
			"node": Road.node_name(node_id),
			"food": Chronicle.number_word(tithe),
		}, "season")
	if WorldState.priories.is_empty():
		WorldState.remove_tag("priory_founded")


## A devout brother who dies old may be acclaimed a saint, which brings pilgrims and goodwill.
func _check_saint(m: Dictionary) -> void:
	if not WorldState.monk_has(m, "devout") or int(m["age"]) < 55:
		return
	var chance := 0.5 * (1.0 + Rule.value("saint_pct") / 100.0)
	if not Oracle.chance(chance):
		return
	WorldState.saints.append({"name": str(m["name"]), "year": WorldState.year()})
	WorldState.change_resource("goodwill", 2)
	WorldState.add_tag("relics")
	Chronicle.add_template("saint_acclaimed", {"monk": WorldState.display_name(m)}, "saint")


func _novice() -> void:
	var m := WorldState.generate_monk("", [], 17, 24, true)
	Chronicle.add_template("novice_joins", {"monk": WorldState.display_name(m)}, "joining")


## Road men may wait at a place whose people do not love the house.
func _ambushed(p: Dictionary, living: Array) -> bool:
	var node_id := str(p["node"])
	var node := Road.node(node_id)
	if living.is_empty() or Road.standing(str(node.get("faction", ""))) > -1:
		return false
	if not str(node.get("kind", "")) in ["town", "hold", "ruin"]:
		return false
	if not Oracle.chance(0.3):
		return false
	return Skirmish.start("ambush_on_road", living, node_id)


# --- Save ---------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"return_queue": return_queue}


func from_dict(d: Dictionary) -> void:
	return_queue = []
	for id in d.get("return_queue", []):
		return_queue.append(int(id))
