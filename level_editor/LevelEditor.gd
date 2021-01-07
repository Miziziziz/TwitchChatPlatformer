extends Node2D

const SAVE_FILES_DIRECTORY = "user://saved_levels/"

onready var player_ui = $World/CanvasLayer
onready var editor_ui = $EditorUI
onready var game_manager = $World
onready var command_input = $EditorUI/CommandInput
onready var ground_tile_button = $EditorUI/TilePalette/GridContainer/GroundTile
onready var spikes_tile_button = $EditorUI/TilePalette/GridContainer/SpikesTile
onready var moving_platform_tile_button = $EditorUI/TilePalette/GridContainer/MovingPlatformTile

onready var tilemap = $TileMap
onready var saved_levels_container = $EditorUI/LoadLevels/Panel/ScrollContainer/VBoxContainer
onready var save_level_button = $EditorUI/SaveButton
onready var save_level_name_input = $EditorUI/SaveButton/SaveFileInput
onready var confirm_save_level_dialog = $EditorUI/SaveButton/ConfirmOverwrite
onready var save_anim_player = $EditorUI/SaveButton/SaveSuccessfuly/AnimationPlayer
onready var enter_play_mode_button = $EditorUI/PlayButton
onready var exit_play_mode_button = $EditorUI/StopPlayButton
onready var widget_drawer = $WidgetDrawer

onready var start_point = $StartPoint
onready var end_point = $EndPoint

var in_edit_mode = true

var top_left_pos = Vector2()
var bot_right_pos = Vector2()

func _ready():
	set_edit_mode()
	command_input.connect("text_entered", self, "enter_input_command")
	ground_tile_button.connect("button_up", self, "select_ground_tile")
	spikes_tile_button.connect("button_up", self, "select_spikes_tile")
	moving_platform_tile_button.connect("button_up", self, "select_moving_platform_tile")
	
	top_left_pos = tilemap.world_to_map($TileMap/TopLeft.global_position)
	bot_right_pos = tilemap.world_to_map($TileMap/BotRight.global_position)
	
	var d = Directory.new()
	if not d.dir_exists(SAVE_FILES_DIRECTORY):
		d.make_dir(SAVE_FILES_DIRECTORY)
	update_saved_levels_list()

func set_play_mode():
	for child in editor_ui.get_children():
		child.hide()
	game_manager.enable()
	in_edit_mode = false
	cur_tile = TILES.NONE
	selected_sprite_display.hide()
	enter_play_mode_button.hide()
	exit_play_mode_button.show()
	command_input.show()
	widget_drawer.hide_widgets()
	ClockManager.reset()
	get_tree().call_group("moving_platforms", "play")
	$World/CanvasLayer/DeathDisplay.hide()

func set_edit_mode():
	for child in editor_ui.get_children():
		child.show()
	game_manager.disable()
	in_edit_mode = true
	selected_sprite_display.show()
	selected_sprite_display.texture = null
	enter_play_mode_button.show()
	exit_play_mode_button.hide()
	widget_drawer.draw_widgets()
	get_tree().call_group("instanced", "queue_free")
	get_tree().call_group("moving_platforms", "pause")

func enter_input_command(command_text: String):
	game_manager.parse_chat_input(SettingsManager.channel_name, command_text, true)
	command_input.text = ""

enum TILES {NONE, GROUND, SPIKES, MOVING_PLATFORM}
var cur_tile = TILES.NONE
onready var selected_sprite_display = $SelectedSpriteDisplay
const GROUND_TILE_ID = 1
var moving_platform_obj = preload("res://Environment/MovingPlatform.tscn")
var spike_obj = preload("res://Environment/Spikes.tscn")
var all_spikes_placed = {}
var all_moving_platforms_placed = {}

var last_x = 9999
var last_y = 9999

func set_tile_none():
	cur_tile = TILES.NONE
	selected_sprite_display.texture = null
	ground_tile_button.pressed = false
	spikes_tile_button.pressed = false
	moving_platform_tile_button.pressed = false
	
func select_spikes_tile():
	if cur_tile == TILES.SPIKES:
		set_tile_none()
		return
	cur_tile = TILES.SPIKES
	selected_sprite_display.texture = spikes_tile_button.icon

func select_ground_tile():
	if cur_tile == TILES.GROUND:
		set_tile_none()
		return
	cur_tile = TILES.GROUND
	selected_sprite_display.texture = ground_tile_button.icon

func select_moving_platform_tile():
	if cur_tile == TILES.MOVING_PLATFORM:
		set_tile_none()
		return
	cur_tile = TILES.MOVING_PLATFORM
	selected_sprite_display.texture = moving_platform_tile_button.icon

var grabbed_obj : Node2D
func _process(delta):
	if !in_edit_mode:
		return
	widget_drawer.draw_widgets()
	var tilepos_hovering_over = tilemap.world_to_map(get_global_mouse_position())
	var snapped_map_pos = tilemap.map_to_world(tilepos_hovering_over) + Vector2(8, 8)
	selected_sprite_display.global_position = snapped_map_pos
	var x := int(round(tilepos_hovering_over.x))
	var y := int(round(tilepos_hovering_over.y))
	
	if Input.is_action_just_pressed("place_tile"):
		for movable in get_tree().get_nodes_in_group("movable_in_editor"):
			if get_global_mouse_position().distance_squared_to(movable.global_position) < 16 * 16:
				grabbed_obj = movable
				grabbed_obj.global_position = snapped_map_pos
				return
	
	if Input.is_action_pressed("place_tile") and is_instance_valid(grabbed_obj):
		grabbed_obj.global_position = snapped_map_pos
	
	if Input.is_action_just_released("place_tile"):
		grabbed_obj = null
	
	if Input.is_action_just_pressed("delete_tile"):
		for movable in get_tree().get_nodes_in_group("movable_in_editor"):
			if get_global_mouse_position().distance_squared_to(movable.global_position) < 16 * 16:
				if movable.get_parent().is_in_group("moving_platforms"):
					movable.get_parent().queue_free()
				return
	if x >= top_left_pos.x and x <= bot_right_pos.x and y >= top_left_pos.y and y <= bot_right_pos.y:
		if y != last_y or x != last_x:
			if Input.is_action_pressed("place_tile"):
				place_tile(x, y)
		if Input.is_action_pressed("delete_tile"):
			delete_tile(x, y)

func place_tile(x: int, y: int):
	if cur_tile != TILES.NONE:
		delete_tile(x, y)
	if cur_tile == TILES.SPIKES:
		place_spike(x, y)
	elif cur_tile == TILES.GROUND:
		place_ground_tile(x, y)
	elif cur_tile == TILES.MOVING_PLATFORM:
		place_moving_platform(x, y)
	last_x = x
	last_y = y

func place_spike(x: int, y: int):
	var spike_inst = spike_obj.instance()
	all_spikes_placed[get_id_from_coords(x, y)] = spike_inst
	get_tree().get_root().add_child(spike_inst)
	spike_inst.global_position = tilemap.map_to_world(Vector2(x, y)) + Vector2(8,8)
	
	var left_tile_taken = tilemap.get_cell(x - 1, y) >= 0
	var right_tile_taken = tilemap.get_cell(x + 1, y) >= 0
	var top_tile_taken = tilemap.get_cell(x, y - 1) >= 0
	var bot_tile_taken = tilemap.get_cell(x, y + 1) >= 0
	
	if !bot_tile_taken: # default rotation
		if left_tile_taken:
			spike_inst.global_rotation = deg2rad(90)
		elif right_tile_taken:
			spike_inst.global_rotation = deg2rad(-90)
		elif top_tile_taken:
			spike_inst.global_rotation = deg2rad(180)

func place_moving_platform(x: int, y: int):
	var moving_platform_inst = moving_platform_obj.instance()
	all_moving_platforms_placed[get_id_from_coords(x, y)] = moving_platform_inst
	moving_platform_inst.global_position = tilemap.map_to_world(Vector2(x, y)) + Vector2(8,8)
	get_tree().get_root().add_child(moving_platform_inst)
	moving_platform_inst.pause()
	return moving_platform_inst

func place_ground_tile(x: int, y: int):
	tilemap.set_cell(x, y, GROUND_TILE_ID)
	tilemap.update_bitmask_area(Vector2(x, y))
	if y == to_int(top_left_pos.y):
		for i in range(8):
			place_ground_tile(x, y - 1 - i)

func delete_tile(x: int, y: int):
	tilemap.set_cell(x, y, -1)
	tilemap.update_bitmask_area(Vector2(x, y))
	var spike_id = get_id_from_coords(x, y)
	if spike_id in all_spikes_placed:
		all_spikes_placed[spike_id].queue_free()
		all_spikes_placed.erase(spike_id)

func get_id_from_coords(x: int, y: int):
	return str(x) + "," + str(y)

func clear_map():
	var start_x = int(round(top_left_pos.x))
	var end_x = int(round(bot_right_pos.x))
	var start_y = int(round(top_left_pos.y))
	var end_y = int(round(bot_right_pos.y))
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			delete_tile(x, y)
	for spike_id in all_spikes_placed:
		all_spikes_placed[spike_id].queue_free()
	get_tree().call_group("moving_platforms", "queue_free")

func update_saved_levels_list():
	for child in saved_levels_container.get_children():
		child.queue_free()
	for save_file_name in get_list_of_save_file_names():
		var new_button = Button.new()
		new_button.rect_min_size.y = 20
		new_button.text = save_file_name
		new_button.connect("button_up", self, "load_level", [save_file_name])
		saved_levels_container.add_child(new_button)

var last_save_file_attempted_loading = ""
func force_save():
	save_level(last_save_file_attempted_loading)

func attempt_save():
	var save_file_name = save_level_name_input.text
	if save_file_name == "":
		return
	var save_file_path = save_file_name_to_path(save_file_name)
	var saved_level = File.new()
	if saved_level.file_exists(save_file_path):
		last_save_file_attempted_loading = save_file_name
		confirm_save_level_dialog.show()
	else:
		save_level(save_file_name)

func copy_level_data_to_clipboard():
	OS.set_clipboard(to_json(get_level_data()))

func load_level_from_clipboard():
	var clipboard = OS.get_clipboard()
	if not validate_json(clipboard):
		set_level_data(parse_json(clipboard))

func save_level(save_file_name: String):
	var save_file_path = save_file_name_to_path(save_file_name)
	var save_game = File.new()
	save_game.open(save_file_path, File.WRITE)
	save_game.store_line(to_json(get_level_data()))
	save_game.close()
	save_anim_player.play("fade_out")
	update_saved_levels_list()

func get_level_data():
	var ground_tiles_data = []
	var start_x = int(round(top_left_pos.x))
	var end_x = int(round(bot_right_pos.x))
	var start_y = int(round(top_left_pos.y))
	var end_y = int(round(bot_right_pos.y))
	for y in range(start_y, end_y+1):
		for x in range(start_x, end_x+1):
				if tilemap.get_cell(x, y) >= 0:
					ground_tiles_data.append({"x" : x, "y" : y})
	
	var spikes_data = []
	for spike in all_spikes_placed:
		var data = {}
		var spike_obj = all_spikes_placed[spike]
		var map_pos = tilemap.world_to_map(spike_obj.global_position)
		data.x = to_int(map_pos.x)
		data.y = to_int(map_pos.y)
		spikes_data.append(data)
	
	var moving_platforms_data = []
	for moving_platform in all_moving_platforms_placed:
		var mp = all_moving_platforms_placed[moving_platform]
		if is_instance_valid(mp):
			moving_platforms_data.append(mp._save())
	
	var level_data = {
		"ground_tiles_data" : ground_tiles_data,
		"spikes_data" : spikes_data,
		"moving_platforms_data" : moving_platforms_data,
		"start_point" : {"x": start_point.global_position.x, "y": start_point.global_position.y},
		"end_point" : {"x": end_point.global_position.x, "y": end_point.global_position.y},
	}
	return level_data

func load_level(save_file_name: String):
	var save_file_path = save_file_name_to_path(save_file_name)
	var saved_level = File.new()
	var loaded_data = {}
	if saved_level.file_exists(save_file_path):
		saved_level.open(save_file_path, File.READ)
		loaded_data = parse_json(saved_level.get_line())
	else:
		saved_level.close()
		return
	saved_level.close()
	
	set_level_data(loaded_data)
	save_level_name_input.text = save_file_name

func set_level_data(level_data):
	if level_data == null:
		return
	clear_map()
	if "ground_tiles_data" in level_data:
		for ground_tile_data in level_data.ground_tiles_data:
			place_ground_tile(ground_tile_data.x, ground_tile_data.y)
	if "spikes_data" in level_data:
		for spike_data in level_data.spikes_data:
			place_spike(spike_data.x, spike_data.y)
	if "start_point" in level_data:
		start_point.global_position = Vector2(level_data.start_point.x, level_data.start_point.y)
	if "end_point" in level_data:
		end_point.global_position = Vector2(level_data.end_point.x, level_data.end_point.y)
	if "moving_platforms_data" in level_data:
		for moving_platform_data in level_data.moving_platforms_data:
			place_moving_platform(0, 0)._load(moving_platform_data)

func save_file_name_to_path(save_file_name: String):
	return SAVE_FILES_DIRECTORY + save_file_name + ".level"

func to_int(val: float):
	return int(round(val))

func get_list_of_save_files() -> Array:
	var save_files = []
	var dir = Directory.new()
	if dir.open(SAVE_FILES_DIRECTORY) == OK:
		dir.list_dir_begin()
		var save_file_name = dir.get_next()
		while save_file_name != "":
			if !dir.current_is_dir():
				save_files.append(SAVE_FILES_DIRECTORY + save_file_name)
			save_file_name = dir.get_next()
	
	save_files.sort_custom(self, "compare_dates_modified")
	return save_files

func get_list_of_save_file_names() -> Array:
	var save_file_names = []
	for save_file in get_list_of_save_files():
		save_file_names.append(get_file_name_from_save_file_path(save_file))
	return save_file_names

func compare_dates_modified(file_path_a: String, file_path_b: String):
	return File.new().get_modified_time(file_path_a) > File.new().get_modified_time(file_path_b)

func get_file_name_from_save_file_path(file_path: String):
	return file_path.get_file().trim_suffix("."+file_path.get_extension())

