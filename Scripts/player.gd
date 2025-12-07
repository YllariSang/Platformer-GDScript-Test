extends CharacterBody2D

signal crouch_toggled(new_state: bool)

var is_dashing = false
var can_dash = true
var dash_direction: Vector2 = Vector2.ZERO
var input_enabled: bool = true

const DASH_SPEED = 1200.0
const DASH_DURATION = 0.12
const DASH_COOLDOWN = 0.3

var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0

const SPEED = 300.0
@export var JUMP_VELOCITY: float = -500.0
@export var JUMP_VELOCITY_CROUCH: float = -350.0

# Variable jump (hold to jump higher)
@export var JUMP_HOLD_TIME: float = 0.14
@export var JUMP_HOLD_STRENGTH: float = -700.0
@export var JUMP_HOLD_STRENGTH_CROUCH: float = -350.0

@export var COYOTE_TIME: float = 0.12
@export var JUMP_BUFFER_TIME: float = 0.12

var is_holding_jump: bool = false
var jump_hold_time_left: float = 0.0
var coyote_time_left: float = 0.0
var jump_buffer_time_left: float = 0.0
var _jump_was_crouched: bool = false

var is_crouching: bool = false
var crouch_tween: Tween = null

# Optional collision shapes to swap when crouching. If your `player.tscn` has
# a `CollisionShape2D` for standing and another named `CrouchCollisionShape2D`,
# the script will toggle them automatically.
@onready var standing_collision: CollisionShape2D = null
@onready var crouch_collision: CollisionShape2D = null
@onready var sprite_node: Node = null
var original_sprite_scale: Vector2 = Vector2.ONE
var facing_right: bool = true
var is_playing_crouch_anim: bool = false
@export var crouch_sprite_offset_y: float = 0.0
const CROUCH_SCALE = 0.5
const CROUCH_TRANSITION = 0.12
const CROUCH_STATE_NONE: int = 0
const CROUCH_STATE_ENTERING: int = 1
const CROUCH_STATE_IN: int = 2
const CROUCH_STATE_EXITING: int = 3
var crouch_state: int = CROUCH_STATE_NONE
var original_collision_position: Vector2 = Vector2.ZERO
var original_sprite_position: Vector2 = Vector2.ZERO
var prev_is_crouching: bool = false
var original_shape_size: Vector2 = Vector2.ZERO
@onready var camera_node: Camera2D = null
var original_camera_zoom: Vector2 = Vector2.ONE
var original_collision_scale: Vector2 = Vector2.ONE
@export var camera_scale_follow_sprite: bool = true
@export var camera_scale_smoothing: float = 8.0
@export var camera_min_scale_x: float = 0.01

# Plunge: fast downward attack. Cannot be used while crouched.
@export var PLUNGE_SPEED: float = 1200.0
@export var PLUNGE_DURATION: float = 0.12
@export var PLUNGE_COOLDOWN: float = 0.6

var is_plunging: bool = false
var plunge_time_left: float = 0.0
var plunge_cooldown_left: float = 0.0
var can_plunge: bool = true

# Last safe position (used for respawning after death)
var last_safe_position: Vector2 = Vector2.ZERO
@onready var sfx_player: AudioStreamPlayer2D = null
# Optional explicit checkpoint set by `Checkpoint` nodes. When present,
# this will be preferred over `last_safe_position` when respawning.
var checkpoint_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false

var _input_was_enabled: bool = true
var _paused_for_dialogue: bool = false

func _ready() -> void:
	# Try to find mobile controls (optional)
	# Not required when using TouchScreenButton actions
	if has_node("CollisionShape2D"):
		standing_collision = $CollisionShape2D
		# record original shape size if it's a RectangleShape2D
		if standing_collision.shape and standing_collision.shape is RectangleShape2D:
			var rect = standing_collision.shape as RectangleShape2D
			original_shape_size = rect.size
		# record original collision position
		original_collision_position = standing_collision.position
		# record original collision node scale
		original_collision_scale = standing_collision.scale
	if has_node("CrouchCollisionShape2D"):
		crouch_collision = $CrouchCollisionShape2D

	if has_node("Sprite2D"):
		sprite_node = $Sprite2D
		# Node2D has `scale` and `position` so this works for Sprite2D and AnimatedSprite2D
		original_sprite_scale = sprite_node.scale
		original_sprite_position = sprite_node.position

	# Ensure player is in the `player` group so pressure plates detect it
	add_to_group("player")
	# Debug: print group membership and collision info so triggers can detect the player
	print("[Player] ready - name=", name, "global_pos=", global_position)
	if has_method("get_groups"):
		print("[Player] groups=", get_groups())
	print("[Player] is_in_group('player')=", is_in_group("player"))
	# Collision layer/mask may be on the physics body
	if "collision_layer" in self:
		print("[Player] collision_layer=", collision_layer, "collision_mask=", collision_mask)
	if has_node("CollisionShape2D"):
		print("[Player] has CollisionShape2D at", $CollisionShape2D.position)
	# initialize respawn point to current position
	last_safe_position = global_position
	if has_node("Camera2D"):
		camera_node = $Camera2D
		# Ensure this camera is the active camera so Parallax nodes respond to movement
		if camera_node and not camera_node.is_current():
			camera_node.make_current()
		original_camera_zoom = camera_node.zoom

	# ensure an AudioStreamPlayer2D exists under the Sprite2D to play simple SFX
	if has_node("Sprite2D"):
		if $Sprite2D.has_node("AudioStreamPlayer2D"):
			sfx_player = $Sprite2D.get_node("AudioStreamPlayer2D") as AudioStreamPlayer2D
		else:
			# create one so we can play sounds from the player
			var ap = AudioStreamPlayer2D.new()
			$Sprite2D.add_child(ap)
			sfx_player = ap


# Helper functions for mobile + keyboard input
func _get_move_axis() -> float:
	return Input.get_axis("left", "right")

func _is_jump_just_pressed() -> bool:
	return Input.is_action_just_pressed("ui_accept")

func _is_jump_pressed() -> bool:
	return Input.is_action_pressed("ui_accept")

func _is_jump_just_released() -> bool:
	return Input.is_action_just_released("ui_accept")

func _is_dash_just_pressed() -> bool:
	return Input.is_action_just_pressed("dash")

func _is_crouch_just_pressed() -> bool:
	return Input.is_action_just_pressed("crouch")


func _physics_process(delta: float) -> void:
	# Physics always runs so the player continues to be affected by gravity
	# and other physics while input may be disabled by external systems.

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		# Cap fall velocity to prevent infinite buildup when stuck
		velocity.y = min(velocity.y, 1000.0)

	# Update dash timers
	if dash_time_left > 0.0:
		dash_time_left -= delta
		if dash_time_left <= 0.0:
			is_dashing = false
			dash_cooldown_left = DASH_COOLDOWN

	if dash_cooldown_left > 0.0:
		dash_cooldown_left -= delta
		if dash_cooldown_left <= 0.0:
			can_dash = true

	# Update plunge timers
	if plunge_time_left > 0.0:
		plunge_time_left -= delta
		if plunge_time_left <= 0.0:
			is_plunging = false
			plunge_cooldown_left = PLUNGE_COOLDOWN

	if plunge_cooldown_left > 0.0:
		plunge_cooldown_left -= delta
		if plunge_cooldown_left <= 0.0:
			can_plunge = true

	# Update coyote time (grace period after stepping off edge)
	if is_on_floor():
		coyote_time_left = COYOTE_TIME
	else:
		coyote_time_left = max(coyote_time_left - delta, 0.0)

	# Update jump buffer timer
	if jump_buffer_time_left > 0.0:
		jump_buffer_time_left -= delta
		if jump_buffer_time_left < 0.0:
			jump_buffer_time_left = 0.0

	# Handle jump hold (variable jump height)
	if input_enabled and not Game.suppress_jump and is_holding_jump and jump_hold_time_left > 0.0 and _is_jump_pressed() and not is_on_floor():
		var strength = JUMP_HOLD_STRENGTH
		if _jump_was_crouched:
			strength = JUMP_HOLD_STRENGTH_CROUCH
		# apply extra upward force while holding (strength is negative)
		velocity.y += strength * delta
		jump_hold_time_left -= delta
	else:
		# if hold timed out or button released, stop holding
		is_holding_jump = false
		jump_hold_time_left = 0.0

	# Handle jump input with coyote time and jump buffering.
	if input_enabled and not Game.suppress_jump and _is_jump_just_pressed():
		# If we can jump immediately (on floor or within coyote window), do it.
		if is_on_floor() or coyote_time_left > 0.0:
			_do_jump()
		else:
			# buffer the jump input until we land within the buffer window
			jump_buffer_time_left = JUMP_BUFFER_TIME

	# If a buffered jump exists and we now can jump, consume it
	if jump_buffer_time_left > 0.0 and (is_on_floor() or coyote_time_left > 0.0):
		_do_jump()
		jump_buffer_time_left = 0.0

	# If jump button released early, cut the upward velocity so jump is smaller
	if input_enabled and not Game.suppress_jump and _is_jump_just_released():
		if is_holding_jump:
			is_holding_jump = false
			jump_hold_time_left = 0.0
			if velocity.y < 0.0:
				velocity.y *= 0.6

	# Handle crouch input (toggle). Requires InputMap action `crouch`.
	# Toggle crouch on press so player can hold or lock crouch.
	if input_enabled and _is_crouch_just_pressed():
		is_crouching = not is_crouching
		if is_crouching:
			crouch_state = CROUCH_STATE_ENTERING
		else:
			crouch_state = CROUCH_STATE_EXITING
		# Notify listeners (e.g. springs) that crouch state changed
		emit_signal("crouch_toggled", is_crouching)
	# Note: collision will be scaled based on sprite scale via the tween.
	# No immediate enabling/disabling of separate crouch shapes here.

	# If crouch state changed, start a smooth transition tween for sprite & collision
	if is_crouching != prev_is_crouching:
		_start_crouch_tween(is_crouching)
		prev_is_crouching = is_crouching

	# Apply visual scaling for crouch if a sprite node exists
	# immediate fallback: ensure correct scale if no tween system available
	if not sprite_node:
		# nothing to do
		pass

	# Plunge input (requires InputMap action `plunge`). Allow while crouched; must be airborne.
	if input_enabled and Input.is_action_just_pressed("plunge") and can_plunge and not is_on_floor():
		_start_plunge()


	# Handle dash input (requires an InputMap action named "dash")
	if input_enabled and _is_dash_just_pressed() and can_dash:
		# Determine dash direction from player input or facing
		var input_dir := Input.get_axis("left", "right")
		var dir_x := 0.0
		if input_dir != 0.0:
			dir_x = input_dir
		# prefer the last facing direction when no input is provided
		elif facing_right != null:
			dir_x = 1.0 if facing_right else -1.0
		elif velocity.x != 0.0:
			dir_x = sign(velocity.x)
		else:
			dir_x = 1.0

		dash_direction = Vector2(dir_x, 0)
		is_dashing = true
		can_dash = false
		dash_time_left = DASH_DURATION
		# update facing to match dash direction
		_update_facing_from_dir(dir_x)
		# Optional: cancel vertical velocity to make dash feel snappier
		velocity.y = 0.0
		# play dash animation immediately if present
		if not is_playing_crouch_anim:
			if sprite_node is AnimatedSprite2D:
				(sprite_node as AnimatedSprite2D).play("dash")
			elif has_node("AnimationPlayer"):
				$AnimationPlayer.play("dash")

			# play dash sfx if available
			if sfx_player and ResourceLoader.exists("res://Assets/Audio/SFX/dash.wav"):
				sfx_player.stream = load("res://Assets/Audio/SFX/dash.wav")
				sfx_player.play()

	# Movement: normal movement is disabled while dashing
	if is_dashing:
		velocity.x = dash_direction.x * DASH_SPEED
	# Plunge: fast vertical downwards movement while in air
	elif is_plunging:
		velocity.y = PLUNGE_SPEED
	else:
		# Get the input direction and handle the movement/deceleration.
		# When input is disabled we keep processing physics but ignore player controls.
		if input_enabled:
			var direction := _get_move_axis()
			if direction:
				velocity.x = direction * SPEED
				# update facing when player provides horizontal input
				_update_facing_from_dir(direction)
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
		else:
			# keep current horizontal velocity (or gently decelerate)
			velocity.x = move_toward(velocity.x, 0, SPEED * 0.25)

	move_and_slide()

	# If we were plunging and hit the floor, stop and start cooldown
	if is_plunging and is_on_floor():
		is_plunging = false
		plunge_time_left = 0.0
		plunge_cooldown_left = PLUNGE_COOLDOWN
		can_plunge = false

	# Update sprite animation each frame
	_update_animation()

	# Record last safe position when standing on the floor (simple checkpoint)
	if is_on_floor():
		last_safe_position = global_position


func _start_crouch_tween(crouch: bool) -> void:
	# Kill any running crouch tween to avoid conflicts/flicker
	if crouch_tween and crouch_tween.is_valid():
		crouch_tween.kill()
	var tween = create_tween()
	crouch_tween = tween
	# target values for sprite
	var target_scale = original_sprite_scale * CROUCH_SCALE if crouch else original_sprite_scale
	var target_sprite_pos = original_sprite_position
	# compute target collision scale & position early so we can align the sprite bottom to the collision bottom
	# Determine which collision node/values should be used as the "active" hitbox
	var target_collision_scale: Vector2
	var target_collision_pos: Vector2
	if crouch and crouch_collision and crouch_collision.shape:
		# If a separate crouch collision shape exists, use its designed position/scale
		target_collision_pos = crouch_collision.position
		target_collision_scale = crouch_collision.scale
	else:
		# Otherwise compute a scaled standing collision and shift it so the bottom stays aligned
		target_collision_scale = original_collision_scale * CROUCH_SCALE if crouch else original_collision_scale
		var delta_y = 0.0
		if original_shape_size != Vector2.ZERO:
			var current_scale_y = original_collision_scale.y
			var target_scale_y = target_collision_scale.y
			delta_y = original_shape_size.y * (current_scale_y - target_scale_y) * 0.5
		target_collision_pos = original_collision_position + Vector2(0, delta_y) if crouch else original_collision_position
	if sprite_node:
		# if this is a `Sprite2D` we can use its texture size to compute the bottom offset
		if sprite_node is Sprite2D and sprite_node.texture:
			var tex_size: Vector2 = sprite_node.texture.get_size()
			var sprite_h: float = tex_size.y
			# Try to respect the sprite pivot if available; otherwise assume centered pivot
			var pivot_y: float = 0.0
			if "pivot_offset" in sprite_node:
				pivot_y = sprite_node.pivot_offset.y
			elif "centered" in sprite_node and sprite_node.centered:
				pivot_y = sprite_h * 0.5
			# compute bottom relative to node origin and align that to collision bottom
			var bottom_local: float = (sprite_h - pivot_y) * target_scale.y
			target_sprite_pos.y = target_collision_pos.y - bottom_local + crouch_sprite_offset_y
		else:
			# Fallback: use the original heuristic but allow manual offset
			var tex_size2: Vector2 = Vector2.ZERO
			if "texture" in sprite_node and sprite_node.texture:
				tex_size2 = sprite_node.texture.get_size()
			var sprite_h2: float = tex_size2.y if tex_size2 != Vector2.ZERO else (original_sprite_scale.y * 32.0)
			var bottom_local2: float = (sprite_h2 * target_scale.y * 0.5)
			target_sprite_pos.y = target_collision_pos.y - bottom_local2 + crouch_sprite_offset_y
		# animate sprite
		tween.tween_property(sprite_node, "scale", target_scale, CROUCH_TRANSITION)
		tween.tween_property(sprite_node, "position", target_sprite_pos, CROUCH_TRANSITION)

	# Ensure facing is correct immediately when crouch starts so the crouch pose is directional.
	# Prefer current input direction, otherwise use the last known facing.
	var input_dir := Input.get_axis("left", "right")
	if input_dir != 0.0:
		_update_facing_from_dir(input_dir)
	else:
		# apply last known facing so crouch doesn't snap to default direction
		_update_facing_from_dir(1.0 if facing_right else -1.0)

	# Play crouch animation while the visual tween is active, then restore.
	if sprite_node is AnimatedSprite2D:
		(sprite_node as AnimatedSprite2D).play("crouch")
		is_playing_crouch_anim = true
		# restore animation after the tween finishes (only for this tween)
		_restore_after_crouch_tween(tween)
	elif has_node("AnimationPlayer"):
		$AnimationPlayer.play("crouch")
		is_playing_crouch_anim = true
		_restore_after_crouch_tween(tween)

	# play crouch sfx if present
	if sfx_player and ResourceLoader.exists("res://Assets/Audio/SFX/crouch.wav"):
		sfx_player.stream = load("res://Assets/Audio/SFX/crouch.wav")
		sfx_player.play()

	# Tween camera zoom so visual player size on screen remains consistent
	if camera_node:
		var safe_target_scale_x = target_scale.x if target_scale.x != 0 else CROUCH_SCALE
		var target_zoom = original_camera_zoom * (original_sprite_scale.x / safe_target_scale_x)
		if not crouch:
			target_zoom = original_camera_zoom
		tween.tween_property(camera_node, "zoom", target_zoom, CROUCH_TRANSITION)

	# handle collision by switching/scaling the collision node immediately so physics reacts this frame.
	if standing_collision and standing_collision.shape:
		if crouch_collision and crouch_collision.shape:
			# Use the separate shape if available. Compute sprite alignment from the active shape.
			if crouch:
				# activate crouch collision; leave its authored position/scale intact
				_enable_crouch_shape()
			else:
				# restore standing collision; use standing collision's position/scale
				_disable_crouch_shape()
			# Note: target_collision_pos already reflects the active shape used above
		else:
			# No separate shape: apply the computed target scale/position to the standing collision
			standing_collision.scale = target_collision_scale
			standing_collision.position = target_collision_pos

	# No separate crouch collision swapping: collision follows sprite scale.

	# start the tween
	tween.play()


func _enable_crouch_shape() -> void:
	if standing_collision and crouch_collision:
		standing_collision.disabled = true
		crouch_collision.disabled = false


func _disable_crouch_shape() -> void:
	if standing_collision and crouch_collision:
		standing_collision.disabled = false
		crouch_collision.disabled = true


func _start_plunge() -> void:
	# Programmatic start of the plunge.
	is_plunging = true
	can_plunge = false
	plunge_time_left = PLUNGE_DURATION
	# cancel any dash in progress
	if is_dashing:
		is_dashing = false
		dash_time_left = 0.0
		dash_cooldown_left = DASH_COOLDOWN
		can_dash = false
	# force downward velocity
	velocity.y = PLUNGE_SPEED

	# play plunge animation immediately if present
	if not is_playing_crouch_anim:
		if sprite_node is AnimatedSprite2D:
			(sprite_node as AnimatedSprite2D).play("plunge")
		elif has_node("AnimationPlayer"):
			$AnimationPlayer.play("plunge")

	# optional: small plunge sound if you add one later


func plunge() -> void:
	# Public callable API: start a plunge if allowed. No effect while crouched.
	if not can_plunge:
		return
	_start_plunge()


func _do_jump() -> void:
	# Shared logic to begin a jump. Records crouch state for hold strength.
	_jump_was_crouched = is_crouching
	if is_crouching:
		# cancel any ongoing crouch tween so we don't fight the current transform
		if crouch_tween and crouch_tween.is_valid():
			crouch_tween.kill()
		# keep visual crouch and let collision follow sprite scale (no immediate restore)
		prev_is_crouching = is_crouching

	# smaller base jump when crouched
	velocity.y = JUMP_VELOCITY_CROUCH if _jump_was_crouched else JUMP_VELOCITY
	# begin jump hold window
	is_holding_jump = true
	jump_hold_time_left = JUMP_HOLD_TIME
	# consume coyote window so we don't double-trigger
	coyote_time_left = 0.0

	# play jump animation immediately if present
	if not is_playing_crouch_anim:
		if sprite_node is AnimatedSprite2D:
			(sprite_node as AnimatedSprite2D).play("jump")
		elif has_node("AnimationPlayer"):
			$AnimationPlayer.play("jump")

	# play jump sfx if available
	if sfx_player and ResourceLoader.exists("res://Assets/Audio/SFX/Jump.wav"):
		sfx_player.stream = load("res://Assets/Audio/SFX/Jump.wav")
		sfx_player.play()


func _update_animation() -> void:
	if not sprite_node:
		return
	# If the crouch animation is playing, it has absolute priority and we don't override it.
	if is_playing_crouch_anim:
		return

	var anim := "idle"
	# Priority order
	if is_plunging:
		anim = "plunge"
	elif is_dashing:
		anim = "dash"
	elif not is_on_floor():
		anim = "jump" if velocity.y < 0 else "fall"
	elif abs(velocity.x) > 10.0:
		# walking animation should be used even when crouching (crouch-walk == walk)
		anim = "walk"
	elif is_crouching:
		anim = "crouch"
	else:
		anim = "idle"

	# AnimatedSprite2D support
	if sprite_node is AnimatedSprite2D:
		var a := sprite_node as AnimatedSprite2D
		if a.animation != anim:
			a.play(anim)
	# AnimationPlayer support (state machine named animations)
	elif has_node("AnimationPlayer"):
		var ap := $AnimationPlayer
		if ap.current_animation != anim:
			ap.play(anim)


func _update_facing_from_dir(dir_x: float) -> void:
	# Only update when a meaningful horizontal direction is provided
	if dir_x == 0.0:
		return
	var should_face_right: bool = dir_x > 0.0
	if sprite_node is Sprite2D:
		(sprite_node as Sprite2D).flip_h = not should_face_right
	else:
		# Fallback: invert local X scale while preserving magnitude (works with tweens)
		var cur_scale: Vector2 = sprite_node.scale
		cur_scale.x = abs(cur_scale.x) * (1.0 if should_face_right else -1.0)
		sprite_node.scale = cur_scale
	# record facing state
	facing_right = should_face_right


func set_input_enabled(enabled: bool) -> void:
	# Public API for external systems to enable/disable player input.
	input_enabled = enabled
	if not enabled:
		# stop horizontal movement and cancel dashes/plunges, but keep vertical velocity
		velocity.x = 0.0
		is_dashing = false
		dash_time_left = 0.0
		is_plunging = false
		plunge_time_left = 0.0


func pause_for_dialogue() -> void:
	# Disable player controls for dialogue without canceling dash/plunge timers.
	if _paused_for_dialogue:
		return
	_input_was_enabled = input_enabled
	# Stop horizontal movement immediately so player doesn't slide away during dialogue.
	velocity.x = 0.0
	# Disable input so player cannot issue new actions, but DO NOT modify dash/plunge
	# state variables or cooldowns so transient actions continue their timing.
	input_enabled = false
	_paused_for_dialogue = true


func resume_after_dialogue() -> void:
	# Restore input state previously saved by `pause_for_dialogue()`.
	if not _paused_for_dialogue:
		return
	input_enabled = _input_was_enabled
	_paused_for_dialogue = false


func _restore_after_crouch_tween(tween: Tween) -> void:
	# Wait for this tween to finish, then restore animation state if it's still the active crouch tween.
	# This prevents earlier/overlapped tweens from stomping newer ones.
	await tween.finished
	if crouch_tween != tween:
		return
	# If we finished entering crouch, mark state and end the crouch animation (freeze pose)
	if is_crouching:
		crouch_state = CROUCH_STATE_IN
		# If moving, switch to walk (we reuse walk while crouch-walking). Otherwise stop the crouch animation so it doesn't loop.
		if abs(velocity.x) > 10.0:
			# clear the playing flag then update so walk can play
			is_playing_crouch_anim = false
			_update_animation()
		else:
			if sprite_node is AnimatedSprite2D:
				(sprite_node as AnimatedSprite2D).stop()
				is_playing_crouch_anim = false
			elif has_node("AnimationPlayer"):
				$AnimationPlayer.stop()
				is_playing_crouch_anim = false
		# keep collision/visual crouch until uncrouched
	else:
		# finished uncrouching
		crouch_state = CROUCH_STATE_NONE
		_update_animation()
		is_playing_crouch_anim = false


func _process(delta: float) -> void:
	# Keep camera zoom in proportion to the sprite's visual scale.
	# Skips while a crouch tween is active to avoid fighting the tween.
	if not camera_scale_follow_sprite:
		return
	if not camera_node or not sprite_node:
		return
	if crouch_tween and crouch_tween.is_valid():
		return

	# Use the absolute X scale so a negative sprite scale (used for flipping)
	# does not produce a negative camera zoom which flips the whole view.
	var cur_x: float = abs(sprite_node.scale.x)
	var current_scale_x: float = cur_x if cur_x != 0.0 else camera_min_scale_x
	var ratio: float = float(original_sprite_scale.x) / current_scale_x
	var target_zoom: Vector2 = original_camera_zoom * ratio
	var t: float = clamp(camera_scale_smoothing * delta, 0.0, 1.0)
	camera_node.zoom = camera_node.zoom.lerp(target_zoom, t)


func set_checkpoint(pos: Vector2) -> void:
	# Explicit API other nodes can call to set the player's respawn point.
	checkpoint_position = pos
	has_checkpoint = true
	print("[Player] checkpoint set to:", checkpoint_position)


func die() -> void:
	# Debug: announce death and target respawn
	var preferred = last_safe_position
	if has_checkpoint:
		preferred = checkpoint_position
	print("[Player] die() called. Preferred respawn:", preferred, " (checkpoint=", has_checkpoint, ")")
	# Choose a safe respawn position (try checkpoint or last safe, then nudge up if needed)
	var target_pos: Vector2 = _find_safe_respawn(preferred)
	# Teleport player back to resolved safe position and reset transient state
	global_position = target_pos
	velocity = Vector2.ZERO
	is_dashing = false
	dash_time_left = 0.0
	dash_cooldown_left = 0.0
	can_dash = true
	is_plunging = false
	plunge_time_left = 0.0
	plunge_cooldown_left = 0.0
	can_plunge = true
	is_holding_jump = false
	is_crouching = false
	# ensure animation state is refreshed
	_update_animation()


func _position_overlaps_danger(pos: Vector2) -> bool:
	# Uses direct space queries to see if the given position collides with any
	# bodies/areas on the `danger` collision layer (we set spikes to layer 1).
	# Returns true if any collision was found at the point.
	var dss = get_world_2d().direct_space_state
	# Try a point query first (small margin). If API signature differs on your
	# Godot version adjust accordingly.
	var params = PhysicsPointQueryParameters2D.new()
	params.position = pos
	# collision mask 1 checks layer 1 (spikes)
	params.collision_mask = 1
	var result = dss.intersect_point(params, 4)
	return result.size() > 0


func _find_safe_respawn(preferred: Vector2) -> Vector2:
	# If the preferred location overlaps a danger (spike), try to nudge upward
	# in small steps to find a nearby safe spot. If none found, fall back to
	# `preferred` and log a warning.
	if not _position_overlaps_danger(preferred):
		return preferred

	var attempt_pos = preferred
	var step = Vector2(0, -16) # move up 16 pixels each attempt
	var max_attempts = 12
	for i in range(max_attempts):
		attempt_pos += step
		if not _position_overlaps_danger(attempt_pos):
			print("[Player] found safe respawn after", i+1, "nudges")
			return attempt_pos

	# Last resort: try moving horizontally a bit as well
	for dx in [-16, 16, -32, 32]:
		var test_pos = preferred + Vector2(dx, -16)
		if not _position_overlaps_danger(test_pos):
			print("[Player] found safe respawn by horizontal nudge dx=", dx)
			return test_pos

	print("[Player] WARNING: could not find safe respawn near", preferred)
	return preferred


func _on_sprite_2d_animation_changed() -> void:
	pass # Replace with function body.


func screen_shake(intensity: float = 8.0, duration: float = 0.25, step: float = 0.02) -> void:
	# Simple camera shake that offsets the local camera position briefly.
	if not camera_node:
		return
	# Ensure randomness
	randomize()
	var original_offset: Vector2 = camera_node.offset
	var elapsed: float = 0.0
	while elapsed < duration:
		var rx = randf_range(-1.0, 1.0)
		var ry = randf_range(-1.0, 1.0)
		var rvec = Vector2(rx, ry)
		if rvec.length() == 0.0:
			rvec = Vector2(0, -1)
		camera_node.offset = original_offset + rvec.normalized() * (intensity * randf_range(0.5, 1.0))
		await get_tree().create_timer(step).timeout
		elapsed += step
	# restore
	camera_node.offset = original_offset
