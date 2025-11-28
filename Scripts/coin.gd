extends Node2D

@onready var area: Area2D = $Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if area:
		area.connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if not body or not body.is_in_group("player"):
		return
	# Prevent further pickups
	if area:
		area.monitoring = false

	# First try the current scene (most common case: `Main/Game`)
	var current_scene = get_tree().get_current_scene()
	var game = null
	if current_scene:
		game = current_scene.get_node_or_null("Game")

	# Fallback to an autoload named `Game` at /root/Game
	if game == null:
		game = get_node_or_null("/root/Game")

	if game and game.has_method("add_coin"):
		print("Coin: player hit, calling Game.add_coin()")
		game.add_coin()
	else:
		push_warning("Coin pickup: no Game node with add_coin() found")

	# Play a short collect animation using a Tween: scale up, fade out, and rise
	var t = create_tween()
	if sprite:
		# scale up
		t.tween_property(sprite, "scale", sprite.scale * 1.5, 0.25)
		# fade out
		t.tween_property(sprite, "modulate:a", 0.0, 0.25)
	# rise slightly (animate the coin node itself)
	t.tween_property(self, "position:y", position.y - 16, 0.25)

	# Wait for the tween to finish, then free the coin
	await t.finished
	queue_free()
