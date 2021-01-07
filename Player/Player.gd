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
var has_won = false

const SKINS_FOLDER_PATH = "res://Player/skins/"

var command_queue = []
var jump_count = 0

var last_time_grounded = 0.0
var last_time_jumped = 0.0
var was_grounded = true
var snap = Vector2.DOWN * 2

func set_player_name(new_name: String):
	player_name = new_name
	$Label.text = new_name

func _physics_process(delta):
	velocity += Vector2.DOWN * gravity * delta
	velocity.y = move_and_slide_with_snap(velocity, snap, Vector2.UP).y
	for i in range(get_slide_count()):
		if get_slide_collision(i).collider.is_in_group("spikes"):
			died()
	
	if is_on_wall():
		velocity.x -= sign(velocity.x) * SLOW_DOWN_ON_WALL * delta

	if is_on_floor():
		if !was_grounded:
			snap = Vector2.DOWN * 2
		last_time_grounded = get_cur_time()
		if command_queue.size() > 0 and command_queue.back().time < 0:
			run_next_command()
		else:
			velocity = Vector2(0.0, 1.0)
		anim_player.play("idle")
	else:
		anim_player.play("jump")
	
	was_grounded = is_on_floor()

func jump(jump_right: bool, power: int):
	snap = Vector2.ZERO
	last_time_jumped = get_cur_time()
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
	$AfkTimer.start()
	jump_count += 1

func add_to_jump_queue(jump_right: bool, power: int, time=-1):
	command_queue.push_front({
		"jump_right": jump_right,
		"power": power,
		"time": time,
		})

func flip():
	facing_right = !facing_right
	$Graphics.scale.x *= -1

var dead = false
func died():
	if dead:
		return
	dead = true
	var blood_spray_inst = blood_spray_obj.instance()
	get_tree().get_root().add_child(blood_spray_inst)
	blood_spray_inst.global_position = global_position
	emit_signal("died", player_name)

func get_player_name():
	return player_name

func set_won():
	has_won = true
	$Label.modulate = Color.yellow

#var custom_offsets = {
#	"boxes.png": Vector2(0.0, 7.5),
#	"cat-sprite.png": Vector2(0.0, 10.0),
#	"skeleton.png": Vector2(0.0, 10.0),
#	"Miz_Goku.png": Vector2(0.0, 12.0),
#}

func set_skin(skin_index: int):
	var files = []
	var dir = Directory.new()
	dir.open(SKINS_FOLDER_PATH)
	dir.list_dir_begin()

	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif file.ends_with(".png"):
			files.append(file)

	dir.list_dir_end()
	
	if skin_index < 0:
		skin_index = randi()
	skin_index = posmod(skin_index, files.size())
	var file_name = files[skin_index]
	var sprite : Sprite = $Graphics/Sprite
	sprite.texture = load(SKINS_FOLDER_PATH + file_name)
	if file_name.begins_with("large"):
		sprite.scale = Vector2.ONE * 0.75
	sprite.offset.y = -sprite.texture.get_size().y / 2.0
#	if file_name in custom_offsets:
#		$Graphics/Sprite.position += custom_offsets[file_name]

func reset():
	jump_count = 0
	command_queue = []
	velocity = Vector2.ZERO

func update_time(cur_time):
	if command_queue.size() > 0 and posmod(command_queue.back().time, ClockManager.MAX_TIME) == ClockManager.cur_time:
		run_next_command()

func run_next_command():
	if get_cur_time() - last_time_grounded < 0.05:
		var command = command_queue.pop_back()
		jump(command.jump_right, command.power)

func get_cur_time():
	return OS.get_ticks_msec()/1000.0
