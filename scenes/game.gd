extends Node

@onready var world : Node = get_tree().root.get_node("World")

func spawn_sound(src : String, origin : Vector3):
	var player : AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = load(src)
	player.position = origin
	world.add_child(player)
	player.play()
	await player.finished
	player.queue_free()
