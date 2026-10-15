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
	if EventEngine.has_pending():
		_show_event(EventEngine.current_view())


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
	status_label.text = "Year %d  ·  %s, week %d  ·  Abbot %s" % [
		WorldState.year(), WorldState.season().capitalize(), WorldState.week_in_season(), ab.get("name", "none")]
	resources_label.text = "Food %d/%d   Firewood %d/%d   Medicine %d/%d   Books %d   Goodwill %d   ·   %d brothers" % [
		WorldState.res("food"), WorldState.cap("food"), WorldState.res("firewood"), WorldState.cap("firewood"),
		WorldState.res("medicine"), WorldState.cap("medicine"), WorldState.res("books"), WorldState.res("goodwill"),
		WorldState.living_monks().size()]
	forecast_label.text = _forecast_text()
	forecast_label.add_theme_color_override("font_color", RED if _winter_short() else DIM)
	_render_estate_if_changed()
	var waiting := EventEngine.has_pending()
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
		parts.append("%d:%s:%s" % [int(m["id"]), m["status"], WorldState.job_of(m)])
	for b in WorldState.BUILDINGS:
		parts.append("%s:%s" % [b, WorldState.has_building(b)])
	parts.append(str(WorldState.abbot_id))
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

	estate_box.add_child(_section_title("Buildings"))
	if not WorldState.has_builder_at_home():
		var note := _label(18, RED)
		note.text = "A builder must be at home to raise a building."
		estate_box.add_child(note)
	for b in WorldState.BUILDINGS:
		estate_box.add_child(_building_row(b))


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
	_render_chronicle()
	_refresh()


func _notice(text: String) -> void:
	notice_dialog.dialog_text = text
	notice_dialog.popup_centered()
