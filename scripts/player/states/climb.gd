extends State

func physics_update(delta: float) -> void:
	if player.consume_dash_buffer():
		state_machine.transition_to("Dash", {"direction": player.get_dash_direction()})
		return
	if player.has_jump_buffer():
		var away := Input.get_axis("move_left", "move_right") == -player.facing
		if away:
			player.do_wall_jump(-player.facing)
		else:
			player.do_climb_jump(-player.facing)
		state_machine.transition_to("Air")
		return
	if not Input.is_action_pressed("grab") or player.stamina <= 0.0:
		state_machine.transition_to("Air")
		return

	var wall_direction := player.get_wall_direction()
	if wall_direction == 0:
		if player.velocity.y < 0.0:
			player.do_climb_hop(player.facing)
		state_machine.transition_to("Air")
		return
	player.facing = wall_direction
	var vertical := Input.get_axis("move_up", "move_down")
	var target := player.climb_slip_speed
	if player.can_move_climb():
		if vertical < 0.0:
			target = -player.climb_up_speed
		elif vertical > 0.0:
			target = player.climb_down_speed
	player.velocity.x = 0.0
	player.velocity.y = move_toward(player.velocity.y, target, player.climb_acceleration * delta)
	player.move_and_slide()
	player.post_move()
	if player.can_move_climb():
		if vertical < 0.0:
			player.stamina -= player.climb_up_stamina_cost * delta
		elif vertical == 0.0:
			player.stamina -= player.climb_still_stamina_cost * delta
	player.stamina = maxf(0.0, player.stamina)
