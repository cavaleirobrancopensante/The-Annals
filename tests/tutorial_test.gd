extends SceneTree
## Checks the walk-through's states: the offer, the seven steps, skipping, replay, and the save round trip.
## godot --headless --path . --script res://tests/tutorial_test.gd

var failures := 0
var ran := false


func _process(_delta: float) -> bool:
	if ran:
		return false
	ran = true
	var tu = root.get_node("Tutorial")
	var game = root.get_node("Game")
	game.new_game()
	_expect("a new house is offered the walk-through", tu.state, "offer")
	tu.begin()
	_expect("beginning starts at the first step", [tu.state, tu.step, tu.current_name()], ["active", 0, "house"])
	for i in tu.STEPS.size() - 1:
		tu.next()
	_expect("the last step is reached", [tu.step, tu.is_last()], [tu.STEPS.size() - 1, true])
	tu.next()
	_expect("finishing the last step ends the walk-through", tu.state, "done")
	tu.begin()
	tu.finish()
	_expect("skip all ends it at once", tu.state, "done")
	tu.begin()
	_expect("replay starts again from the first step", [tu.state, tu.step], ["active", 0])
	var saved: Dictionary = tu.to_dict()
	tu.finish()
	tu.from_dict(saved)
	_expect("the state survives a save", [tu.state, tu.step], ["active", 0])
	tu.from_dict({})
	_expect("a save without a walk-through is never offered it", tu.state, "done")
	tu.finish()
	print("Tutorial checks: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)
	return true


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
