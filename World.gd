extends Gift

onready var player_obj = preload("res://Player/Player.tscn")
var all_players = {}
var players_who_won = {}
const MAX_PLAYERS = 20
const CANT_REJOIN_FOR_TIME = 10.0

onready var player_counter = $CanvasLayer/PlayerCounter
onready var player_died_display = $CanvasLayer/DeathDisplay
func _ready() -> void:
	connect("cmd_no_permission", self, "no_permission")
	connect("chat_message", self, "parse_chat_input")
	connect_to_twitch()
	yield(self, "twitch_connected")
	
	# Login using your username and an oauth token.
	# You will have to either get a oauth token yourself or use
	# https://twitchapps.com/tokengen/
	# to generate a token with custom scopes.
	var file = File.new()
	file.open("res://config.json", file.READ)
	var dict = parse_json(file.get_as_text())
	file.close()
	
	authenticate_oauth(dict.account_name, dict.oauth_token)
	if(yield(self, "login_attempt") == false):
	  print("Invalid username or token.")
	  return
	join_channel(dict.channel_name)
	for winzone in get_tree().get_nodes_in_group("winzone"):
		winzone.connect("player_won", self, "add_winning_player")

func parse_chat_input(sender_data: SenderData, message: String):
	message = message.to_lower()
	if message.begins_with("join") and !sender_data.user in all_players and all_players.size() < MAX_PLAYERS and !player_died_recently(sender_data.user):
		add_new_player(sender_data.user)
	elif sender_data.user in all_players:
		if message.begins_with("reset"):
			reset_player(sender_data.user)
		else:
			run_player_command(sender_data.user, message)

func add_new_player(player_name: String):
	var player_inst = player_obj.instance()
	get_tree().get_root().add_child(player_inst)
	player_inst.global_position = get_node("../StartPoint").global_position
	all_players[player_name] = player_inst
	player_inst.set_player_name(player_name)
	if player_name in players_who_won:
		player_inst.set_won()
	player_inst.connect("died", self, "remove_player")
	update_player_counter()

func reset_player(player_name: String):
	all_players[player_name].global_position = get_node("../StartPoint").global_position

func run_player_command(player_name: String, player_command: String):
	var player_ref : Player = all_players[player_name]
	var jump_right = false
	var jump_power = 1
	
	var p_c = player_command.split("_")
	
	if p_c.size() >= 2:
		var first_char : String = p_c[0]
		if first_char == "r":
			jump_right = true
		elif first_char == "l":
			jump_right = false
		else:
			return
		
		if p_c[1].is_valid_integer():
			jump_power = int(p_c[1])
		else:
			return
		player_ref.jump(jump_right, jump_power)

var dead_players = {}
func remove_player(player_name: String):
	var player_ref: Player = all_players[player_name]
	player_ref.disconnect("died", self, "remove_player")
	player_ref.queue_free()
	all_players.erase(player_name)
	dead_players[player_name] = OS.get_ticks_msec() / 1000.0
	update_player_counter()
	player_died_display.say_player_died(player_name)

func player_died_recently(player_name: String):
	if !player_name in dead_players:
		return false
	if MAX_PLAYERS - all_players.size() >= 5:
		return false
	var time_since_died = OS.get_ticks_msec() / 1000.0 - dead_players[player_name] 
	if time_since_died > CANT_REJOIN_FOR_TIME:
		return false
	return true
	
func update_player_counter():
	player_counter.text = "Player Count: " + str(all_players.size())
	player_counter.text += "\nMax Players: " + str(MAX_PLAYERS)
	update_player_list()

func update_player_list():
	var s = "Player List:\n"
	var i = 0
	for player in all_players:
		var player_name = player
		if player_name in players_who_won:
			player_name = "[color=#%s]%s[/color]" % [Color.yellow.to_html(), player_name]
		if i % 2 == 0:
			s += player_name + "\n"
		else:
			s += player_name + "       "
		i += 1
	$CanvasLayer/PlayerList.bbcode_text = s

func add_winning_player(player_name: String):
	players_who_won[player_name] = ""
	all_players[player_name].set_won()
	update_player_list()
