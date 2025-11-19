extends Control

signal start_game
signal open_options

@export var menu_theme: Theme
@export var bg_texture: Texture2D
@export var play_scene: PackedScene = preload("res://Scenes/main.tscn")

var background: TextureRect = null
var play_btn: Button = null
var options_btn: Button = null
var quit_btn: Button = null

func _ready() -> void:
	# locate nodes robustly in case the scene file was imported with different naming
	background = _find_texturerect_recursive(self)
	play_btn = _find_button_by_text_recursive(self, "Play")
	options_btn = _find_button_by_text_recursive(self, "Options")
	quit_btn = _find_button_by_text_recursive(self, "Quit")

	if not background:
		push_warning("Menu: Background node not found; background skin won't be applied.")
	if not play_btn or not options_btn or not quit_btn:
		push_warning("Menu: One or more buttons not found; button signals won't be connected.")

	apply_skin()

	if play_btn:
		play_btn.connect("pressed", Callable(self, "_on_play_pressed"))
	if options_btn:
		options_btn.connect("pressed", Callable(self, "_on_options_pressed"))
	if quit_btn:
		quit_btn.connect("pressed", Callable(self, "_on_quit_pressed"))

func apply_skin() -> void:
	if menu_theme:
		theme = menu_theme
	if bg_texture and background:
		background.texture = bg_texture
	# make sure background expands to fill the control
	if background:
		background.expand = true
		background.stretch_mode = TextureRect.STRETCH_SCALE


func _find_button_by_text_recursive(node: Node, txt: String) -> Button:
	if node is Button and str(node.text) == txt:
		return node
	for child in node.get_children():
		var found = _find_button_by_text_recursive(child, txt)
		if found:
			return found
	return null


func _find_texturerect_recursive(node: Node) -> TextureRect:
	if node is TextureRect:
		return node
	for child in node.get_children():
		var found = _find_texturerect_recursive(child)
		if found:
			return found
	return null

func _on_play_pressed() -> void:
	if play_scene:
		# Some Godot builds/environments may not expose SceneTree.change_scene_to.
		# Instantiate the PackedScene and swap it in as the current scene instead.
		if play_scene is PackedScene:
			var new_scene = play_scene.instantiate()
			var old_scene = get_tree().current_scene
			get_tree().root.add_child(new_scene)
			get_tree().current_scene = new_scene
			if old_scene and old_scene != new_scene:
				old_scene.queue_free()
		elif typeof(play_scene) == TYPE_STRING:
			# support passing a path string
			get_tree().change_scene_to_file(str(play_scene))
		else:
			push_warning("Menu: play_scene is not a PackedScene or path; cannot change scene.")
	else:
		emit_signal("start_game")

func _on_options_pressed() -> void:
	emit_signal("open_options")

func _on_quit_pressed() -> void:
	get_tree().quit()
