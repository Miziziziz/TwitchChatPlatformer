extends Node2D

var show_widgets = true

func hide_widgets():
	show_widgets = false
	update()

func draw_widgets():
	show_widgets = true
	update()

func _draw():
	if !show_widgets:
		return
	for movable in get_tree().get_nodes_in_group("movable_in_editor"):
		var pos = to_local(movable.global_position)
		draw_line(pos + Vector2.UP * 8, pos + Vector2.DOWN * 8, Color.green, 3)
		draw_line(pos + Vector2.RIGHT * 8, pos + Vector2.LEFT * 8, Color.blue, 3)
		draw_circle(pos, 4, Color.red)
		
	for mp in get_tree().get_nodes_in_group("moving_platforms"):
		var p_pos = to_local(mp.get_node("Platform").global_position)
		var e_pos = to_local(mp.get_node("EndPos").global_position)
		draw_line(p_pos, e_pos, Color.purple, 2)
		
