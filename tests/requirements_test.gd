extends SceneTree
## Checks the path entry requirements: a path that needs a tag is never drawn at random, and cannot be set without it.
## godot --headless --path . --script res://tests/requirements_test.gd

var failures := 0
var ran := false


func _process(_delta: float) -> bool:
	if ran:
		return false
	ran = true
	var pa = root.get_node("Paths")
	root.get_node("Oracle").start(23)

	var drawn_priest := 0
	for i in 400:
		var m := {"id": i + 1, "status": "home", "tags": [], "traits": [], "path": ""}
		pa.assign(m, false)
		if str(m["path"]) == "priest":
			drawn_priest += 1
	_expect("a priest is never drawn at random", drawn_priest, 0)

	var m := {"id": 1, "status": "home", "tags": [], "traits": [], "path": "monk", "path_known": false}
	_expect("a priest path is refused without the tag", pa.set_path(m, "priest"), false)
	_expect("the refused path leaves the brother as he was", str(m["path"]), "monk")
	m["tags"].append("ordained")
	_expect("the priest path is allowed with the tag", pa.set_path(m, "priest"), true)
	_expect("the priest path is then known", str(m["path"]), "priest")
	_expect("a path with no requirement still sets", pa.set_path(m, "soldier"), true)

	# Perks: a known path gives one to checks on its skill once the level is reached; a hidden path gives none.
	var sk = root.get_node("Skills")
	var mk := {"id": 9, "status": "home", "path": "monk", "path_known": true, "skills": {"devotion": 5, "scribing": 3}}
	_expect("a known monk at devotion five has one perk on devotion", pa.perk_bonus(mk, "devotion"), 1)
	_expect("a known monk at scribing three has the Illuminator", pa.perk_bonus(mk, "scribing"), 1)
	mk["skills"]["scribing"] = 2
	_expect("a known monk below the perk level has none", pa.perk_bonus(mk, "scribing"), 0)
	mk["path_known"] = false
	_expect("a hidden path gives no perk bonus", pa.perk_bonus(mk, "devotion"), 0)
	_expect("a hidden path lists no perks", pa.perks_of(mk).size(), 0)
	_expect("the skills module is loaded", sk != null, true)

	print("Requirement checks: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)
	return false


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
