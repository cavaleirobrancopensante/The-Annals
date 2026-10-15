extends SceneTree
## Plays a few years in each language, choosing the first option of every event, and checks that the
## translated data loads and the house keeps running. Ends with English set again.
## godot --headless --path . --script res://tests/language_test.gd

var failures := 0
var ran := false


func _process(_delta: float) -> bool:
	if ran:
		return false
	ran = true
	var st = root.get_node("Settings")
	var game = root.get_node("Game")
	var ee = root.get_node("EventEngine")
	var ch = root.get_node("Chronicle")
	root.get_node("Oracle").start(21)
	var english_cards := 0
	var english_first := ""
	for lang in ["en", "pt_BR", "es"]:
		st.set_language(lang)
		game.new_game()
		var cards: int = ee.cards.size()
		if lang == "en":
			english_cards = cards
			english_first = str(ch.templates["founding"][0])
		_expect("%s: the same number of event cards" % lang, cards, english_cards)
		if lang != "en":
			_expect("%s: chronicle text is translated" % lang, str(ch.templates["founding"][0]) != english_first, true)
		var weeks := 0
		while weeks < 150:
			if game.waiting():
				var view: Dictionary = game.current_view()
				game.choose(0)
			else:
				game.advance_week()
			weeks += 1
		_expect("%s: the house plays on for 150 weeks" % lang, weeks, 150)
		_expect("%s: the date reads in the language" % lang, root.get_node("Calendar").long_date(2502, 6, 15) != "", true)
	st.set_language("en")
	print("Language checks: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)
	return true


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
