extends State
## Dash uses Player-owned timers. Frame order stays input buffer → state → move → collision bookkeeping.

func enter(msg: Dictionary = {}) -> void:
	player.start_dash(msg.get("direction", player.get_dash_direction()))

func physics_update(delta: float) -> void:
	# Celeste DashUpdate checks jump before DashCoroutine moves.
	var wall_direction := player.get_wall_direction()
	if player.has_jump_buffer() and wall_direction != 0:
		player.do_wall_jump(-wall_direction)
		state_machine.transition_to("Air")
		return
	if player.has_jump_buffer() and player.is_on_floor():
		if player.dash_direction.y > 0.0 and player.dash_direction.x != 0.0:
			player.do_hyper_jump()
		elif player.dash_direction.y == 0.0:
			player.do_super_jump()
		else:
			player.do_jump()
		state_machine.transition_to("Air")
		return
	if not player.update_dash(delta):
		return
	player.finish_dash()
	state_machine.transition_to("Run" if player.is_on_floor() and Input.get_axis("move_left", "move_right") != 0.0 else "Idle" if player.is_on_floor() else "Air")
