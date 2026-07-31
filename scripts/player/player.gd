class_name Player
extends CharacterBody2D
## Celeste Player.cs 帧逻辑移植。单一模拟所有者，帧序固定：
## 采样输入 -> 计时器 -> 状态更新（移动/重力/跳跃） -> 一次 move_and_slide -> 碰撞结算。
## 所有像素类参数 = Celeste 原值 * 1.875（Celeste 8px 砖 -> 本项目 15px 格）。

enum Mode { NORMAL, DASH, CLIMB }

@export_category("Movement")
@export var max_speed := 168.75 # MaxRun 90
@export var acceleration := 1875.0 # RunAccel 1000
@export var over_speed_decel := 750.0 # RunReduce 400
@export var air_accel_mult := 0.65 # AirMult
@export var duck_friction := 937.5 # DuckFriction 500

@export_category("Jump")
@export var jump_speed := 196.875 # JumpSpeed 105
@export var jump_speed_boost := 75.0 # JumpHBoost 40
@export var var_jump_time := 0.20 # VarJumpTime
@export var coyote_time := 0.10 # JumpGraceTime
@export var jump_buffer_time := 0.12
@export var ceiling_var_jump_grace := 0.05 # CeilingVarJumpGrace

@export_category("Gravity")
@export var gravity := 1687.5 # Gravity 900
@export var max_fall_speed := 300.0 # MaxFall 160
@export var half_gravity_threshold := 75.0 # HalfGravThreshold 40

@export_category("Dash")
@export var max_dashes := 1
@export var dash_speed := 450.0 # DashSpeed 240
@export var dash_end_speed := 300.0 # EndDashSpeed 160
@export var end_dash_up_mult := 0.75 # EndDashUpMult
@export var dash_duration := 0.15 # DashTime
@export var dash_cooldown := 0.20 # DashCooldown
@export var dash_attack_time := 0.30 # DashAttackTime
@export var dash_buffer_time := 0.12
@export var super_jump_speed := 487.5 # SuperJumpH 260
@export var dodge_slide_speed_mult := 1.2 # DodgeSlideSpeedMult
@export var duck_super_jump_x_mult := 1.25 # DuckSuperJumpXMult
@export var duck_super_jump_y_mult := 0.5 # DuckSuperJumpYMult
@export var super_wall_jump_speed := 300.0 # SuperWallJumpSpeed 160
@export var super_wall_jump_horizontal := 318.75 # MaxRun + JumpHBoost * 2

@export_category("Climb")
@export var max_stamina := 110.0 # ClimbMaxStamina
@export var climb_grab_y_mult := 0.2 # ClimbGrabYMult
@export var climb_no_move_time := 0.10 # ClimbNoMoveTime
@export var climb_up_speed := 84.375 # ClimbUpSpeed 45
@export var climb_down_speed := 150.0 # ClimbDownSpeed 80
@export var climb_slip_speed := 56.25 # ClimbSlipSpeed 30
@export var climb_acceleration := 1687.5 # ClimbAccel 900
@export var climb_up_stamina_cost := 45.45 # ClimbUpCost 100/2.2
@export var climb_still_stamina_cost := 10.0 # ClimbStillCost 100/10
@export var climb_jump_stamina_cost := 27.5 # ClimbJumpCost 110/4
@export var wall_check_distance := 5.625 # WallJumpCheckDist 3
@export var wall_jump_speed := 243.75 # MaxRun + JumpHBoost
@export var climb_hop_x := 187.5 # ClimbHopX 100
@export var climb_hop_y := 225.0 # ClimbHopY 120

@export_category("Feel")
@export var corner_correction_px := 7.5 # UpwardCornerCorrection 4
@export var dash_corner_correction_px := 7.5 # DashCornerCorrection 4

@export_category("Carry")
@export var throw_speed := 300.0
@export var throw_lift := 220.0

@export_category("Debug")
@export var show_controller_debug := false

var mode := Mode.NORMAL
var dash_count := 1
var stamina := 110.0
var facing := 1.0
var is_ducking := false
var dash_dir := Vector2.ZERO
var dash_started_on_ground := false
var before_dash_speed := Vector2.ZERO
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_attack_timer := 0.0
var last_technique := "None"
var corner_corrections := 0
var dash_corner_corrections := 0

var _jump_buffer := 0.0
var _dash_buffer := 0.0
var _coyote := 0.0
var _var_jump_timer := 0.0
var _var_jump_speed := 0.0
var _climb_lock := 0.0
var _floor_last_frame := false
var _landed_this_move := false
var _wall_direction := 0
var _event_text := ""
var _event_timer := 0.0

@onready var visuals: Node2D = $Visuals
@onready var carry_anchor: Marker2D = $CarryAnchor
@onready var grab_detector: Area2D = $GrabDetector
@onready var dash_pips: Array[ColorRect] = [$UI/DashPip1, $UI/DashPip2, $UI/DashPip3]
@onready var stamina_fill: ColorRect = $UI/StaminaBar/Fill
@onready var debug_label: Label = get_node_or_null("ControllerDebug")
var carried_item: CarryItem

func _ready() -> void:
	var config := get_node_or_null("/root/Config")
	if config: config.apply_to(self)
	dash_count = max_dashes
	stamina = max_stamina
	_floor_last_frame = is_on_floor()
	if debug_label: debug_label.visible = show_controller_debug
	_update_indicators()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload_config"):
		var config := get_node_or_null("/root/Config")
		if config: config.reload_and_apply(self)

func _physics_process(delta: float) -> void:
	_poll_input()
	_tick_timers(delta)
	_update_facing()
	match mode:
		Mode.DASH: _dash_update()
		Mode.CLIMB: _climb_update(delta)
		_: _normal_update(delta)
	var pre_move_velocity := velocity
	move_and_slide()
	_resolve_collisions(pre_move_velocity)
	_update_indicators()
	_update_debug()

# 输入在物理帧采样：一帧一次判定，也让 headless 回归能用 Input.action_press 驱动。
func _poll_input() -> void:
	if Input.is_action_just_pressed("jump"): _jump_buffer = jump_buffer_time
	if Input.is_action_just_pressed("dash"): _dash_buffer = dash_buffer_time
	if Input.is_action_just_pressed("grab"):
		if carried_item: throw_carried_item()
		elif has_nearby_item(): pick_up_nearest_item()

func _tick_timers(delta: float) -> void:
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_dash_buffer = maxf(0.0, _dash_buffer - delta)
	_coyote = maxf(0.0, _coyote - delta)
	_var_jump_timer = maxf(0.0, _var_jump_timer - delta)
	_climb_lock = maxf(0.0, _climb_lock - delta)
	dash_attack_timer = maxf(0.0, dash_attack_timer - delta)
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	_event_timer = maxf(0.0, _event_timer - delta)
	if mode == Mode.DASH: dash_timer = maxf(0.0, dash_timer - delta)

func _update_facing() -> void:
	if mode == Mode.DASH: return
	var x := Input.get_axis("move_left", "move_right")
	if x != 0.0: facing = signf(x)
	visuals.scale.x = facing

# 参考 NormalUpdate 帧序：先水平移动与重力，最后跳跃判定，跳跃速度不会再被摩擦吃掉。
func _normal_update(delta: float) -> void:
	if _try_start_dash(): return
	if _try_start_climb(): return
	if is_ducking and is_on_floor() and Input.get_axis("move_up", "move_down") <= 0.0:
		is_ducking = false
	_apply_horizontal(delta)
	_apply_gravity(delta)
	_try_jump()

# 参考 DashUpdate：Dash 期间速度只在起手写一次，本函数只做跳跃派生技巧。
func _dash_update() -> void:
	if _jump_buffer <= 0.0: return
	if dash_dir.y == 0.0 and _coyote > 0.0:
		_super_jump()
		return
	var wall := get_wall_direction()
	if wall != 0:
		_wall_jump(-wall, dash_dir.x == 0.0 and dash_dir.y < 0.0)

func _climb_update(delta: float) -> void:
	if _try_start_dash(): return
	var wall := get_wall_direction()
	if not Input.is_action_pressed("grab") or stamina <= 0.0 or wall == 0:
		if wall == 0 and velocity.y < 0.0 and Input.is_action_pressed("grab") and stamina > 0.0:
			_climb_hop()
		else:
			mode = Mode.NORMAL
			_event("Climb end")
		return
	facing = wall
	if _jump_buffer > 0.0:
		_wall_jump(-wall, false)
		return
	velocity.x = 0.0
	var vertical := Input.get_axis("move_up", "move_down")
	var target := climb_slip_speed
	if _climb_lock <= 0.0:
		if vertical < 0.0: target = -climb_up_speed
		elif vertical > 0.0: target = climb_down_speed
	velocity.y = move_toward(velocity.y, target, climb_acceleration * delta)
	if _climb_lock <= 0.0:
		if vertical < 0.0: stamina = maxf(0.0, stamina - climb_up_stamina_cost * delta)
		elif vertical == 0.0: stamina = maxf(0.0, stamina - climb_still_stamina_cost * delta)

func _apply_horizontal(delta: float) -> void:
	var grounded := is_on_floor()
	if is_ducking and grounded:
		velocity.x = move_toward(velocity.x, 0.0, duck_friction * delta)
		return
	var direction := Input.get_axis("move_left", "move_right")
	var mult := 1.0 if grounded else air_accel_mult
	var rate := acceleration
	if absf(velocity.x) > max_speed and signf(velocity.x) == signf(direction):
		rate = over_speed_decel
	velocity.x = move_toward(velocity.x, max_speed * direction, rate * mult * delta)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var mult := 1.0
		if absf(velocity.y) < half_gravity_threshold and Input.is_action_pressed("jump"):
			mult = 0.5
		velocity.y = minf(velocity.y + gravity * mult * delta, max_fall_speed)
	if _var_jump_timer > 0.0:
		if Input.is_action_pressed("jump"): velocity.y = minf(velocity.y, _var_jump_speed)
		else: _var_jump_timer = 0.0

func _try_jump() -> void:
	if _jump_buffer <= 0.0: return
	if _coyote > 0.0:
		_jump()
		return
	var wall := get_wall_direction()
	if wall != 0: _wall_jump(-wall, false)

func _jump() -> void:
	_consume_jump()
	is_ducking = false
	velocity.y = -jump_speed
	velocity.x += jump_speed_boost * Input.get_axis("move_left", "move_right")
	_var_jump_speed = velocity.y
	_event("Jump")

# 参考 SuperJump：Ducking 时乘 Duck 倍率，这就是 Hyper / Ultra 的真实来源。
func _super_jump() -> void:
	_consume_jump()
	velocity.x = super_jump_speed * facing
	velocity.y = -jump_speed
	if is_ducking:
		is_ducking = false
		velocity.x *= duck_super_jump_x_mult
		velocity.y *= duck_super_jump_y_mult
		_event("Hyper" if dash_started_on_ground else "Ultra")
	else:
		_event("Super")
	_var_jump_speed = velocity.y
	mode = Mode.NORMAL

func _wall_jump(direction: int, super_wall: bool) -> void:
	_consume_jump()
	is_ducking = false
	if super_wall:
		velocity.x = super_wall_jump_horizontal * direction
		velocity.y = -super_wall_jump_speed
	else:
		velocity.x = wall_jump_speed * direction
		velocity.y = -jump_speed
	_var_jump_speed = velocity.y
	facing = direction
	if mode == Mode.CLIMB:
		stamina = maxf(0.0, stamina - climb_jump_stamina_cost)
		_event("ClimbJump")
	else:
		_event("SuperWallJump" if super_wall else "WallJump")
	mode = Mode.NORMAL

func _climb_hop() -> void:
	_consume_jump()
	stamina = maxf(0.0, stamina - climb_jump_stamina_cost)
	velocity.x = climb_hop_x * facing
	velocity.y = -climb_hop_y
	_var_jump_speed = velocity.y
	mode = Mode.NORMAL
	_event("ClimbHop")

func _consume_jump() -> void:
	_jump_buffer = 0.0
	_coyote = 0.0
	dash_attack_timer = 0.0
	_var_jump_timer = var_jump_time

func _try_start_dash() -> bool:
	if _dash_buffer <= 0.0 or dash_count <= 0 or dash_cooldown_timer > 0.0: return false
	_dash_buffer = 0.0
	dash_count -= 1
	dash_started_on_ground = is_on_floor() or _coyote > 0.0
	before_dash_speed = velocity
	dash_dir = get_dash_direction()
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_attack_timer = dash_attack_time
	mode = Mode.DASH
	# 参考 DashCoroutine：同向且更快的旧速度保留，绝不降速。
	var new_speed := dash_dir * dash_speed
	if signf(before_dash_speed.x) == signf(new_speed.x) and absf(before_dash_speed.x) > absf(new_speed.x):
		new_speed.x = before_dash_speed.x
	velocity = new_speed
	if dash_dir.x != 0.0:
		facing = signf(dash_dir.x)
		visuals.scale.x = facing
	_event("Dash")
	if is_on_floor() and dash_dir.x != 0.0 and dash_dir.y > 0.0 and velocity.y > 0.0:
		_dash_slide()
	return true

# 参考 Dash Slide：斜下 Dash 触地转为水平 Dash 并提速，绝不清零水平速度。
func _dash_slide() -> void:
	dash_dir = Vector2(signf(dash_dir.x), 0.0)
	velocity.y = 0.0
	velocity.x *= dodge_slide_speed_mult
	is_ducking = true
	_event("DashSlide")

func _finish_dash() -> void:
	if dash_dir.y <= 0.0: velocity = dash_dir * dash_end_speed
	if velocity.y < 0.0: velocity.y *= end_dash_up_mult
	mode = Mode.NORMAL
	_event("Dash end")

func _try_start_climb() -> bool:
	if not Input.is_action_pressed("grab") or carried_item != null or stamina <= 0.0: return false
	var wall := get_wall_direction()
	if wall == 0: return false
	mode = Mode.CLIMB
	facing = wall
	is_ducking = false
	velocity.x = 0.0
	velocity.y *= climb_grab_y_mult
	_climb_lock = climb_no_move_time
	_event("Climb")
	return true

func _resolve_collisions(pre_move_velocity: Vector2) -> void:
	var landed := is_on_floor() and not _floor_last_frame
	var corrected := false
	if pre_move_velocity.y < 0.0 and is_on_ceiling():
		_upward_corner_correction(pre_move_velocity)
	elif landed and pre_move_velocity.y > 0.0 and mode == Mode.DASH:
		if not dash_started_on_ground and _dash_corner_correction(pre_move_velocity):
			corrected = true
			landed = false
		elif dash_dir.x != 0.0 and dash_dir.y > 0.0:
			_dash_slide()
	var grounded := is_on_floor() and not corrected
	if grounded:
		_coyote = coyote_time
		dash_count = max_dashes
		stamina = max_stamina
	_landed_this_move = landed
	_wall_direction = get_wall_direction()
	if mode == Mode.DASH and dash_timer <= 0.0: _finish_dash()
	_floor_last_frame = grounded

# 参考 OnCollideV 的 UpwardCornerCorrection：上升撞顶时逐像素横移穿过角落。
func _upward_corner_correction(pre_move_velocity: Vector2) -> void:
	var limit := int(corner_correction_px)
	var directions: Array[int] = []
	if pre_move_velocity.x <= 0.0: directions.append(-1)
	if pre_move_velocity.x >= 0.0: directions.append(1)
	for direction in directions:
		for i in range(1, limit + 1):
			var probe := global_transform
			probe.origin = global_position + Vector2(direction * i, -1.0)
			if not test_move(probe, Vector2(0.0, -1.0)):
				global_position = probe.origin
				velocity.y = pre_move_velocity.y
				corner_corrections += 1
				_event("CornerCorrect")
				return
	if _var_jump_timer < var_jump_time - ceiling_var_jump_grace:
		_var_jump_timer = 0.0

# 参考 OnCollideV 的 DashCornerCorrection：空中起手的 Dash 撞地角时横移让位。
func _dash_corner_correction(pre_move_velocity: Vector2) -> bool:
	var limit := int(dash_corner_correction_px)
	var directions: Array[int] = []
	if pre_move_velocity.x <= 0.0: directions.append(-1)
	if pre_move_velocity.x >= 0.0: directions.append(1)
	for direction in directions:
		for i in range(1, limit + 1):
			var probe := global_transform
			probe.origin = global_position + Vector2(direction * i, 0.0)
			if not test_move(probe, Vector2(0.0, 1.0)):
				global_position = probe.origin + Vector2(0.0, 1.0)
				velocity = pre_move_velocity
				dash_corner_corrections += 1
				_event("DashCorner")
				return true
	return false

func get_dash_direction() -> Vector2:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return (direction if direction != Vector2.ZERO else Vector2(facing, 0.0)).normalized()

func get_wall_direction() -> int:
	if test_move(global_transform, Vector2.LEFT * wall_check_distance): return -1
	if test_move(global_transform, Vector2.RIGHT * wall_check_distance): return 1
	return 0

func _event(event_name: String) -> void:
	last_technique = event_name
	_event_text = event_name
	_event_timer = 1.2

func _update_debug() -> void:
	if not debug_label: return
	debug_label.visible = show_controller_debug
	if not show_controller_debug: return
	debug_label.text = "MODE %s DUCK %s | V (%.0f, %.0f)\nDASH (%.2f, %.2f) x%d | STA %.0f\nEVENT %s" % [
		Mode.keys()[mode], "Y" if is_ducking else "N", velocity.x, velocity.y,
		dash_dir.x, dash_dir.y, dash_count, stamina, _event_text if _event_timer > 0.0 else "-"]

func has_nearby_item() -> bool: return _get_nearest_item() != null

func pick_up_nearest_item() -> bool:
	var item := _get_nearest_item()
	if item == null: return false
	item.pick_up(carry_anchor)
	carried_item = item
	return true

func throw_carried_item() -> void:
	if carried_item == null: return
	var item := carried_item
	carried_item = null
	item.throw_into(get_tree().current_scene, Vector2(facing, 0.0), throw_speed, throw_lift)

func _get_nearest_item() -> CarryItem:
	var nearest: CarryItem
	var distance := INF
	for body in grab_detector.get_overlapping_bodies():
		if body is CarryItem and not body.is_carried():
			var d := global_position.distance_squared_to(body.global_position)
			if d < distance:
				nearest = body
				distance = d
	return nearest

func _update_indicators() -> void:
	if not is_instance_valid(stamina_fill): return
	for index in dash_pips.size():
		dash_pips[index].visible = index < max_dashes
		dash_pips[index].color = Color("f7d65a") if index < dash_count else Color("4d5261")
	stamina_fill.size.x = 30.0 * clampf(stamina / maxf(max_stamina, 0.001), 0.0, 1.0)
