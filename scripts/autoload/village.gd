extends Node
## The village below the house: a standing the house earns or loses, and control that follows it.
## Control is either held or not. While the house controls the village it pays a tithe and gives labour
## to the fields, and its own deck of events is drawn. Neglect lowers the standing, week by week.

const LIMIT := 10
const START := 2
## Control is gained when the standing reaches this, and lost when it falls to LOSS_AT or below.
const GAIN_AT := 6
const LOSS_AT := 0
const TITHE_EVERY := 4
const TITHE_FOOD := 4
const TITHE_FIREWOOD := 2
const LABOUR_FOOD := 2
## Weeks without a visit before the village begins to turn away, then one point lost every NEGLECT_STEP weeks.
const NEGLECT_WEEKS := 26
const NEGLECT_STEP := 8
const EVENT_CHANCE_CONTROLLED := 0.12
const EVENT_CHANCE_OTHER := 0.03
const PATH := "res://data/village/village.json"

var standing := START
var controlled := false
## Week of the last visit or village event. Neglect counts from here.
var last_contact := 0
var _neglect_noted := false


func new_game() -> void:
	standing = START
	controlled = false
	last_contact = 0
	_neglect_noted = false


## The village's name, as the current language has it.
func name_of() -> String:
	var data = JSON.parse_string(FileAccess.get_file_as_string(Strings.data(PATH)))
	if data is Dictionary:
		return str(data.get("name", "the village"))
	return "the village"


## Moves the standing and checks whether control was gained or lost.
func change(delta: int) -> void:
	standing = clampi(standing + delta, -LIMIT, LIMIT)
	if not controlled and standing >= GAIN_AT:
		controlled = true
		Chronicle.add(tr("village.gained") % name_of(), "village")
	elif controlled and standing <= LOSS_AT:
		controlled = false
		Chronicle.add(tr("village.lost") % name_of(), "village")


## A visit or an event with the village: the neglect clock starts again.
func touch() -> void:
	last_contact = WorldState.week
	_neglect_noted = false


## Once a week: neglect, and the tithe and labour while the house controls the village.
func weekly() -> void:
	var w := WorldState.week
	if w - last_contact > NEGLECT_WEEKS and w % NEGLECT_STEP == 0:
		if not _neglect_noted:
			_neglect_noted = true
			Chronicle.add(tr("village.neglected") % name_of(), "village")
		change(-1)
	if controlled and w % TITHE_EVERY == 0:
		WorldState.change_resource("food", TITHE_FOOD)
		WorldState.change_resource("firewood", TITHE_FIREWOOD)


## Food the village's labour adds to the fields this week. Only in the working seasons.
func labour_food(season: String) -> int:
	if controlled and season in ["spring", "summer", "autumn"]:
		return LABOUR_FOOD
	return 0


## Whether the village deck gets a turn this week.
func wants_event() -> bool:
	return Oracle.chance(EVENT_CHANCE_CONTROLLED if controlled else EVENT_CHANCE_OTHER)


func to_dict() -> Dictionary:
	return {"standing": standing, "controlled": controlled, "last_contact": last_contact}


func from_dict(d: Dictionary) -> void:
	standing = int(d.get("standing", START))
	controlled = bool(d.get("controlled", false))
	last_contact = int(d.get("last_contact", 0))
	_neglect_noted = false
