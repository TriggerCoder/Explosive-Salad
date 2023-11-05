extends Node

signal hurt
signal died
signal spawned

const MAX_HP : float = 10.0
@export var hp : float = 10.0 : set = _set_hp, get = _get_hp
@export var last_damage_dealer : int = 1
@export var dead : bool = false

func _ready():
	hp = MAX_HP
	set_multiplayer_authority(1)
	$ProgressBar.visible = multiplayer.get_unique_id() == get_parent().get_multiplayer_authority()

func _set_hp(value):
	if value < hp:
		emit_signal("hurt")
	hp = value
	$ProgressBar.value = value
	if value <= 0.0:
		die()

func _get_hp():
	return hp

func die():
	if dead: return
	dead = true
	emit_signal("died")
	await get_tree().create_timer(1.0).timeout
	dead = false
	emit_signal("spawned")
	hp = MAX_HP
	var dealer = Game.world.get_node(str(last_damage_dealer))
	if dealer == null:
		return
	dealer.scoreboard.score += 1
	if get_parent().has_method("is_bot"):
		get_parent().target = dealer
