extends Node

const GRAVITY : float = 20.0

@onready var world : Node = get_tree().root.get_node("World")

func spawn_sound(src : String, origin : Vector3):
	var player : AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = load(src)
	player.position = origin
	world.add_child(player)
	player.play()
	await player.finished
	player.queue_free()

func get_spawn() -> Vector3:
	var map = Game.world.get_node_or_null("Map")
	if map == null: return Vector3.UP * 2.0
	var spawns = map.get_node("Spawns").get_children()
	return spawns.pick_random().position + Vector3(randf(), randf(), randf())
