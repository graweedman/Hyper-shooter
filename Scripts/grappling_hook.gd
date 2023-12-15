extends Node3D

@export var player:Node3D = get_node("Player")



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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	grapple()
	

