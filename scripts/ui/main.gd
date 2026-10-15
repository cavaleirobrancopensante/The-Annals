extends Control
## Phase 2 text interface, built for a portrait phone screen.
## Header with the winter forecast, chronicle and estate tabs, the current event, and turn buttons.

const BG := Style.BG
const PANEL := Style.PANEL
const PARCHMENT := Style.PARCHMENT
const DIM := Style.DIM
const GOLD := Style.GOLD
const RED := Style.RED

var title_label: Label
var status_label: Label
var feast_label: Label
var resources_label: RichTextLabel
var stores_label: RichTextLabel
var beings_label: RichTextLabel
var until_hint: Label
var _unread := 0
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
var event_scene: TextureRect
var event_text: RichTextLabel
var choices_box: VBoxContainer
var controls_box: HBoxContainer
var fallen_box: VBoxContainer
var settings_sheet: PanelContainer
var tutorial_box: PanelContainer
var _tut_step: Label
var _tut_title: Label
var _tut_text: Label
var _tut_begin: Button
var _tut_next: Button
var _tut_skip: Button
var _built_key := ""
var notice_dialog: AcceptDialog
var confirm_dialog: ConfirmationDialog

var _last_year_rendered := 0
var _estate_signature := ""


func _ready() -> void:
	# A house is opened from the main menu, which chooses its slot and sets the state up.
	if SaveSystem.slot == 0:
		get_tree().change_scene_to_file.call_deferred(Style.MENU_SCENE)
		return
	_built_key = "%s|%s" % [Settings.language, Settings.text_size]
	_build_ui()
	EventBus.chronicle_added.connect(_on_chronicle_added)
	EventBus.event_presented.connect(_show_event)
	EventBus.world_changed.connect(_refresh)
	EventBus.house_fell.connect(_refresh)
	Settings.changed.connect(_on_settings_changed, CONNECT_DEFERRED)
	_render_chronicle()
	_refresh()
	if Tutorial.state == "active":
		_show_tutorial_tab()
	if Game.waiting():
		_show_event(Game.current_view())


# --- Building the interface ---------------------------------------------

func _build_ui() -> void:
	theme = Style.theme()
	add_child(Style.background("house"))

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
	feast_label = _label(22, GOLD)
	root.add_child(feast_label)
	resources_label = _inline_label(20, PARCHMENT)
	root.add_child(resources_label)
	stores_label = _inline_label(20, PARCHMENT)
	root.add_child(stores_label)
	beings_label = _inline_label(18, PARCHMENT)
	root.add_child(beings_label)
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
	tabs.set_tab_title(0, tr("house.chronicle"))
	tabs.set_tab_title(1, tr("house.estate"))
	tabs.set_tab_title(2, tr("house.road"))
	tabs.tab_changed.connect(_on_tab_changed)

	event_panel = PanelContainer.new()
	event_panel.add_theme_stylebox_override("panel", _box(PANEL, GOLD, 2, 10, 16))
	event_panel.visible = false
	root.add_child(event_panel)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 10)
	event_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ev_scroll := ScrollContainer.new()
	ev_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ev_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_panel.add_child(ev_scroll)
	ev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ev_scroll.add_child(ev)
	event_scene = TextureRect.new()
	event_scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	event_scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	event_scene.custom_minimum_size = Vector2(0, 180)
	event_scene.visible = false
	ev.add_child(event_scene)
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

	tutorial_box = PanelContainer.new()
	tutorial_box.add_theme_stylebox_override("panel", _box(PANEL, GOLD, 2, 10, 14))
	tutorial_box.visible = false
	root.add_child(tutorial_box)
	var tut := VBoxContainer.new()
	tut.add_theme_constant_override("separation", 8)
	tutorial_box.add_child(tut)
	_tut_step = _label(18, DIM)
	tut.add_child(_tut_step)
	_tut_title = _label(24, GOLD)
	tut.add_child(_tut_title)
	_tut_text = _label(20, PARCHMENT)
	tut.add_child(_tut_text)
	var tut_row := HBoxContainer.new()
	tut_row.add_theme_constant_override("separation", 8)
	tut.add_child(tut_row)
	_tut_skip = _button(tr("tut.skip_all"))
	_tut_skip.pressed.connect(_on_tut_skip)
	tut_row.add_child(_tut_skip)
	_tut_next = _button(tr("tut.next"))
	_tut_next.pressed.connect(_on_tut_next)
	tut_row.add_child(_tut_next)
	_tut_begin = _button(tr("tut.begin"))
	_tut_begin.pressed.connect(_on_tut_begin)
	tut_row.add_child(_tut_begin)

	settings_sheet = PanelContainer.new()
	settings_sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_sheet.add_theme_stylebox_override("panel", _box(PANEL, GOLD, 2, 10, 16))
	settings_sheet.visible = false
	root.add_child(settings_sheet)
	var settings_scroll := ScrollContainer.new()
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_sheet.add_child(settings_scroll)
	var settings_panel := SettingsPanel.new()
	settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_panel.show_replay = true
	settings_panel.back_pressed.connect(_close_settings)
	settings_panel.replay_pressed.connect(_replay_tutorial)
	settings_scroll.add_child(settings_panel)

	controls_box = HBoxContainer.new()
	controls_box.add_theme_constant_override("separation", 8)
	root.add_child(controls_box)
	until_hint = _label(17, DIM)
	until_hint.text = tr("house.until_hint")
	root.add_child(until_hint)
	var day_btn := _button(tr("house.next_day"))
	day_btn.pressed.connect(_on_next_day)
	controls_box.add_child(day_btn)
	var next_btn := _button(tr("house.next_week"))
	next_btn.pressed.connect(_on_next_week)
	controls_box.add_child(next_btn)
	var until_btn := _button(tr("house.until"))
	until_btn.pressed.connect(_on_until)
	controls_box.add_child(until_btn)
	var menu := MenuButton.new()
	menu.text = tr("house.menu")
	menu.custom_minimum_size = Vector2(110, 64)
	menu.flat = false
	var popup := menu.get_popup()
	popup.add_theme_font_size_override("font_size", 24)
	popup.add_item(tr("house.copy"), 0)
	popup.add_item(tr("house.save_text"), 1)
	popup.add_item(tr("house.settings"), 2)
	popup.add_separator()
	popup.add_item(tr("house.to_menu"), 3)
	popup.add_item(tr("house.found_new"), 4)
	popup.id_pressed.connect(_on_menu)
	controls_box.add_child(menu)

	fallen_box = VBoxContainer.new()
	fallen_box.visible = false
	root.add_child(fallen_box)
	var fallen_label := _label(22, RED)
	fallen_label.text = tr("house.fallen")
	fallen_box.add_child(fallen_label)
	var new_btn := _button(tr("house.found_here"))
	new_btn.pressed.connect(_start_new_house)
	fallen_box.add_child(new_btn)
	var fallen_menu := _button(tr("house.to_menu"))
	fallen_menu.pressed.connect(_to_menu)
	fallen_box.add_child(fallen_menu)

	notice_dialog = AcceptDialog.new()
	notice_dialog.title = "The Annals"
	add_child(notice_dialog)
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = tr("house.found_new") + "?"
	confirm_dialog.dialog_text = tr("house.confirm_new")
	confirm_dialog.confirmed.connect(_start_new_house)
	add_child(confirm_dialog)


func _box(fill: Color, border: Color, width: int, radius: int, pad: int = 12) -> StyleBoxFlat:
	return Style.box(fill, border, width, radius, pad)


func _label(size: int, color: Color) -> Label:
	return Style.label(size, color)


func _rich(tab_name: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.name = tab_name
	r.bbcode_enabled = true
	r.selection_enabled = true
	r.add_theme_stylebox_override("normal", _box(PANEL, PANEL, 0, 6, 14))
	return r


func _button(text: String) -> Button:
	return Style.button(text, 64)


# --- Refreshing ---------------------------------------------------------

## A rich text label with no box, so item icons can sit inline with the numbers.
func _inline_label(size: int, color: Color) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", color)
	return r


## An item from the art set, as an inline image of the line's height.
func _icon(item: String) -> String:
	return "[img=24x24]res://assets/art/%s.svg[/img]" % item


func _refresh() -> void:
	title_label.text = WorldState.full_house_name()
	var ab := WorldState.abbot()
	var feasts := Calendar.feasts_on(WorldState.cal_year, WorldState.cal_month, WorldState.cal_day)
	status_label.text = "%s\n%s" % [WorldState.date_text(), tr("ui.status") % [WorldState.year(), tr("season." + WorldState.season()),
		WorldState.week_in_season(), ab.get("name", "none"), WorldState.generation]]
	feast_label.visible = not feasts.is_empty()
	if not feasts.is_empty():
		feast_label.text = tr("house.feast") % str(feasts[0]["name"])
	resources_label.text = "%s %d/%d    %s %d/%d    %s %d/%d" % [
		_icon("items/bread"), WorldState.res("food"), WorldState.cap("food"),
		_icon("items/log"), WorldState.res("firewood"), WorldState.cap("firewood"),
		_icon("items/herb"), WorldState.res("medicine"), WorldState.cap("medicine")]
	resources_label.add_theme_color_override("default_color", RED if _winter_short() else PARCHMENT)
	stores_label.text = "%s %d    %s %d    ·    %s" % [
		_icon("items/book"), WorldState.res("books"), _icon("icons/heart"), WorldState.res("goodwill"),
		tr("ui.brothers_n") % WorldState.living_monks().size()]
	beings_label.text = _beings_text()
	forecast_label.text = _forecast_text()
	forecast_label.add_theme_color_override("font_color", RED if _winter_short() else DIM)
	_render_estate_if_changed()
	_refresh_road()
	var waiting := Game.waiting()
	event_panel.visible = waiting
	controls_box.visible = not waiting and not WorldState.fallen
	fallen_box.visible = WorldState.fallen
	var sheet_open := settings_sheet.visible
	event_panel.visible = waiting and not sheet_open
	controls_box.visible = controls_box.visible and not sheet_open
	tabs.visible = not sheet_open and not waiting
	settings_sheet.visible = sheet_open
	until_hint.visible = controls_box.visible and Settings.hints
	_refresh_tutorial()


func _winter_short() -> bool:
	return WorldState.res("food") < WorldState.winter_food_need() or WorldState.res("firewood") < WorldState.winter_wood_need()


func _forecast_text() -> String:
	var food_need := WorldState.winter_food_need()
	var wood_need := WorldState.winter_wood_need()
	var text := tr("ui.winter_needs") % [food_need, wood_need]
	var food_short := food_need - WorldState.res("food")
	var wood_short := wood_need - WorldState.res("firewood")
	if food_short > 0 or wood_short > 0:
		var parts := []
		if food_short > 0:
			parts.append(tr("ui.more_food") % food_short)
		if wood_short > 0:
			parts.append(tr("ui.more_wood") % wood_short)
		text += tr("ui.short_by") % " and ".join(parts)
	else:
		text += tr("ui.stores_enough")
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

	estate_box.add_child(_section_title(tr("ui.section_brothers")))
	var living := WorldState.living_monks()
	living.sort_custom(_brother_order)
	for m in living:
		estate_box.add_child(_brother_row(m))

	var gone := WorldState.monks.filter(func(m): return not WorldState.is_living(m))
	if not gone.is_empty():
		var lines := []
		for m in gone:
			var how := tr("ui.died") % Chronicle.ordinal(int(m.get("died", 0))) if m["status"] == "dead" else tr("ui.left") % Chronicle.ordinal(int(m.get("left", 0)))
			lines.append("%s, %s" % [m["name"], how])
		var gone_label := _label(18, DIM)
		gone_label.text = tr("ui.departed") + "; ".join(lines)
		estate_box.add_child(gone_label)

	estate_box.add_child(_rule_section())
	estate_box.add_child(_house_section())
	estate_box.add_child(_section_title(tr("ui.section_buildings")))
	if not WorldState.has_builder_at_home():
		var note := _label(18, RED)
		note.text = tr("ui.builder_needed")
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

	road_box.add_child(_section_title(tr("ui.section_road")))
	road_map = RoadMap.new()
	road_map.node_picked.connect(func(_id: String): _refresh_road())
	road_box.add_child(road_map)
	road_info = _label(19, PARCHMENT)
	road_box.add_child(road_info)

	road_box.add_child(_section_title(tr("ui.section_send")))
	var help := _label(18, DIM)
	help.text = tr("ui.road_help")
	road_box.add_child(help)
	party_box = VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 6)
	road_box.add_child(party_box)
	var send_btn := _button(tr("ui.send_party"))
	send_btn.pressed.connect(_on_send_party)
	road_box.add_child(send_btn)
	var colony_btn := _button(tr("ui.send_colony"))
	colony_btn.pressed.connect(_on_send_colony)
	road_box.add_child(colony_btn)
	send_note = _label(18, RED)
	road_box.add_child(send_note)

	road_box.add_child(_section_title(tr("ui.section_onroad")))
	road_parties_box = VBoxContainer.new()
	road_parties_box.add_theme_constant_override("separation", 6)
	road_box.add_child(road_parties_box)

	road_box.add_child(_section_title(tr("ui.section_standing")))
	standings_label = _label(19, PARCHMENT)
	road_box.add_child(standings_label)


## The village below the house and the four beings, in a line each.
func _beings_text() -> String:
	var village := ""
	if Village.controlled:
		village = tr("ui.village_held") % [Village.name_of(), Village.standing]
	else:
		village = tr("ui.village_free") % [Village.name_of(), Village.standing]
	var line := tr("ui.beings_line") % [
		tr("state." + Beings.state("marred")), tr("state." + Beings.state("chimera")),
		tr("state." + Beings.state("engine")), tr("state." + Beings.state("hollow"))]
	return "%s\n%s" % [village, line]


func _refresh_road() -> void:
	_render_party_checks_if_changed()
	var sel := road_map.selected
	if sel == "":
		road_info.text = tr("ui.no_place")
	else:
		var n := Road.node(sel)
		var f := str(n["faction"])
		var weeks := Road.weeks_one_way(sel)
		road_info.text = tr("ui.road_info") % [n["name"], n["kind"], n["desc"],
			_weeks_text(weeks), Road.faction_name(f).capitalize(), _standing_word(Road.standing(f))]
		if Road.is_hostile(sel):
			road_info.text += "\n" + tr("ui.closed_note")

	for c in road_parties_box.get_children():
		road_parties_box.remove_child(c)
		c.queue_free()
	if Road.parties.is_empty():
		var none := _label(19, DIM)
		none.text = tr("ui.no_one_road")
		road_parties_box.add_child(none)
	for p in Road.parties:
		var line := _label(19, PARCHMENT)
		var who := Road.party_names(p)
		var where := Road.node_name(p["node"])
		if p["arrived"]:
			line.text = tr("ui.party_at") % [who, where, _weeks_text(int(p["back"]))]
		else:
			line.text = tr("ui.party_way") % [who, where, _weeks_text(int(p["out"]))]
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
		none.text = tr("ui.no_brother_send")
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
		send_note.text = tr("ui.choose_place")
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
	Tutorial.did("party")
	_refresh_road()


func _on_send_colony() -> void:
	send_note.text = ""
	var node_id := road_map.selected
	if node_id == "":
		send_note.text = tr("ui.choose_place")
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
	return tr("ui.week_one") % w if w == 1 else tr("ui.week_many") % w


func _standing_word(v: int) -> String:
	if v <= Road.HOSTILE:
		return tr("ui.stand_closed") % v
	if v < 0:
		return tr("ui.stand_wary") % v
	if v == 0:
		return tr("ui.stand_neutral")
	if v < 3:
		return tr("ui.stand_friendly") % v
	return tr("ui.stand_allied") % v


# --- The Rule and the house ---------------------------------------------

func _rule_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_section_title(tr("ui.section_rule")))
	var help := _label(18, DIM)
	help.text = tr("ui.rule_help")
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
	box.add_child(_section_title(tr("ui.section_house")))
	var lines := [tr("ui.generation") % WorldState.generation]
	if WorldState.saints.is_empty():
		lines.append(tr("ui.no_saint"))
	for sa in WorldState.saints:
		lines.append(tr("ui.saint") % [sa["name"], Chronicle.ordinal(int(sa["year"]))])
	if WorldState.priories.is_empty():
		lines.append(tr("ui.no_daughter"))
	for pr in WorldState.priories:
		lines.append(tr("ui.daughter") % [Road.node_name(pr["node"]), Chronicle.ordinal(int(pr["since"]))])
	var text := _label(19, PARCHMENT)
	text.text = "\n".join(lines)
	box.add_child(text)
	return box


func _on_rule_selected(index: int, axis_id: String, ids: Array) -> void:
	Game.set_rule(axis_id, str(ids[index]))


func _section_title(text: String) -> Label:
	return Style.section_title(text)


func _brother_row(m: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var info := _label(20, PARCHMENT)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var marks: Array = m["traits"].duplicate()
	for t in m["tags"]:
		if not str(t).begins_with("on_"):
			marks.append(str(t).replace("_", " "))
	for kid in m.get("skills", {}):
		if int(m["skills"][kid]) > 0:
			marks.append("%s %d" % [str(Skills.skill_names[kid]).to_lower(), int(m["skills"][kid])])
	marks.insert(0, tr("ui.path") % (Paths.name_of(str(m["path"])).to_lower() if bool(m["path_known"]) else "?"))
	for perk in Paths.perks_of(m):
		marks.append(str(perk).to_lower())
	var extra := ""
	if m["status"] == "away":
		var party := Road.party_of(m)
		if not party.is_empty():
			extra = tr("ui.with_party") % Road.node_name(party["node"])
		else:
			var w := int(m["away_weeks"])
			extra = tr("ui.on_road") % _weeks_text(w)
	elif not Skills.training_of(m).is_empty():
		extra = tr("ui.learning") % str(Skills.skill_names[Skills.training_of(m)["skill"]]).to_lower()
	elif int(m["health"]) < 3:
		extra = tr("ui.health_note") % WorldState.health_word(int(m["health"]))
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
		var label: String = WorldState.job_name(job)
		if WorldState.job_blocked(job):
			label = tr("ui.no_building") % label
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
		costs.append("%d %s" % [int(data["cost"][r]), tr("res." + r)])
	info.text = "%s · %s\n%s" % [WorldState.building_name(b), ", ".join(costs), WorldState.building_desc(b)]
	row.add_child(info)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 56)
	btn.add_theme_font_size_override("font_size", 20)
	if WorldState.has_building(b):
		btn.text = tr("ui.built")
		btn.disabled = true
	else:
		btn.text = tr("ui.build")
		btn.disabled = not WorldState.can_build(b)
		btn.pressed.connect(_on_build.bind(b))
	row.add_child(btn)
	return row


func _on_job_selected(index: int, monk_id: int) -> void:
	var m := WorldState.get_monk(monk_id)
	if m.is_empty():
		return
	Game.set_job(m, WorldState.JOB_ORDER[index])
	Tutorial.did("job")


func _on_build(b: String) -> void:
	if not Game.build(b):
		_notice(tr("ui.cannot_raise") % WorldState.building_name(b))


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
		chronicle_text.append_text("[center][color=#%s]%s[/color][/center]\n\n" % [
			GOLD.to_html(false), tr("ui.year_head") % Chronicle.ordinal(_last_year_rendered).capitalize()])
	var text: String = e["text"]
	if e.get("kind", "") in ["death", "fall"]:
		text = "[i]%s[/i]" % text
	chronicle_text.append_text(text + "\n\n")


func _on_chronicle_added(e: Dictionary) -> void:
	_append_entry(e)
	if tabs.current_tab != 0:
		_unread += 1
		_update_chronicle_title()


func _on_tab_changed(index: int) -> void:
	if index == 0:
		_unread = 0
	_update_chronicle_title()


func _update_chronicle_title() -> void:
	tabs.set_tab_title(0, tr("house.chronicle") + (" •" if _unread > 0 else ""))


# --- Events -------------------------------------------------------------

func _show_event(view: Dictionary) -> void:
	if view.is_empty():
		return
	event_title.text = view.get("title", "")
	event_title.visible = event_title.text != ""
	var scene_tex := Style.scene_for(str(EventEngine.pending.get("id", "")))
	event_scene.texture = scene_tex
	event_scene.visible = scene_tex != null
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
		if Settings.hints and ch.has("roll"):
			var roll: Dictionary = ch["roll"]
			b.text += "\n" + tr("event.roll") % [roll["stat"], roll["skill"], int(roll["difficulty"])]
		b.pressed.connect(_on_choice.bind(i))
		choices_box.add_child(b)
	event_panel.visible = true
	tabs.visible = false
	controls_box.visible = false
	until_hint.visible = false
	tutorial_box.visible = false


func _on_choice(index: int) -> void:
	event_panel.visible = false
	tabs.visible = true
	Game.choose(index)


# --- Buttons ------------------------------------------------------------

func _on_next_day() -> void:
	Tutorial.did("advance")
	Game.advance_day()


func _on_next_week() -> void:
	Tutorial.did("advance")
	Game.advance_week()


func _on_until() -> void:
	Tutorial.did("advance")
	Game.advance_until_something()


func _on_menu(id: int) -> void:
	match id:
		0:
			DisplayServer.clipboard_set(Chronicle.export_text())
			_notice(tr("house.copied"))
		1:
			var path := Chronicle.save_export()
			_notice(tr("house.saved_to") % path if path != "" else tr("house.not_saved"))
		2:
			_open_settings()
		3:
			_to_menu()
		4:
			_ask_new_house()


func _open_settings() -> void:
	settings_sheet.visible = true
	tabs.visible = false
	event_panel.visible = false
	controls_box.visible = false
	until_hint.visible = false
	tutorial_box.visible = false


func _refresh_tutorial() -> void:
	var on := Tutorial.state != "done" and not WorldState.fallen and not Game.waiting() and not settings_sheet.visible
	tutorial_box.visible = on
	if not on:
		return
	if Tutorial.state == "offer":
		_tut_step.text = ""
		_tut_title.text = tr("tut.offer_title")
		_tut_text.text = tr("tut.offer_text")
		_tut_begin.visible = true
		_tut_next.visible = false
	else:
		var name := Tutorial.current_name()
		_tut_step.text = tr("tut.step_of") % [Tutorial.step + 1, Tutorial.STEPS.size()]
		_tut_title.text = tr("tut.%s.title" % name)
		_tut_text.text = tr("tut.%s.text" % name)
		_tut_begin.visible = false
		_tut_next.visible = true
		_tut_next.text = tr("tut.finish") if Tutorial.is_last() else tr("tut.next")
		_tut_next.disabled = not Tutorial.can_advance()
		if not Tutorial.can_advance():
			_tut_next.text = tr("tut.do_it")
	_tut_skip.visible = true


func _show_tutorial_tab() -> void:
	if Tutorial.state == "active":
		tabs.current_tab = Tutorial.tab()


func _on_tut_begin() -> void:
	Tutorial.begin()
	_show_tutorial_tab()
	_refresh()


func _on_tut_next() -> void:
	if not Tutorial.can_advance():
		return
	Tutorial.next()
	_show_tutorial_tab()
	_refresh()


func _on_tut_skip() -> void:
	Tutorial.finish()
	_refresh()


func _replay_tutorial() -> void:
	Tutorial.begin()
	_close_settings()
	_show_tutorial_tab()


func _close_settings() -> void:
	settings_sheet.visible = false
	_refresh()


func _ask_new_house() -> void:
	if Settings.confirm_close:
		confirm_dialog.popup_centered()
	else:
		_start_new_house()


func _to_menu() -> void:
	SaveSystem.save_game()
	get_tree().change_scene_to_file(Style.MENU_SCENE)


func _on_settings_changed() -> void:
	if "%s|%s" % [Settings.language, Settings.text_size] != _built_key:
		get_tree().reload_current_scene()


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
