extends Node
## The oracle: every random decision in the game goes through here,
## from one seeded generator, so a house can be replayed exactly.

const ODDS := {
	"impossible": 0.05,
	"very_unlikely": 0.15,
	"unlikely": 0.3,
	"even": 0.5,
	"likely": 0.7,
	"very_likely": 0.85,
	"certain": 0.95,
}

var rng := RandomNumberGenerator.new()
var seed_value: int = 0


func start(new_seed: int = -1) -> void:
	if new_seed < 0:
		var r := RandomNumberGenerator.new()
		r.randomize()
		new_seed = r.randi() % 1000000000
	seed_value = new_seed
	rng.seed = new_seed


func odds_value(odds) -> float:
	if odds is String:
		return ODDS.get(odds, 0.5)
	return float(odds)


## Yes/no question to the oracle, like in solo play.
func ask(odds = "even") -> bool:
	return rng.randf() < odds_value(odds)


func chance(p: float) -> bool:
	return rng.randf() < p


func range_int(a: int, b: int) -> int:
	return rng.randi_range(a, b)


func pick(arr: Array):
	if arr.is_empty():
		return null
	return arr[rng.randi_range(0, arr.size() - 1)]


func pick_weighted_index(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return -1
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= float(weights[i])
		if roll < 0.0:
			return i
	return weights.size() - 1


func to_dict() -> Dictionary:
	# The state is a 64-bit integer; JSON would lose precision, so store it as text.
	return {"seed": seed_value, "state": str(rng.state)}


func from_dict(d: Dictionary) -> void:
	seed_value = int(d.get("seed", 0))
	rng.seed = seed_value
	rng.state = String(d.get("state", "0")).to_int()
