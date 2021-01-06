extends Node

const MAX_TIME = 6
var cur_time = 1

func inc_time():
	cur_time += 1
	if cur_time >= MAX_TIME:
		cur_time = 0
	get_tree().call_group("timed", "update_time", cur_time)

func reset():
	cur_time = 0
	$Timer.start()
