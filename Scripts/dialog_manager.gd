extends CanvasLayer

signal dialogue_started(text: String)
signal dialogue_finished()

@onready var panel := get_node_or_null("Panel")
var _label_node = null
var _prev_left_pressed := false

func _ready() -> void:
	# Try both RichTextLabel and plain Label under Panel
	if panel:
		_label_node = panel.get_node_or_null("RichTextLabel")
		if _label_node == null:
			_label_node = panel.get_node_or_null("Label")
		panel.visible = false

	print("DialogManager: ready; panel=", panel != null, " label=", _label_node != null, " label_type=", typeof(_label_node))

	# If the panel wasn't present in the scene, try to load the dialog UI scene and add it.
	if panel == null:
		var scene_path := "res://Scenes/dialog_ui.tscn"
		var packed := ResourceLoader.load(scene_path)
		if packed:
			var inst = packed.instantiate()
			add_child(inst)
			# search for Panel under the newly added instance
			panel = _find_node_by_name_recursive(inst, "Panel")
			if panel:
				_label_node = panel.get_node_or_null("RichTextLabel")
				if _label_node == null:
					_label_node = panel.get_node_or_null("Label")
				panel.visible = false
				print("DialogManager: loaded dialog UI from ", scene_path)
		else:
			print("DialogManager: could not load dialog UI scene at ", scene_path)

func show_dialogue(text: String, typing_speed := 0.0, disable_player_input := true) -> void:
	# Display dialog with optional typing effect (seconds per character).
	if panel == null or _label_node == null:
		print("DialogManager: cannot show dialogue - panel or label missing (panel=", panel, ", label=", _label_node, ")")
		return

	print("DialogManager: show_dialogue() called; typing_speed=", typing_speed, " text=", text)

	# Determine whether to disable player input for this dialogue
	var disable_input := disable_player_input
	var players := []
	if disable_input:
		# If players exist in the scene, disable their input so they stop acting.
		players = get_tree().get_nodes_in_group("player")
		for p in players:
			if p:
				# Prefer a conservative pause that preserves action timers if available
				if p.has_method("pause_for_dialogue"):
					p.pause_for_dialogue()
				elif p.has_method("set_input_enabled"):
					p.set_input_enabled(false)

	emit_signal("dialogue_started", text)

	panel.visible = true

	# Clear previous text
	if _label_node.has_method("clear"):
		_label_node.clear()
	else:
		_label_node.text = ""

	var is_rich := _label_node is RichTextLabel
	if is_rich:
		_label_node.bbcode_enabled = true

	if typing_speed > 0.0:
		var built := ""
		for i in range(text.length()):
			built += text[i]
			if _label_node.has_method("append_text"):
				_label_node.append_text(text[i])
			else:
				_label_node.text = built
			await get_tree().create_timer(typing_speed).timeout
	else:
		if _label_node.has_method("append_text"):
			_label_node.append_text(text)
		else:
			_label_node.text = text

	# Wait for player confirm
	await _wait_for_accept()

	panel.visible = false
	emit_signal("dialogue_finished")

	# Re-enable player input (only if we disabled it)
	if disable_input:
		for p2 in players:
			if p2:
				# Prefer a conservative resume if available
				if p2.has_method("resume_after_dialogue"):
					p2.resume_after_dialogue()
				elif p2.has_method("set_input_enabled"):
					p2.set_input_enabled(true)

func _wait_for_accept() -> void:
	# Wait until either keyboard confirm is pressed or the user clicks/touches anywhere.
	while true:
		await get_tree().process_frame
		# Keyboard/confirm
		if Input.is_action_just_pressed("ui_accept"):
			return

		# Mouse left-button just pressed (button id 1)
		var cur_left := Input.is_mouse_button_pressed(1 as MouseButton)
		if cur_left and not _prev_left_pressed:
			_prev_left_pressed = cur_left
			return
		_prev_left_pressed = cur_left


# Note: panel-local gui input handling removed; we now detect clicks/touches globally in _wait_for_accept().


func _find_node_by_name_recursive(node: Node, target_name: String) -> Node:
	if node == null:
		return null
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node_by_name_recursive(child, target_name)
		if found:
			return found
	return null
