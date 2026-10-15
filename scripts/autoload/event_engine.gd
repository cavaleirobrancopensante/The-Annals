extends Node
## Loads event cards from res://data/events/*.json, picks the ones whose
## conditions fit the world, and applies the outcome of the player's choice.
## See docs/EVENT_CARDS.md for the card format.
##
## Decks: "abbey" (weekly events at home), "return" (a brother comes home),
## "node" (a party arrives at a place on the road).

const EVENTS_DIR := "res://data/events"
const MONK_SLOTS := ["monk", "monk2"]

var cards: Array = []
var cards_by_id := {}
## card id -> week it can fire again
var cooldowns := {}
var used_once: Array = []
## {"id": card id, "bind": {"monk": id, "monk2": id, "newcomer": id}, "node": node id}
var pending := {}
## card id -> times fired (for testing and balancing)
var fired := {}


func _ready() -> void:
	load_cards()


func load_cards() -> void:
	cards.clear()
	cards_by_id.clear()
	for f in DirAccess.get_files_at(EVENTS_DIR):
		if not f.ends_with(".json"):
			continue
		var path := "%s/%s" % [EVENTS_DIR, f]
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Array:
			push_error("Event file is not a JSON array: %s" % path)
			continue
		for c in parsed:
			if not (c is Dictionary and c.has("id")):
				push_error("Event card without id in %s" % path)
				continue
			if cards_by_id.has(c["id"]):
				push_error("Duplicate event id '%s' in %s" % [c["id"], path])
				continue
			if not c.has("deck"):
				c["deck"] = "abbey"
			cards.append(c)
			cards_by_id[c["id"]] = c


func reset() -> void:
	cooldowns = {}
	used_once = []
	pending = {}
	fired = {}


func has_pending() -> bool:
	return not pending.is_empty()


# --- Conditions ---------------------------------------------------------

func _check_world(when: Dictionary, node_id: String = "") -> bool:
	if when.has("season") and not WorldState.season() in when["season"]:
		return false
	if when.has("not_season") and WorldState.season() in when["not_season"]:
		return false
	var mins: Dictionary = when.get("min", {})
	for r in mins:
		if WorldState.res(r) < int(mins[r]):
			return false
	var maxs: Dictionary = when.get("max", {})
	for r in maxs:
		if WorldState.res(r) > int(maxs[r]):
			return false
	for t in when.get("has_tag", []):
		if not WorldState.has_tag(t):
			return false
	for t in when.get("not_tag", []):
		if WorldState.has_tag(t):
			return false
	if when.has("min_monks") and WorldState.living_monks().size() < int(when["min_monks"]):
		return false
	if when.has("year_min") and WorldState.year() < int(when["year_min"]):
		return false
	# Road conditions: a node card only fires at its node.
	if when.has("rule") and not Rule.matches(when["rule"]):
		return false
	if when.has("node") and not node_id in when["node"]:
		return false
	if when.has("node_kind") and not Road.node_kind(node_id) in when["node_kind"]:
		return false
	var smin: Dictionary = when.get("standing_min", {})
	for f in smin:
		if Road.standing(f) < int(smin[f]):
			return false
	var smax: Dictionary = when.get("standing_max", {})
	for f in smax:
		if Road.standing(f) > int(smax[f]):
			return false
	return true


func _monk_matches(m: Dictionary, cond: Dictionary) -> bool:
	if m["status"] != cond.get("status", "home"):
		return false
	var is_abbot: bool = int(m["id"]) == WorldState.abbot_id
	if is_abbot != bool(cond.get("abbot", false)):
		return false
	if cond.has("vocation") and not m["vocation"] in cond["vocation"]:
		return false
	for t in cond.get("has", []):
		if not WorldState.monk_has(m, t):
			return false
	var any_list: Array = cond.get("has_any", [])
	if not any_list.is_empty() and not any_list.any(func(t): return WorldState.monk_has(m, t)):
		return false
	for t in cond.get("not", []):
		if WorldState.monk_has(m, t):
			return false
	if cond.has("min_age") and int(m["age"]) < int(cond["min_age"]):
		return false
	if cond.has("max_age") and int(m["age"]) > int(cond["max_age"]):
		return false
	if cond.has("min_health") and int(m["health"]) < int(cond["min_health"]):
		return false
	return true


func _try_bind(card: Dictionary, forced_monk_id: int = -1, node_id: String = "") -> Dictionary:
	var when: Dictionary = card.get("when", {})
	if not _check_world(when, node_id):
		return {"ok": false}
	var bind := {"ok": true}
	var taken := []
	for slot in MONK_SLOTS:
		if not when.has(slot):
			continue
		var cands := []
		if slot == "monk" and forced_monk_id >= 0:
			var fm := WorldState.get_monk(forced_monk_id)
			if not fm.is_empty() and _monk_matches(fm, when[slot]):
				cands = [fm]
		else:
			for m in WorldState.monks:
				if not int(m["id"]) in taken and _monk_matches(m, when[slot]):
					cands.append(m)
		if cands.is_empty():
			return {"ok": false}
		var chosen: Dictionary = Oracle.pick(cands)
		bind[slot] = int(chosen["id"])
		taken.append(int(chosen["id"]))
	# A forced brother must fit the card if the card is about a brother.
	if forced_monk_id >= 0 and when.has("monk") and not bind.has("monk"):
		return {"ok": false}
	return bind


## Cards that read tags the world remembers get more likely. That is
## how callbacks to earlier events emerge.
func _weight(card: Dictionary) -> float:
	var when: Dictionary = card.get("when", {})
	var refs: int = when.get("has_tag", []).size()
	for slot in MONK_SLOTS:
		if when.has(slot):
			refs += when[slot].get("has", []).size()
	return float(card.get("weight", 10)) * (1.0 + 0.75 * refs)


func _available(card: Dictionary) -> bool:
	if bool(card.get("once", false)) and card["id"] in used_once:
		return false
	return int(cooldowns.get(card["id"], -1)) <= WorldState.week


# --- Picking ------------------------------------------------------------

## Picks one eligible card from a deck and starts it. Returns false if none fit.
## forced_monk_id: the brother this event is about (returns, party arrivals).
## node_id: the place on the road, for "node" deck events.
func pick_event(deck: String = "abbey", forced_monk_id: int = -1, node_id: String = "") -> bool:
	if has_pending():
		return false
	var options := []
	var weights := []
	for c in cards:
		if c["deck"] != deck or not _available(c):
			continue
		var b := _try_bind(c, forced_monk_id, node_id)
		if b["ok"]:
			options.append({"card": c, "bind": b})
			weights.append(_weight(c))
	if options.is_empty():
		return false
	var chosen: Dictionary = options[Oracle.pick_weighted_index(weights)]
	_begin(chosen["card"], chosen["bind"], node_id)
	return true


## Starts a specific card if its conditions fit. Useful for testing.
func force_event(id: String) -> bool:
	if not cards_by_id.has(id) or has_pending():
		return false
	var b := _try_bind(cards_by_id[id])
	if not b["ok"]:
		return false
	_begin(cards_by_id[id], b, "")
	return true


func _begin(card: Dictionary, bind: Dictionary, node_id: String = "") -> void:
	bind.erase("ok")
	pending = {"id": card["id"], "bind": bind, "node": node_id}
	fired[card["id"]] = int(fired.get(card["id"], 0)) + 1
	if card.get("choices", []).is_empty():
		resolve(-1)
	else:
		EventBus.event_presented.emit(current_view())


func _ctx(bind: Dictionary, node_id: String = "") -> Dictionary:
	var ctx := {}
	for slot in ["monk", "monk2", "newcomer"]:
		if bind.has(slot):
			var m := WorldState.get_monk(bind[slot])
			if not m.is_empty():
				ctx[slot] = WorldState.display_name(m)
				ctx[slot + "_name"] = m["name"]
				ctx[slot + "_vocation"] = WorldState.vocation_name(m)
	if node_id != "":
		ctx["node"] = Road.node_name(node_id)
	return ctx


func requirements_met(choice: Dictionary) -> bool:
	var req: Dictionary = choice.get("requires", {})
	for r in req:
		if WorldState.res(r) < int(req[r]):
			return false
	return true


## What the UI shows for the pending event.
func current_view() -> Dictionary:
	if pending.is_empty():
		return {}
	var card: Dictionary = cards_by_id[pending["id"]]
	var ctx := _ctx(pending["bind"], pending.get("node", ""))
	var choices := []
	for ch in card.get("choices", []):
		choices.append({
			"label": Chronicle.format(ch.get("label", "..."), ctx),
			"enabled": requirements_met(ch),
			"requires": ch.get("requires", {}),
		})
	return {
		"id": card["id"],
		"title": Chronicle.format(card.get("title", ""), ctx),
		"text": Chronicle.format(card.get("text", ""), ctx),
		"choices": choices,
	}


# --- Resolving ----------------------------------------------------------

func resolve(choice_index: int) -> void:
	if pending.is_empty():
		return
	var card: Dictionary = cards_by_id[pending["id"]]
	var bind: Dictionary = pending["bind"].duplicate()
	var node_id: String = pending.get("node", "")
	var lines := []
	var effects: Dictionary = card.get("effects", {})
	var headline: String = card.get("chronicle", "")
	var choices: Array = card.get("choices", [])
	if choice_index >= 0 and not choices.is_empty():
		var choice: Dictionary = choices[clampi(choice_index, 0, choices.size() - 1)]
		effects = choice.get("effects", {})
		headline = choice.get("chronicle", headline)
	if headline != "":
		lines.append(headline)
	_apply(effects, bind, lines)
	# A brother home from the road sheds his journey tags.
	if card["deck"] == "return" and bind.has("monk"):
		var m := WorldState.get_monk(bind["monk"])
		if not m.is_empty():
			m["tags"] = m["tags"].filter(func(t): return not str(t).begins_with("on_"))
	cooldowns[card["id"]] = WorldState.week + int(card.get("cooldown", 30))
	if bool(card.get("once", false)):
		used_once.append(card["id"])
	pending = {}
	if not lines.is_empty():
		Chronicle.add(" ".join(lines), card.get("kind", "event"), _ctx(bind, node_id))
	EventBus.event_resolved.emit(card["id"], choice_index)


func _as_array(v) -> Array:
	if v == null:
		return []
	if v is Array:
		return v
	return [v]


func _apply(effects: Dictionary, bind: Dictionary, lines: Array) -> void:
	for r in WorldState.RESOURCES:
		if effects.has(r):
			WorldState.change_resource(r, int(effects[r]))
	var tag_weeks := int(effects.get("tag_weeks", -1))
	for t in _as_array(effects.get("add_tag")):
		WorldState.add_tag(t, tag_weeks)
	for t in _as_array(effects.get("remove_tag")):
		WorldState.remove_tag(t)
	var standing: Dictionary = effects.get("standing", {})
	for f in standing:
		Road.change_standing(f, int(standing[f]))
	for slot in MONK_SLOTS:
		if not bind.has(slot):
			continue
		var m := WorldState.get_monk(bind[slot])
		if m.is_empty():
			continue
		for t in _as_array(effects.get(slot + "_add_tag")):
			if not t in m["tags"]:
				m["tags"].append(t)
		for t in _as_array(effects.get(slot + "_remove_tag")):
			m["tags"].erase(t)
			m["traits"].erase(t)
		if effects.has(slot + "_health"):
			WorldState.change_health(m, int(effects[slot + "_health"]))
		if effects.has(slot + "_away"):
			var away: Dictionary = effects[slot + "_away"]
			m["status"] = "away"
			m["away_weeks"] = int(away.get("weeks", 4))
			var journey: String = away.get("tag", "")
			if journey != "" and not journey in m["tags"]:
				m["tags"].append(journey)
		if bool(effects.get(slot + "_departs", false)):
			WorldState.depart_monk(m)
		if effects.has(slot + "_dies"):
			WorldState.kill_monk(m, str(effects[slot + "_dies"]))
	if effects.has("new_monk"):
		var spec: Dictionary = effects["new_monk"] if effects["new_monk"] is Dictionary else {}
		var age: Array = spec.get("age", [17, 30])
		var nm := WorldState.generate_monk(spec.get("vocation", ""), spec.get("traits", []), int(age[0]), int(age[1]), true)
		bind["newcomer"] = nm["id"]
	if effects.has("chronicle") and str(effects["chronicle"]) != "":
		lines.append(effects["chronicle"])
	if effects.has("oracle"):
		var o: Dictionary = effects["oracle"]
		var answer := Oracle.ask(o.get("odds", "even"))
		_apply(o.get("yes" if answer else "no", {}), bind, lines)


# --- Save ---------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"cooldowns": cooldowns, "used_once": used_once, "pending": pending, "fired": fired}


func from_dict(d: Dictionary) -> void:
	cooldowns = {}
	for k in d.get("cooldowns", {}):
		cooldowns[k] = int(d["cooldowns"][k])
	used_once = d.get("used_once", [])
	fired = d.get("fired", {})
	pending = d.get("pending", {})
	if not pending.is_empty():
		var bind: Dictionary = pending.get("bind", {})
		for k in bind:
			bind[k] = int(bind[k])
		if not cards_by_id.has(pending.get("id", "")):
			pending = {}
