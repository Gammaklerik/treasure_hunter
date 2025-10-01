extends CharacterBody2D

@onready var gm : Node = get_tree().current_scene.get_node("game_manager")

var base_move_speed : float = 200.0
@onready var move_speed : float = base_move_speed
var momentum : float = 0.0 :
	set(value):
		momentum = clampf(value, 0, max_momentum)
var momentum_inc : float = 0.25
var momentum_dec : float = 0.75
var max_momentum : float = 1.5

var jump_velocity : float = -500.0
var jump_amount : int
@onready var climb_raycast : RayCast2D = $climb_raycast
@onready var upper_mantle_raycast : RayCast2D = $upper_mantle_raycast
@onready var lower_mantle_raycast : RayCast2D = $lower_mantle_raycast
var mantling : bool = false :
	set(value):
		mantling = value
		if mantling:
			mantle_target = Vector2((to_global((climb_raycast.target_position * climb_raycast.scale.x)).x), to_global(climb_raycast.target_position).y - global_position.y / 8)
			#velocity = Vector2.ZERO
var mantle_target : Vector2

var crouched : bool :
	set(value):
		crouched = value
		if crouched:
			move_speed /= 2
			collider.disabled = true
			$crouch_collider.disabled = false
			$sprite.scale.y = 0.5
		else:
			move_speed = base_move_speed
			is_sliding = false
			collider.disabled = false
			$crouch_collider.disabled = true
			$sprite.scale.y = 1
var is_sliding : bool = false :
	set(value):
		is_sliding = value
		$sprite.flip_v = is_sliding
		if !is_sliding:
			$crouch_collider.rotation = deg_to_rad(90)
var slide_init_speed : float = 500.0
var slide_deceleration : float = 400.0
var slide_stop_threshold : float = 100.0
var min_slide_speed : float = 250.0

@onready var collider : CollisionShape2D = $collider

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if !is_on_floor():
		velocity += get_gravity() * delta
		if (upper_mantle_raycast.is_colliding() || lower_mantle_raycast.is_colliding()) && !climb_raycast.is_colliding() && Input.is_action_pressed("jump") && !crouched:
			if upper_mantle_raycast.get_collider() != null:
				if upper_mantle_raycast.get_collider().is_in_group("map"):
					if !mantling:
						mantling = true
			elif lower_mantle_raycast.get_collider() != null:
				if lower_mantle_raycast.get_collider().is_in_group("map"):
					if !mantling:
						mantling = true
	
	if !mantling:
		# Handle jump.
		if Input.is_action_just_pressed("jump") && (is_on_floor() || !$coyote_timer.is_stopped()):
			$jump_height_timer.start()
			velocity.y = jump_velocity
			jump_amount -= 1
			crouched = false
		
		if Input.is_action_just_pressed("crouch_slide"):
			if !crouched:
				crouched = true
				if is_on_floor() && abs(velocity.x) > min_slide_speed && !is_sliding:
					is_sliding = true
					velocity.x = slide_init_speed * sign(velocity.x)
			else:
				crouched = false
		
		var direction := Input.get_axis("move_left", "move_right")
		if !is_sliding:
			if direction:
				if !is_on_floor() && crouched:
					velocity.x = direction * (base_move_speed * (1.0 + momentum))
				else:
					velocity.x = direction * (move_speed * (1.0 + momentum))
			else:
				if !is_on_floor():
					velocity.x = move_toward(velocity.x, 0, (base_move_speed * (1.0 + momentum)))
				else:
					velocity.x = move_toward(velocity.x, 0, (move_speed * (1.0 + momentum)))
		else:
			velocity.x -= slide_deceleration * delta * sign(velocity.x)
			#$crouch_collider.rotation_degrees = int(90 - rad_to_deg(get_floor_angle()))
			
			if abs(velocity.x) <= slide_stop_threshold:
				is_sliding = false
		
		if direction != 0:
			climb_raycast.scale.x = direction
			upper_mantle_raycast.scale.x = direction
			lower_mantle_raycast.scale.x = direction
			if direction == -1:
				$sprite.flip_h = true
			else:
				$sprite.flip_h = false
		
		if velocity.x != 0 && !is_sliding:
			momentum += momentum_inc * delta
		elif velocity.x == 0 || is_sliding:
			momentum -= momentum_dec * delta
	else:
		global_position = lerp(global_position, mantle_target, 0.15)
		print(str(global_position) + ", " + str(mantle_target))
		if int(global_position.x) == int(mantle_target.x) || is_on_floor():
			mantling = false
	
	
	var was_on_floor = is_on_floor()
	
	move_and_slide()
	
	if was_on_floor && !is_on_floor():
		$coyote_timer.start()
	
	if crouched && !was_on_floor && is_on_floor() && abs(velocity.x) >= min_slide_speed:
		is_sliding = true
		velocity.x = (velocity.x * 0.50) + slide_init_speed * sign(velocity.x)

func _on_jump_height_timer_timeout() -> void:
	if !Input.is_action_pressed("jump"):
		if velocity.y < -100:
			velocity.y = -100
