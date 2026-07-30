extends State

var _direction := Vector2.ZERO
var _freeze_timer := 0.0
var _dash_timer := 0.0

func enter(msg: Dictionary = {}) -> void:
	_direction = msg.get("direction", player.get_dash_direction())
	player.start_dash(_direction)
	_freeze_timer = player.dash_freeze_time
	_dash_timer = player.dash_duration

func physics_update(delta: float) -> void:
	if _freeze_timer > 0.0:
		_freeze_timer -= delta
		player.move_and_slide()
		return

	if player.has_jump_buffer() and _direction.y == 0.0 and player.is_on_floor():
		player.do_super_jump()
		state_machine.transition_to("Air")
		return

	var wall_direction := player.get_wall_direction()
	if player.has_jump_buffer() and wall_direction != 0:
		player.do_wall_jump(-wall_direction)
		state_machine.transition_to("Air")
		return

	player.velocity = _direction * player.dash_speed
	player.move_and_slide()
	_dash_timer -= delta
	if _dash_timer > 0.0:
		return

	player.finish_dash()
	if player.is_on_floor():
		if Input.get_axis("move_left", "move_right") != 0.0:
			state_machine.transition_to("Run")
		else:
			state_machine.transition_to("Idle")
	else:
		state_machine.transition_to("Air")
