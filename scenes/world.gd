extends Node

@onready var main_menu = $Menu
@onready var address_entry = $Menu/Main/MarginContainer/VBoxContainer/AddressEntry

const MAX_BOTS = 16
const PORT = 27015
var enet_peer = ENetMultiplayerPeer.new()

func _ready():
	if OS.has_feature("dedicated_server"):
		create_server() 

func create_server():
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	for n in MAX_BOTS:
		var bot = preload("res://scenes/bot.tscn").instantiate()
		bot.position = Game.get_spawn()
		Game.world.add_child(bot, true)

func host():
	create_server()
	add_player(multiplayer.get_unique_id())

func join():
	enet_peer.create_client(address_entry.text, PORT)
	multiplayer.multiplayer_peer = enet_peer

func quickjoin():
	# Join my server
	enet_peer.create_client("188.225.38.117", PORT)
	multiplayer.multiplayer_peer = enet_peer

func add_player(peer_id):
	var player = preload("res://scenes/player.tscn").instantiate()
	player.name = str(peer_id)
	add_child(player)

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func _on_multiplayer_spawner_spawned(_node):
	pass
