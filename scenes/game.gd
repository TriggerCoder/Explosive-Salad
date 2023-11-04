extends Node

const GRAVITY : float = 20.0

@onready var world : Node = get_tree().root.get_node("World")

func spawn_sound(src : String, origin : Vector3):
	var player : AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = load(src)
	player.position = origin
	player.bus = "Sounds"
	world.add_child(player)
	player.play()
	await player.finished
	player.queue_free()

func get_spawn() -> Vector3:
	var map = world.get_node_or_null("Map")
	if map == null: return Vector3.UP * 2.0
	var spawns = map.get_node("Spawns").get_children()
	return spawns.pick_random().position + Vector3(randf(), randf(), randf())

func spawn_ragdoll(skeleton : Skeleton3D, last_velocity : Vector3):
	var ragdoll : Skeleton3D = preload("res://ragdolls/pickle.tscn").instantiate()
	ragdoll.global_transform = skeleton.global_transform
	for i in ragdoll.get_bone_count():
		ragdoll.set_bone_pose_position(i, skeleton.get_bone_pose(i).origin)
		ragdoll.set_bone_pose_rotation(i, skeleton.get_bone_pose(i).basis)
	ragdoll.physical_bones_start_simulation()
	world.add_child(ragdoll)
	# await get_tree().process_frame
	ragdoll.get_node("Physical Bone Pelvis").apply_central_impulse(last_velocity.normalized() * 100.0)
	
