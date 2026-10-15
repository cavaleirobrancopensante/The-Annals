extends SceneTree
## Checks the village below the house: the standing, control gained and lost at its thresholds,
## the neglect that lowers it, the tithe and labour while controlled, the cards that read it, and the save.
## godot --headless --path . --script res://tests/village_test.gd

var failures := 0
var ran := false


func _process(_delta: float) -> bool:
	if ran:
		return false
	ran = true
	var v = root.get_node("Village")
	var ws = root.get_node("WorldState")
	var ee = root.get_node("EventEngine")
	var ch = root.get_node("Chronicle")
	root.get_node("Oracle").start(5)
	ws.new_game()
	v.new_game()

	_expect("the village starts at its standing, not controlled", [v.standing, v.controlled], [v.START, false])
	_expect("it is named from its data file", v.name_of(), "Kilbride")

	# Gaining control: the standing must reach GAIN_AT, and the annals say so once.
	ch.clear()
	v.change(v.GAIN_AT - v.standing - 1)
	_expect("one point short of control, still not controlled", v.controlled, false)
	v.change(1)
	_expect("control is gained at the threshold", v.controlled, true)
	_expect("gaining control is written in the annals", ch.entries.size(), 1)

	# Holding control: a small drop does not lose it; falling to LOSS_AT does.
	v.change(-2)
	_expect("a small setback keeps control", v.controlled, true)
	v.change(-(v.standing - v.LOSS_AT))
	_expect("control is lost at the loss threshold", v.controlled, false)
	_expect("losing control is written in the annals", ch.entries.size(), 2)

	# The standing is clamped.
	v.change(100)
	_expect("the standing is capped", v.standing, v.LIMIT)
	v.change(-100)
	_expect("the standing is floored", v.standing, -v.LIMIT)

	# Neglect: no visit for more than NEGLECT_WEEKS, and the standing falls every NEGLECT_STEP weeks.
	v.new_game()
	ws.week = 10
	v.weekly()
	_expect("a recent start is not neglected", v.standing, v.START)
	ws.week = v.NEGLECT_WEEKS + 2 * v.NEGLECT_STEP + 2
	v.weekly()
	_expect("a week that is not a step does not fall", v.standing, v.START)
	ws.week = 8 * v.NEGLECT_STEP
	v.weekly()
	_expect("a neglected village loses a point on a step week", v.standing, v.START - 1)
	v.touch()
	ws.week = 8 * v.NEGLECT_STEP + v.NEGLECT_STEP
	v.weekly()
	_expect("a visit restarts the clock", v.standing, v.START - 1)

	# Tithe and labour: only while controlled.
	v.new_game()
	v.controlled = true
	v.touch()
	ws.set_resource("food", 50)
	ws.set_resource("firewood", 10)
	ws.week = 40
	v.weekly()
	_expect("a controlled village tithes food on its week", ws.res("food"), 50 + v.TITHE_FOOD)
	_expect("and firewood", ws.res("firewood"), 10 + v.TITHE_FIREWOOD)
	ws.set_resource("food", 50)
	ws.week = 41
	v.weekly()
	_expect("no tithe in between", ws.res("food"), 50)
	_expect("labour feeds the fields in summer", v.labour_food("summer"), v.LABOUR_FOOD)
	_expect("and not in winter", v.labour_food("winter"), 0)
	v.controlled = false
	_expect("an uncontrolled village gives no labour", v.labour_food("summer"), 0)

	# The cards read control and standing.
	var village_card = ee.cards_by_id["village_alms"]
	v.new_game()
	_expect("alms are asked at standing 2", ee._check_world(village_card["when"]), true)
	v.change(10)
	_expect("alms are not asked of a controlled village", ee._check_world(village_card["when"]), false)
	var banns = ee.cards_by_id["village_banns"]
	_expect("banns need control", ee._check_world(banns["when"]), true)
	v.new_game()
	_expect("banns are not read before control", ee._check_world(banns["when"]), false)

	# A village card that is resolved is a visit, and its standing change is applied.
	v.new_game()
	ws.week = 30
	v.touch()
	v.change(3)
	_expect("an event's standing change is applied", v.standing, v.START + 3)

	# Save round trip.
	v.standing = 7
	v.controlled = true
	v.last_contact = 88
	var saved: Dictionary = v.to_dict()
	v.new_game()
	v.from_dict(saved)
	_expect("the village survives a save", [v.standing, v.controlled, v.last_contact], [7, true, 88])

	print("village test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
	return false


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
