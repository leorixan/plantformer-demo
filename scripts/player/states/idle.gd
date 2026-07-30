extends State
## Idle：地面静止。无输入时由 apply_ground_movement 自动刹车。

func physics_update(delta: float) -> void:
	if Input.is_action_just_pressed("dash") and player.can_dash():
		state_machine.transition_to("Dash", {"direction": player.get_dash_direction()})
		return
	player.apply_ground_movement(delta)
	player.velocity.y = 0.0
	player.move_and_slide()

	if player.wants_jump():
		player.do_jump()
		state_machine.transition_to("Air")
		return
	if Input.get_axis("move_left", "move_right") != 0.0:
		state_machine.transition_to("Run")
		return
	if not player.is_on_floor():
		state_machine.transition_to("Air")
