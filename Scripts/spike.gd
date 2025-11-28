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
        if body.has_method("die"):
            body.die()
        else:
            print("[Spike] player has no die() method")
