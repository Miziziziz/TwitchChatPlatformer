extends Node

var max_players = 20
var rejoin_timer = 10.0

var account_name = ""
var channel_name = ""
var oauth_token = ""

const SETTINGS_SAVE_FILE_PATH = "user://settings.save"
const MAIN_MENU_SCENE = "res://main_menu/MainMenu.tscn"
var serializable_fields = [
	"max_players",
	"rejoin_timer",
	"account_name",
	"channel_name",
	"oauth_token",
]

var premade_levels = [
	"res://levels/World.tscn",
	"res://levels/World2.tscn",
	"res://levels/World3.tscn",
	"res://levels/World4.tscn",
	"res://levels/World5.tscn",
	"res://levels/World6.tscn",
	"res://levels/World7.tscn",
	"res://levels/World8.tscn",
	"res://levels/World9.tscn",
]

func _ready():
	initialize()

var initialized = false
func initialize():
	if initialized:
		return
	load_saved_settings()

func load_saved_settings():
	var save_file = File.new()
	if !save_file.file_exists(SETTINGS_SAVE_FILE_PATH):
		return
	save_file.open(SETTINGS_SAVE_FILE_PATH, File.READ)
	var saved_data = parse_json(save_file.get_as_text())
	for field in saved_data:
		set(field, saved_data[field])
	save_file.close()

func save_settings():
	var save_file = File.new()
	save_file.open(SETTINGS_SAVE_FILE_PATH, File.WRITE)
	var save_data = {}
	for field in serializable_fields:
		save_data[field] = get(field)
	save_file.store_line(to_json(save_data))
	save_file.close()

func load_main_menu():
	get_tree().call_group("instanced", "queue_free")
	get_tree().change_scene(MAIN_MENU_SCENE)

func load_premade_level(index: int):
	get_tree().change_scene(premade_levels[index])
