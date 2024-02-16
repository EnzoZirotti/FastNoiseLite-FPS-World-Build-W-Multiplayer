extends CharacterBody3D

@export var speed: float = 0.0

const WALK_SPEED: float = 10.0
const SPRINT_SPEED: float = 10.0
const JUMP_VELOCITY: float = 10
@export var SENSITIVITY: float = 0.001
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

var _is_crouching : bool = false
var Couch_speed : float = 7.0
var _is_sliding : bool = false
var Slide_distance : float = 7.0


const HIT_STAGGER = 5.2

signal health_changed(health_value)


@export var TOGGLE_CROUCH : bool = true

@onready var head = $Head
@onready var sight = $Head/Camera3D/sight
@onready var hand = $Head/Hand
@onready var touch = $Head/Hand/touch
@onready var muzzle_flash = $Head/Camera3D/Pistol/MuzzleFlash
@onready var walkingsound = $Walking
@onready var jumpingsound = $Jumping
@onready var runningsound = $Running
@onready var shootingsound = $Shooting
@onready var pistol = $Head/Camera3D/Pistol




@export var crouch_shapecast : ShapeCast3D
@export var anim_player : AnimationPlayer
@export var camera : Camera3D


signal player_hit


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
	
	crouch_shapecast.add_exception($".")


	camera.current = true



func _unhandled_input(event):
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

	# Adding gun shooting effects
	if Input.is_action_just_pressed("shoot") \
			and anim_player.current_animation != "shoot":
		play_shoot_effects.rpc()
		shootingsound.transform.origin  = pistol.global_position
		shootingsound.play()
		
		if sight.is_colliding():
			var hit_player = sight.get_collider()
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

func _input(event):
	var input_dir = Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		if event is InputEventMouseMotion:
			head.rotate_y(-event.relative.x * SENSITIVITY)
			camera.rotate_x(-event.relative.y * SENSITIVITY)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
			
	if event.is_action_pressed("crouch") and is_on_floor():
		toggle_crouch()
			
	
	if direction.length() > 0.0 and is_on_floor():
		if not walkingsound.is_playing():
			walkingsound.play()
	elif direction.length() == 0 or jumpingsound.is_playing():
		walkingsound.stop()
		runningsound.stop()
		
func _physics_process(_delta):
	if not is_multiplayer_authority(): return
	
	

	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * _delta

	# Handle Jump.
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if runningsound.is_playing():
			runningsound.stop()
		jumpingsound.play()

	# Handle Sprint
	if Input.is_action_pressed("sprint") and is_on_floor():
		if not runningsound.is_playing():
			runningsound.play()
		speed = SPRINT_SPEED
		
		walkingsound.stop()
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
	
func toggle_crouch():
	if _is_crouching == true and crouch_shapecast.is_colliding() == false:
		anim_player.play("Crouch", -1 , -Couch_speed, true)
	elif _is_crouching == false:
		anim_player.play("Crouch", -1 , Couch_speed)
		
func _on_animation_player_animation_started(anim_name):
	if anim_name == "Crouch":
		_is_crouching = !_is_crouching

func _headbob(time: float) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
	
func hit(dir):
	emit_signal("player_hit")
	velocity += dir * HIT_STAGGER

@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true
	
func rand_range(min: float, max: float) -> float:
	return randf() * (max - min) + min	
	
@rpc("any_peer")
func receive_damage():
	health -= 1
	if health <= 0:
		health = 3
		
		position = Vector3(
		rand_range(-20.0, 20.0),
		150.00,
		rand_range(-20.0, 20.0)
	) 
	health_changed.emit(health)



func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		anim_player.play("idle")
