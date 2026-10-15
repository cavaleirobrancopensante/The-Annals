extends SceneTree
## Checks the uses of the skills: work multipliers, hunting, fighting strength and event checks.
## godot --headless --path . --script res://tests/uses_test.gd

var failures := 0
var ran := false


func _process(_delta: float) -> bool:
	if ran:
		return false
	ran = true
	var sk = root.get_node("Skills")
	var ws = root.get_node("WorldState")
	var sm = root.get_node("Skirmish")
	var ee = root.get_node("EventEngine")
	root.get_node("Oracle").start(5)

	# Work multipliers take only the three values.
	var worker := {"stats": {"might": 2, "hand": 2, "wit": 2}, "skills": {"labour": 1}, "practice": {}}
	var seen := {}
	for i in 300:
		seen[sk.work_multiplier(worker, "might", "labour", sk.EASY)] = true
	var allowed := true
	for v in seen:
		if not v in [0.5, 1.0, 1.5]:
			allowed = false
	_expect("work multipliers are 0.5, 1 or 1.5", allowed, true)
	_expect("a worker with a good chance sometimes earns full work", seen.has(1.0) or seen.has(1.5), true)

	# Hunting: nobody out, no food. A strong hunter always brings meat.
	ws.monks = []
	_expect("no hunters, no food", sk.hunt_food(false), 0)
	var hunter := {"id": 1, "status": "home", "health": 3, "job": "hunt", "vocation": "soldier",
		"training": {}, "path": "hunter", "path_known": true,
		"stats": {"might": 1, "hand": 5, "wit": 1, "craft": 1, "hardiness": 1, "lore": 1, "presence": 1, "faith": 1},
		"skills": {"hunting": 5}, "practice": {}}
	sk.normalise(hunter)
	ws.monks = [hunter]
	ws.abbot_id = 1
	var food_ok := true
	for i in 50:
		var f: int = sk.hunt_food(false)
		if f < sk.HUNT_FOOD:
			food_ok = false
	_expect("a strong hunter always brings food in summer", food_ok, true)
	# A weak hunter in winter (difficulty 10) sometimes comes home empty-handed.
	hunter["stats"]["hand"] = 1
	hunter["skills"]["hunting"] = 0
	var winter_low := 0
	for i in 200:
		if sk.hunt_food(true) == 0:
			winter_low += 1
	_expect("a weak hunter sometimes comes home empty in winter", winter_low > 0, true)

	# Fighting strength: the better of Might with Melee, or Hand with Ranged, halved.
	var soldier := {"stats": {"might": 3, "hand": 1}, "skills": {"melee": 3}, "health": 3, "tags": [], "traits": []}
	_expect("a skilled soldier is strong", sm._power(soldier), 3)
	var raw := {"stats": {"might": 1, "hand": 1}, "skills": {}, "health": 3, "tags": [], "traits": []}
	_expect("a raw brother is at least one", sm._power(raw), 1)

	# Event checks: a strong brother always succeeds a 10; a weak one (at most 13) never reaches 14.
	var strong := {"id": 2, "status": "home", "health": 3, "stats": {"presence": 5}, "skills": {"persuasion": 5},
		"practice": {}, "path": "monk", "path_known": true, "job": "scriptorium", "vocation": "scribe", "tags": [], "traits": [], "training": {}}
	var weak := {"id": 3, "status": "home", "health": 3, "stats": {"presence": 1}, "skills": {},
		"practice": {}, "path": "monk", "path_known": true, "job": "scriptorium", "vocation": "scribe", "tags": [], "traits": [], "training": {}}
	ws.monks = [strong, weak]
	var choice := {
		"check": {"stat": "presence", "skill": "persuasion", "difficulty": 10},
		"success": {"chronicle": "won"},
		"failure": {"chronicle": "lost"},
	}
	_expect("a strong brother wins the check", ee._roll_check(choice, {"monk": 2}).get("chronicle", ""), "won")
	var hard := choice.duplicate(true)
	hard["check"]["difficulty"] = 14
	_expect("a weak brother cannot reach 14", ee._roll_check(hard, {"monk": 3}).get("chronicle", ""), "lost")

	_expect("difficulty words", [sk.difficulty_word(7), sk.difficulty_word(10), sk.difficulty_word(13)], ["easy", "hard", "very hard"])

	print("Uses checks: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)
	return true


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
