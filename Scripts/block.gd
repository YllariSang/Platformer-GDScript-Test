extends CharacterBody2D

# Breakable block: breaks when hit by a player while that player is plunging
# and not crouched. Optionally checks downward velocity to avoid accidental
# breaks from gentle touches.
@onready var label: Label = $"../label"

# Minimum downward velocity (px/s) required to count as a break impact.
@export var min_downward_speed: float = 300.0

func _ready() -> void:
	if has_node("Hitbox"):
		$Hitbox.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))
	else:
		push_warning("Block: missing Hitbox Area2D child; block won't detect plunges.")

func _on_hitbox_body_entered(body: Node) -> void:
	# Only react to the player
	if not body.is_in_group("player"):
		return
	# Ensure the body exposes the expected state. Use safe `get()` when available.
	var plunging := false
	var crouched := false
	var down_speed := 0.0
	if body.has_method("get"):
		var pv = body.get("is_plunging")
		plunging = bool(pv)
		var cv = body.get("is_crouching")
		crouched = bool(cv)
		var vv = body.get("velocity")
		if vv:
			down_speed = float(vv.y)
	else:
		# Fallback: try direct access (may error if property missing)
		if "is_plunging" in body:
			plunging = bool(body.is_plunging)
		if "is_crouching" in body:
			crouched = bool(body.is_crouching)
		if "velocity" in body:
			down_speed = float(body.velocity.y)

	# Only break if the player is plunging, not crouched, and moving downward fast enough
	if plunging and not crouched and down_speed > min_downward_speed:
		# spawn simple break shards (Sprite2D) and a cleanup timer container so this
		# doesn't depend on this node after freeing.
		var root = get_parent() if get_parent() else get_tree().get_current_scene()
		if not root:
			root = get_tree().get_root()
		var sprite_tex: Texture2D = null
		var sprite_scale: Vector2 = Vector2.ONE
		if has_node("Sprite2D"):
			sprite_tex = $Sprite2D.texture
			sprite_scale = $Sprite2D.scale
		# container to hold shards and timer so we can free them later
		var container := Node2D.new()
		root.add_child(container)
		var shards: Array = []
		for i in range(6):
			var s := Sprite2D.new()
			if sprite_tex:
				s.texture = sprite_tex
				s.scale = sprite_scale
			s.global_position = global_position
			container.add_child(s)
			shards.append(s)
			var dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			if dir.length() == 0.0:
				dir = Vector2(0, -1)
			dir = dir.normalized()
			var dist = randf_range(12.0, 48.0)
			var tw = create_tween()
			tw.tween_property(s, "global_position", s.global_position + dir * dist, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(s, "modulate:a", 0.0, 0.45)
		# schedule cleanup of container (and shards)
		var timer := Timer.new()
		timer.wait_time = 0.6
		timer.one_shot = true
		container.add_child(timer)
		timer.start()
		timer.timeout.connect(Callable(container, "queue_free"))
		# play break sound if available: create AudioStreamPlayer2D in the container
		var sfx_path := "res://Assets/Audio/SFX/blockbreak.wav"
		if ResourceLoader.exists(sfx_path):
			var ap := AudioStreamPlayer2D.new()
			ap.stream = load(sfx_path)
			ap.global_position = global_position
			container.add_child(ap)
			ap.play()
		# trigger screen shake on the player if available
		if body and body.has_method("screen_shake"):
			body.screen_shake(10.0, 0.28)
		# finally, free this block
		queue_free()
