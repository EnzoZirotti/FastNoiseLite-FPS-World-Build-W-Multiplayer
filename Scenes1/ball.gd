extends RigidBody3D

@onready var ball = $"."

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if ball.get_colliding_bodies() = true:
		ball.transform.position = ball.global_position = -6 * delta
