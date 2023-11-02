extends RigidBody3D

func _ready():
	pass

func _physics_process(_delta):
	if get_colliding_bodies().size() > 0:
		pass
