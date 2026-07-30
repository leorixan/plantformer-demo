extends State
## Air：空中（跳跃上升/下落/走出平台）。
## 包含：重力三分段、空中操控、土狼跳、落地缓存起跳（兔子跳窗口）、角落修正。

func physics_update(delta: float) -> void:
	if Input.is_action_just_pressed("dash") and player.can_dash():
		state_machine.transition_to("Dash", {"direction": player.get_dash_direction()})
		return
	if Input.is_action_pressed("grab") and player.carried_item == null and player.can_climb():
		state_machine.transition_to("Climb", {"wall_direction": player.get_wall_direction()})
		return
	player.apply_gravity(delta)
	player.apply_air_movement(delta)
	# 记录移动前的 vy：撞头后 velocity.y 会被碰撞清零，角落修正必须用移动前的值
	var pre_move_vy: float = player.velocity.y
	player.move_and_slide()
	player.apply_corner_correction(pre_move_vy)

	# 土狼跳：走出边缘后的宽限内仍可起跳（留在 Air）
	if player.wants_jump():
		player.do_jump()
		return

	if player.is_on_floor():
		player.apply_ultra()
		# 落地瞬间消费跳跃缓存 → 立即再起跳（§4.6 兔子跳：不吃地面摩擦）
		if player.has_jump_buffer():
			player.do_jump()
			return
		if Input.get_axis("move_left", "move_right") != 0.0:
			state_machine.transition_to("Run")
		else:
			state_machine.transition_to("Idle")
