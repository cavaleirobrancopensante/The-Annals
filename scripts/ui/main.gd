extends Control
## Phase 2 text interface, built for a portrait phone screen.
## Header with the winter forecast, chronicle and estate tabs, the current event, and turn buttons.

const BG := Color("1b1611")
const PANEL := Color("2a2119")
const PARCHMENT := Color("e9dcbf")
const DIM := Color("a8977a")
const GOLD := Color("c9a14a")
const RED := Color("b0503c")

var title_label: Label
var status_label: Label
var resources_label: Label
var forecast_label: Label
var tabs: TabContainer
var chronicle_text: RichTextLabel
var estate_box: VBoxContainer
var estate_scroll: ScrollContainer
var road_box: VBoxContainer
var road_map: RoadMap
var road_info: Label
var party_box: VBoxContainer
var party_checks: Array = []
var send_note: Label
var road_parties_box: VBoxContainer
var standings_label: Label
var _road_signature := ""
var event_panel: PanelContainer
var event_title: Label
var event_text: RichTextLabel
var choices_box: VBoxContainer
var controls_box: HBoxContainer
var fallen_box: VBoxContainer
var notice_dialog: AcceptDialog
var confirm_dialog: ConfirmationDialog

var _last_year_rendered := 0
var _estate_signature := ""


func _ready() -> void:
	_build_ui()
	EventBus.chronicle_added.connect(_on_chronicle_added)
	EventBus.event_presented.connect(_show_event)
	EventBus.world_changed.connect(_refresh)
	EventBus.house_fell.connect(_refresh)
	if not SaveSystem.load_game():
		Game.new_game()
	_render_chronicle()
	_refresh()
	if Game.waiting():
		_show_event(Game.current_view())


# --- Building the interface ---------------------------------------------

func _build_ui() -> void:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", PARCHMENT)
	t.set_color("default_color", "RichTextLabel", PARCHMENT)
	t.set_color("font_color", "Button", PARCHMENT)
	t.set_color("font_disabled_color", "Button", DIM.darkened(0.3))
	t.set_stylebox("normal", "Button", _box(PANEL.lightened(0.06), DIM.darkened(0.4), 1, 8))
	t.set_stylebox("hover", "Button", _box(PANEL.lightened(0.12), GOLD, 1, 8))
	t.set_stylebox("pressed", "Button", _box(PANEL.lightened(0.18), GOLD, 2, 8))
	t.set_stylebox("disabled", "Button", _box(PANEL, PANEL.lightened(0.1), 1, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme = t

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 44)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	title_label = _label(30, GOLD)
	root.add_child(title_label)
	status_label = _label(20, DIM)
	root.add_child(status_label)
	resources_label = _label(20, PARCHMENT)
	root.add_child(resources_label)
	forecast_label = _label(19, DIM)
	root.add_child(forecast_label)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	chronicle_text = _rich("Chronicle")
	chronicle_text.scroll_following = true
	tabs.add_child(chronicle_text)

	estate_scroll = ScrollContainer.new()
	estate_scroll.name = "Estate"
	estate_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(estate_scroll)
	estate_box = VBoxContainer.new()
	estate_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	estate_box.add_theme_constant_override("separation", 10)
	estate_scroll.add_child(estate_box)
	_build_road_tab()

	event_panel = PanelContainer.new()
	event_panel.add_theme_stylebox_override("panel", _box(PANEL, GOLD, 2, 10, 16))
	event_panel.visible = false
	root.add_child(event_panel)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 10)
	event_panel.add_child(ev)
	event_title = _label(24, GOLD)
	ev.add_child(event_title)
	event_text = RichTextLabel.new()
	event_text.bbcode_enabled = true
	event_text.fit_content = true
	event_text.scroll_active = false
	ev.add_child(event_text)
	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 8)
	ev.add_child(choices_box)

	controls_box = HBoxContainer.new()
	controls_box.add_theme_constant_override("separation", 8)
	root.add_child(controls_box)
	var day_btn := _button("Next day")
	day_btn.pressed.connect(_on_next_day)
	controls_box.add_child(day_btn)
	var next_btn := _button("Next week")
	next_btn.pressed.connect(_on_next_week)
	controls_box.add_child(next_btn)
	var until_btn := _button("Until something happens")
	until_btn.pressed.connect(_on_until)
	controls_box.add_child(until_btn)
	var menu := MenuButton.new()
	menu.text = "Menu"
	menu.custom_minimum_size = Vector2(110, 64)
	menu.flat = false
	var popup := menu.get_popup()
	popup.add_theme_font_size_override("font_size", 24)
	popup.add_item("Copy chronicle", 0)
	popup.add_item("Save chronicle as text file", 1)
	popup.add_separator()
	popup.add_item("Found a new house", 2)
	popup.id_pressed.connect(_on_menu)
	controls_box.add_child(menu)

	fallen_box = VBoxContainer.new()
	fallen_box.visible = false
	root.add_child(fallen_box)
	var fallen_label := _label(22, RED)
	fallen_label.text = "The house has fallen. Its annals are complete."
	fallen_box.add_child(fallen_label)
	var new_btn := _button("Found a new house")
	new_btn.pressed.connect(_start_new_house)
	fallen_box.add_child(new_btn)

	notice_dialog = AcceptDialog.new()
	notice_dialog.title = "The Annals"
	add_child(notice_dialog)
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Found a new house?"
	confirm_dialog.dialog_text = "This house and its chronicle will be closed for good. Begin again?"
	confirm_dialog.confirmed.connect(_start_new_house)
	add_child(confirm_dialog)


func _box(fill: Color, border: Color, width: int, radius: int, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _rich(tab_name: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.name = tab_name
	r.bbcode_enabled = true
	r.selection_enabled = true
	r.add_theme_stylebox_override("normal", _box(PANEL, PANEL, 0, 6, 14))
	return r


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


# --- Refreshing ---------------------------------------------------------

func _refresh() -> void:
	title_label.text = WorldState.full_house_name()
	var ab := WorldState.abbot()
	var feasts := Calendar.feasts_on(WorldState.cal_year, WorldState.cal_month, WorldState.cal_day)
	var today := "  ·  Today is %s" % str(feasts[0]["name"]) if not feasts.is_empty() else ""
	status_label.text = "%s%s\nYear %d  ·  %s, week %d  ·  Abbot %s  ·  Generation %d" % [
		WorldState.date_text(), today, WorldState.year(), WorldState.season().capitalize(),
		WorldState.week_in_season(), ab.get("name", "none"), WorldState.generation]
	resources_label.text = "Food %d/%d   Firewood %d/%d   Medicine %d/%d   Books %d   Goodwill %d   ·   %d brothers" % [
		WorldState.res("food"), WorldState.cap("food"), WorldState.res("firewood"), WorldState.cap("firewood"),
		WorldState.res("medicine"), WorldState.cap("medicine"), WorldState.res("books"), WorldState.res("goodwill"),
		WorldState.living_monks().size()]
	forecast_label.text = _forecast_text()
	forecast_label.add_theme_color_override("font_color", RED if _winter_short() else DIM)
	_render_estate_if_changed()
	_refresh_road()
	var waiting := Game.waiting()
	event_panel.visible = waiting
	controls_box.visible = not waiting and not WorldState.fallen
	fallen_box.visible = WorldState.fallen


func _winter_short() -> bool:
	return WorldState.res("food") < WorldState.winter_food_need() or WorldState.res("firewood") < WorldState.winter_wood_need()


func _forecast_text() -> String:
	var food_need := WorldState.winter_food_need()
	var wood_need := WorldState.winter_wood_need()
	var text := "Winter needs %d food and %d firewood. " % [food_need, wood_need]
	var food_short := food_need - WorldState.res("food")
	var wood_short := wood_need - WorldState.res("firewood")
	if food_short > 0 or wood_short > 0:
		var parts := []
		if food_short > 0:
			parts.append("%d more food" % food_short)
		if wood_short > 0:
			parts.append("%d more firewood" % wood_short)
		text += "Short by " + " and ".join(parts) + "."
	else:
		text += "Stores are enough."
	return text


# --- Estate: jobs and buildings -----------------------------------------

func _compute_estate_signature() -> String:
	var parts := []
	for m in WorldState.monks:
		parts.append("%d:%s:%s:%d" % [int(m["id"]), m["status"], WorldState.job_of(m), int(m.get("party", 0))])
	for b in WorldState.BUILDINGS:
		parts.append("%s:%s" % [b, WorldState.has_building(b)])
	parts.append(str(WorldState.abbot_id))
	parts.append(str(Rule.chosen))
	parts.append("%d:%d:%d" % [WorldState.saints.size(), WorldState.priories.size(), WorldState.generation])
	parts.append(str(WorldState.has_builder_at_home()))
	return "|".join(parts)


## Rebuilding the list closes any open menus, so it happens only when something it shows has changed.
func _render_estate_if_changed() -> void:
	var sig := _compute_estate_signature()
	if sig == _estate_signature:
		return
	_estate_signature = sig
	_render_estate()


func _render_estate() -> void:
	for c in estate_box.get_children():
		estate_box.remove_child(c)
		c.queue_free()

	estate_box.add_child(_section_title("Brothers and their work"))
	var living := WorldState.living_monks()
	living.sort_custom(_brother_order)
	for m in living:
		estate_box.add_child(_brother_row(m))

	var gone := WorldState.monks.filter(func(m): return not WorldState.is_living(m))
	if not gone.is_empty():
		var lines := []
		for m in gone:
			var how := "died in the %s year" % Chronicle.ordinal(int(m.get("died", 0))) if m["status"] == "dead" else "left in the %s year" % Chronicle.ordinal(int(m.get("left", 0)))
			lines.append("%s, %s" % [m["name"], how])
		var gone_label := _label(18, DIM)
		gone_label.text = "Departed: " + "; ".join(lines)
		estate_box.add_child(gone_label)

	estate_box.add_child(_rule_section())
	estate_box.add_child(_house_section())
	estate_box.add_child(_section_title("Buildings"))
	if not WorldState.has_builder_at_home():
		var note := _label(18, RED)
		note.text = "A builder must be at home to raise a building."
		estate_box.add_child(note)
	for b in WorldState.BUILDINGS:
		estate_box.add_child(_building_row(b))


# --- Road: the map, parties and standing --------------------------------

func _build_road_tab() -> void:
	var road_scroll := ScrollContainer.new()
	road_scroll.name = "Road"
	road_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(road_scroll)
	road_box = VBoxContainer.new()
	road_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	road_box.add_theme_constant_override("separation", 10)
	road_scroll.add_child(road_box)

	road_box.add_child(_section_title("The road"))
	road_map = RoadMap.new()
	road_map.node_picked.connect(func(_id: String): _refresh_road())
	road_box.add_child(road_map)
	road_info = _label(19, PARCHMENT)
	road_box.add_child(road_info)

	road_box.add_child(_section_title("Send a party"))
	var help := _label(18, DIM)
	help.text = "Tap a place on the map, then choose up to three brothers at home. A place whose people have closed their doors will not take the house's party."
	road_box.add_child(help)
	party_box = VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 6)
	road_box.add_child(party_box)
	var send_btn := _button("Send the party")
	send_btn.pressed.connect(_on_send_party)
	road_box.add_child(send_btn)
	var colony_btn := _button("Send three brothers to found a daughter house")
	colony_btn.pressed.connect(_on_send_colony)
	road_box.add_child(colony_btn)
	send_note = _label(18, RED)
	road_box.add_child(send_note)

	road_box.add_child(_section_title("On the road"))
	road_parties_box = VBoxContainer.new()
	road_parties_box.add_theme_constant_override("separation", 6)
	road_box.add_child(road_parties_box)

	road_box.add_child(_section_title("Standing"))
	standings_label = _label(19, PARCHMENT)
	road_box.add_child(standings_label)


func _refresh_road() -> void:
	_render_party_checks_if_changed()
	var sel := road_map.selected
	if sel == "":
		road_info.text = "No place chosen yet. Tap a dot on the map."
	else:
		var n := Road.node(sel)
		var f := str(n["faction"])
		var weeks := Road.weeks_one_way(sel)
		road_info.text = "%s (%s). %s\nIt takes %s each way. %s: %s." % [n["name"], n["kind"], n["desc"],
			_weeks_text(weeks), Road.faction_name(f).capitalize(), _standing_word(Road.standing(f))]
		if Road.is_hostile(sel):
			road_info.text += "\nThey will not receive the house."

	for c in road_parties_box.get_children():
		road_parties_box.remove_child(c)
		c.queue_free()
	if Road.parties.is_empty():
		var none := _label(19, DIM)
		none.text = "No one is on the road."
		road_parties_box.add_child(none)
	for p in Road.parties:
		var line := _label(19, PARCHMENT)
		var who := Road.party_names(p)
		var where := Road.node_name(p["node"])
		if p["arrived"]:
			line.text = "%s at %s, home in %s." % [who, where, _weeks_text(int(p["back"]))]
		else:
			line.text = "%s on the way to %s, %s to go." % [who, where, _weeks_text(int(p["out"]))]
		road_parties_box.add_child(line)

	var lines := []
	for f in Road.factions:
		lines.append("%s: %s" % [Road.faction_name(f).capitalize(), _standing_word(Road.standing(f))])
	standings_label.text = "\n".join(lines)


## Rebuilding the checkboxes clears them, so it happens only when the brothers at home change.
func _render_party_checks_if_changed() -> void:
	var home := WorldState.home_monks()
	var parts := []
	for m in home:
		parts.append("%d:%d" % [int(m["id"]), int(m["health"])])
	var sig := "|".join(parts)
	if sig == _road_signature:
		return
	_road_signature = sig
	for c in party_box.get_children():
		party_box.remove_child(c)
		c.queue_free()
	party_checks = []
	home.sort_custom(_brother_order)
	if home.is_empty():
		var none := _label(18, DIM)
		none.text = "No brother is at home to send."
		party_box.add_child(none)
	for m in home:
		# Toggle buttons rather than CheckBox: the theme has no check icons.
		var cb := Button.new()
		cb.toggle_mode = true
		cb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		cb.custom_minimum_size = Vector2(0, 52)
		cb.text = "%s, %s" % [WorldState.display_name(m), WorldState.vocation_name(m)]
		cb.add_theme_font_size_override("font_size", 20)
		cb.set_meta("monk_id", int(m["id"]))
		party_box.add_child(cb)
		party_checks.append(cb)


func _on_send_party() -> void:
	send_note.text = ""
	var node_id := road_map.selected
	if node_id == "":
		send_note.text = "Choose a place on the map first."
		return
	var ids := []
	for cb in party_checks:
		if cb.button_pressed:
			ids.append(int(cb.get_meta("monk_id")))
	var reason := Road.refusal(node_id, ids)
	if reason != "":
		send_note.text = reason
		return
	Game.dispatch_party(node_id, ids)
	_refresh_road()


func _on_send_colony() -> void:
	send_note.text = ""
	var node_id := road_map.selected
	if node_id == "":
		send_note.text = "Choose a place on the map first."
		return
	var ids := []
	for cb in party_checks:
		if cb.button_pressed:
			ids.append(int(cb.get_meta("monk_id")))
	var reason := Game.send_colony(node_id, ids)
	if reason != "":
		send_note.text = reason
		return
	_refresh_road()


func _weeks_text(w: int) -> String:
	return "%d week%s" % [w, "" if w == 1 else "s"]


func _standing_word(v: int) -> String:
	if v <= Road.HOSTILE:
		return "closed to us (%d)" % v
	if v < 0:
		return "wary (%d)" % v
	if v == 0:
		return "neutral"
	if v < 3:
		return "friendly (+%d)" % v
	return "allied (+%d)" % v


# --- The Rule and the house ---------------------------------------------

func _rule_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_section_title("The Rule"))
	var help := _label(18, DIM)
	help.text = "Each change costs a little goodwill and is written into the annals."
	box.add_child(help)
	for a in Rule.axes:
		var axis_id := str(a["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := _label(20, PARCHMENT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text = str(a["name"])
		row.add_child(name_label)
		var pick := OptionButton.new()
		pick.custom_minimum_size = Vector2(250, 56)
		pick.add_theme_font_size_override("font_size", 19)
		var ids := []
		for i in a["options"].size():
			var o: Dictionary = a["options"][i]
			ids.append(str(o["id"]))
			pick.add_item(str(o["name"]), i)
			if str(o["id"]) == Rule.current(axis_id):
				pick.select(i)
		pick.item_selected.connect(_on_rule_selected.bind(axis_id, ids))
		row.add_child(pick)
		box.add_child(row)
		var desc := _label(18, DIM)
		desc.text = str(Rule.current_option(axis_id).get("desc", ""))
		box.add_child(desc)
	return box


func _house_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_section_title("The house"))
	var lines := ["Generation %d of the house." % WorldState.generation]
	if WorldState.saints.is_empty():
		lines.append("No brother has yet been acclaimed a saint.")
	for sa in WorldState.saints:
		lines.append("Saint %s, acclaimed in the %s year." % [sa["name"], Chronicle.ordinal(int(sa["year"]))])
	if WorldState.priories.is_empty():
		lines.append("No daughter house stands on the road.")
	for pr in WorldState.priories:
		lines.append("A daughter house at %s since the %s year." % [Road.node_name(pr["node"]), Chronicle.ordinal(int(pr["since"]))])
	var text := _label(19, PARCHMENT)
	text.text = "\n".join(lines)
	box.add_child(text)
	return box


func _on_rule_selected(index: int, axis_id: String, ids: Array) -> void:
	Game.set_rule(axis_id, str(ids[index]))


func _section_title(text: String) -> Label:
	var l := _label(24, GOLD)
	l.text = text
	return l


func _brother_row(m: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var info := _label(20, PARCHMENT)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var marks: Array = m["traits"].duplicate()
	for t in m["tags"]:
		if not str(t).begins_with("on_"):
			marks.append(str(t).replace("_", " "))
	var extra := ""
	if m["status"] == "away":
		var party := Road.party_of(m)
		if not party.is_empty():
			extra = "  · with the party to %s" % Road.node_name(party["node"])
		else:
			var w := int(m["away_weeks"])
			extra = "  · on the road, %d week%s" % [w, "" if w == 1 else "s"]
	elif int(m["health"]) < 3:
		extra = "  · %s" % WorldState.HEALTH_WORDS[int(m["health"])]
	info.text = "%s, %d, %s%s\n%s" % [WorldState.display_name(m), int(m["age"]),
		WorldState.vocation_name(m), extra, ", ".join(marks)]
	row.add_child(info)

	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(190, 56)
	pick.add_theme_font_size_override("font_size", 19)
	pick.disabled = m["status"] != "home"
	var current := WorldState.job_of(m)
	for i in WorldState.JOB_ORDER.size():
		var job: String = WorldState.JOB_ORDER[i]
		var label: String = WorldState.JOB_NAMES[job]
		if WorldState.job_blocked(job):
			label += " (no building)"
		pick.add_item(label, i)
		if job == current:
			pick.select(i)
	pick.item_selected.connect(_on_job_selected.bind(int(m["id"])))
	row.add_child(pick)
	return row


func _building_row(b: String) -> Control:
	var data: Dictionary = WorldState.BUILDINGS[b]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var info := _label(19, PARCHMENT)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var costs := []
	for r in data["cost"]:
		costs.append("%d %s" % [int(data["cost"][r]), r])
	info.text = "%s · %s\n%s" % [data["name"], ", ".join(costs), data["desc"]]
	row.add_child(info)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 56)
	btn.add_theme_font_size_override("font_size", 20)
	if WorldState.has_building(b):
		btn.text = "Built"
		btn.disabled = true
	else:
		btn.text = "Build"
		btn.disabled = not WorldState.can_build(b)
		btn.pressed.connect(_on_build.bind(b))
	row.add_child(btn)
	return row


func _on_job_selected(index: int, monk_id: int) -> void:
	var m := WorldState.get_monk(monk_id)
	if m.is_empty():
		return
	Game.set_job(m, WorldState.JOB_ORDER[index])


func _on_build(b: String) -> void:
	if not Game.build(b):
		_notice("The %s cannot be raised yet." % WorldState.BUILDINGS[b]["name"])


## Abbot first, then by age, oldest first. Must be a strict ordering.
func _brother_order(a: Dictionary, b: Dictionary) -> bool:
	var a_abbot := int(a["id"]) == WorldState.abbot_id
	var b_abbot := int(b["id"]) == WorldState.abbot_id
	if a_abbot != b_abbot:
		return a_abbot
	if int(a["age"]) != int(b["age"]):
		return int(a["age"]) > int(b["age"])
	return int(a["id"]) < int(b["id"])


# --- Chronicle ----------------------------------------------------------

func _render_chronicle() -> void:
	chronicle_text.clear()
	_last_year_rendered = 0
	for e in Chronicle.entries:
		_append_entry(e)


func _append_entry(e: Dictionary) -> void:
	if int(e["year"]) != _last_year_rendered:
		_last_year_rendered = int(e["year"])
		chronicle_text.append_text("[center][color=#%s]~ The %s Year of the House ~[/color][/center]\n\n" % [
			GOLD.to_html(false), Chronicle.ordinal(_last_year_rendered).capitalize()])
	var text: String = e["text"]
	if e.get("kind", "") in ["death", "fall"]:
		text = "[i]%s[/i]" % text
	chronicle_text.append_text(text + "\n\n")


func _on_chronicle_added(e: Dictionary) -> void:
	_append_entry(e)


# --- Events -------------------------------------------------------------

func _show_event(view: Dictionary) -> void:
	if view.is_empty():
		return
	event_title.text = view.get("title", "")
	event_title.visible = event_title.text != ""
	event_text.text = view.get("text", "")
	for c in choices_box.get_children():
		choices_box.remove_child(c)
		c.queue_free()
	var choices: Array = view.get("choices", [])
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var b := _button(ch["label"])
		if not ch["enabled"]:
			var needs := []
			for r in ch["requires"]:
				needs.append("%d %s" % [int(ch["requires"][r]), r])
			b.text += "  (needs %s)" % ", ".join(needs)
			b.disabled = true
		b.pressed.connect(_on_choice.bind(i))
		choices_box.add_child(b)
	event_panel.visible = true
	controls_box.visible = false


func _on_choice(index: int) -> void:
	event_panel.visible = false
	Game.choose(index)


# --- Buttons ------------------------------------------------------------

func _on_next_day() -> void:
	Game.advance_day()


func _on_next_week() -> void:
	Game.advance_week()


func _on_until() -> void:
	Game.advance_until_something()


func _on_menu(id: int) -> void:
	match id:
		0:
			DisplayServer.clipboard_set(Chronicle.export_text())
			_notice("The chronicle has been copied. Paste it anywhere.")
		1:
			var path := Chronicle.save_export()
			_notice("Saved to:\n%s" % path if path != "" else "Could not save the file.")
		2:
			confirm_dialog.popup_centered()


func _start_new_house() -> void:
	Game.new_game()
	_estate_signature = ""
	_road_signature = ""
	road_map.selected = ""
	_render_chronicle()
	_refresh()


func _notice(text: String) -> void:
	notice_dialog.dialog_text = text
	notice_dialog.popup_centered()
