extends Node2D

@export var bounce_velocity: float = -700.0
@export var only_when_crouched: bool = true

@onready var area: Area2D = $Area2D
@onready var sprite: Node = $Sprite2D
var sfx_player: AudioStreamPlayer2D = null
@export var sfx_name: String = "Pickup"
var _sfx_extensions: Array = [".wav", ".ogg", ".flac"]
var _tracked_bodies: Array = []
var _body_callbacks: Dictionary = {}

func _ready() -> void:
	if area:
		area.connect("body_entered", Callable(self, "_on_body_entered"))
		area.connect("body_exited", Callable(self, "_on_body_exited"))
	# Ensure an AudioStreamPlayer2D exists under the sprite for spring SFX
	if sprite:
		if sprite.has_node("AudioStreamPlayer2D"):
			sfx_player = sprite.get_node("AudioStreamPlayer2D") as AudioStreamPlayer2D
		else:
			sfx_player = AudioStreamPlayer2D.new()
			sprite.add_child(sfx_player)

	# Try to resolve and preload the SFX by name (tries common extensions)
	if sfx_player and sfx_name:
		var found_path: String = ""
		for ext in _sfx_extensions:
			var p = "res://Assets/Audio/SFX/%s%s" % [sfx_name, ext]
			if ResourceLoader.exists(p):
				found_path = p
				break
		if found_path != "":
			sfx_player.stream = load(found_path)

func _on_body_entered(body: Node) -> void:
	if not body:
		return
	# Only react to the player group
	if not body.is_in_group("player"):
		return
	# Optionally require crouch on enter
	if only_when_crouched and not body.is_crouching:
		# Still track the body so we can respond if it crouches while overlapping
		_track_body(body)
		return

	# Apply the bounce immediately and track the body
	_apply_bounce(body)
	_track_body(body)


func _track_body(body: Node) -> void:
	# Connect to player's crouch_toggled signal so we can react while overlapping
	if body in _tracked_bodies:
		return
	_tracked_bodies.append(body)
	if body.has_signal("crouch_toggled"):
		# bind the body as an extra argument so the callback knows which body sent it
		var cb: Callable = Callable(self, "_on_body_crouch_toggled").bind(body)
		body.connect("crouch_toggled", cb)
		_body_callbacks[body] = cb


func _play_bounce_anim() -> void:
	if not sprite:
		return
	# short bounce: squash then restore
	var orig_scale: Vector2 = sprite.scale
	var squash_scale: Vector2 = orig_scale * Vector2(1.15, 0.8)
	var t = create_tween()
	t.tween_property(sprite, "scale", squash_scale, 0.08)
	t.tween_property(sprite, "scale", orig_scale, 0.12)


func _apply_bounce(body: Node) -> void:
	if not body:
		return
	# Apply bounce by setting the player's vertical velocity
	if "velocity" in body:
		body.velocity.y = bounce_velocity
	else:
		body.set("velocity", Vector2(0, bounce_velocity))

	# Nudge the player slightly upward to ensure physics separation
	if body.has_method("move_and_slide") and body.is_on_floor():
		body.global_position.y -= 2

	# Play bounce visual and SFX
	_play_bounce_anim()
	if sfx_player and sfx_player.stream:
		sfx_player.play()


func _on_body_exited(body: Node) -> void:
	# Stop tracking and disconnect any signal connection we made
	if body in _tracked_bodies:
		_tracked_bodies.erase(body)
		if body in _body_callbacks:
			var cb2: Callable = _body_callbacks[body]
			if body.is_connected("crouch_toggled", cb2):
				body.disconnect("crouch_toggled", cb2)
			_body_callbacks.erase(body)


func _on_body_crouch_toggled(is_crouching: bool, body: Node) -> void:
	# Called when a tracked body toggles crouch while overlapping the spring area.
	if not body or not body.is_in_group("player"):
		return
	# If the spring requires crouch, only bounce when the player crouches (true)
	if only_when_crouched and not is_crouching:
		return
	# Apply bounce when the player enters crouch while overlapping
	if is_crouching:
		_apply_bounce(body)
