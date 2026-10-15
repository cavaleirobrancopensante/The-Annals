extends SceneTree
## Checks the stats and skills: data shape, starting values, the 2d6 check and the caps.
## godot --headless --path . --script res://tests/skills_test.gd

var failures := 0
var ran := false


func _process(_delta: float) -> bool:
	if ran:
		return false
	ran = true
	var sk = root.get_node("Skills")
	var oracle = root.get_node("Oracle")
	oracle.start(7)

	_expect("eight stats", sk.stat_ids.size(), 8)
	_expect("three skills each", sk.skill_ids_by_stat["hand"].size(), 3)
	_expect("ranged belongs to hand", sk.stat_of_skill["ranged"], "hand")
	_expect("twenty-four skills in all", sk.skill_names.size(), 24)

	var m := {}
	sk.init_monk(m)
	var starts_ok := true
	for sid in sk.stat_ids:
		var v: int = sk.stat(m, sid)
		if v < 1 or v > 3:
			starts_ok = false
	_expect("starting stats are 1 to 3", starts_ok, true)
	_expect("no skills at start", m["skills"].size(), 0)

	sk.set_level(m, "ranged", 9)
	_expect("skill level capped at 5", sk.level(m, "ranged"), 5)
	sk.set_stat(m, "might", 9)
	_expect("stat capped at 5", sk.stat(m, "might"), 5)

	# The check: a fixed stat and skill, many rolls. Totals must stay within the 2d6 range.
	var brother := {"stats": {"might": 2}, "skills": {"melee": 3}}
	var lowest := 99
	var highest := -99
	var crits := 0
	var wins := 0
	var rolls := 2000
	for i in rolls:
		var r: Dictionary = sk.check(brother, "might", "melee", sk.EASY)
		var dice: Array = r["dice"]
		_check_dice(dice)
		lowest = mini(lowest, r["total"])
		highest = maxi(highest, r["total"])
		if r["critical"]:
			crits += 1
		if r["success"]:
			wins += 1
		_check_result(r, sk)
	_expect("bonus is stat plus skill", sk.check(brother, "might", "melee", 7)["bonus"], 5)
	_expect("lowest total is 2d6 minimum plus bonus", lowest, 2 + 5)
	_expect("highest total is 2d6 maximum plus bonus", highest, 12 + 5)
	_expect("doubles come up about one in six", abs(float(crits) / rolls - 1.0 / 6.0) < 0.03, true)
	_expect("an easy check is usually won", float(wins) / rolls > 0.9, true)

	# Loading an old or loose brother: stats become whole numbers and fill in.
	var loose := {"stats": {"might": 2.0}, "skills": {"melee": 3.0}}
	sk.normalise(loose)
	_expect("loaded stats are whole numbers", typeof(loose["stats"]["might"]), TYPE_INT)
	_expect("missing stats filled in", loose["stats"].size(), 8)
	_expect("loaded skills are whole numbers", typeof(loose["skills"]["melee"]), TYPE_INT)

	print("Skills checks: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)
	return true


func _check_dice(dice: Array) -> void:
	for d in dice:
		if d < 1 or d > 6:
			_fail("die out of range: %s" % str(d))


func _check_result(r: Dictionary, sk) -> void:
	if r["success"] != (r["total"] >= r["difficulty"]):
		_fail("success flag disagrees with total")
	if r["margin"] != r["total"] - r["difficulty"]:
		_fail("margin wrong")


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		_fail("%s: got %s, want %s" % [label, str(got), str(want)])


func _fail(msg: String) -> void:
	failures += 1
	print("FAIL %s" % msg)
