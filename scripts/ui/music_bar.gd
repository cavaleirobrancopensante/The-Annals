class_name MusicBar
extends Button
## The bar at the top of the house: the track now playing. Tap it to open the music menu.


func _init() -> void:
	flat = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_text = true
	custom_minimum_size = Vector2(0, 46)
	add_theme_font_size_override("font_size", 20)
	add_theme_color_override("font_color", Style.GOLD)
	pressed.connect(_open)
	Music.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var i := Music.current_index()
	if not Settings.music_on:
		text = tr("music.off")
	elif i < 0:
		text = tr("music.none")
	else:
		text = tr("music.bar") % Music.name_of(i)
		if Music.paused:
			text += " " + tr("music.paused")


func _open() -> void:
	get_tree().current_scene.add_child(MusicMenu.new())
