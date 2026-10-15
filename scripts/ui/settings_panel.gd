class_name SettingsPanel
extends VBoxContainer
## The settings list: language flags, text size, two toggles. Used by the main menu and the house's menu sheet.

signal back_pressed
signal replay_pressed

## Shows the walk-through replay button; only inside a house.
var show_replay := false

var _flag_buttons := {}
var _size_buttons := {}
var _hint_button: Button
var _confirm_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(Style.section_title(tr("settings.title")))

	add_child(_caption(tr("settings.language")))
	var flags := HBoxContainer.new()
	flags.add_theme_constant_override("separation", 12)
	for code in Strings.LANGUAGES:
		var b := Button.new()
		b.icon = Flags.texture(code)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(120, 80)
		b.toggle_mode = true
		b.button_pressed = code == Settings.language
		b.tooltip_text = Strings.LANGUAGE_NAMES[code]
		b.pressed.connect(_on_language.bind(code))
		_flag_buttons[code] = b
		flags.add_child(b)
	add_child(flags)

	add_child(_caption(tr("settings.text_size")))
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 10)
	var font_sizes := {"small": 18, "normal": 22, "large": 26}
	for s in Settings.SIZES:
		var b := Button.new()
		b.text = "A"
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(96, 64)
		b.add_theme_font_size_override("font_size", font_sizes[s])
		b.button_pressed = s == Settings.text_size
		b.pressed.connect(_on_size.bind(s))
		_size_buttons[s] = b
		sizes.add_child(b)
	add_child(sizes)

	_hint_button = _toggle(tr("settings.hints"), Settings.hints, _on_hints)
	_confirm_button = _toggle(tr("settings.confirm_close"), Settings.confirm_close, _on_confirm)

	if show_replay:
		var rep := Style.button(tr("tut.replay"), 64)
		rep.pressed.connect(func(): replay_pressed.emit())
		add_child(rep)
	var back := Style.button(tr("menu.back"), 64)
	back.pressed.connect(func(): back_pressed.emit())
	add_child(back)


func _caption(text: String) -> Label:
	var l := Style.label(20, Style.DIM)
	l.text = text
	return l


func _toggle(text: String, on: bool, handler: Callable) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_label := Style.label(20, Style.PARCHMENT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = text
	row.add_child(name_label)
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(140, 56)
	b.button_pressed = on
	b.text = tr("settings.on") if on else tr("settings.off")
	b.toggled.connect(handler.bind(b))
	row.add_child(b)
	add_child(row)
	return b


func _on_language(code: String) -> void:
	Settings.set_language(code)


func _on_size(s: String) -> void:
	Settings.set_text_size(s)
	for k in _size_buttons:
		_size_buttons[k].button_pressed = k == Settings.text_size


func _on_hints(on: bool, b: Button) -> void:
	Settings.set_hints(on)
	b.text = tr("settings.on") if on else tr("settings.off")


func _on_confirm(on: bool, b: Button) -> void:
	Settings.set_confirm_close(on)
	b.text = tr("settings.on") if on else tr("settings.off")
