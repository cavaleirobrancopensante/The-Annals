extends SceneTree
## Checks the beings that can be allies or enemies: the attitude and its limits, the allied and hostile
## states written in the annals, the allied engine's firewood, the Hollow's deck only while it is hostile,
## the cards that read attitude, and the save.
## godot --headless --path . --script res://tests/beings_test.gd

var failures := 0
var ran := false


func _process(_delta: float) -> bool:
	if ran:
		return false
	ran = true
	var b = root.get_node("Beings")
	var ws = root.get_node("WorldState")
	var ee = root.get_node("EventEngine")
	var ch = root.get_node("Chronicle")
	root.get_node("Oracle").start(9)
	ws.new_game()
	b.new_game()

	_expect("every being starts neutral at 0", [b.attitude("marred"), b.state("marred")], [0, "neutral"])
	_expect("the names come from the data file", b.name_of("hollow"), "The Hollow")

	# Allied at 3, and the annals say so once.
	ch.clear()
	b.change("chimera", 2)
	_expect("two points is still neutral", b.state("chimera"), "neutral")
	b.change("chimera", 1)
	_expect("three points is allied", b.state("chimera"), "allied")
	_expect("becoming allied is written in the annals", ch.entries.size(), 1)
	b.change("chimera", 1)
	_expect("moving within allied is not written again", ch.entries.size(), 1)

	# The limits.
	b.change("chimera", 100)
	_expect("the attitude is capped at the top", b.attitude("chimera"), b.LIMIT)
	b.change("chimera", -100)
	_expect("the attitude is floored at the bottom", b.attitude("chimera"), -b.LIMIT)
	_expect("falling to hostile is written in the annals", [b.state("chimera"), ch.entries.size()], ["hostile", 2])
	b.change("chimera", 3)
	_expect("drawing back to neutral is written too", [b.state("chimera"), ch.entries.size()], ["neutral", 3])

	# An unknown being is refused.
	b.change("nothing", 5)
	_expect("an unknown being is not added", b.attitudes.has("nothing"), false)

	# The allied engine turns the woodshed's wheel.
	b.new_game()
	ws.set_resource("firewood", 10)
	b.change("engine", b.ALLIED)
	b.weekly()
	_expect("an allied engine adds a log a week", ws.res("firewood"), 11)
	b.change("engine", -2)
	ws.set_resource("firewood", 10)
	b.weekly()
	_expect("a neutral engine adds nothing", ws.res("firewood"), 10)

	# The Hollow's deck is drawn only while the Hollow is hostile.
	b.new_game()
	var drawn_neutral := 0
	for i in 300:
		if b.wants_hollow_event():
			drawn_neutral += 1
	_expect("the Hollow's deck is never drawn while neutral", drawn_neutral, 0)
	b.change("hollow", -b.LIMIT)
	var drawn_hostile := 0
	for i in 300:
		if b.wants_hollow_event():
			drawn_hostile += 1
	_expect("the Hollow's deck is drawn while hostile", drawn_hostile > 0, true)
	_expect("and not more often than its chance allows", drawn_hostile < 300 * 0.3, true)

	# Every card loads.
	for id in ["marred_envoy", "marred_trade", "chimera_nest_found", "chimera_deer", "engine_found", "engine_turns", "hollow_stirs", "hollow_whisper", "hollow_wane"]:
		_expect("card %s is loaded" % id, ee.cards_by_id.has(id), true)
	_expect("the Hollow's cards are in the Hollow's deck", [ee.cards_by_id["hollow_whisper"]["deck"], ee.cards_by_id["hollow_wane"]["deck"]], ["hollow", "hollow"])

	# Cards read attitude.
	b.new_game()
	var banns_like = ee.cards_by_id["marred_trade"]["when"]
	_expect("marred trade needs an allied Marred", ee._check_world(banns_like), false)
	b.change("marred", 2)
	_expect("marred trade fits at attitude 2", ee._check_world(banns_like), true)
	var whisper = ee.cards_by_id["hollow_whisper"]["when"]
	_expect("names under the floor fit a hostile Hollow only", ee._check_world(whisper), false)
	b.change("hollow", -3)
	_expect("names under the floor fit at attitude -3", ee._check_world(whisper), true)

	# An effect moves the attitude.
	b.new_game()
	ee._apply({"attitude": {"chimera": 2, "marred": -1}}, {}, [])
	_expect("an event effect moves two beings at once", [b.attitude("chimera"), b.attitude("marred")], [2, -1])

	# Save round trip.
	b.attitudes["engine"] = 4
	b.attitudes["hollow"] = -5
	b._last_state["hollow"] = "hostile"
	var saved: Dictionary = b.to_dict()
	b.new_game()
	b.from_dict(saved)
	_expect("the beings survive a save", [b.attitude("engine"), b.attitude("hollow"), b.state("hollow")], [4, -5, "hostile"])

	# A hostile chimera nest closes the place it holds on the road, and an allied one does not.
	var road = root.get_node("Road")
	road.new_game()
	b.new_game()
	_expect("the nest holds slieve bloom", road.being_at("slieve_bloom"), "chimera")
	_expect("a neutral nest does not close its place", road.is_hostile("slieve_bloom"), false)
	b.change("chimera", -3)
	_expect("a hostile nest closes its place", road.is_hostile("slieve_bloom"), true)
	_expect("the refusal names the nest", road.refusal("slieve_bloom", [1]).contains("holds this place"), true)
	_expect("a place with no being is not closed", road.is_hostile("knockmore"), false)
	b.change("chimera", 6)
	_expect("an allied nest leaves its place open", road.is_hostile("slieve_bloom"), false)

	print("beings test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
	return false


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
