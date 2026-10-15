extends Node
## The keeper's walk-through for a new house: an offer, then seven coach cards with Skip all on each.
## The state is kept in the house's save, so a house is offered it once. Older houses are never offered it.
## The text is in strings.gd; the screen is in main.gd.

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


func next() -> void:
	if step + 1 >= STEPS.size():
		finish()
	else:
		step += 1


func is_last() -> bool:
	return step + 1 >= STEPS.size()


func finish() -> void:
	state = "done"
	step = 0


func current_name() -> String:
	return str(STEPS[step]["name"])


func tab() -> int:
	return int(STEPS[step]["tab"])


func to_dict() -> Dictionary:
	return {"state": state, "step": step}


func from_dict(d: Dictionary) -> void:
	state = str(d.get("state", "done"))
	step = clampi(int(d.get("step", 0)), 0, STEPS.size() - 1)
