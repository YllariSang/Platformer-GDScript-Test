extends Area2D

# Script for spike Area2D: when the player touches the spike, call their die() method.
func _ready():
    # Ensure monitoring is enabled and mask is set so we detect the player
    monitoring = true
    collision_mask = 1
    collision_layer = 0
    print("[Spike] ready at", global_position, "mask=", collision_mask, "layer=", collision_layer)
    # Connect signal using a Callable to avoid ambiguity
    connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
    print("[Spike] body entered:", body)
    if body and body.is_in_group("player"):
        print("[Spike] hit player")
        # play a hit SFX at the spike's position if available
        var sfx_path := "res://Assets/Audio/SFX/spikehit1.wav"
        if ResourceLoader.exists(sfx_path):
            var root = get_tree().get_current_scene()
            if not root:
                root = get_tree().get_root()
            var ap := AudioStreamPlayer2D.new()
            ap.stream = load(sfx_path)
            ap.global_position = global_position
            root.add_child(ap)
            ap.play()
            var cleanup_t := Timer.new()
            cleanup_t.one_shot = true
            var sfx_len := 1.0
            if ap.stream and ap.stream.has_method("get_length"):
                sfx_len = ap.stream.get_length()
            cleanup_t.wait_time = sfx_len + 0.1
            root.add_child(cleanup_t)
            cleanup_t.start()
            cleanup_t.timeout.connect(Callable(ap, "queue_free"))
            cleanup_t.timeout.connect(Callable(cleanup_t, "queue_free"))

        if body.has_method("die"):
            body.die()
        else:
            print("[Spike] player has no die() method")
