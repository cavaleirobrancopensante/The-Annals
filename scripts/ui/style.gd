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


static func background() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	return bg


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
