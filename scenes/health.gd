extends Node

const MAX_HP : float = 10.0
@export var hp : float = 10.0 : set = _set_hp, get = _get_hp

func _ready():
	hp = MAX_HP
	set_multiplayer_authority(1)
	$ProgressBar.visible = get_parent().is_multiplayer_authority()

func _set_hp(value):
	if value < hp:
		Game.spawn_sound("res://sounds/pain.wav", get_parent().position)
	hp = value
	$ProgressBar.value = value
	if value <= 0.0:
		die()

func _get_hp():
	return hp

func die():
	$"..".visible = false
	$"../CollisionShape3D".disabled = true
	$"../CollisionShape3D2".disabled = true
	$"../Camera3D".current = false
	await get_tree().create_timer(1.0).timeout
	$"..".visible = true
	$"../CollisionShape3D".disabled = false
	$"../CollisionShape3D2".disabled = false
	$"..".position = Vector3(0.0, 2.0, 0.0)
	$"../Camera3D".current = get_parent().is_multiplayer_authority()
	hp = MAX_HP
