extends Node
## The keeper's walk-through for a new house: an offer, then seven coach cards with Skip all on each.
## The state is kept in the house's save, so a house is offered it once. Older houses are never offered it.
## The text is in strings.gd; the screen is in main.gd.

## Steps that wait for the player: the step's Next button stays off until the named action happens.
## Skip all is always available.
const REQUIRES := {"estate": "job", "time": "advance", "road": "party"}

var satisfied := false

## Each step names its text keys (tut.<name>.title / .text) and the tab it opens (0 chronicle, 1 estate, 2 road).
const STEPS := [
	{"name": "house", "tab": 0},
	{"name": "estate", "tab": 1},
	{"name": "time", "tab": 0},
	{"name": "choice", "tab": 0},
	{"name": "road", "tab": 2},
	{"name": "paths", "tab": 1},
	{"name": "menu", "tab": 0},
]

## "offer" before the walk-through is begun, "active" while it runs, "done" once it is finished or skipped.
var state := "done"
var step := 0


func start_offer() -> void:
	state = "offer"
	step = 0


func begin() -> void:
	state = "active"
	step = 0
	satisfied = false


func next() -> void:
	if step + 1 >= STEPS.size():
		finish()
	else:
		step += 1
		satisfied = false


## The player has done something; the current step is satisfied if it was the action it waits for.
func did(action: String) -> void:
	if state == "active" and REQUIRES.get(current_name(), "") == action:
		satisfied = true


## Whether the player may move on from this step.
func can_advance() -> bool:
	if state != "active":
		return true
	return satisfied or not REQUIRES.has(current_name())


func is_last() -> bool:
	return step + 1 >= STEPS.size()


func finish() -> void:
	state = "done"
	step = 0
	satisfied = false


func current_name() -> String:
	return str(STEPS[step]["name"])


func tab() -> int:
	return int(STEPS[step]["tab"])


func to_dict() -> Dictionary:
	return {"state": state, "step": step}


func from_dict(d: Dictionary) -> void:
	state = str(d.get("state", "done"))
	step = clampi(int(d.get("step", 0)), 0, STEPS.size() - 1)
