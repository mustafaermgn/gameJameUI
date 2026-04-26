extends Node

var player_name: String = "Oyuncu"

signal coin_changed(new_amount)

var coins: int = 2000:
	set(value):
		if coins == value:
			return
		coins = value
		coin_changed.emit(coins)

func add_coins(amount: int):
	coins += amount
