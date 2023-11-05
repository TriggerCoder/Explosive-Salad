extends CharacterBody3D

const ATTACK_DELAY : float = 0.25
const ACCEL : float = 10.0
var attacked = false
var attack_hand_cycle : bool = false

@export var target : CharacterBody3D : set = _set_target
@export var movement_speed: float = 14.0

@onready var navigation_agent: NavigationAgent3D = get_node("NavigationAgent3D")
@onready var sm_playback : AnimationNodeStateMachinePlayback = $Character/AnimationTree.get("parameters/sm/playback")
@onready var health = $Health

var last_velocity : Vector3

func _ready() -> void:
	health.connect("died", _on_death)
	health.connect("spawned", _on_spawn)
	health.connect("hurt", _on_hurt)
	$Character/AnimationTree.active = true
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	navigation_agent.link_reached.connect(_on_navlink_reached)

func set_movement_target(movement_target: Vector3):
	navigation_agent.set_target_position(movement_target)

func process_animations():
	# Ground movement blend space
	var blend = Vector2(velocity.dot(transform.basis.x) / movement_speed, -velocity.dot(transform.basis.z) / movement_speed)
	$Character/AnimationTree.set("parameters/sm/ground/blend_position", blend)
	# Common states
	if is_on_floor():
		sm_playback.travel("ground")
	else:
		sm_playback.travel("air")

func process_bounds():
	if position.y <= -10.0:
		position = Game.get_spawn()

func _physics_process(delta):
	process_animations()
	if not multiplayer.is_server(): return
	
	process_bounds()
	
	if not is_on_floor(): velocity.y -= Game.GRAVITY * delta

	if target == null: 
		target = get_closest_target()
		return

	# Look at target direction
	var look_dir = transform.looking_at(target.position)
	rotation.y = look_dir.basis.get_euler().y
	
#	if navigation_agent.is_navigation_finished(): return
	# Once every 2 idle (render) frames
	if Engine.get_process_frames() % 60 == 0:
		set_movement_target(target.position)
	
	var next_path_position: Vector3 = navigation_agent.get_next_path_position()
	var current_agent_position: Vector3 = global_position
	var new_velocity: Vector3 = (next_path_position - current_agent_position).normalized() * movement_speed
	if navigation_agent.avoidance_enabled:
		navigation_agent.velocity = new_velocity
	else:
		_on_velocity_computed(new_velocity)
		
	last_velocity = velocity
	
	if position.distance_squared_to(target.position) <= 1.0 and !attacked:
		var attack_target = $RayCast3D.get_collider()
		if attack_target == null: return
		if attack_target.has_method("is_player"):
			attack_target.health.hp -= 1.0
			if attack_target.health.dead: target = get_closest_target()
		attacked = true
		if attack_hand_cycle:
			start_state.rpc("attack_hand_left")
			attack_hand_cycle = false
		else:
			start_state.rpc("attack_hand_right")
			attack_hand_cycle = true
		await get_tree().create_timer(ATTACK_DELAY).timeout
		attacked = false

func _on_velocity_computed(safe_velocity: Vector3):
	velocity.x = lerp(velocity.x, safe_velocity.x, get_physics_process_delta_time() * ACCEL)
	velocity.z = lerp(velocity.z, safe_velocity.z, get_physics_process_delta_time() * ACCEL)
	move_and_slide()

func _set_target(value):
	target = value

func sort_closest(a, b):
	return a.position < b.position

func get_closest_target():
	var targets : Array = get_tree().get_nodes_in_group("Players")
	if targets.size() <= 0: return
	targets.sort_custom(sort_closest)
	return targets.front()

@rpc("call_local")
func start_state(state_name : String):
	sm_playback.start(state_name)

func add_force(dir : Vector3, force : float):
	velocity += dir.normalized() * force
	navigation_agent.set_velocity(velocity)

func is_bot():
	return true

func _on_navlink_reached(_dict):
	# print('Reached')
	velocity.y += 10.0
	velocity += (position - _dict.link_exit_position).normalized() * -10.0
	if navigation_agent.avoidance_enabled:
		navigation_agent.set_velocity(velocity)

func _on_death():
	visible = false
	$CollisionShape3D.disabled = true
	Game.spawn_ragdoll($Character/Player/Armature/Skeleton3D, last_velocity)
	
func _on_spawn():
	visible = true
	$CollisionShape3D.disabled = false
	position = Game.get_spawn()

func _on_hurt():
	Game.spawn_sound("res://sounds/pain.wav", position)
	$Character/Juice.restart()
	$Character/Juice.rotation = Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	var pos = $Character/Juice/RayCast3D.get_collision_point()
	var norm = $Character/Juice/RayCast3D.get_collision_normal()
	Game.spawn_decal("res://decals/stain.tscn", pos, norm)
