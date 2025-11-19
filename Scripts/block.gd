extends CharacterBody2D

# Breakable block: breaks when hit by a player while that player is plunging
# and not crouched. Optionally checks downward velocity to avoid accidental
# breaks from gentle touches.

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
		# optional: spawn particles/sound here
		queue_free()
