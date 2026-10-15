extends SceneTree
## Checks the year review: a hidden brother who works one job for a year learns yes or no.
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

	# A householder at the fields, path hidden and set to householder: the review says yes and reveals him.
	var yes_m := _brother(1, "fields", "householder", sk, pa)
	ws.monks.append(yes_m)
	# A brother at the woods whose path is a monk's: the review says no, and the path stays hidden.
	var no_m := _brother(2, "woods", "monk", sk, pa)
	ws.monks.append(no_m)

	for i in sk.REVIEW_WEEKS - 1:
		sk.weekly_reviews()
	_expect("no review before a year", yes_m["path_known"], false)
	_expect("weeks counted", int(yes_m["job_weeks"]), sk.REVIEW_WEEKS - 1)

	var reviews: Array = sk.weekly_reviews()
	_expect("one review per brother at a year", reviews.size(), 2)
	_expect("the householder's review is a yes", _yes(reviews, 1), true)
	_expect("the yes reveals the path", yes_m["path_known"], true)
	_expect("the woods brother's review is a no", _yes(reviews, 2), false)
	_expect("the no keeps the path hidden", no_m["path_known"], false)
	_expect("the no rules the job out", "woods" in no_m["ruled_out"], true)
	_expect("the counter resets after a review", int(no_m["job_weeks"]), 0)

	# A ruled-out job is not counted again.
	for i in sk.REVIEW_WEEKS + 2:
		sk.weekly_reviews()
	_expect("a ruled-out job is not reviewed again", int(no_m["job_weeks"]), 0)

	# Changing job restarts the count.
	ws.set_job(no_m, "kitchen")
	_expect("a new job starts the count at zero", int(no_m["job_weeks"]), 0)

	print("Review checks: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(failures)
	return false


func _brother(id: int, job: String, path: String, sk, pa) -> Dictionary:
	var m := {"id": id, "status": "home", "health": 3, "vocation": "scribe", "job": job,
		"training": {}, "stats": {}, "skills": {}, "practice": {}}
	sk.init_monk(m)
	pa.assign(m, false)
	m["path"] = path
	m["path_known"] = false
	return m


func _yes(reviews: Array, id: int) -> bool:
	for r in reviews:
		if int(r["monk"]["id"]) == id:
			return bool(r["yes"])
	return false


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
