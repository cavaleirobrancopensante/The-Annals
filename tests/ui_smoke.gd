extends Node
## Loads the real main scene, presses its buttons for a few in-game years,
## takes a screenshot, and quits. Catches UI script errors.
##
## godot --path . res://tests/ui_smoke.tscn   (needs a display; use xvfb-run on a server)

var main: Control


func _ready() -> void:
	SaveSystem.enabled = false
	Oracle.start(42)
	Game.new_game()
	SaveSystem.slot = 1
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	for i in 160:
		if Game.waiting():
			var buttons: Array = main.choices_box.get_children().filter(func(b): return b is Button and not b.disabled)
			if not buttons.is_empty():
				buttons[0].pressed.emit()
		else:
			main._on_next_week()
		if i % 20 == 0:
			await get_tree().process_frame
	for i in 10:
		main._on_next_day()
	main._on_until()
	for b in ["granary", "woodshed", "scriptorium"]:
		Game.build(b)
	main._refresh()
	main.tabs.current_tab = 1
	await get_tree().process_frame
	# Road tab: settle any waiting choice, then choose a place, tick two brothers at home, send them.
	var settle := 0
	while Game.waiting() and settle < 10:
		var waiting: Array = main.choices_box.get_children().filter(func(b): return b is Button and not b.disabled)
		if waiting.is_empty():
			break
		waiting[0].pressed.emit()
		settle += 1
	if not Game.waiting():
		main.road_map.selected = "inishkeel"
		main._refresh_road()
		var ticked := 0
		for cb in main.party_checks:
			if ticked < 2:
				cb.button_pressed = true
				ticked += 1
		main._on_send_party()
		print("Road tab: %d parties out, note '%s'" % [Road.parties.size(), main.send_note.text])
	# A skirmish: the riders at the gate, shown in the event panel.
	if not Game.waiting():
		Skirmish.start("riders_at_gate")
		print("Skirmish started: %s" % Skirmish.is_active())
	main.tabs.current_tab = 1 if "estate" in OS.get_cmdline_user_args() else 2
	await get_tree().process_frame
	await get_tree().process_frame
	var out := "(none in headless mode)"
	if DisplayServer.get_name() != "headless":
		for i in 10:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		out = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://ui_smoke.png"
		img.save_png(out)
	print("UI smoke test ok: year %d, %d entries, screenshot %s" % [WorldState.year(), Chronicle.entries.size(), out])
	get_tree().quit()
