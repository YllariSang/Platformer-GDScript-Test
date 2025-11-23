extends Node2D

@export var open_offset: Vector2 = Vector2(0, -64)  # how far the door moves when opened
@export var transition_time: float = 0.25
@export var disable_collision_on_open: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var collider: CollisionShape2D = null

var closed_position: Vector2
var open_position: Vector2
var is_open: bool = false
var door_tween: Tween = null
var _temp_token: int = 0

func _ready() -> void:
	closed_position = position
	open_position = closed_position + open_offset
	# ensure collider reference exists
	if not collider:
		# try to find a CollisionShape2D anywhere under this node
		collider = _find_collision_shape(self)
		if not collider:
			push_warning("Door: missing CollisionShape2D descendant.")
		else:
			print("Door: found collider at %s" % [collider.get_path()])


func open() -> void:
	if is_open:
		return
	is_open = true
	print("Door: open() called; is_open set to true")
	if door_tween and door_tween.is_valid():
		door_tween.kill()
	door_tween = create_tween()
	door_tween.tween_property(self, "position", open_position, transition_time)
	if disable_collision_on_open and collider:
		# disable collider at the end of the tween
		door_tween.tween_callback(Callable(self, "_disable_collider_after_tween"))
	door_tween.play()


func close() -> void:
	if not is_open:
		return
	is_open = false
	print("Door: close() called; is_open set to false")
	if door_tween and door_tween.is_valid():
		door_tween.kill()
	# re-enable collider immediately so the door blocks while closing
	if disable_collision_on_open and collider:
		collider.disabled = false
	door_tween = create_tween()
	door_tween.tween_property(self, "position", closed_position, transition_time)
	door_tween.play()


func _disable_collider_after_tween() -> void:
	if collider:
		collider.disabled = true


func disable_collision_temporarily(duration: float) -> void:
	# Disable collision immediately and re-enable after `duration` seconds.
	if not collider:
		return
	# token to avoid overlapping calls restoring state prematurely
	_temp_token += 1
	var my_token = _temp_token
	var prev_collider_disabled = collider.disabled
	var prev_sprite_visible = true
	if sprite:
		prev_sprite_visible = sprite.visible

	collider.disabled = true
	if sprite:
		sprite.visible = false

	# Use a scene timer and await its timeout to re-enable
	var timer = get_tree().create_timer(duration)
	await timer.timeout
	# Only restore if this is still the latest temporary call
	if my_token != _temp_token:
		return
	# restore previous states
	if collider:
		collider.disabled = prev_collider_disabled
	if sprite:
		sprite.visible = prev_sprite_visible


func _find_collision_shape(node: Node) -> CollisionShape2D:
	for child in node.get_children():
		if child is CollisionShape2D:
			return child
		# recursive search
		if child.get_child_count() > 0:
			var found = _find_collision_shape(child)
			if found:
				return found
	# nothing found
	return null
