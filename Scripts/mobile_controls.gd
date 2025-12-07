extends CanvasLayer

# This script only toggles visibility for mobile; actual input is driven by TouchScreenButton nodes.

func _ready() -> void:
	visible = OS.get_name() in ["Android", "iOS"]
