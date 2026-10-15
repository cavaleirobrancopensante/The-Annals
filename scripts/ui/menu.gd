extends Control
## The main menu: continue the last house, found a new one or open a saved one, settings, and quit.
## Choosing a slot prepares the house, then opens the house scene.

var _root: Control
var _screens := {}
var _screen := "start"
var _built_key := ""
var _slots_title: Label
var _slot_grid: GridContainer
var _quit_dialog: ConfirmationDialog
var _confirm_dialog: ConfirmationDialog
var _notice: AcceptDialog
var _mode := "load"
var _pending := 0
var _pending_action := ""


func _ready() -> void:
	_quit_dialog = ConfirmationDialog.new()
	_quit_dialog.title = "The Annals"
	_quit_dialog.dialog_text = tr("menu.quit_text")
	_quit_dialog.confirmed.connect(func(): get_tree().quit())
	add_child(_quit_dialog)
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "The Annals"
	_confirm_dialog.confirmed.connect(_on_confirmed)
	add_child(_confirm_dialog)
	_notice = AcceptDialog.new()
	_notice.title = "The Annals"
	add_child(_notice)

	SaveSystem.migrate_legacy()
	Settings.changed.connect(_on_settings_changed, CONNECT_DEFERRED)
	_build()
	show_screen("start")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _screen == "start":
			_quit_dialog.popup_centered()
		else:
			show_screen("start")


# --- Building -----------------------------------------------------------

## Rebuilt when the language or text size changes, so every label takes the new text.
func _build() -> void:
	if _root:
		remove_child(_root)
		_root.queue_free()
	theme = Style.theme()
	_built_key = "%s|%s" % [Settings.language, Settings.text_size]
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.add_child(Style.background("menu"))
	_screens = {}
	_build_start()
	_build_slots()
	_build_settings()


func _add_screen(name: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 44)
	_root.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	_screens[name] = margin
	return box


func _spacer(height: float, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func _build_start() -> void:
	var box := _add_screen("start")
	box.add_child(_flags_row())
	box.add_child(_spacer(60))
	var banner := TextureRect.new()
	banner.texture = load("res://assets/art/banners/title.svg")
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	banner.custom_minimum_size = Vector2(0, 110)
	var title := Style.label(40, Style.GOLD)
	title.text = tr("menu.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.add_child(title)
	box.add_child(banner)
	var sub := Style.label(20, Style.DIM)
	sub.text = tr("menu.subtitle")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(_spacer(0, true))
	if Settings.last_slot > 0 and SaveSystem.has_slot(Settings.last_slot):
		var cont := Style.button(tr("menu.continue"), 72)
		cont.pressed.connect(_open_house.bind(Settings.last_slot))
		box.add_child(cont)
	var new_btn := Style.button(tr("menu.new_house"), 72)
	new_btn.pressed.connect(_show_slots.bind("new"))
	box.add_child(new_btn)
	var load_btn := Style.button(tr("menu.load_house"), 72)
	load_btn.pressed.connect(_show_slots.bind("load"))
	box.add_child(load_btn)
	var set_btn := Style.button(tr("menu.settings"), 72)
	set_btn.pressed.connect(show_screen.bind("settings"))
	box.add_child(set_btn)
	var quit_btn := Style.button(tr("menu.quit"), 72)
	quit_btn.pressed.connect(_quit_dialog.popup_centered)
	box.add_child(quit_btn)
	box.add_child(_spacer(0, true))
	var ver := Style.label(16, Style.DIM)
	ver.text = tr("menu.version")
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ver)


## The three flags across the top of the start screen. The chosen language is pressed.
func _flags_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for code in Strings.LANGUAGES:
		var b := Button.new()
		b.icon = Flags.texture(code)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(120, 80)
		b.toggle_mode = true
		b.button_pressed = code == Settings.language
		b.tooltip_text = Strings.LANGUAGE_NAMES[code]
		b.pressed.connect(Settings.set_language.bind(code))
		row.add_child(b)
	return row


func _build_slots() -> void:
	var box := _add_screen("slots")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var back := Style.button(tr("menu.back"), 56)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size.x = 120
	back.pressed.connect(show_screen.bind("start"))
	top.add_child(back)
	_slots_title = Style.label(24, Style.GOLD)
	_slots_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_slots_title)
	box.add_child(top)
	_slot_grid = GridContainer.new()
	_slot_grid.columns = 2
	_slot_grid.add_theme_constant_override("h_separation", 12)
	_slot_grid.add_theme_constant_override("v_separation", 12)
	box.add_child(_slot_grid)


func _build_settings() -> void:
	var box := _add_screen("settings")
	var panel := SettingsPanel.new()
	panel.back_pressed.connect(show_screen.bind("start"))
	box.add_child(panel)


func show_screen(name: String) -> void:
	_screen = name
	for k in _screens:
		_screens[k].visible = k == name


# --- Slots --------------------------------------------------------------

func _show_slots(mode: String) -> void:
	_mode = mode
	_slots_title.text = tr("slots.new_title") if mode == "new" else tr("slots.load_title")
	for c in _slot_grid.get_children():
		_slot_grid.remove_child(c)
		c.queue_free()
	for n in range(1, SaveSystem.SLOT_COUNT + 1):
		_slot_grid.add_child(_slot_card(n))
	show_screen("slots")


func _slot_card(n: int) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	var filled := SaveSystem.has_slot(n)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 132)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.text = _slot_text(n, filled)
	btn.add_theme_font_size_override("font_size", Style.sized(19))
	btn.disabled = _mode == "load" and not filled
	btn.pressed.connect(_on_slot.bind(n))
	col.add_child(btn)
	if _mode == "load" and filled:
		var del := Button.new()
		del.text = tr("slots.delete")
		del.custom_minimum_size = Vector2(0, 48)
		del.add_theme_font_size_override("font_size", Style.sized(18))
		del.pressed.connect(_ask_delete.bind(n))
		col.add_child(del)
	return col


func _slot_text(n: int, filled: bool) -> String:
	var head := tr("slots.slot") % n
	if not filled:
		return "%s\n%s" % [head, tr("slots.empty")]
	var s := SaveSystem.summary(n)
	if bool(s.get("fallen", false)):
		return "%s\n%s\n%s" % [head, s.get("house", ""), tr("slots.fallen") % Chronicle.ordinal(int(s.get("year", 0)))]
	return "%s\n%s\n%s\n%s" % [head, s.get("house", ""), s.get("date", ""),
		tr("slots.brothers") % int(s.get("brothers", 0))]


func _on_slot(n: int) -> void:
	if _mode == "new":
		if SaveSystem.has_slot(n):
			_pending = n
			_pending_action = "new"
			_confirm_dialog.dialog_text = tr("slots.confirm_new") % n
			_confirm_dialog.popup_centered()
		else:
			_start_house(n)
	else:
		_open_house(n)


func _ask_delete(n: int) -> void:
	_pending = n
	_pending_action = "delete"
	_confirm_dialog.dialog_text = tr("slots.confirm_delete") % n
	_confirm_dialog.popup_centered()


func _on_confirmed() -> void:
	if _pending_action == "new":
		_start_house(_pending)
	elif _pending_action == "delete":
		SaveSystem.delete_slot(_pending)
		_show_slots(_mode)


func _start_house(n: int) -> void:
	SaveSystem.new_slot(n)
	Game.new_game()
	SaveSystem.save_game()
	get_tree().change_scene_to_file(Style.HOUSE_SCENE)


func _open_house(n: int) -> void:
	if SaveSystem.open_slot(n):
		get_tree().change_scene_to_file(Style.HOUSE_SCENE)
	else:
		_notice.dialog_text = tr("slots.unreadable")
		_notice.popup_centered()


func _on_settings_changed() -> void:
	if "%s|%s" % [Settings.language, Settings.text_size] != _built_key:
		var keep := _screen
		_build()
		show_screen(keep)
