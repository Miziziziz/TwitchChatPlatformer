extends KinematicBody2D

class_name Player
var player_name = ""
var velocity : Vector2
var gravity = 250

const BASE_JUMP_FORCE = 40
const MAX_JUMP_POWER = 10
const SLOW_DOWN_ON_WALL = 400

signal died

var blood_spray_obj = preload("res://Effects/BloodSpray.tscn")
onready var anim_player = $Graphics/AnimationPlayer

var facing_right = true

func _ready():
	var char_graphics = []
	for child in $Graphics.get_children():
		if "Character" in child.name:
			char_graphics.append(child)
			child.hide()
	char_graphics[randi() % char_graphics.size()].show()

func set_player_name(new_name: String):
	player_name = new_name
	$Label.text = new_name

func _physics_process(delta):
	velocity += Vector2.DOWN * gravity * delta
	velocity.y = move_and_slide(velocity, Vector2.UP).y
	
	for i in range(get_slide_count()):
		if get_slide_collision(i).collider.is_in_group("spikes"):
			died()
	
	if is_on_wall():
		velocity.x -= sign(velocity.x) * SLOW_DOWN_ON_WALL * delta
	
	if is_on_floor():
		anim_player.play("idle")
		velocity = Vector2(0.0, 1.0)
	else:
		anim_player.play("jump")

func jump(jump_right: bool, power: int):
	if !is_on_floor():
		return
	var move_vec = Vector2.UP
	if jump_right:
		move_vec += Vector2.RIGHT
		if !facing_right:
			flip()
	else:
		move_vec += Vector2.LEFT
		if facing_right:
			flip()
	move_vec = move_vec.normalized()
	velocity = move_vec * BASE_JUMP_FORCE * clamp(power, 1, MAX_JUMP_POWER)


func flip():
	facing_right = !facing_right
	$Graphics.scale.x *= -1

func died():
	var blood_spray_inst = blood_spray_obj.instance()
	get_tree().get_root().add_child(blood_spray_inst)
	blood_spray_inst.global_position = global_position
	emit_signal("died", player_name)

func get_player_name():
	return player_name

func set_won():
	$Label.modulate = Color.yellow
