class_name Style
extends RefCounted
## Colours, scene paths and widget helpers shared by the menu, the house and the settings list.

const BG := Color("1b1611")
const PANEL := Color("2a2119")
const PARCHMENT := Color("e9dcbf")
const DIM := Color("a8977a")
const GOLD := Color("c9a14a")
const RED := Color("b0503c")

const MENU_SCENE := "res://scenes/menu.tscn"
const HOUSE_SCENE := "res://scenes/main.tscn"


## A font size scaled by the player's text size setting.
static func sized(n: int) -> int:
	return roundi(n * Settings.font_scale())


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = sized(22)
	t.set_color("font_color", "Label", PARCHMENT)
	t.set_color("default_color", "RichTextLabel", PARCHMENT)
	t.set_color("font_color", "Button", PARCHMENT)
	t.set_color("font_disabled_color", "Button", DIM.darkened(0.3))
	t.set_stylebox("normal", "Button", box(PANEL.lightened(0.06), DIM.darkened(0.4), 1, 8))
	t.set_stylebox("hover", "Button", box(PANEL.lightened(0.12), GOLD, 1, 8))
	t.set_stylebox("pressed", "Button", box(PANEL.lightened(0.18), GOLD, 2, 8))
	t.set_stylebox("disabled", "Button", box(PANEL, PANEL.lightened(0.1), 1, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	return t


## The screen's tapestry from the art set when it exists, otherwise a flat colour.
static func background(screen: String = "") -> Control:
	var path := "res://assets/art/backgrounds/%s.svg" % screen
	if screen != "" and ResourceLoader.exists(path):
		var art := TextureRect.new()
		art.texture = load(path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		return art
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	return bg


static var _scene_map := {}


## The scene drawn above an event card, from data/events/scenes.json. Null when the card has none.
static func scene_for(card_id: String) -> Texture2D:
	if _scene_map.is_empty():
		var f := FileAccess.open("res://data/scenes/events.json", FileAccess.READ)
		if f:
			_scene_map = JSON.parse_string(f.get_as_text())
	var scene := str(_scene_map.get(card_id, ""))
	if scene == "":
		return null
	# In winter the scene is drawn under snow, when the snowy version exists.
	if WorldState.season() == "winter":
		var snowy := "res://assets/art/scenes/%s_winter.svg" % scene
		if ResourceLoader.exists(snowy):
			return load(snowy)
	var path := "res://assets/art/scenes/%s.svg" % scene
	if not ResourceLoader.exists(path):
		return null
	return load(path)


static func box(fill: Color, border: Color, width: int, radius: int, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


static func label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", sized(size))
	l.add_theme_color_override("font_color", color)
	return l


static func section_title(text: String) -> Label:
	var l := label(24, GOLD)
	l.text = text
	return l


static func button(text: String, height: int = 64) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b
