extends Gift

onready var player_obj = preload("res://Player/Player.tscn")
var all_players = {}
var players_who_won = {}

var enabled = true

onready var player_counter = $CanvasLayer/PlayerCounter
onready var player_died_display = $CanvasLayer/DeathDisplay
func _ready() -> void:
	ClockManager.reset()
	update_player_list()
	connect("cmd_no_permission", self, "no_permission")
	connect("chat_message", self, "parse_chat_data")
	connect("whisper_message", self, "parse_chat_data")
	connect_to_twitch()
	yield(self, "twitch_connected")
	
	# Login using your username and an oauth token.
	# You will have to either get a oauth token yourself or use
	# https://twitchapps.com/tokengen/
	# to generate a token with custom scopes.
#	var file = File.new()
#	file.open("res://config.json", file.READ)
#	var dict = parse_json(file.get_as_text())
#	file.close()
	
	authenticate_oauth(SettingsManager.account_name, SettingsManager.oauth_token)
	if(yield(self, "login_attempt") == false):
	  print("Invalid username or token.")
	  return
	join_channel(SettingsManager.channel_name)
	for winzone in get_tree().get_nodes_in_group("winzone"):
		winzone.connect("player_won", self, "add_winning_player")

func parse_chat_data(sender_data: SenderData, message: String, override=false):
	parse_chat_input(sender_data.user, message, override)

func parse_chat_input(player_name: String, message: String, override=false):
	if !enabled and !override:
		return
	
	message = message.to_lower()
	if message.begins_with("join") and !player_name in all_players and (player_name == SettingsManager.channel_name or\
			 (all_players.size() < SettingsManager.max_players and !player_died_recently(player_name))):
		var msg = message.split(" ")
		var skin_index = -1
		if msg.size() > 1 and msg[1].is_valid_integer():
			skin_index = int(msg[1])
		add_new_player(player_name, skin_index)
	elif message.begins_with("exit"):
		remove_player(player_name)
	elif player_name in all_players:
		if message.begins_with("reset"):
			reset_player(player_name)
		else:
			run_player_command(player_name, message)

func _process(delta):
	if Input.is_action_just_pressed("exit"):
		SettingsManager.load_main_menu()

func add_new_player(player_name: String, skin_index=-1):
	var player_inst = player_obj.instance()
	get_tree().get_root().add_child(player_inst)
	player_inst.global_position = get_node("../StartPoint").global_position
	all_players[player_name] = player_inst
	player_inst.set_player_name(player_name)
	player_inst.set_skin(skin_index)
	if player_name in players_who_won:
		player_inst.set_won()
	player_inst.connect("died", self, "kill_player")
	update_player_counter()

func reset_player(player_name: String):
	all_players[player_name].global_position = get_node("../StartPoint").global_position
	all_players[player_name].reset()

func run_player_command(player_name: String, player_command: String):
	var player_ref : Player = all_players[player_name]
	var jump_right = false
	var jump_power = 1
	var jump_time = -1
	var p_c = player_command.split(" ")
	
	var has_time_command = false
	
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
		if p_c.size() >= 3:
			if p_c[2].is_valid_integer():
				jump_time = int(p_c[2])
				has_time_command = true
		player_ref.add_to_jump_queue(jump_right, jump_power, jump_time)
	if p_c.size() > 2:
		p_c.remove(0)
		p_c.remove(0)
		if has_time_command:
			p_c.remove(0)
		var new_cmd = ""
		for s in p_c:
			new_cmd += s + " "
		run_player_command(player_name, new_cmd)

var dead_players = {}
func kill_player(player_name: String):
	remove_player(player_name)
	player_died_display.say_player_died(player_name)

func remove_player(player_name: String):
	if !player_name in all_players:
		print('error player missing ', player_name)
		return
	var player_ref: Player = all_players[player_name]
	#player_ref.disconnect("died", self, "remove_player")
	player_ref.queue_free()
	all_players.erase(player_name)
	dead_players[player_name] = OS.get_ticks_msec() / 1000.0
	update_player_counter()

func player_died_recently(player_name: String):
	if !player_name in dead_players:
		return false
	if SettingsManager.max_players - all_players.size() >= 5:
		return false
	var time_since_died = OS.get_ticks_msec() / 1000.0 - dead_players[player_name] 
	if time_since_died > SettingsManager.rejoin_timer:
		return false
	return true
	
func update_player_counter():
	player_counter.text = "Player Count: " + str(all_players.size())
	player_counter.text += "\nMax Players: " + str(SettingsManager.max_players)
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

func update_winning_players_display():
	var s = "Winners[Move Count]\n"
	if players_who_won.size() == 0:
		s = ""
	var sorted_players_who_won = players_who_won.keys()
	sorted_players_who_won.sort_custom(self, "compare_winning_players")
	
	var i = 0
	for player_who_won in sorted_players_who_won:
		s += "%s[%s]\n" % [player_who_won, str(players_who_won[player_who_won])]
		i += 1
		if i > 20:
			break
	$CanvasLayer/Scoreboard.text = s

func compare_winning_players(player_name_a: String, player_name_b: String):
	   return players_who_won[player_name_a] < players_who_won[player_name_b]

func add_winning_player(player_name: String, jump_count: int):
	if not player_name in players_who_won or players_who_won[player_name] >= jump_count:
		players_who_won[player_name] = jump_count
	all_players[player_name].set_won()
	update_player_list()
	update_winning_players_display()

func reset_game():
	for player in all_players:
		remove_player(player)
		players_who_won = {}
	update_player_counter()
	update_winning_players_display()


func disable():
	enabled = false
	for child in $CanvasLayer.get_children():
		child.hide()

func enable():
	enabled = true
	for child in $CanvasLayer.get_children():
		child.show()
