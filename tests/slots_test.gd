extends SceneTree
## Checks the ten save slots: writing and summaries, opening, deleting, and moving an old single save into a slot.
## Uses its own file names, so no real save is touched.
## godot --headless --path . --script res://tests/slots_test.gd

var failures := 0
var ran := false


func _process(_delta: float) -> bool:
	if ran:
		return false
	ran = true
	var ss = root.get_node("SaveSystem")
	var game = root.get_node("Game")
	var world = root.get_node("WorldState")
	root.get_node("Oracle").start(5)
	ss.prefix = "user://test_slot_"
	ss.legacy_path = "user://test_legacy_save.json"
	ss.enabled = true
	for n in range(1, ss.SLOT_COUNT + 1):
		ss.delete_slot(n)
	if FileAccess.file_exists(ss.legacy_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ss.legacy_path))

	_expect("ten slots", ss.SLOT_COUNT, 10)
	_expect("an empty slot has no file", ss.has_slot(3), false)

	game.new_game()
	ss.new_slot(3)
	game.new_game()
	ss.save_game()
	_expect("a started house writes its slot", ss.has_slot(3), true)
	var s: Dictionary = ss.summary(3)
	var house: String = world.full_house_name()
	_expect("summary names the house", s.get("house", ""), house)
	_expect("summary counts the brothers", int(s.get("brothers", -1)), world.living_monks().size())
	_expect("summary is not fallen", bool(s.get("fallen", true)), false)

	ss.new_slot(4)
	game.new_game()
	ss.save_game()
	_expect("a second house goes to another slot", ss.has_slot(4), true)

	_expect("opening slot 3 succeeds", ss.open_slot(3), true)
	_expect("opening restores the house", world.full_house_name(), house)
	_expect("the open slot is 3", ss.slot, 3)

	ss.delete_slot(4)
	_expect("a deleted slot is empty", ss.has_slot(4), false)
	_expect("slot 3 survives another delete", ss.has_slot(3), true)

	# A single save from before the slots moves into the first empty slot.
	ss.delete_slot(1)
	var legacy := FileAccess.open(ss.legacy_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify(ss.build_data()))
	legacy.close()
	ss.migrate_legacy()
	_expect("the old save moves into slot 1", ss.has_slot(1), true)
	_expect("the old save is no longer loose", FileAccess.file_exists(ss.legacy_path), false)

	for n in range(1, ss.SLOT_COUNT + 1):
		ss.delete_slot(n)
	print("Slots checks: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)
	return true


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
