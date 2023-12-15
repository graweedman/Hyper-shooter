extends CharacterBody3D

@onready var neck = $neck
@onready var head = $neck/head 
@onready var eyes = $neck/head/eyes
@onready var camera = $neck/head/eyes/camera
@onready var animation_player = $neck/head/eyes/animation_player
@onready var grapple_raycast = $neck/head/eyes/camera/grapple_cast
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
const AIR_LERP_SPEED = 5.0
const MOUSE_SENSITIVITY = 0.4

# movement variables
var current_speed = 5.0
var direction = Vector3.ZERO
var crouching_depth = -0.9
var last_velocity = Vector3.ZERO

# sliding variables
var slide_timer = 0.0
var slide_vector = Vector2.ZERO

# head bobbing

const head_bobbing_sprinting_speed = 22.0
const head_bobbing_walking_speed = 14.0
const head_bobbing_crouching_speed = 10.0

const head_bobbing_crouching_intensity = 0.2
const head_bobbing_walking_intensity = 0.1
const head_bobbing_sprinting_intensity = 0.05

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0

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

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			print("stop sliding")
			sliding = false
			print("free_look_stop", free_look)

	# Head bobbing.
	if running:
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed * delta
	elif walking:
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
	elif crouching:
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed * delta
	else:
		head_bobbing_current_intensity = 0.0

	if is_on_floor() && !sliding && input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = cos(head_bobbing_index/ 2)+0.5

		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity/2.0), delta*LERP_SPEED)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * (head_bobbing_current_intensity), delta*LERP_SPEED)

	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta*LERP_SPEED)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta*LERP_SPEED)
		head_bobbing_vector = Vector2.ZERO

	if not is_on_floor():
		if not grappling:
			velocity.y -= gravity * delta

	
	#Handle landing
	if is_on_floor():
		if last_velocity.y < -10.0:
			animation_player.play("roll")
		elif last_velocity.y < -4.0:
			animation_player.play("landing")
		
	

	# Handle Free Look.
	if Input.is_action_pressed("free_look") || sliding:
		free_look = true
		if sliding:
			camera.rotation.z = lerp(camera.rotation.z, deg_to_rad(5.0), delta*LERP_SPEED)
	else:
		free_look = false
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta*LERP_SPEED)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, delta*LERP_SPEED)

	if Input.is_action_pressed("crouch") || sliding:
		

		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false

		current_speed = lerp(current_speed, CROUCHING_SPEED, delta*LERP_SPEED)
		head.position.y = lerp(head.position.y, crouching_depth, delta*LERP_SPEED)

		if running && input_dir != Vector2.ZERO:
			sliding = true
			slide_timer = SLIDE_TIMER_MAX
			slide_vector = input_dir

		player_state("crouching")
		
	elif !character_raycast.is_colliding() && !sliding:

		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, 0.0, delta*LERP_SPEED)

		if Input.is_action_pressed("sprint"):
			player_state("running")
			current_speed = lerp(current_speed, RUNNING_SPEED, delta*LERP_SPEED)
		else:
			player_state("walking")
			current_speed = lerp(current_speed, WALKING_SPEED, delta*LERP_SPEED)

	# Handle Airtime
	if is_on_floor():
		direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*LERP_SPEED)
	else:
		if input_dir != Vector2.ZERO:
			direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*AIR_LERP_SPEED)

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") && is_on_floor():
		velocity.y = JUMP_VELOCITY
		sliding = false
		animation_player.play("jump")

	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
		current_speed = (slide_timer + 0.1) * SLIDING_SPEED
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	# else:
		# velocity.x = move_toward(velocity.x, 0, current_speed)
		# velocity.z = move_toward(velocity.z, 0, current_speed)

		last_velocity = velocity
	move_and_slide()

	




			
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
	
