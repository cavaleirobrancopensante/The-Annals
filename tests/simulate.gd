extends Node
## Headless test: plays a house for several years, choosing at random,
## then prints the chronicle and a summary. Never touches the real save.
##
## godot --headless --path . res://tests/simulate.tscn -- --seed=42 --years=3
## Flags: --no-build (no building policy), --no-road (brothers stay home)


func _ready() -> void:
	SaveSystem.enabled = false
	var seed_value := 42
	var years := 3
	var build_policy := true
	var road_policy := true
	var job_policy := "--passive" not in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.get_slice("=", 1))
		elif arg.begins_with("--years="):
			years = int(arg.get_slice("=", 1))
		elif arg == "--no-build":
			build_policy = false
		elif arg == "--no-road":
			road_policy = false

	Game.new_game(seed_value)
	var choices_made := 0
	var hunger_weeks := 0
	var field_sum := 0
	var home_sum := 0
	var cold_weeks := 0
	var builds := []
	var sent := 0
	var arrivals := 0
	var returns := 0
	var arrived_ids := {}
	var colonies := 0
	var rule_changes := 0
	var trainings := 0
	var controlled_weeks := 0
	for i in years * WorldState.WEEKS_PER_YEAR:
		if build_policy:
			for b in ["granary", "woodshed", "scriptorium", "infirmary"]:
				if WorldState.can_build(b) and Game.build(b):
					builds.append("%s (year %d)" % [b, WorldState.year()])
					break
		if job_policy and i % 4 == 0:
			_assign_jobs()
		if road_policy and i % 16 == 4:
			sent += _send_party()
		if road_policy and i % 60 == 30:
			colonies += 1 if _send_colony() else 0
		if i % 48 == 20 and _change_rule():
			rule_changes += 1
		if i % 40 == 10 and _train():
			trainings += 1
		var out_before := Road.parties.size()
		var priories_before := WorldState.priories.size()
		Game.advance_week()
		var founded := maxi(0, WorldState.priories.size() - priories_before)
		returns += out_before - Road.parties.size() - founded
		for p in Road.parties:
			if p["arrived"] and not arrived_ids.has(p["id"]):
				arrived_ids[p["id"]] = true
				arrivals += 1
		field_sum += WorldState.count_working("fields")
		home_sum += WorldState.home_monks().size()
		if WorldState.has_tag("hunger"):
			hunger_weeks += 1
		if WorldState.has_tag("cold"):
			cold_weeks += 1
		if Village.controlled:
			controlled_weeks += 1
		var guard := 0
		while Game.waiting() and guard < 10:
			var view := Game.current_view()
			var enabled := []
			for c in view["choices"].size():
				if view["choices"][c]["enabled"]:
					enabled.append(c)
			Game.choose(Oracle.pick(enabled) if not enabled.is_empty() else 0)
			choices_made += 1
			guard += 1
		if WorldState.fallen:
			break

	print(Chronicle.export_text())
	print("==== SUMMARY ====")
	print("Seed %d, reached %s (house year %d), %s week %d" % [seed_value, WorldState.date_text(), WorldState.year(), WorldState.season(), WorldState.week_in_season()])
	print("Entries: %d, choices made: %d, fallen: %s" % [Chronicle.entries.size(), choices_made, WorldState.fallen])
	print("Resources: %s" % WorldState.resources)
	print("Living brothers: %d of %d ever" % [WorldState.living_monks().size(), WorldState.monks.size()])
	print("Builds: %s" % str(builds))
	print("Road: parties sent %d, arrivals %d, returns %d, still out %d" % [sent, arrivals, returns, Road.parties.size()])
	print("Standings: %s" % str(Road.standings))
	print("Known places: %d of %d" % [Road.known.size(), Road.nodes.size()])
	print("Phase 4: colonies sent %d, daughter houses standing %d, rule changes %d, generation %d, saints %s" % [colonies, WorldState.priories.size(), rule_changes, WorldState.generation, str(WorldState.saints)])
	print("Rule now: %s" % str(Rule.chosen))
	var best := 0
	var learned := 0
	for m in WorldState.monks:
		for kid in m["skills"]:
			best = maxi(best, int(m["skills"][kid]))
			if int(m["skills"][kid]) >= 3:
				learned += 1
	print("Practice: trainings started %d, skills at level three or more %d, highest level %d" % [trainings, learned, best])
	print("Skirmishes fought: %d" % Chronicle.entries.filter(func(e): return e.get("kind", "") == "skirmish").size())
	print("Great feasts kept: %d" % Chronicle.entries.filter(func(e): return e.get("kind", "") == "feast").size())
	print("Weeks hungry: %d, weeks cold: %d" % [hunger_weeks, cold_weeks])
	var weeks_run := maxi(1, WorldState.week)
	var known := 0
	for mm in WorldState.monks:
		if bool(mm.get("path_known", false)):
			known += 1
	print("Field workers: %.1f a week of %.1f at home. Paths known: %d of %d brothers ever." % [float(field_sum) / weeks_run, float(home_sum) / weeks_run, known, WorldState.monks.size()])
	print("Village: standing %d, controlled for %d of %d weeks, held at the end: %s" % [Village.standing, controlled_weeks, weeks_run, str(Village.controlled)])
	print("Beings: marred %d, chimera %d, engine %d, hollow %d" % [Beings.attitude("marred"), Beings.attitude("chimera"), Beings.attitude("engine"), Beings.attitude("hollow")])
	print("World tags: %s" % str(WorldState.tags.keys()))
	var fired := EventEngine.fired.keys()
	fired.sort()
	print("Events fired (%d of %d cards): %s" % [fired.size(), EventEngine.cards.size(), EventEngine.fired])
	var never := EventEngine.cards.map(func(c): return c["id"]).filter(func(id): return not id in fired)
	print("Never fired: %s" % str(never))
	get_tree().quit()


## Sends two home brothers to a random place the road will receive.
func _send_party() -> int:
	var home := WorldState.home_monks().filter(func(m): return int(m["id"]) != WorldState.abbot_id)
	if home.size() < 5 or Road.parties.size() >= Road.MAX_PARTIES:
		return 0
	var open := []
	for n in Road.nodes:
		if Road.is_known(n["id"]) and not Road.is_hostile(n["id"]):
			open.append(n["id"])
	if open.is_empty():
		return 0
	var node_id: String = open[Oracle.range_int(0, open.size() - 1)]
	var ids := []
	for k in 2:
		var pick = Oracle.pick(home)
		ids.append(int(pick["id"]))
		home.erase(pick)
	return 1 if Game.dispatch_party(node_id, ids) else 0


## Sends three home brothers to found a daughter house at a random place that allows one.
func _send_colony() -> bool:
	var home := WorldState.home_monks().filter(func(m): return int(m["id"]) != WorldState.abbot_id)
	if home.size() < 3:
		return false
	var spots := []
	for n in Road.nodes:
		if Road.is_known(n["id"]) and n["kind"] != "town" and not Road.is_hostile(n["id"]) and not WorldState.has_priory(n["id"]):
			spots.append(n["id"])
	if spots.is_empty():
		return false
	var node_id: String = spots[Oracle.range_int(0, spots.size() - 1)]
	var ids := []
	for k in 3:
		var pick = Oracle.pick(home)
		ids.append(int(pick["id"]))
		home.erase(pick)
	return Game.send_colony(node_id, ids) == ""


## Sets a random home brother to learn his job's skill, with a teacher at home if one can teach.
func _train() -> bool:
	var home := WorldState.home_monks().filter(func(m): return Skills.training_of(m).is_empty() and int(m["health"]) >= 2)
	if home.is_empty():
		return false
	var m = Oracle.pick(home)
	var job := WorldState.job_of(m)
	if not Skills.JOB_SKILL.has(job):
		return false
	var kid: String = Skills.JOB_SKILL[job]
	var teacher := -1
	for t in WorldState.home_monks():
		if int(t["id"]) != int(m["id"]) and Skills.level(t, kid) >= Skills.TEACHER_LEVEL:
			teacher = int(t["id"])
			break
	return Game.start_training(int(m["id"]), kid, teacher) == ""


## Picks a random option on a random axis of the Rule.
func _change_rule() -> bool:
	var axis = Oracle.pick(Rule.axes)
	var options: Array = axis["options"]
	var option = Oracle.pick(options)
	return Game.set_rule(str(axis["id"]), str(option["id"]))


## A careful keeper's rota: three on the fields, two at the woods, one hunting, one in the kitchen,
## and the rest on the fields. Scriptorium and infirmary once built.
func _assign_jobs() -> void:
	var home := WorldState.home_monks()
	home.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
	var plan := ["fields", "fields", "fields", "woods", "woods", "hunt", "kitchen"]
	var i := 0
	for m in home:
		var job := "fields"
		if i < plan.size():
			job = plan[i]
		elif WorldState.has_building("scriptorium") and i % 3 == 0:
			job = "scriptorium"
		elif WorldState.has_building("infirmary") and i % 3 == 1:
			job = "infirmary"
		else:
			# The rota also staffs the four path jobs, one brother in every eight of the rest.
			match i % 8:
				2: job = "chapel"
				4: job = "gate"
				6: job = "guesthouse"
				7: job = "confessional"
		Game.set_job(m, job)
		i += 1

