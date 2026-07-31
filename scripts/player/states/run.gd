extends State
## Run ground state.

func physics_update(delta: float) -> void:
	if player.consume_dash_buffer():
		state_machine.transition_to("Dash", {"direction": player.get_dash_direction()})
		return
	player.apply_ground_movement(delta)
	player.velocity.y = 0.0
	player.move_and_slide()
	if player.has_jump_buffer() and player.can_ultra_jump():
		player.do_ultra_jump()
		state_machine.transition_to("Air")
		return
	if player.wants_jump():
		player.do_jump()
		state_machine.transition_to("Air")
		return
	if not player.is_on_floor():
		state_machine.transition_to("Air")
	elif Input.get_axis("move_left", "move_right") == 0.0 and absf(player.velocity.x) < 5.0:
		state_machine.transition_to("Idle")
