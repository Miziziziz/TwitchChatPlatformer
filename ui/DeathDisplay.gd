extends Label


func say_player_died(player_name: String):
	text = player_name + " has died!"
	show()
	$Timer.start()
