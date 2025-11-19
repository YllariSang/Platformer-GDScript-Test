extends Area2D

# 0 = any body, 1 = must be crouched, 2 = must be standing
# Default to 0 so stepping on the plate (any player body) opens doors
@export var mode: int = 0
@export var door_path: NodePath = NodePath()
@export var disable_duration: float = 0.35
@export var close_delay: float = 0.0

signal pressed
signal released

var pressing_bodies := {} # map instance_id -> body
var is_pressed := false
var linked_door: Node = null
var _close_token: int = 0


func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

	# Try to resolve a linked door if a path is provided
	if door_path != NodePath():
		linked_door = get_node_or_null(door_path)
		if not linked_door:
			push_warning("PressurePlate: door_path set but node not found: %s" % [door_path])
		else:
			print("PressurePlate: linked door resolved: %s" % [linked_door.get_path()])
	else:
		print("PressurePlate: no door_path provided in inspector")
		# Try to auto-find a nearby door: look in parent for a node with open/close methods
		var p = get_parent()
		if p:
			for child in p.get_children():
				if child is Node and child.has_method("open") and child.has_method("close"):
					linked_door = child
					print("PressurePlate: auto-linked door to %s" % [linked_door.get_path()])
					break
		# if still not found, search the whole scene for a node named 'Door'
		if not linked_door:
				var root = get_tree().get_root()
				var found = _recursive_find_by_name(root, "Door")
				if found and found.has_method("open") and found.has_method("close"):
					linked_door = found
					print("PressurePlate: auto-linked door (search) to %s" % [linked_door.get_path()])
					# no need to break since _recursive_find_by_name returns the first match

func _on_body_entered(body: Node) -> void:
	# only consider player group bodies (optional: allow other bodies)
	if not body.is_in_group("player"):
		return

	# check condition
	if _meets_mode(body):
		pressing_bodies[body.get_instance_id()] = body
		_update_state()

func _on_body_exited(body: Node) -> void:
	var id = body.get_instance_id()
	if pressing_bodies.has(id):
		pressing_bodies.erase(id)
		_update_state()

func _meets_mode(body: Node) -> bool:
	# Safe check: assume your player has `is_crouching` var
	var crouched := false
	# try to read the property safely
	if body.has_method("get"):
		# `get()` returns property if it exists (otherwise returns null)
		var v = body.get("is_crouching")
		crouched = bool(v)
	else:
		# fallback (best-effort)
		crouched = false

	if mode == 0:
		return true
	elif mode == 1:
		return crouched
	else:
		return not crouched

func _update_state() -> void:
	var should_press = pressing_bodies.size() > 0
	if should_press and not is_pressed:
		is_pressed = true
		emit_signal("pressed")
		# debug
		print("PressurePlate: pressed; bodies=", pressing_bodies.keys())
		# auto-open linked door if provided
		if linked_door:
			# debug info about the linked door
			print("PressurePlate: linked_door present at %s" % [linked_door.get_path()])
			if linked_door.has_method("open"):
				print("PressurePlate: calling open() on linked door")
				linked_door.call("open")
			else:
				print("PressurePlate: linked door has no open() method")
			# also ask the door to temporarily disable collision so player can pass through
			if linked_door.has_method("disable_collision_temporarily"):
				linked_door.call("disable_collision_temporarily", disable_duration)
			else:
				print("PressurePlate: linked door has no disable_collision_temporarily() method")
		else:
			print("PressurePlate: no linked_door to call")
	elif not should_press and is_pressed:
		is_pressed = false
		emit_signal("released")
		# debug
		print("PressurePlate: released")
		# auto-close linked door if provided (optionally delayed)
		if linked_door and linked_door.has_method("close"):
			if close_delay > 0.0:
				_close_token += 1
				var my_token = _close_token
				var timer = get_tree().create_timer(close_delay)
				await timer.timeout
				# if token changed the plate was pressed again; abort close
				if my_token != _close_token:
					return
				# only close if still not pressed
				if not is_pressed:
					linked_door.call("close")
			else:
				linked_door.call("close")


func _recursive_find_by_name(node: Node, target_name: String) -> Node:
	# Depth-first search for a node with the given name
	for child in node.get_children():
		if child.name == target_name:
			return child
		if child.get_child_count() > 0:
			var found = _recursive_find_by_name(child, target_name)
			if found:
				return found
	return null
