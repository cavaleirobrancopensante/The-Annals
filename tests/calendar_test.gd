extends SceneTree
## Checks the calendar's arithmetic against known dates. Run with:
## godot --headless --path . --script res://tests/calendar_test.gd

var failures := 0
var ran := false


func _process(_delta: float) -> bool:
	if ran:
		return false
	ran = true
	root.get_node("Settings").set_language("en")
	var cal = root.get_node("Calendar")
	_expect("Easter 2024", cal.easter(2024), [3, 31])
	_expect("Easter 2025", cal.easter(2025), [4, 20])
	_expect("Easter 2000", cal.easter(2000), [4, 23])
	_expect("Easter 2500", cal.easter(2500), [4, 18])
	_expect("weekday 2026-10-15 is Thursday", cal.weekday(2026, 10, 15), 4)
	_expect("weekday 2024-03-31 is Sunday", cal.weekday(2024, 3, 31), 0)
	_expect("house start is Wednesday", cal.weekday(2500, 9, 29), 3)
	_expect("Advent 2024 begins 1 December", cal.feasts_on(2024, 12, 1).any(func(f): return f["id"] == "advent"), true)
	_expect("Advent 2025 begins 30 November", cal.feasts_on(2025, 11, 30).any(func(f): return f["id"] == "advent"), true)
	_expect("Christ the King 2024 is 27 October", cal.feasts_on(2024, 10, 27).any(func(f): return f["id"] == "christ_king"), true)
	_expect("Ascension 2024 is 9 May", cal.feasts_on(2024, 5, 9).any(func(f): return f["id"] == "ascension"), true)
	_expect("Pentecost 2024 is 19 May", cal.feasts_on(2024, 5, 19).any(func(f): return f["id"] == "pentecost"), true)
	_expect("Ash Wednesday 2024 is 14 February", cal.feasts_on(2024, 2, 14).any(func(f): return f["id"] == "ash_wednesday"), true)
	_expect("Michaelmas 2500 is a great feast", str(cal.great_feast(2500, 9, 29).get("id", "")), "michael")
	_expect("no feast on 2500-09-30", cal.feasts_on(2500, 9, 30).size(), 0)
	_expect("next day across a leap February", cal.next_date(2024, 2, 28), [2024, 2, 29])
	_expect("next day across the year end", cal.next_date(2500, 12, 31), [2501, 1, 1])
	_expect("days into autumn at the start", cal.days_into_season(2500, 9, 29), 28)
	_expect("days into winter from 1 December", cal.days_into_season(2024, 12, 1), 0)
	_expect("days into winter on 1 January", cal.days_into_season(2025, 1, 1), 31)
	_expect("season of February is winter", cal.season_of(2), "winter")
	_expect("church season in Lent", cal.church_season(2024, 3, 1), "lent")
	_expect("church season in Eastertide", cal.church_season(2024, 5, 1), "eastertide")
	_expect("church season in Advent", cal.church_season(2024, 12, 10), "advent")
	_expect("long date", cal.long_date(2500, 9, 29), "Wednesday 29 September 2500")
	_expect("Ss Philip and James is 11 May", cal.feasts_on(2024, 5, 11).any(func(f): return f["id"] == "philip_james"), true)
	_expect("no Philip and James on 1 May", cal.feasts_on(2024, 5, 1).any(func(f): return f["id"] == "philip_james"), false)
	_expect("All Souls is a first-class feast", cal.great_feast(2024, 11, 2).get("id", ""), "all_souls")
	_expect("the Chair of St Peter is 22 February", cal.feasts_on(2024, 2, 22).any(func(f): return f["id"] == "chair_peter"), true)
	_expect("Trinity Sunday 2024 is second class", cal.feasts_on(2024, 5, 26).any(func(f): return f["id"] == "trinity" and f["rank"] == "high"), true)
	print("Calendar checks: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)
	return true


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
