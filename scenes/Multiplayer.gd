extends Node2D

export var SOCKET_URL = "ws://localhost:3000"
var _client = WebSocketClient.new()
var other_players: Array = []

const player_type_list = ["Player", "BallPlayer"]

var _player = null;
var connected = false

var prev_x = 0;
var prev_y = 0;

var client_id: String
var current_level = null;

func _ready():
	_client.connect("connection_closed", self, "_on_connection_closed")
	_client.connect("connection_error", self, "_on_connection_closed")
	_client.connect("connection_established", self, "_on_connected")
	_client.connect("data_received", self, "_on_data")
	
	var err = _client.connect_to_url(SOCKET_URL)
	if (err != OK):
		print("unable to connect: ", err)
		set_process(false)

func _process(delta):
	_client.poll()
	
	if connected == true:
		update_player()
		update_other_players(delta)		

func update_player():
	if  is_instance_valid(_player) and _player.is_inside_tree():
		var current_position = _player.get_position()
		if prev_x != current_position.x or prev_y != current_position.y:
			_send({"newPosition" : {"x": current_position.x, "y": current_position.y}})
			prev_x = current_position.x
			prev_y = current_position.y
	else:
		get_player()

func update_other_players(delta):
	for player in other_players:
		if "position" in player.data:
			var x = player.data.position.x
			var y = player.data.position.y
			
			player.data.delta -= (delta * 1000);
			if (player.data.delta < 0):
				player.data.delta = 0;
				
			var d = (player.data.delta / 50)
			
			var xDis = (x - get_node(player.id).position.x)
			var yDis = (y - get_node(player.id).position.y)
			
			var position = Vector2(x - (xDis * d), y - (yDis * d))
			get_node(player.id).set_position(position)

func get_player():
	var level = get_current_level()
	_player = null;
	for player_type in player_type_list:
		if level.get_node(player_type) != null:
			_player = level.get_node(player_type);
			current_level = level.filename
			_send({"level": current_level});
			
	if _player == null and current_level != "null":
		print('did this ever run?')
		current_level = "null";
		_send({"level": current_level});

func get_current_level():
	var children = get_parent().get_children();
	for child in children:
		if child is TileMap:
			return child

func _on_connection_closed(was_clean = false):
	print("closed, clean: ", was_clean)
	set_process(false)
	
func _on_connected(proto = ""):
	connected = true
	print("Connected with protocol: ", proto)
	_send({"test": "client"})

func _send(data):
	_client.get_peer(1).put_packet(JSON.print(data).to_utf8())
		

func _on_data():
	var payload = JSON.parse(_client.get_peer(1).get_packet().get_string_from_utf8()).result
	if ("id" in payload):
		client_id = payload.id;
		_send({"updatePlayers" : true}) #fetch me the players
	if ("players" in payload):
		createPlayers(payload.players);
	if ("positions" in payload):
		 updatePositions(payload.positions);
	if ("message" in payload):
		print("received data: ", payload)
		
func updatePositions(newPlayersPositions):
	for newPlayer in newPlayersPositions:
		for player in other_players:
			if player.id == newPlayer.id:
				player.data.position = newPlayer.data.position;
				player.data.delta = 50; # make this in milliseconds from last update

func createPlayers(allPlayers):
	for player in allPlayers:
		if get_node(player.id) == null:
			createSprite(player.id)
			player.data.delta = 50;
			other_players.append(player);

	for localPlayer in other_players:
		var found = false
		for player in allPlayers:
			if player.id == localPlayer.id:
				found = true

		if not found == true:
			remove_child(get_node(localPlayer.id))
			other_players.erase(localPlayer)

func createSprite(id):
	var sprite = Sprite.new();
	sprite.texture = load("res://sprites/ballmario.png");
	sprite.name = id;
	add_child(sprite);
