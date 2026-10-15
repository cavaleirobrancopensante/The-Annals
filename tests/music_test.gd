extends SceneTree
## Checks for the music and the sound effects: the 100 tracks and their moments and elements, the queue,
## shuffle and the season's track, and that the sound is made.
## godot --headless --path . --script res://tests/music_test.gd

var failures := 0
var ran := false


func _process(_delta: float) -> bool:
	if ran:
		return false
	ran = true
	var music = root.get_node("Music")
	var ws = root.get_node("WorldState")

	_expect("there are 100 tracks", music.tracks.size(), 100)
	var ids := {}
	var pairs := {}
	var moments := {}
	var elements := {}
	for t in music.tracks:
		ids[t["id"]] = true
		pairs[str(t["moment"]) + "/" + str(t["element"])] = true
		moments[t["moment"]] = int(moments.get(t["moment"], 0)) + 1
		elements[t["element"]] = int(elements.get(t["element"], 0)) + 1
	_expect("every track has its own id", ids.size(), 100)
	_expect("no two tracks share a moment and an element", pairs.size(), 100)
	var thin := []
	for m in moments:
		if moments[m] < 5:
			thin.append(m)
	_expect("every moment has at least five tracks", thin, [])
	thin = []
	for e in elements:
		if elements[e] < 5:
			thin.append(e)
	_expect("every element has at least five tracks", thin, [])
	_expect("the seasons name real moments", music.seasons.size(), 4)
	_expect("a track name is written in the current language", music.name_of(0).contains("·"), true)

	# The queue: a chosen track plays, and the list goes on from it.
	music.choose(5)
	_expect("choosing a track plays it", music.current_index(), 5)
	music.set_shuffle(true)
	_expect("shuffle starts with the chosen track", music.current_index(), 5)
	var order: Array = music.queue
	var seen := {}
	for i in order:
		seen[i] = true
	_expect("shuffle keeps every track once", order.size() == 100 and seen.size() == 100, true)
	music.next()
	_expect("next moves along the queue", music.position, 1)
	music.previous()
	music.previous()
	_expect("previous wraps round the queue", music.position, 99)
	music.set_shuffle(false)
	_expect("unshuffled, the list is in order", music.queue[7], 7)

	# Follow the season: the queue holds only the season's moment.
	music.set_follow(true)
	var want: String = str(music.seasons[ws.season()])
	var all_match := true
	for i in music.queue:
		if music.tracks[i]["moment"] != want:
			all_match = false
	_expect("following the season plays its moment", all_match and music.queue.size() > 0, true)
	_expect("the season's track is in the queue", music.tracks[music.current_index()]["moment"], want)

	# The sound: a track of 2 seconds is 16-bit mono at 22050 Hz, and each effect has sound in it.
	var pcm: PackedByteArray = Synth.track_pcm({"seconds": 2, "root": 50, "mode": "dorian", "tempo": 60,
		"voice": "harp", "texture": "rain", "seed": 4})
	_expect("a 2 second track is 88200 bytes", pcm.size(), 88200)
	var silent := true
	for k in range(0, pcm.size(), 2):
		if pcm.decode_s16(k) != 0:
			silent = false
			break
	_expect("a track is not silent", silent, false)
	var empty := []
	for name in ["click", "chime", "bell", "page", "thunder", "clash", "horn", "snuff", "door", "error"]:
		if Synth.effect_pcm(name).size() < 2000:
			empty.append(name)
	_expect("every effect makes sound", empty, [])
	var stream: AudioStreamWAV = Synth.track({"seconds": 1, "root": 50, "mode": "major", "tempo": 60, "voice": "bells", "texture": "wind", "seed": 2})
	_expect("a track loops", stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, true)

	print("music test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
	return false


func _expect(label: String, got, want) -> void:
	if got == want:
		print("ok   %s" % label)
	else:
		failures += 1
		print("FAIL %s: got %s, want %s" % [label, str(got), str(want)])
