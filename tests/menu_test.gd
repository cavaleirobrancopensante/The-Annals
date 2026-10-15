extends SceneTree
## Opens the main menu, presses each flag, and checks the text changes language. Restores English after.
## godot --headless --path . --script res://tests/menu_test.gd

var failures := 0
var frames := 0
var menu: Control


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		root.get_node("Oracle").start(3)
		menu = load("res://scenes/menu.tscn").instantiate()
		root.add_child(menu)
		return false
	if frames == 3:
		_expect("starts in English", TranslationServer.translate("menu.new_house"), "New house")
		_expect("three flags on the start screen", _flag_count(), 3)
		_press_flag("pt_BR")
		return false
	if frames == 5:
		_expect("Portuguese after the Brazil flag", TranslationServer.translate("menu.new_house"), "Nova casa")
		_expect("the menu is rebuilt in Portuguese", _has_text("Nova casa"), true)
		_press_flag("es")
		return false
	if frames == 7:
		_expect("Spanish after the Spain flag", _has_text("Casa nueva"), true)
		_press_flag("en")
		return false
	if frames == 9:
		_expect("back to English", _has_text("New house"), true)
		print("Menu checks: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
		quit(failures)
	return false


func _flag_count() -> int:
	var n := 0
	for b in _buttons(menu._screens["start"]):
		if b.icon != null and b.toggle_mode:
			n += 1
	return n


func _press_flag(code: String) -> void:
	for b in _buttons(menu):
		if b.icon != null and b.tooltip_text == Strings.LANGUAGE_NAMES[code]:
			b.pressed.emit()


func _has_text(text: String) -> bool:
	for b in _buttons(menu):
		if b.text == text:
			return true
	return false


func _buttons(node: Node) -> Array:
	var out := []
	for c in node.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_buttons(c))
	return out


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
