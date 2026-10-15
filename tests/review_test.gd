extends SceneTree
## Checks the review of a hidden path: a shortlist hint at a year's work, a reveal at two years if the job is the path,
## faster progress for skilled workers, and a ruled-out job that is not reviewed again.
## godot --headless --path . --script res://tests/review_test.gd

var failures := 0
var ran := false


func _process(_delta: float) -> bool:
	if ran:
		return false
	ran = true
	var sk = root.get_node("Skills")
	var pa = root.get_node("Paths")
	var ws = root.get_node("WorldState")
	root.get_node("Oracle").start(11)
	ws.monks.clear()

	# A householder at the fields: the job is his path.
	var yes_m := _brother(1, "fields", "householder", sk, pa)
	ws.monks.append(yes_m)
	# A monk at the woods: the job is not his path.
	var no_m := _brother(2, "woods", "monk", sk, pa)
	ws.monks.append(no_m)
	# A skilled householder at the fields: his labour is already level three, so progress is doubled.
	var skilled := _brother(3, "fields", "householder", sk, pa)
	skilled["skills"]["labour"] = 3
	ws.monks.append(skilled)

	# Week 25: the householder has 25 weeks, the skilled brother 50 progress. Nobody is hinted yet.
	var reviews: Array = _weeks(sk, 25)
	_expect("no hint before week 26", reviews.size(), 0)
	_expect("progress counts one a week", float(yes_m["job_weeks"]), 25.0)

	# Week 26: the skilled brother reaches 52 progress at two a week; the others are not hinted.
	reviews = _weeks(sk, 1)
	_expect("the skilled brother is hinted at week 26", _has_hint(reviews, 3), true)
	_expect("the householder is not hinted at week 26", _has_hint(reviews, 1), false)
	_expect("the hint is three paths", _candidates_of(skilled).size(), 3)
	_expect("the skilled brother's hint names his path", "householder" in _candidates_of(skilled), true)

	# Week 52: the householder and the monk at the woods reach 52 progress.
	reviews = _weeks(sk, 26)
	_expect("the householder is hinted at a year", _has_hint(reviews, 1), true)
	_expect("the monk at the woods is hinted at a year", _has_hint(reviews, 2), true)
	_expect("the skilled brother is not hinted again", _has_hint(reviews, 3), false)
	_expect("the hint names the true path", "householder" in _candidates_of(yes_m), true)
	_expect("the hint is three paths", _candidates_of(yes_m).size(), 3)
	_expect("a hint is not a reveal", yes_m["path_known"], false)
	_expect("the hint for the non-match names the true path", "monk" in _candidates_of(no_m), true)
	_expect("the hint for the non-match leaves out the job's path", "builder" in _candidates_of(no_m), false)
	_expect("the non-match rules the woods out", "woods" in no_m["ruled_out"], true)

	# Week 104: the householder reaches 104 progress and is revealed; the ruled-out job is no longer counted.
	reviews = _weeks(sk, 52)
	_expect("two years reveal the householder", _has_reveal(reviews, 1), true)
	_expect("the reveal sets the path known", yes_m["path_known"], true)
	_expect("no reveal for the non-match", _has_reveal(reviews, 2), false)
	_expect("the ruled-out job is no longer counted", float(no_m["job_weeks"]), 52.0)

	print("Review checks: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)
	return false


func _weeks(sk, n: int) -> Array:
	var all := []
	for i in n:
		all.append_array(sk.weekly_reviews())
	return all


func _hints(reviews: Array) -> Array:
	return reviews.filter(func(r): return r.has("hint"))


func _has_hint(reviews: Array, id: int) -> bool:
	for r in reviews:
		if r.has("hint") and int(r["monk"]["id"]) == id:
			return true
	return false


func _has_reveal(reviews: Array, id: int) -> bool:
	for r in reviews:
		if r.has("reveal") and int(r["monk"]["id"]) == id:
			return true
	return false


func _candidates_of(m: Dictionary) -> Array:
	return m.get("candidates", [])


func _brother(id: int, job: String, path: String, sk, pa) -> Dictionary:
	var m := {"id": id, "status": "home", "health": 3, "vocation": "scribe", "job": job,
		"training": {}, "stats": {}, "skills": {}, "practice": {}}
	sk.init_monk(m)
	pa.assign(m, false)
	m["path"] = path
	m["path_known"] = false
	return m


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
