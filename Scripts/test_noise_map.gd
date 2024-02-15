extends Node3D
# World aspects
const GRID_SIZE = 150
const MESH_SIZE = 1
const M_HEIGHT = 15

#PORT FOR MULTIPLAYER
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()


@export var fnoise : FastNoiseLite
@export var grad : GradientTexture1D

@onready var map = $Map
@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud = $CanvasLayer/HUD
@onready var health_bar = $CanvasLayer/HUD/HealthBar



var player_scene: PackedScene
var spawn_radius: float = 50.0
var fixed_y_position: float = 150.00  #


var current_x_offset: int = 0
var current_y_offset: int = 0

var world_ready : bool = false
var direction : Vector2 = Vector2.ZERO
var timer_update : float = 0.0
var speed : float = 0.1 - (50 / 1000.0)

func _ready():
	player_scene = preload("res://Scenes/player.tscn")
	
#
#
#	create_world()
#	world_ready = true
	# Spawn the player initially
	#spawn_player()
	
		
##NEED TO FIND A WAY TO USE THIS CORRECTLY
#func _process(delta):
#
#	timer_update += delta
#	if direction and timer_update > speed:
#		timer_update = 0
#
#		current_x_offset += direction.x
#		current_y_offset += direction.y
#		fnoise.offset.x = current_x_offset
#		fnoise.offset.y = current_y_offset
#
#		#update_world()

#func create_world():
#	var noise: float
#	var x: float
#	var z: float
#	var y: float
#	var mat_mesh: StandardMaterial3D
#	var new_mesh: MeshInstance3D
#	var static_body: StaticBody3D
#	var collision_shape: CollisionShape3D
#
#	for i in range(GRID_SIZE):
#		for j in range(GRID_SIZE):
#			noise = get_noise(i, j)
#			if noise < 2:
#				y = M_HEIGHT / 2
#			else:
#				y = round(noise * M_HEIGHT)
#			x = i * MESH_SIZE + MESH_SIZE / 2
#			z = j * MESH_SIZE + MESH_SIZE / 2
#
#			new_mesh = MeshInstance3D.new()
#			new_mesh.mesh = BoxMesh.new()
#			new_mesh.mesh.size = Vector3(MESH_SIZE, 50, MESH_SIZE)
#			map.add_child(new_mesh)
#			mat_mesh = StandardMaterial3D.new()
#			mat_mesh.albedo_color = grad.gradient.get_color(floor(noise))
#			new_mesh.mesh.material = mat_mesh
#			new_mesh.position = Vector3(x, y, z)
#			new_mesh.name = "Tile_" + str(i) + '_' + str(j)
#
#			# Create a StaticBody3D for collision
#			static_body = StaticBody3D.new()
#			new_mesh.add_child(static_body)  # Attach to the MeshInstance3D
#
#			# Add a CollisionShape3D for collision
#			for k in range(3):
#				collision_shape = CollisionShape3D.new()
#				collision_shape.shape = ConvexPolygonShape3D.new()  # Replace with your desired shape (e.g., BoxShape3D, SphereShape3D, etc.)
#				static_body.add_child(collision_shape)
#				new_mesh.create_convex_collision(k)
#
#	map.position = Vector3(-GRID_SIZE / 2.0 * MESH_SIZE, 0, -GRID_SIZE / 2.0 * MESH_SIZE)
#
#
#### THIS NEEDS TO BE ADJUSTED
##func update_world():
##	var noise : float
##	var tile_mesh
##	for i in range(GRID_SIZE):
##		for j in range(GRID_SIZE):
##			noise = get_noise(i, j)
##			tile_mesh = map.get_node("Tile_" + str(i) + '_' + str(j))
##			tile_mesh.mesh.material.albedo_color = grad.gradient.get_color(floor(noise))
##			if noise < 2:
##				tile_mesh.position.y = M_HEIGHT / 2
##			else:
##				tile_mesh.position.y = round(noise * M_HEIGHT)
##	offset_lbl.text = "Offset X,Y : " + str(current_x_offset) + " , " + str(current_y_offset)
#
#func get_noise(x, y):
##	return s_noise.get_noise_2d(x, y)
#	var n = remap(fnoise.get_noise_2d(x, y), -1.0, 1.0, 0.0, 10.0)
#	return clampf(n, 0.0, 9.99)


func add_player(peer_id):
	var random_position = Vector3(
		rand_range(-spawn_radius, spawn_radius),
		fixed_y_position,
		rand_range(-spawn_radius, spawn_radius)
	)
	var player = player_scene.instantiate()  # Use instance() instead of instantiate()
	player.name = str(peer_id)
	player.transform.origin = random_position
	add_child(player)
	if player.is_multiplayer_authority():
		player.health_changed.connect(update_health_bar)

func rand_range(min: float, max: float) -> float:
	return randf() * (max - min) + min

func _on_host_button_pressed():
	main_menu.hide()
	hud.show()

	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	add_player(multiplayer.get_unique_id())

	upnp_setup()

func _on_join_button_pressed():
	main_menu.hide()
	hud.show()
	enet_peer.create_client(address_entry.text, PORT)
	multiplayer.multiplayer_peer = enet_peer

	# Set a valid Y-axis position for the player spawn
	var valid_y_position = 150  # Adjust this value based on your map's height
	var spawn_position = Vector3(
		rand_range(-spawn_radius, spawn_radius),
		valid_y_position,
		rand_range(-spawn_radius, spawn_radius)
	)

	# Instantiate and position the player
	var player = player_scene.instantiate()
	player.name = str(multiplayer.get_unique_id())
	player.transform.origin = spawn_position
	add_child(player)
	if player.is_multiplayer_authority():
		player.health_changed.connect(update_health_bar)

func update_health_bar(health_value):
	health_bar.value = health_value
	



func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)

	
func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
		
func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Discover Failed! Error %s" % discover_result)

	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")

	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Port Mapping Failed! Error %s" % map_result)
	
	print("Success! Join Address: %s" % upnp.query_external_address())
