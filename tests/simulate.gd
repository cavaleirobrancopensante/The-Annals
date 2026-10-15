extends Node
## Headless test: plays a house for several years, choosing at random,
## then prints the chronicle and a summary. Never touches the real save.
##
## godot --headless --path . res://tests/simulate.tscn -- --seed=42 --years=3


func _ready() -> void:
	SaveSystem.enabled = false
	var seed_value := 42
	var years := 3
	var build_policy := true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.get_slice("=", 1))
		elif arg.begins_with("--years="):
			years = int(arg.get_slice("=", 1))
		elif arg == "--no-build":
			build_policy = false

	Game.new_game(seed_value)
	var choices_made := 0
	var hunger_weeks := 0
	var cold_weeks := 0
	var builds := []
	for i in years * WorldState.WEEKS_PER_YEAR:
		if build_policy:
			for b in ["granary", "woodshed", "scriptorium", "infirmary"]:
				if WorldState.can_build(b) and Game.build(b):
					builds.append("%s (year %d)" % [b, WorldState.year()])
					break
		Game.advance_week()
		if WorldState.has_tag("hunger"):
			hunger_weeks += 1
		if WorldState.has_tag("cold"):
			cold_weeks += 1
		var guard := 0
		while EventEngine.has_pending() and guard < 10:
			var view := EventEngine.current_view()
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
	print("Seed %d, reached year %d, %s %d" % [seed_value, WorldState.year(), WorldState.season(), WorldState.week_in_season()])
	print("Entries: %d, choices made: %d, fallen: %s" % [Chronicle.entries.size(), choices_made, WorldState.fallen])
	print("Resources: %s" % WorldState.resources)
	print("Living brothers: %d of %d ever" % [WorldState.living_monks().size(), WorldState.monks.size()])
	print("Builds: %s" % str(builds))
	print("Weeks hungry: %d, weeks cold: %d" % [hunger_weeks, cold_weeks])
	print("World tags: %s" % str(WorldState.tags.keys()))
	var fired := EventEngine.fired.keys()
	fired.sort()
	print("Events fired (%d of %d cards): %s" % [fired.size(), EventEngine.cards.size(), EventEngine.fired])
	var never := EventEngine.cards.map(func(c): return c["id"]).filter(func(id): return not id in fired)
	print("Never fired: %s" % str(never))
	get_tree().quit()
