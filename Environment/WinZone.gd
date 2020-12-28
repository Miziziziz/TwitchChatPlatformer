extends Area2D

var fireworks_obj = preload("res://Effects/FireWorks.tscn")

signal player_won

func _ready():
	connect("body_entered", self, "on_body_enter")

func on_body_enter(body: PhysicsBody2D):
	var fireworks_inst = fireworks_obj.instance()
	get_tree().get_root().add_child(fireworks_inst)
	fireworks_inst.global_position = $FireworksSpawnPoint.global_position
	if body.has_method("get_player_name"):
		emit_signal("player_won", body.get_player_name())
