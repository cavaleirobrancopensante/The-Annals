extends SceneTree
## Checks practice and training: levels from points, work rates, teachers and the chronicle-free rules.
## godot --headless --path . --script res://tests/practice_test.gd

var failures := 0
var ran := false


func _process(_delta: float) -> bool:
	if ran:
		return false
	ran = true
	var sk = root.get_node("Skills")
	var ws = root.get_node("WorldState")
	root.get_node("Oracle").start(3)

	_expect("twelve points to level one", sk.points_to_next(0), 12.0)
	_expect("sixty points to level five", sk.points_to_next(4), 60.0)

	# Work rates by the gap between job and skill.
	_expect("work below level earns little", sk.work_points(4, 1), 0.25)
	_expect("work at level earns a point", sk.work_points(2, 2), 1.0)
	_expect("work above level earns most", sk.work_points(0, 3), 2.0)

	# Levels from points.
	var m := {}
	sk.init_monk(m)
	var gained: Array = sk.add_practice(m, "labour", 5.0)
	_expect("five points is not yet a level", sk.level(m, "labour"), 0)
	gained = sk.add_practice(m, "labour", 7.0)
	_expect("twelve points make level one", sk.level(m, "labour"), 1)
	_expect("one level gained is reported", gained.size(), 1)
	gained = sk.add_practice(m, "labour", 24.0)
	_expect("twenty-four more make level two", sk.level(m, "labour"), 2)
	_expect("points carry over", m["practice"]["labour"], 0.0)
	sk.add_practice(m, "labour", 200.0)
	_expect("level stops at the cap", sk.level(m, "labour"), 5)
	_expect("no practice kept at the cap", m["practice"]["labour"], 0.0)

	# A week at the fields for a brother with no labour.
	var farmer := {"id": 1, "status": "home", "health": 3, "job": "fields", "vocation": "farmer",
		"training": {}, "stats": {}, "skills": {}, "practice": {}}
	sk.normalise(farmer)
	ws.monks = [farmer]
	ws.abbot_id = 1
	var weekly: Array = sk.weekly_practice()
	_expect("one week of fields gives two points, not a level", sk.level(farmer, "labour"), 0)
	_expect("the field is practised", farmer["practice"]["labour"], 2.0)
	_expect("no levels from one week", weekly.size(), 0)

	# A brother who is ill does not work.
	farmer["health"] = 1
	sk.weekly_practice()
	_expect("an ill brother earns nothing", farmer["practice"]["labour"], 2.0)
	farmer["health"] = 3

	# Training: a brother with a teacher learns twice as fast.
	var teacher := {"id": 2, "status": "home", "health": 3, "job": "scriptorium", "vocation": "scribe",
		"training": {}, "stats": {}, "skills": {"scribing": 3}, "practice": {}}
	var pupil := {"id": 3, "status": "home", "health": 3, "job": "scriptorium", "vocation": "scribe",
		"training": {}, "stats": {}, "skills": {}, "practice": {}}
	sk.normalise(teacher)
	sk.normalise(pupil)
	ws.monks = [teacher, pupil]
	_expect("a teacher must hold the skill", sk.start_training(pupil, "scribing", 2), "")
	_expect("the pupil is now training", sk.training_of(pupil).is_empty(), false)
	_expect("a second block is refused", sk.start_training(pupil, "scribing", -1) != "", true)
	_expect("an untrained teacher is refused", sk.start_training(farmer, "scribing", 3) != "", true)
	var t: Dictionary = sk.weekly_training()
	_expect("a teacher doubles the week: six points, level zero", sk.level(pupil, "scribing"), 0)
	_expect("six points are kept", pupil["practice"]["scribing"], 6.0)
	_expect("still training after one week", sk.training_of(pupil).is_empty(), false)
	sk.weekly_training()
	sk.weekly_training()
	t = sk.weekly_training()
	_expect("four weeks finish the block", sk.training_of(pupil).is_empty(), true)
	_expect("the finished pupil is reported", t["finished"].size(), 1)
	_expect("four teacher-led weeks make level one, with twelve kept", sk.level(pupil, "scribing"), 1)
	_expect("the remainder is kept", pupil["practice"]["scribing"], 12.0)

	# Learning alone is slower: three points a week.
	var lone := {"id": 4, "status": "home", "health": 3, "job": "rest", "vocation": "scribe",
		"training": {}, "stats": {}, "skills": {}, "practice": {}}
	sk.normalise(lone)
	ws.monks.append(lone)
	sk.start_training(lone, "ruins_machines", -1)
	sk.weekly_training()
	_expect("alone, a week is three points", lone["practice"]["ruins_machines"], 3.0)

	# Training ends the brother's work for its length; an away brother stops training.
	lone["status"] = "away"
	sk.weekly_training()
	_expect("a brother who leaves cancels his training", sk.training_of(lone).is_empty(), true)

	print("Practice checks: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)
	return true


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
