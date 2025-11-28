extends Area2D

@export var one_shot: bool = true
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
    # Connect body_entered using Godot 4 style
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if not body:
        return
    if body.is_in_group("player"):
        if body.has_method("set_checkpoint"):
            body.set_checkpoint(global_position)
        # Optionally mark this checkpoint as used and disable further triggers
        if one_shot:
            if collision_shape:
                collision_shape.disabled = true
            set_process(false)
            if has_node("Sprite2D"):
                $Sprite2D.modulate = Color(0.6, 0.6, 0.6)
