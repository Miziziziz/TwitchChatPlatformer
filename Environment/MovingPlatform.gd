extends KinematicBody2D

var cur_time = 0.0

onready var start_pos = $StartPos.global_position
onready var end_pos = $EndPos.global_position

var pause_time = 1.0
var in_between_time = (ClockManager.MAX_TIME - 2 * pause_time) / 2.0

func _ready():
	global_position = start_pos

func _physics_process(delta):
	cur_time += delta
	if cur_time >= 0.0 and cur_time < pause_time:
		global_position = start_pos
	elif cur_time >= pause_time and cur_time < pause_time + in_between_time:
		var t = (cur_time - pause_time) / in_between_time
		global_position = start_pos.linear_interpolate(end_pos, t)
	elif cur_time >= pause_time + in_between_time and cur_time < 2*pause_time + in_between_time:
		global_position = end_pos
	else:
		var t = (cur_time - 2*pause_time - in_between_time) / in_between_time
		#print("cur_time: %s val to sub: %s t: %s" % [cur_time, 2*pause_time + in_between_time, t])
		global_position = end_pos.linear_interpolate(start_pos, t)

func update_time(new_time: int):
	cur_time = float(new_time)
