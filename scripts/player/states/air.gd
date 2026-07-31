extends State
## Air owns normal movement; Player owns all buffered input and post-collision facts.

func physics_update(delta: float) -> void:
	if player.consume_dash_buffer():
		state_machine.transition_to("Dash", {"direction": player.get_dash_direction()})
		return
	if Input.is_action_pressed("grab") and player.carried_item == null and player.can_climb():
		state_machine.transition_to("Climb", {"wall_direction": player.get_wall_direction()})
		return
	player.apply_gravity(delta)
	player.apply_air_movement(delta)
	var pre_move_vy := player.velocity.y
	player.move_and_slide()
	player.post_move()
	player.apply_corner_correction(pre_move_vy)
	if player.has_jump_buffer() and player.can_corner_kick():
		player.do_wall_jump(-player._wall_collision_direction)
		return
	if player.is_on_floor():
		if player.has_jump_buffer() and player.can_ultra_jump():
			player.do_ultra_jump()
			return
		if player.has_jump_buffer():
			player.do_jump()
			return
		state_machine.transition_to("Run" if Input.get_axis("move_left", "move_right") != 0.0 else "Idle")
