class_name RoadMap
extends Control
## The road as a sketch: places as dots coloured by who holds them, the house as a square.
## Tap a dot to choose it as the destination.

signal node_picked(node_id: String)

const FACTION_COLORS := {
	"tollmaster": Color("b0503c"),
	"glen_lords": Color("c9a14a"),
	"church": Color("9cc3d6"),
	"fishers": Color("6f9a7a"),
	"bog": Color("8a7a5a"),
}
const PAD := 26.0
const HIT_RADIUS := 40.0
const INK := Color("e9dcbf")

var selected := ""


func _init() -> void:
	custom_minimum_size = Vector2(0, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _to_px(v: Vector2) -> Vector2:
	return Vector2(PAD + v.x * (size.x - 2 * PAD), PAD + v.y * (size.y - 2 * PAD))


func _node_px(n: Dictionary) -> Vector2:
	return _to_px(Vector2(float(n["x"]), float(n["y"])))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("231c15"))
	var font := ThemeDB.fallback_font
	var house := _to_px(Road.house_pos)

	if selected != "" and not Road.node(selected).is_empty():
		draw_line(house, _node_px(Road.node(selected)), Color(Color("c9a14a"), 0.35), 2.0)

	for n in Road.nodes:
		var p := _node_px(n)
		var col: Color = FACTION_COLORS.get(n["faction"], Color.GRAY)
		if Road.is_hostile(n["id"]):
			col = col.darkened(0.55)
		draw_circle(p, 9.0, col)
		if n["id"] == selected:
			draw_arc(p, 17.0, 0.0, TAU, 32, INK, 2.0)
		draw_string(font, p + Vector2(14, 6), str(n["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)

	draw_rect(Rect2(house - Vector2(8, 8), Vector2(16, 16)), INK)
	draw_string(font, house + Vector2(14, 6), "the house", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var best := ""
		var best_d := HIT_RADIUS
		for n in Road.nodes:
			var d := _node_px(n).distance_to(event.position)
			if d < best_d:
				best_d = d
				best = str(n["id"])
		if best != "":
			selected = best
			queue_redraw()
			node_picked.emit(best)
