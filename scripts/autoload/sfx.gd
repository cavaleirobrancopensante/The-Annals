extends Node
## Sound effects: the tap of a button, a chime when a card comes, a bell for a death or a fall of the house.
## Each is synthesised once (scripts/audio/synth.gd) and then played as a short one-shot.

var _cache := {}


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	EventBus.event_presented.connect(func(_view: Dictionary) -> void: play("chime"))
	EventBus.monk_died.connect(func(_monk: Dictionary) -> void: play("bell"))
	EventBus.house_fell.connect(func() -> void: play("bell"))


func play(effect: String) -> void:
	if not Settings.sfx_on:
		return
	if not _cache.has(effect):
		_cache[effect] = Synth.effect(effect)
	var p := AudioStreamPlayer.new()
	p.stream = _cache[effect]
	p.volume_db = -4.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Every button in the game makes the click.
func _on_node_added(node: Node) -> void:
	if node is Button:
		node.pressed.connect(play.bind("click"))
