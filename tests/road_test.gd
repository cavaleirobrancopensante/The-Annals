extends SceneTree
## Checks for the road's fog: which places the house knows, and how it learns more.

var failures := 0


var ran := false


func _process(_delta: float) -> bool:
	if ran:
		return false
	ran = true
	var road = root.get_node("Road")
	road.load_data()
	road.new_game()

	# At the start the house knows only the places one road away from it.
	var start: Array = road.neighbours("house")
	_expect("the house has roads to three places", start.size(), 3)
	_expect("the house knows its neighbours", road.known.size(), 3)
	_expect("a far place is in the fog", road.is_known("armagh"), false)
	_expect("a far place cannot be sent to", road.refusal("armagh", [1]).contains("knows the way"), true)
	_expect("a neighbour can be sent to", road.is_known(start[0]), true)

	# A party arriving reveals the place and the places the road leads on from it.
	var target: String = start[0]
	var onward: Array = road.neighbours(target).filter(func(id): return id != "house")
	road.parties.append({"id": 99, "node": target, "members": [], "out": 1, "back": 1, "arrived": false})
	road.tick()
	_expect("arrival reveals the place", road.is_known(target), true)
	var all_onward := true
	for id in onward:
		if not road.is_known(id):
			all_onward = false
	_expect("arrival reveals the places beyond it", all_onward, true)

	# The known set survives a save, and an older save gets the house's neighbours back.
	var saved: Dictionary = road.to_dict()
	var before: int = road.known.size()
	road.new_game()
	road.from_dict(saved)
	_expect("the known places survive a save", road.known.size(), before)
	road.new_game()
	road.from_dict({"standings": {}, "parties": [], "next_party_id": 1})
	_expect("an older save knows the house's neighbours", road.known.size(), 3)

	# Every road in the map joins two places that exist, or the house.
	var broken := 0
	for r in road.roads:
		for end in [r[0], r[1]]:
			if end != "house" and road.node(end).is_empty():
				broken += 1
	_expect("every road joins real places", broken, 0)

	print("road test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
	return false


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
