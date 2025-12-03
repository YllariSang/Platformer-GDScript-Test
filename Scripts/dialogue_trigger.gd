extends Area2D

@export var dialogue_text: String = "Hello!"
@export var only_once: bool = true

signal triggered(text: String)

var _triggered: bool = false

func _ready() -> void:
	# Ensure the area is actively monitoring overlaps and has a sensible layer/mask.
	monitoring = true
	# default to layer 1 and mask 1 so it detects typical player bodies
	collision_layer = 1
	collision_mask = 1

	print("DialogueTrigger: ready at", global_position, "monitoring=", monitoring, "layer=", collision_layer, "mask=", collision_mask)
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if _triggered and only_once:
		return
	# Debug: always log entering bodies to help diagnose non-detection
	if body:
		var groups = []
		if body.has_method("get_groups"):
			groups = body.get_groups()
		print("DialogueTrigger: body_entered:", body.name, "pos=", str(body.global_position if "global_position" in body else "?"), "groups=", groups)

	# Detect player by group (player.gd already adds the player to 'player')
	if body and body.is_in_group("player"):
		print("DialogueTrigger: player entered at", body.global_position)

		# Try several places to find the DialogManager: autoload at /root, current scene, or anywhere in the tree.
		var dm = get_node_or_null("/root/DialogManager")
		if dm == null:
			var cs = get_tree().current_scene
			if cs and cs.has_node("DialogManager"):
				dm = cs.get_node("DialogManager")
		if dm == null:
			dm = _find_node_by_name_recursive(get_tree().root, "DialogManager")

		var did_fire: bool = false
		if dm and dm.has_method("show_dialogue"):
			print("DialogueTrigger: calling DialogManager.show_dialogue()")
			dm.show_dialogue(dialogue_text)
			did_fire = true
		else:
			print("DialogueTrigger: DialogManager not found; will emit signal instead")
			# Emit signal for other systems to listen (fallback)
			emit_signal("triggered", dialogue_text)
			did_fire = true

		# Only mark as triggered / free the node if we actually fired the dialogue
		if did_fire:
			_triggered = true
			if only_once:
				queue_free()


func _find_node_by_name_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node_by_name_recursive(child, target_name)
		if found:
			return found
	return null
