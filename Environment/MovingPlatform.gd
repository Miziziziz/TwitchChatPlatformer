extends Node2D

var cur_time = 0.0

onready var platform = $Platform
onready var end_indicator = $EndPos
onready var start_pos = platform.global_position
onready var end_pos = end_indicator.global_position

var pause_time = 1.0
var in_between_time = (ClockManager.MAX_TIME - 2 * pause_time) / 2.0

func pause():
	platform.global_position = start_pos
	set_physics_process(false)

func play():
	start_pos = platform.global_position
	end_pos = end_indicator.global_position
	set_physics_process(true)

func _physics_process(delta):
	cur_time += delta
	if cur_time >= 0.0 and cur_time < pause_time:
		platform.global_position = start_pos
	elif cur_time >= pause_time and cur_time < pause_time + in_between_time:
		var t = (cur_time - pause_time) / in_between_time
		platform.global_position = start_pos.linear_interpolate(end_pos, t)
	elif cur_time >= pause_time + in_between_time and cur_time < 2*pause_time + in_between_time:
		platform.global_position = end_pos
	else:
		var t = (cur_time - 2*pause_time - in_between_time) / in_between_time
		#print("cur_time: %s val to sub: %s t: %s" % [cur_time, 2*pause_time + in_between_time, t])
		platform.global_position = end_pos.linear_interpolate(start_pos, t)

func update_time(new_time: int):
	cur_time = float(new_time)

func _save():
	return {
		"start_x" : platform.global_position.x,
		"start_y" : platform.global_position.y,
		"end_x" : end_indicator.global_position.x,
		"end_y" : end_indicator.global_position.y,
	}

func _load(data):
	platform.global_position.x = data.start_x
	platform.global_position.y = data.start_y
	end_indicator.global_position.x = data.end_x
	end_indicator.global_position.y = data.end_y
