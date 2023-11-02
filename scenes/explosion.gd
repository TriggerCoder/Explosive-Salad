extends Area3D

func _ready():
	connect("body_entered", _on_body_entered)
	Game.spawn_sound("res://sounds/explosion.wav", position)

func _on_body_entered(body):
	if !body.has_method("is_player"):
		return
	await get_tree().process_frame
	body.health.hp -= 3.0
	body.add_force(body.position - position, 25.0)
	$CollisionShape3D.disabled = true
	
