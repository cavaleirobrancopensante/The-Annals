extends Node
## The chronicle: turns what happens into a scribe's entries, and exports the book.

const ORDINALS := ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth",
	"ninth", "tenth", "eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth",
	"sixteenth", "seventeenth", "eighteenth", "nineteenth", "twentieth"]
const ONES := ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
	"ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
	"eighteen", "nineteen"]
const TENS := ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]

var entries: Array = []
var templates := {}


func _ready() -> void:
	load_data()


## Reads the data again, so a language change takes effect.
func load_data() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(Strings.data("res://data/chronicle/templates.json")))
	if data is Dictionary:
		templates = data
	else:
		push_error("Could not read res://data/chronicle/templates.json")


func clear() -> void:
	entries = []


# --- Words --------------------------------------------------------------

func ordinal(n: int) -> String:
	if n >= 1 and n <= ORDINALS.size():
		return tr("ordinal.%d" % n)
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]


func number_word(n: int) -> String:
	if n < 0 or n > 99:
		return str(n)
	if n < 20:
		return tr("num.%d" % n)
	var t: String = tr("tens.%d" % int(n / 10.0))
	return t if n % 10 == 0 else "%s%s%s" % [t, tr("num.join"), tr("num.%d" % (n % 10))]


# --- Formatting ---------------------------------------------------------

const SAME_SEASON := ["that same {season}", "soon after", "in those weeks", "before the {season} was out",
	"that {season}", "a little later", "not long after"]


## The formal date the first time a season appears in the annals,
## then lighter phrases, the way a real chronicler writes.
func _when_phrase(full: String) -> String:
	if entries.is_empty():
		return full
	var last: Dictionary = entries[entries.size() - 1]
	if int(last["year"]) == WorldState.year() and last["season"] == WorldState.season():
		var phrase := str(Oracle.pick(SAME_SEASON))
		return tr("when.same.%d" % SAME_SEASON.find(phrase)).replace("{season}", tr("season." + WorldState.season()))
	return full


func base_context() -> Dictionary:
	var ab := WorldState.abbot()
	var abbot_name: String = ab.get("name", "")
	var n := WorldState.year() - WorldState.abbot_since_year + 1
	return {
		"abbot": tr("ui.abbot") % abbot_name,
		"abbot_name": abbot_name,
		"season": tr("season." + WorldState.season()),
		"year": str(WorldState.year()),
		"year_ordinal": ordinal(WorldState.year()),
		"patron": WorldState.patron,
		"house": WorldState.house_name(),
		"place": WorldState.place,
		"abbot_ordinal": ordinal(n),
		"when_full": tr("when.abbot") % [ordinal(n), tr("season." + WorldState.season()), abbot_name],
	}


func format(text: String, ctx: Dictionary = {}) -> String:
	var full := base_context()
	if text.contains("{when}") or text.contains("{When}"):
		var when := _when_phrase(full["when_full"])
		full["when"] = when
		full["When"] = when.substr(0, 1).to_upper() + when.substr(1)
	full.merge(ctx, true)
	for k in full:
		text = text.replace("{%s}" % k, str(full[k]))
	return text


func add(text: String, kind: String = "event", ctx: Dictionary = {}) -> void:
	if text.strip_edges() == "":
		return
	var e := {
		"week": WorldState.week,
		"year": WorldState.year(),
		"season": WorldState.season(),
		"abbot": WorldState.abbot().get("name", ""),
		"kind": kind,
		"text": format(text, ctx),
	}
	entries.append(e)
	EventBus.chronicle_added.emit(e)


func add_template(key: String, ctx: Dictionary = {}, kind: String = "event") -> void:
	var options: Array = templates.get(key, [])
	if options.is_empty():
		push_warning("No chronicle template for '%s'" % key)
		return
	add(str(Oracle.pick(options)), kind, ctx)


# --- Export -------------------------------------------------------------

func export_text() -> String:
	var lines := []
	lines.append("THE ANNALS OF %s" % WorldState.full_house_name().to_upper())
	lines.append("")
	var current_year := 0
	for e in entries:
		if int(e["year"]) != current_year:
			current_year = int(e["year"])
			lines.append("")
			lines.append("~ The %s Year of the House ~" % ordinal(current_year).capitalize())
			lines.append("")
		lines.append(e["text"])
		lines.append("")
	return "\n".join(lines)


func save_export() -> String:
	var path := "user://chronicle.txt"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(export_text())
	f.close()
	return ProjectSettings.globalize_path(path)


# --- Save ---------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"entries": entries}


func from_dict(d: Dictionary) -> void:
	entries = []
	for e in d.get("entries", []):
		e["week"] = int(e.get("week", 0))
		e["year"] = int(e.get("year", 1))
		entries.append(e)
