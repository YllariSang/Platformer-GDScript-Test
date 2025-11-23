extends CanvasLayer

@onready var coins_label: Label = $Control/CoinsLabel

func _ready() -> void:
	print("HUD: ready - looking for Game node")
	var cs = get_tree().get_current_scene()
	var game = null
	if cs and cs.has_node("Game"):
		game = cs.get_node("Game")
	# fallback to autoload
	if game == null:
		game = get_node_or_null("/root/Game")

	if game and game.has_method("get_coins"):
		coins_label.text = "Coins: %d" % game.get_coins()
	if game:
		print("HUD: connected to Game; connecting to coins_changed signal")
		game.connect("coins_changed", Callable(self, "_on_coins_changed"))
	else:
		push_warning("HUD: could not find Game node to connect to")

func _on_coins_changed(coins: int) -> void:
	print("HUD: coins_changed -> %d" % coins)
	if coins_label:
		print("HUD: label node = %s, old text = '%s'" % [coins_label.get_path(), coins_label.text])
		coins_label.text = "Coins: %d" % coins
		print("HUD: label updated, new text = '%s'" % coins_label.text)
	else:
		push_warning("HUD: coins_label is null when updating")
