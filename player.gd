extends CharacterBody3D

var speed: float = 0.0

const WALK_SPEED: float = 10.0
const SPRINT_SPEED: float = 10.0
const JUMP_VELOCITY: float = 10
const SENSITIVITY: float = 0.001
# Bob frequency
const BOB_FREQ: float = 2.0
const BOB_AMP: float = 0.08
var t_bob: float = 0.0

# FOV Variables
const BASE_FOV: float = 75.0
const FOV_CHANGE: float = 1.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = 9.8

var picked_object 
var pull_power = 4

# Health
var health: int = 3


signal health_changed(health_value)

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var sight = $Head/Camera3D/sight
@onready var hand = $Head/Hand
@onready var touch = $Head/Hand/touch
@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $Head/Camera3D/Pistol/MuzzleFlash



func pick_object():
	var collider = touch.get_collider()
	if collider != null and collider is RigidBody3D:
		picked_object = collider
	else:
		pass

func remove_object():
	if picked_object != null:
		picked_object = null


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	

func _ready():
	if not is_multiplayer_authority(): return
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	camera.current = true



func _unhandled_input(event):
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

	# Adding gun shooting effects
	if Input.is_action_just_pressed("shoot") and anim_player.current_animation != "shoot":
		play_shoot_effects.rpc()

		if sight.is_colliding():
			var hit_player = sight.get_collider()

		# Check if the collider is a StaticBody3D
			if hit_player is StaticBody3D:
			# Skip damage logic for static bodies
				return
			elif hit_player is CharacterBody3D:
		# Assuming other player-related logic here (e.g., apply damage)
				hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())


func _physics_process(_delta):
	if not is_multiplayer_authority(): return
	
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * _delta

	# Handle Jump.
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle Sprint
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction.length() > 0.0:
			velocity.x = lerp(velocity.x, direction.x * speed, _delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, _delta * 7.0)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, _delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, _delta * 3.0)

	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
#Part of picking up
	if Input.is_action_just_pressed("pickup"):
		if picked_object == null:
			pick_object()
		elif picked_object != null:
			remove_object()
	# Head bob
	t_bob += _delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)

	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, _delta * 8.0)
	
	if picked_object != null:
		var a = picked_object.global_transform.origin
		var b = touch.global_transform.origin
		picked_object.set_linear_velocity((b-a) * pull_power)
	# Adding Gun movement
	
	if anim_player.current_animation == "shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		anim_player.play("move")
	else:
		anim_player.play("idle")
		
	move_and_slide()

func _headbob(time: float) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true
	
	
	
@rpc("any_peer")
func receive_damage():
	health -= 1
	if health <= 0:
		health = 3
		position = Vector3.ZERO
	health_changed.emit(health)



func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		anim_player.play("idle")
