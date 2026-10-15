extends Node
## The music of the house: the 100 tracks, a queue through them, shuffle, and the track for the season.
## A track is rendered in the background from its recipe, looped for its length, and the next one follows.
## "Follow the season" plays tracks of the season's moment, and changes them when the season does.

signal changed

const TRACKS_PATH := "res://data/music/tracks.json"
const CACHE_SIZE := 4

var tracks: Array = []
var seasons: Dictionary = {}
## Indices into tracks, in the order they play.
var queue: Array = []
var position := 0
var shuffle := false
var follow := true
var paused := false

var _player: AudioStreamPlayer
var _timer: Timer
var _rng := RandomNumberGenerator.new()
var _task := -1
## The rendered sound of tracks already played: index -> PackedByteArray.
var _cache := {}
## What the background render is making: {"index", "pcm"}, filled by the worker thread.
var _job := {}
var _last_season := ""


func _ready() -> void:
	_rng.randomize()
	_load()
	_player = AudioStreamPlayer.new()
	_player.volume_db = -6.0
	add_child(_player)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(next)
	add_child(_timer)
	EventBus.week_advanced.connect(_on_week)


func _load() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(Strings.data(TRACKS_PATH)))
	if data is Dictionary:
		tracks = data.get("tracks", [])
		seasons = data.get("seasons", {})


func _process(_delta: float) -> void:
	if _task != -1 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if int(_job.get("index", -2)) == current_index():
			_start(int(_job["index"]), _job["pcm"])


## Called when the house opens: plays the season's track, or carries on with the queue already set.
func begin() -> void:
	if queue.is_empty():
		_follow_season()
	else:
		_play_current()


func current_index() -> int:
	if queue.is_empty():
		return -1
	return int(queue[position])


func is_playing() -> bool:
	return _player.playing and not paused


## The track's name in the current language: its moment and its element.
func name_of(index: int) -> String:
	if index < 0 or index >= tracks.size():
		return ""
	var t: Dictionary = tracks[index]
	return tr("music.name") % [tr("moment." + str(t["moment"])), tr("element." + str(t["element"]))]


func _shuffled(list: Array) -> Array:
	var out := list.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _follow_season() -> void:
	_last_season = WorldState.season()
	var moment := str(seasons.get(_last_season, "dawn"))
	var list := []
	for i in tracks.size():
		if tracks[i]["moment"] == moment:
			list.append(i)
	if list.is_empty():
		return
	follow = true
	queue = _shuffled(list)
	position = 0
	_play_current()


## Every track, in order, or shuffled, starting with the one given.
func _whole_queue(first: int) -> Array:
	var out := []
	for i in tracks.size():
		out.append(i)
	if shuffle:
		out.erase(first)
		return [first] + _shuffled(out)
	return out


## Plays one track chosen from the whole list. The queue goes on from it.
func choose(index: int) -> void:
	follow = false
	queue = _whole_queue(index)
	position = 0 if shuffle else index
	_play_current()


func set_shuffle(on: bool) -> void:
	shuffle = on
	if not follow and current_index() >= 0:
		queue = _whole_queue(current_index())
		position = 0
	changed.emit()


func set_follow(on: bool) -> void:
	if on:
		_follow_season()
	else:
		follow = false
	changed.emit()


func next() -> void:
	if queue.is_empty():
		return
	position = (position + 1) % queue.size()
	_play_current()


func previous() -> void:
	if queue.is_empty():
		return
	position = (position - 1 + queue.size()) % queue.size()
	_play_current()


func toggle_pause() -> void:
	if _player.stream == null:
		return
	paused = not paused
	_player.stream_paused = paused
	_timer.paused = paused
	changed.emit()


## Music on or off. Off stops the sound; on starts the season's track, or the queue set before.
func set_enabled(on: bool) -> void:
	if on:
		paused = false
		begin()
	else:
		_player.stop()
		_timer.stop()
	changed.emit()


func _on_week(_week: int) -> void:
	if follow and WorldState.season() != _last_season:
		_follow_season()


## Starts the track at the queue's position. Known tracks start at once; others are rendered in the background.
func _play_current() -> void:
	var index := current_index()
	if index < 0:
		return
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if not Settings.music_on:
		changed.emit()
		return
	if _cache.has(index):
		_start(index, _cache[index])
	else:
		_job = {"index": index, "pcm": PackedByteArray()}
		_task = WorkerThreadPool.add_task(_render.bind(tracks[index], index))
	changed.emit()


## Runs on a worker thread. It writes only _job, which the main thread reads after the task is done.
func _render(recipe: Dictionary, index: int) -> void:
	_job = {"index": index, "pcm": Synth.track_pcm(recipe)}


func _start(index: int, pcm: PackedByteArray) -> void:
	if not Settings.music_on:
		return
	_cache[index] = pcm
	while _cache.size() > CACHE_SIZE:
		_cache.erase(_cache.keys()[0])
	_player.stream = Synth.stream(pcm, true)
	_player.stream_paused = paused
	_player.play()
	_timer.start(float(tracks[index].get("seconds", 40)))
	changed.emit()
