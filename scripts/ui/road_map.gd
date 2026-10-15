class_name RoadMap
extends Control
## The road as a map: the island's land and water, the roads the house knows, and the places it knows.
## Everything else lies in the fog. Tap a known dot to choose it as the destination.

signal node_picked(node_id: String)

const FACTION_COLORS := {
	"tollmaster": Color("b0503c"),
	"glen_lords": Color("c9a14a"),
	"church": Color("9cc3d6"),
	"fishers": Color("6f9a7a"),
	"bog": Color("8a7a5a"),
}
const PAD := 26.0
const HIT_RADIUS := 36.0
const INK := Color("e9dcbf")
const GOLD := Color("c9a14a")
const INK_DARK := Color("231c15")
const MAP_PATH := "res://assets/art/map/geography.svg"
## Fog: ground within CLEAR_PX of a known place is clear, and it fades to full fog over FADE_PX.
const CLEAR_PX := 58.0
const FADE_PX := 80.0
const FOG_CELL := 14.0

var selected := ""
var _chart: Texture2D
## The drawn rectangle of the map, inside the control, in pixels.
var _origin := Vector2.ZERO
var _map_size := Vector2.ZERO


func _init() -> void:
	custom_minimum_size = Vector2(0, 620)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func() -> void:
		_fit()
		queue_redraw())


## Fits the map's true shape into the control, centred, with a margin.
func _fit() -> void:
	var avail := size - Vector2(2 * PAD, 2 * PAD)
	var b := Road.bounds
	var h := avail.y
	var w := h * b.x / b.y
	if w > avail.x:
		w = avail.x
		h = w * b.y / b.x
	_map_size = Vector2(w, h)
	_origin = (size - _map_size) / 2.0


func _to_px(v: Vector2) -> Vector2:
	return _origin + Vector2(v.x * _map_size.x, v.y * _map_size.y)


func _node_px(n: Dictionary) -> Vector2:
	return _to_px(Vector2(float(n["x"]), float(n["y"])))


## Where a place or the house is on the screen, or null if it is not on the map.
func _place_px(id: String) -> Variant:
	if id == "house":
		return _to_px(Road.house_pos)
	var n := Road.node(id)
	if n.is_empty():
		return null
	return _node_px(n)


func _draw() -> void:
	_fit()
	if _chart == null and ResourceLoader.exists(MAP_PATH):
		_chart = load(MAP_PATH)
	draw_rect(Rect2(Vector2.ZERO, size), INK_DARK)
	if _chart:
		draw_texture_rect(_chart, Rect2(_origin, _map_size), false)
	else:
		draw_rect(Rect2(_origin, _map_size), Color("3d3a2a"))

	var known_px := []
	for id in Road.known:
		var p = _place_px(str(id))
		if p != null:
			known_px.append(p)
	_draw_fog(known_px)
	_draw_roads()

	var font := ThemeDB.fallback_font
	if selected != "" and Road.is_known(selected):
		var sp = _place_px(selected)
		if sp != null:
			draw_line(_to_px(Road.house_pos), sp, Color(GOLD, 0.35), 2.0)

	for n in Road.nodes:
		if not Road.is_known(str(n["id"])):
			continue
		var p := _node_px(n)
		var col: Color = FACTION_COLORS.get(n["faction"], Color.GRAY)
		if Road.is_hostile(n["id"]):
			col = col.darkened(0.55)
		draw_circle(p, 9.0, col)
		if WorldState.has_priory(str(n["id"])):
			draw_arc(p, 15.0, 0.0, TAU, 32, GOLD, 3.0)
		if n["id"] == selected:
			draw_arc(p, 17.0, 0.0, TAU, 32, INK, 2.0)
		_draw_label(font, p, str(n["name"]), "right")

	var house := _to_px(Road.house_pos)
	draw_rect(Rect2(house - Vector2(8, 8), Vector2(16, 16)), INK)
	_draw_label(font, house, tr("ui.the_house"), "right")


## Dark cover over the ground the house has not explored. Clear close to known places, fading with distance.
func _draw_fog(known_px: Array) -> void:
	if known_px.is_empty():
		draw_rect(Rect2(_origin, _map_size), Color(INK_DARK, 0.92))
		return
	var cols := int(ceil(_map_size.x / FOG_CELL))
	var rows := int(ceil(_map_size.y / FOG_CELL))
	for cy in rows:
		for cx in cols:
			var c := _origin + Vector2((cx + 0.5) * FOG_CELL, (cy + 0.5) * FOG_CELL)
			var d := INF
			for k in known_px:
				d = minf(d, c.distance_to(k))
			var a := clampf((d - CLEAR_PX) / FADE_PX, 0.0, 1.0) * 0.9
			if a > 0.0:
				draw_rect(Rect2(_origin + Vector2(cx, cy) * FOG_CELL, Vector2(FOG_CELL, FOG_CELL)), Color(INK_DARK, a))


## Roads from a known place. A road into the unknown is drawn faint, so the house sees where it leads.
func _draw_roads() -> void:
	for r in Road.roads:
		var a := str(r[0])
		var b := str(r[1])
		var ka := Road.is_known(a) or a == "house"
		var kb := Road.is_known(b) or b == "house"
		if not (ka or kb):
			continue
		var pa = _place_px(a)
		var pb = _place_px(b)
		if pa == null or pb == null:
			continue
		var alpha := 0.5 if (ka and kb) else 0.2
		draw_line(pa, pb, Color(GOLD, alpha), 2.0)


## Draws a place name beside its dot, with a dark halo so it reads over lines.
func _draw_label(font: Font, p: Vector2, text: String, _side: String) -> void:
	var at := p + Vector2(14, 6)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, INK_DARK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_fit()
		var best := ""
		var best_d := HIT_RADIUS
		for n in Road.nodes:
			if not Road.is_known(str(n["id"])):
				continue
			var d := _node_px(n).distance_to(event.position)
			if d < best_d:
				best_d = d
				best = str(n["id"])
		if best != "":
			selected = best
			queue_redraw()
			node_picked.emit(best)
