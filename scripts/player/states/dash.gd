extends State

var _direction := Vector2.ZERO
var _freeze_timer := 0.0
var _dash_timer := 0.0
var _active := false

func enter(msg: Dictionary = {}) -> void:
	_direction = msg.get("direction", player.get_dash_direction())
	player.start_dash(_direction)
	_freeze_timer = player.dash_freeze_time
	_dash_timer = player.dash_duration
	_active = false

func physics_update(delta: float) -> void:
	# Input buffers keep presses during freeze valid; no state reads just_pressed.
	if _freeze_timer > 0.0:
		_freeze_timer -= delta
		return
	if not _active:
		player.activate_dash()
		_active = true

	var wall_direction := player.get_wall_direction()
	if player.has_jump_buffer() and wall_direction != 0:
		player.do_wall_jump(-wall_direction)
		state_machine.transition_to("Air")
		return
	if player.has_jump_buffer() and player.is_on_floor():
		if _direction.y > 0.0 and _direction.x != 0.0:
			# Down-diagonal dash + ground + jump = Hyper.
			player.do_hyper_jump()
		else:
			# Horizontal dash + ground + jump = Super.
			player.do_super_jump()
		state_machine.transition_to("Air")
		return

	player.move_and_slide()
	if _direction.y > 0.0 and _direction.x != 0.0 and player.is_on_floor():
		# Landing down-diagonal dash arms short Ultra jump window.
		player.prepare_ultra(player.velocity.x)
	_dash_timer -= delta
	if _dash_timer > 0.0:
		return
	player.finish_dash()
	if player.is_on_floor():
		state_machine.transition_to("Run" if Input.get_axis("move_left", "move_right") != 0.0 else "Idle")
	else:
		state_machine.transition_to("Air")
