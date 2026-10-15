class_name MusicMenu
extends Control
## The music menu: the track now playing, play and pause, next and previous, shuffle and follow the season,
## the music and sound effects switches, and the list of all the tracks. Tap a track to play it.

var _now: Label
var _list: VBoxContainer
var _rows: Array = []
var _pause: Button
var _shuffle: Button
var _follow: Button
var _music: Button
var _sfx: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := PanelContainer.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.GOLD, 2, 0, 0))
	add_child(back)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.text = tr("music.title")
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Style.GOLD)
	root.add_child(title)

	_now = Label.new()
	_now.add_theme_font_size_override("font_size", 20)
	_now.add_theme_color_override("font_color", Style.PARCHMENT)
	_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_now)

	var transport := HBoxContainer.new()
	transport.add_theme_constant_override("separation", 8)
	root.add_child(transport)
	transport.add_child(_action(tr("music.prev"), Music.previous))
	_pause = _action("", Music.toggle_pause)
	transport.add_child(_pause)
	transport.add_child(_action(tr("music.next"), Music.next))

	var switches := GridContainer.new()
	switches.columns = 2
	switches.add_theme_constant_override("h_separation", 8)
	switches.add_theme_constant_override("v_separation", 8)
	root.add_child(switches)
	_shuffle = _switch(tr("music.shuffle"), Music.shuffle, Music.set_shuffle)
	switches.add_child(_shuffle)
	_follow = _switch(tr("music.follow"), Music.follow, Music.set_follow)
	switches.add_child(_follow)
	_music = _switch(tr("music.music_on"), Settings.music_on, Settings.set_music_on)
	switches.add_child(_music)
	_sfx = _switch(tr("music.sfx_on"), Settings.sfx_on, Settings.set_sfx_on)
	switches.add_child(_sfx)

	var heading := Label.new()
	heading.text = tr("music.list")
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Style.DIM)
	root.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	for i in Music.tracks.size():
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0, 46)
		row.add_theme_font_size_override("font_size", 19)
		row.pressed.connect(Music.choose.bind(i))
		_list.add_child(row)
		_rows.append(row)

	var close := _action(tr("music.close"), queue_free)
	root.add_child(close)
	Music.changed.connect(_refresh)
	Settings.changed.connect(_refresh)
	_refresh()


func _ready() -> void:
	_refresh()


func _action(label: String, call: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(call)
	return b


func _switch(label: String, on: bool, call: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = on
	b.text = label
	b.custom_minimum_size = Vector2(0, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 19)
	b.toggled.connect(call)
	return b


func _refresh() -> void:
	var i := Music.current_index()
	if i < 0:
		_now.text = tr("music.none")
	else:
		_now.text = tr("music.now") % Music.name_of(i) + ("  " + tr("music.paused") if Music.paused else "")
	_pause.text = tr("music.play") if Music.paused else tr("music.pause")
	_shuffle.set_pressed_no_signal(Music.shuffle)
	_follow.set_pressed_no_signal(Music.follow)
	_music.set_pressed_no_signal(Settings.music_on)
	_sfx.set_pressed_no_signal(Settings.sfx_on)
	for r in _rows.size():
		var row: Button = _rows[r]
		var mark := "> " if r == i else "   "
		row.text = mark + Music.name_of(r)
