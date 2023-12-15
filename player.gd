extends CharacterBody3D

@onready var neck = $neck
@onready var head = $neck/head
@onready var camera = $neck/head/camera
@onready var grapple_raycast = $neck/head/camera/grapple_cast
@onready var standing_collision_shape = $standing_collision_shape
@onready var crouching_collision_shape = $crouching_collision_shape
@onready var sliding_collision_shape = $sliding_collision_shape
@onready var character_raycast = $player_cast
@onready var head_bonk_raycast = $head_bonk

# exported variables
@export var WALKING_SPEED = 5.0
@export var RUNNING_SPEED = 8.0
@export var SLIDING_SPEED = 10.0
@export var CROUCHING_SPEED = 5.0
@export var SLIDE_TIMER_MAX = 1.0

const JUMP_VELOCITY = 4.5
const LERP_SPEED = 10.0
const MOUSE_SENSITIVITY = 0.4

# movement variables
var current_speed = 5.0
var direction = Vector3.ZERO
var crouching_depth = -0.9

# sliding variables
var slide_timer = 0.0
var slide_vector = Vector2.ZERO

# head bobbing

const head_bobbing_sprinting_speed = 22.0
const head_bobbing_walking_speed = 14.0
const head_bobbing_crouching_speed = 10.0

var head_bobbing_speed = 0.0

# states
var grappling = false
var free_look = false

var walking = false
var running = false
var crouching = false
var sliding = false

# grappling
var grappling_point = Vector2.ZERO
var grappling_get = false


@export var REEL_SPEED = 30
@export var MAX_RANGE = 200


# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		if free_look:
			neck.rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENSITIVITY))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-120), deg_to_rad(120))
		else:
			rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENSITIVITY))
		head.rotate_x(deg_to_rad(-event.relative.y * MOUSE_SENSITIVITY))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta):

	grapple()

	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			print("stop sliding")
			sliding = false
			print("free_look_stop", free_look)

	if not is_on_floor():
		if not grappling:
			velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") && is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle Free Look.
	if Input.is_action_pressed("free_look") || sliding:
		free_look = true
		if sliding:
			camera.rotation.z = lerp(camera.rotation.z, deg_to_rad(5.0), delta*LERP_SPEED)
	else:
		free_look = false
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta*LERP_SPEED)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, delta*LERP_SPEED)
		
	# Handle input.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	

	# Crouching/sliding.
	
	if Input.is_action_pressed("sprint") && !crouching:
		player_state("running")

	if Input.is_action_pressed("crouch"):
		grappling = false
		current_speed = CROUCHING_SPEED

		if running:
			print("sliding")
			sliding = true
			slide_timer = SLIDE_TIMER_MAX
			slide_vector = input_dir
			print("free_look_start", free_look)
		player_state("crouching")
		head.position.y = lerp(head.position.y, crouching_depth, delta*LERP_SPEED)
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
	elif !character_raycast.is_colliding() && !sliding:
		if running:
			current_speed = RUNNING_SPEED
			player_state("running")
		else:
			current_speed = WALKING_SPEED
			player_state("walking")
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, 0.0, delta*LERP_SPEED)
		
	

	direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*LERP_SPEED)

	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

		if sliding:
			velocity.x = direction.x * (slide_timer + 0.1) * RUNNING_SPEED
			velocity.z = direction.z * (slide_timer + 0.1) * RUNNING_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	move_and_slide()



func grapple():
	if Input.is_action_just_pressed("grapple"):
		print("grapple")
		if grapple_raycast.is_colliding():
			if not grappling:
				grappling = true
	if head_bonk_raycast.is_colliding():
		grappling = false
		grappling_get = false
		grappling_point = null
		
	if grappling:
		if not grappling_get:
			grappling_point = grapple_raycast.get_collision_point() + Vector3(0, 1, 0)
			grappling_get = true
		if grappling_point.distance_to(position) > 2:
			position = lerp(position, grappling_point, 0.05)
		else:
			grappling = false
			grappling_get = false
			grappling_point = Vector2.ZERO
			
func player_state(state):
	match state:
		"running":
			walking = false
			running = true
			crouching = false
		"crouching":
			walking = false
			running = false
			crouching = true
		_:
			walking = true
			running = false
			crouching = false
	