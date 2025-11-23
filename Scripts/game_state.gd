extends Node

signal coins_changed(coins)

var coins: int = 0

func _ready() -> void:
    print("Game ready. coins=%d" % coins)

func add_coin(amount: int = 1) -> void:
    coins += amount
    print("Game: add_coin -> coins=%d" % coins)
    emit_signal("coins_changed", coins)

func get_coins() -> int:
    return coins

