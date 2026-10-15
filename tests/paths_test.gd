extends SceneTree
## Checks the paths: hidden and revealed growth, the generalist cap, perks and the path rules on training.
## godot --headless --path . --script res://tests/paths_test.gd

var failures := 0
var ran := false


func _process(_delta: float) -> bool:
	if ran:
		return false
	ran = true
	var sk = root.get_node("Skills")
	var pa = root.get_node("Paths")
	root.get_node("Oracle").start(11)

	_expect("ten paths", pa._order.size(), 10)
	_expect("monk grows devotion", pa.grows("monk", "devotion"), true)
	_expect("monk does not grow melee", pa.grows("monk", "melee"), false)

	# A hidden path: the generalist cap of three, and the path is not shown.
	var m := {"id": 1, "status": "home", "health": 3, "vocation": "scribe", "job": "scriptorium",
		"training": {}, "stats": {}, "skills": {}, "practice": {}}
	sk.init_monk(m)
	pa.assign(m, false)
	_expect("a novice's path is hidden", m["path_known"], false)
	_expect("a path is always drawn", pa.exists(str(m["path"])), true)
	_expect("hidden path caps at the generalist level", sk.growth_cap(m, "scribing"), 3)
	sk.add_practice(m, "scribing", 500.0)
	_expect("a hidden path stops at level three", sk.level(m, "scribing"), 3)

	# Reveal: the path locks. Only its growth skills advance now.
	var path := str(m["path"])
	_expect("reveal changes the path to known", pa.reveal(m), true)
	_expect("reveal twice does nothing", pa.reveal(m), false)
	var grow_skill := str(pa.growth_of(path)[0])
	var off_skill := ""
	for kid in sk.stat_of_skill:
		if not pa.grows(path, kid):
			off_skill = kid
			break
	_expect("the top growth skill can rise above three", sk.growth_cap(m, grow_skill), 5)
	_expect("an off-path skill stops at the level it has", sk.growth_cap(m, off_skill), sk.level(m, off_skill))
	sk.add_practice(m, off_skill, 500.0)
	_expect("off-path practice does nothing", sk.level(m, off_skill), 0)
	sk.add_practice(m, grow_skill, 500.0)
	_expect("on-path practice advances to five", sk.level(m, grow_skill), 5)

	# Training is refused for a skill off the path.
	m["status"] = "home"
	_expect("training off the path is refused", sk.start_training(m, off_skill, -1) != "", true)

	# A change of path moves the growth to the new path.
	_expect("a path change is accepted", pa.set_path(m, "soldier"), true)
	_expect("the soldier grows melee", pa.grows(str(m["path"]), "melee"), true)
	_expect("an unknown path is refused", pa.set_path(m, "nobody"), false)

	# Perks appear when their skill reaches the level.
	var monk := {"path": "monk", "path_known": true, "stats": {}, "skills": {"scribing": 2}, "practice": {}}
	sk.normalise(monk)
	_expect("no perk below its level", pa.perks_of(monk).size(), 0)
	sk.set_level(monk, "scribing", 3)
	_expect("the Illuminator perk at scribing three", pa.perks_of(monk), ["Illuminator"])

	# Founders are revealed; legacy brothers without a path get one, known.
	var old := {"stats": {}, "skills": {}}
	sk.normalise(old)
	_expect("a brother from an old save has a path", pa.exists(str(old["path"])), true)
	_expect("and it is known", old["path_known"], true)

	print("Paths checks: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)
	return true


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
