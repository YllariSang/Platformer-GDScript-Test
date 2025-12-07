extends Control

@onready var completion_label: Label = $VBoxContainer/CompletionLabel
@onready var credits_text: RichTextLabel = $VBoxContainer/ScrollContainer/CreditsText
@onready var ending_label: Label = $VBoxContainer/EndingLabel
@onready var ending_art: TextureRect = $VBoxContainer/EndingArt
@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer
@onready var music_player: AudioStreamPlayer = $Music
@onready var back_button: Button = $BackButton

func _ready() -> void:
	Transition.fade_in()
	var am = _get_audio_manager()
	if am:
		am.stop()
	_display_credits()
	_hide_scrollbars()
	_start_autoscroll()
	# Show a back button on mobile/touch devices for exiting credits
	back_button.visible = DisplayServer.is_touchscreen_available()
	back_button.pressed.connect(_return_to_menu)

func _display_credits() -> void:
	var percentage = Game.get_submission_percentage()
	var fragments = Game.fragments_submitted
	var total = Game.total_fragments
	
	# Update completion status
	completion_label.text = "Fragments Submitted: %d/%d (%.1f%%)" % [fragments, total, percentage]
	
	# Determine ending based on percentage
	var ending_text = ""
	var ending_texture: Texture2D
	var music_path := ""
	
	if percentage >= 100.0:
		ending_text = "GOOD ENDING - To illuminate the night, this artifact must go..."
		ending_texture = load("res://Assets/good.png")
		music_path = "res://Assets/Audio/OST/GoodEnding.mp3"
	else:
		ending_text = "NEUTRAL ENDING - You completed the journey. Though you have to give yourself up to illuminate the night. 
		Maybe you should've collected every fragment."
		ending_texture = load("res://Assets/neutral.png")
		music_path = "res://Assets/Audio/OST/NeutralEnding.mp3"
	
	ending_label.text = ending_text
	ending_art.texture = ending_texture
	_play_music(music_path)
	
	# Add your credits here
	credits_text.text = """
	[center][b]GAME CREDITS[/b][/center]

	[center][b]Development Director:[/b][/center]
	[center]CRUZ, SHAWN ASHLEIGH YLLARIS[/center]
	
	[center][b]Project Management:[/b][/center]
	[center]FAZLIOGLU, DENIZ NICOLAI[/center]
	[center]PADILLA, NASH[/center]

	[center][b]Programming:[/b][/center]
	[center]GDScript[/center]

	[center][b]Special Thanks:[/b][/center]
	[center]To YOU![/center]

	[center]Press ESC to return to menu[/center]
	"""

func _play_music(path: String) -> void:
	if path == "":
		return
	if music_player.playing:
		music_player.stop()
	music_player.stream = load(path)
	music_player.play()

func _start_autoscroll() -> void:
	# Wait a frame so layout is ready, then tween the scroll to the bottom.
	await get_tree().process_frame
	scroll_container.scroll_vertical = 0
	var target := scroll_container.get_v_scroll_bar().max_value
	# Auto duration: 40 px per second, clamp to a minimum so it always animates.
	var duration: float = max(6.0, target / 40.0)
	var tw := create_tween()
	tw.tween_property(scroll_container, "scroll_vertical", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _hide_scrollbars() -> void:
	# Hide the bar nodes while keeping scrolling functional
	await get_tree().process_frame
	var vbar := scroll_container.get_v_scroll_bar()
	if vbar:
		vbar.visible = false
	var hbar := scroll_container.get_h_scroll_bar()
	if hbar:
		hbar.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_menu()

func _return_to_menu() -> void:
	var am = _get_audio_manager()
	if am:
		am.play("menu")
	Transition.fade_and_change_scene("res://Scenes/menu.tscn")

func _get_audio_manager():
	return get_node_or_null("/root/AudioManager")
