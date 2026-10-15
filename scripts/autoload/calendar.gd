extends Node
## The Roman calendar of 1962, read day by day: weekdays, the house's seasons,
## Easter and the movable feasts, the feasts that stop the clock, and the church season.

const MONTH_NAMES := ["January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December"]
const WEEKDAY_NAMES := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTH_LENGTHS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
## The season of the house that each month belongs to.
const SEASON_OF_MONTH := ["winter", "winter", "spring", "spring", "spring", "summer",
	"summer", "summer", "autumn", "autumn", "autumn", "winter"]
const SEASON_FIRST_MONTH := {"spring": 3, "summer": 6, "autumn": 9, "winter": 12}
## The house's clock begins at Michaelmas, Anno Domini 2500.
const START_YEAR := 2500
const START_MONTH := 9
const START_DAY := 29
const FEASTS_PATH := "res://data/calendar/feasts.json"
## Feasts of these ranks stop the clock and are written into the chronicle.
const STOP_RANKS := ["great"]

var _fixed: Array = []
var _easter_rel: Array = []
var _rules: Array = []
var _cache := {}


func _ready() -> void:
	load_data()


## Reads the data again, so a language change takes effect.
func load_data() -> void:
	_cache.clear()
	var data = JSON.parse_string(FileAccess.get_file_as_string(Strings.data(FEASTS_PATH)))
	if data is Dictionary:
		_fixed = data.get("fixed", [])
		_easter_rel = data.get("easter", [])
		_rules = data.get("rules", [])
	else:
		push_error("Could not read %s" % FEASTS_PATH)


# --- Date arithmetic ----------------------------------------------------

func is_leap(y: int) -> bool:
	return (y % 4 == 0 and y % 100 != 0) or y % 400 == 0


func month_length(y: int, m: int) -> int:
	if m == 2 and is_leap(y):
		return 29
	return MONTH_LENGTHS[m - 1]


## Day of the year, 1 January = 1.
func day_of_year(y: int, m: int, d: int) -> int:
	var n := d
	for i in range(1, m):
		n += month_length(y, i)
	return n


## The [month, day] that falls on a day of the year.
func date_of_year(y: int, doy: int) -> Array:
	var m := 1
	var d := doy
	while d > month_length(y, m):
		d -= month_length(y, m)
		m += 1
	return [m, d]


## The day after a date, as [year, month, day].
func next_date(y: int, m: int, d: int) -> Array:
	if d < month_length(y, m):
		return [y, m, d + 1]
	if m < 12:
		return [y, m + 1, 1]
	return [y + 1, 1, 1]


## Day of the week, 0 = Sunday (Sakamoto's method).
func weekday(y: int, m: int, d: int) -> int:
	var t := [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
	var yy := y - 1 if m < 3 else y
	return (yy + yy / 4 - yy / 100 + yy / 400 + t[m - 1] + d) % 7


## Gregorian Easter Sunday as [month, day].
func easter(y: int) -> Array:
	var a := y % 19
	var b := y / 100
	var c := y % 100
	var d := b / 4
	var e := b % 4
	var f := (b + 8) / 25
	var g := (b - f + 1) / 3
	var h := (19 * a + b - d - g + 15) % 30
	var i := c / 4
	var k := c % 4
	var l := (32 + 2 * e + 2 * i - h - k) % 7
	var mm := (a + 11 * h + 22 * l) / 451
	var month := (h + l - 7 * mm + 114) / 31
	var day := (h + l - 7 * mm + 114) % 31 + 1
	return [month, day]


func season_of(m: int) -> String:
	return SEASON_OF_MONTH[m - 1]


## Days since the season of the house began (its first day is day 0).
func days_into_season(y: int, m: int, d: int) -> int:
	var s := season_of(m)
	var first: int = SEASON_FIRST_MONTH[s]
	var cy := y - 1 if m < first else y
	var cm := first
	var cd := 1
	var n := 0
	while cy != y or cm != m or cd != d:
		var nx := next_date(cy, cm, cd)
		cy = nx[0]
		cm = nx[1]
		cd = nx[2]
		n += 1
	return n


func long_date(y: int, m: int, d: int) -> String:
	return tr("date.long") % [tr("weekday.%d" % weekday(y, m, d)), d, tr("month.%d" % m), y]


# --- Feasts -------------------------------------------------------------

## Every feast on a date, as {id, name, rank, local}. Empty if none.
func feasts_on(y: int, m: int, d: int) -> Array:
	if not _cache.has(y):
		_cache[y] = _build_year(y)
	return _cache[y].get("%d-%d" % [m, d], [])


## The first feast on a date that stops the clock, or {} if there is none.
func great_feast(y: int, m: int, d: int) -> Dictionary:
	for f in feasts_on(y, m, d):
		if str(f["rank"]) in STOP_RANKS:
			return f
	return {}


## The church's season on a date: advent, christmastide, ordinary, lent, holy_week, eastertide.
func church_season(y: int, m: int, d: int) -> String:
	var doy := day_of_year(y, m, d)
	var e := easter(y)
	var easter_doy := day_of_year(y, e[0], e[1])
	var advent := _rule_date(y, "advent_1")
	var advent_doy := day_of_year(y, advent[0], advent[1])
	var christmas_doy := day_of_year(y, 12, 25)
	if doy >= advent_doy:
		return "advent" if doy < christmas_doy else "christmastide"
	if doy >= christmas_doy or doy <= day_of_year(y, 2, 1):
		return "christmastide"
	if doy < easter_doy - 46:
		return "ordinary"
	if doy < easter_doy - 7:
		return "lent"
	if doy < easter_doy:
		return "holy_week"
	if doy < easter_doy + 49:
		return "eastertide"
	return "ordinary"


func _build_year(y: int) -> Dictionary:
	var table := {}
	for f in _fixed:
		_add(table, int(f["month"]), int(f["day"]), f)
	var e := easter(y)
	var easter_doy := day_of_year(y, e[0], e[1])
	var last := day_of_year(y, 12, 31)
	for f in _easter_rel:
		var doy := easter_doy + int(f["offset"])
		if doy >= 1 and doy <= last:
			var md := date_of_year(y, doy)
			_add(table, md[0], md[1], f)
	for f in _rules:
		var md2 := _rule_date(y, str(f["rule"]))
		if not md2.is_empty():
			_add(table, md2[0], md2[1], f)
	return table


func _add(table: Dictionary, m: int, d: int, f: Dictionary) -> void:
	var key := "%d-%d" % [m, d]
	if not table.has(key):
		table[key] = []
	table[key].append({
		"id": str(f["id"]),
		"name": str(f["name"]),
		"rank": str(f["rank"]),
		"local": bool(f.get("local", false)),
	})


## Feasts fixed by a rule rather than a date: the Sunday nearest St Andrew, the last Sunday of October.
func _rule_date(y: int, rule: String) -> Array:
	match rule:
		"advent_1":
			var w := weekday(y, 11, 30)
			if w == 0:
				return [11, 30]
			if w <= 3:
				return [11, 30 - w]
			return [12, 7 - w]
		"last_sunday_october":
			return [10, 31 - weekday(y, 10, 31)]
	return []
