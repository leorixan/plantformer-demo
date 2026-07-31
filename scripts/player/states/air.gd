extends State
## Air handles buffered dash/jump, wall grab, gravity, corner correction, Ultra landing jump.

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
	player.apply_corner_correction(pre_move_vy)

	if player.wants_jump():
		player.do_jump()
		return
	if player.is_on_floor():
		# Down-diagonal dash landing + buffered jump = Ultra.
		if player.has_jump_buffer() and player.can_ultra_jump():
			player.do_ultra_jump()
			return
		if player.has_jump_buffer():
			player.do_jump()
			return
		state_machine.transition_to("Run" if Input.get_axis("move_left", "move_right") != 0.0 else "Idle")
