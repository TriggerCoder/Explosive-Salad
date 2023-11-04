extends RigidBody3D

@export var instigator : int = 1
@export var last_body : CharacterBody3D = null

func _ready():
	if !is_multiplayer_authority(): return
	$Area3D.connect("body_entered", _on_body_entered)
	await get_tree().create_timer(1.0).timeout
	explode.rpc()

func _on_body_entered(body):
	if not body is CharacterBody3D: return
	last_body = body
	await get_tree().process_frame
	explode.rpc()

@rpc("call_local")
func explode():
	$Area3D.monitorable = false
	$Area3D.monitoring = false
	$Area3D/CollisionShape3D.disabled = true
	var explosion = preload("res://scenes/explosion.tscn").instantiate()
	explosion.position = position
	explosion.instigator = instigator
	Game.world.add_child(explosion)
	if last_body != null and last_body.has_method("is_player"):
		last_body.health.last_damage_dealer = instigator
		last_body.health.hp -= 0.5
	if last_body != null and last_body.has_method("is_bot"):
		last_body.health.last_damage_dealer = instigator
		last_body.health.hp -= 0.5
	# Free only on server, handled by mp spawner
	if !is_multiplayer_authority():
		return
	queue_free()
