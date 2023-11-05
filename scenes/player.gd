extends CharacterBody3D

@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $Camera3D/Pistol/MuzzleFlash
@onready var raycast = $Camera3D/RayCast3D
@onready var health = $Health
@onready var scoreboard = $Scoreboard

# Animation
@onready var sm_playback : AnimationNodeStateMachinePlayback = $Character/AnimationTree.get("parameters/sm/playback")

@export var mouse_sens : float = 0.005
@export var gamepad_sens : float = 0.05

var friction: float = 4
var accel: float = 12
# 4 for quake 2/3 40 for quake 1/source
var accel_air: float = 40
var top_speed_ground: float = 10
# 15 for quake 2/3, 2.5 for quake 1/source
var top_speed_air: float = 2.5
# linearize friction below this speed value
var lin_friction_speed: float = 10
var jump_force: float = 8
var projected_speed: float = 0
var grounded_prev: bool = true
var grounded: bool = true
var wish_dir: Vector3 = Vector3.ZERO

# Stepping and camera bobbing
const STEP_SPEED : float = 20.0
const BOB_AMT : float = 0.2
var step : Vector2i = Vector2i(0,0)
var bob_enabled : bool = true
var bob_time : float = 0.0
var bob_current : Vector2

# For ragdolls
var last_velocity : Vector3

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	$Label3D.text = name

func _ready():
	health.connect("died", _on_death)
	health.connect("spawned", _on_spawn)
	health.connect("hurt", _on_hurt)
	$Character/AnimationTree.active = true
	if not is_multiplayer_authority(): return
	$Character/Player/Armature/Skeleton3D/Pickle.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_VISIBLE
	if not Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: return
	# Mouselook
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sens)
		camera.rotate_x(-event.relative.y * mouse_sens)
		camera.rotation.x = clamp(camera.rotation.x, -1.5, 1.5)
	# Firing
	if Input.is_action_just_pressed("shoot") and anim_player.current_animation != "shoot":
		play_shoot_effects.rpc()
		spawn_grenade.rpc()

func _physics_process(delta):
	process_animations()
	if not is_multiplayer_authority(): return
	if not Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: return
	process_gamepad()
	process_steps(delta)
	process_movement(delta)
	process_bounds()

func process_gamepad():
	var gamepad_look : Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	rotate_y(-gamepad_look.x * gamepad_sens)
	camera.rotate_x(-gamepad_look.y * gamepad_sens)
	camera.rotation.x = clamp(camera.rotation.x, -1.5, 1.5)

func process_animations():
	# Ground movement blend space
	var blend = Vector2(velocity.dot(transform.basis.x) / top_speed_ground, -velocity.dot(transform.basis.z) / top_speed_ground)
	$Character/AnimationTree.set("parameters/sm/ground/blend_position", blend)
	# Common states
	if grounded:
		sm_playback.travel("ground")
	else:
		sm_playback.travel("air")

func process_bounds():
	if position.y <= -10.0:
		position = Game.get_spawn()

func clip_velocity(normal: Vector3, overbounce: float) -> void:
	var correction_amount: float = 0
	var correction_dir: Vector3 = Vector3.ZERO
	var move_vector: Vector3 = get_velocity().normalized()
	correction_amount = move_vector.dot(normal) * overbounce
	correction_dir = normal * correction_amount
	velocity -= correction_dir
	velocity.y -= correction_dir.y * Game.GRAVITY * 0.05

func apply_friction(delta):
	var speed_scalar: float = 0
	var friction_curve: float = 0
	var speed_loss: float = 0
	var current_speed: float = 0
	current_speed = velocity.length()
	if(current_speed < 0.1):
		velocity.x = 0
		velocity.y = 0
		return
	friction_curve = clampf(current_speed, lin_friction_speed, INF)
	speed_loss = friction_curve * friction * delta
	speed_scalar = clampf(current_speed - speed_loss, 0, INF)
	speed_scalar /= clampf(current_speed, 1, INF)
	velocity *= speed_scalar

func apply_acceleration(acceleration: float, top_speed: float, delta):
	var speed_remaining: float = 0
	var accel_final: float = 0
	speed_remaining = (top_speed * wish_dir.length()) - projected_speed
	if speed_remaining <= 0:
		return
	accel_final = acceleration * delta * top_speed
	clampf(accel_final, 0, speed_remaining)
	velocity.x += accel_final * wish_dir.x
	velocity.z += accel_final * wish_dir.z

func air_move(delta):
	apply_acceleration(accel_air, top_speed_air, delta)
	clip_velocity(get_wall_normal(), 14.0)
	clip_velocity(get_floor_normal(), 14.0)
	velocity.y -= Game.GRAVITY * delta

func ground_move(delta):
	floor_snap_length = 0.4
	apply_acceleration(accel, top_speed_ground, delta)
	if Input.is_action_pressed("move_jump"):
		velocity.y = jump_force
	if grounded == grounded_prev:
		apply_friction(delta)
	if is_on_wall:
		clip_velocity(get_wall_normal(), 1.0)

func process_movement(delta):
	grounded_prev = grounded
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	wish_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	projected_speed = (velocity * Vector3(1, 0, 1)).dot(wish_dir)
	if not is_on_floor():
		grounded = false
		air_move(delta)
	if is_on_floor():
		if velocity.y > 10.0:
			grounded = false
			air_move(delta)
		else:
			grounded = true
			ground_move(delta)
	last_velocity = velocity
	move_and_slide()

@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true
	$Character/SoundAttack.play()

@rpc("call_local")
func spawn_grenade():
	sm_playback.start("attack")
	if not multiplayer.is_server():
		return
	var grenade = preload("res://scenes/grenade.tscn").instantiate()
	grenade.instigator = name.to_int()
	Game.world.add_child(grenade, true)
	grenade.global_transform = $Camera3D/RayCast3D/Marker3D.global_transform
	grenade.apply_central_impulse(raycast.global_transform.basis.z * -25.0)

@rpc("call_local")
func spawn_rocket():
	if not multiplayer.is_server():
		return
	var rocket = preload("res://scenes/rocket.tscn").instantiate()
	Game.world.add_child(rocket, true)
	rocket.global_transform = raycast.get_node("Marker3D").global_transform
	rocket.linear_velocity = raycast.global_transform.basis.z * -50.0

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		anim_player.play("idle")

func process_steps(delta : float) -> void:
	var speed_clamped = remap(Vector3(velocity.x, 0.0, velocity.z).length(), 0.0, top_speed_ground, 0.0, 1.0)
	bob_time += delta * STEP_SPEED * speed_clamped
	var bob_target = Vector2(sin(bob_time) * BOB_AMT, cos(bob_time * 0.5) * BOB_AMT) * float(is_on_floor())
	# Step sounds
	if bob_target.y > 0.1 and step.x == 0:
		step = Vector2i(1, 0)
		play_footstep.rpc()
	if bob_target.y < -0.1 and step.y == 0:
		step = Vector2i(0, 1)
		play_footstep.rpc()
	# Reset the bobbing if speed is too small
	if speed_clamped <= 0.1:
		bob_time = 0.0
		bob_target = Vector2.ZERO
	# Calculate head bobbing
	if bob_enabled:
		bob_current = lerp(bob_current, bob_target, delta * 5.0)
		bob_current = lerp(bob_current, bob_target, delta * 5.0)
		camera.transform.origin.x = bob_current.y
		camera.transform.origin.y = bob_current.x + 1.5

func is_player():
	return true

func add_force(dir : Vector3, force : float):
	velocity += dir.normalized() * force

@rpc("call_local")
func play_footstep():
	$Character/SoundStep/AnimationPlayer.play("step")

func _on_death():
	visible = false
	$CollisionShape3D.disabled = true
	$CollisionShape3D2.disabled = true
	$Camera3D.current = false
	Game.spawn_ragdoll($Character/Player/Armature/Skeleton3D, last_velocity)

func _on_spawn():
	visible = true
	$CollisionShape3D.disabled = false
	$CollisionShape3D2.disabled = false
	position = Game.get_spawn()
	$Camera3D.current = is_multiplayer_authority()

func _on_hurt():
	Game.spawn_sound("res://sounds/pain.wav", position)
	$Character/Juice.restart()
