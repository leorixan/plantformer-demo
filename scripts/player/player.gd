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
@export var dash_freeze_time := 0.05 # DashBegin 的 Celeste.Freeze(.05)
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
@export var climb_check_distance := 3.75 # ClimbCheckDist 2；抓墙检测 + 贴墙吸附距离
@export var wall_check_distance := 5.625 # WallJumpCheckDist 3
@export var slip_check_depth := 7.5 # SlipCheck 的 4px 探针深度 ×1.875
@export var wall_jump_speed := 243.75 # MaxRun + JumpHBoost
@export var climb_hop_x := 187.5 # ClimbHopX 100
@export var climb_hop_y := 225.0 # ClimbHopY 120
@export var climb_hop_force_time := 0.20 # ClimbHopForceTime

@export_category("Feel")
@export var corner_correction_px := 7.5 # UpwardCornerCorrection 4
@export var dash_corner_correction_px := 7.5 # DashCornerCorrection 4
@export var wall_jump_force_time := 0.16 # WallJumpForceTime
@export var super_wall_jump_force_time := 0.20 # SuperWallJumpForceTime

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
var move_x := 0.0 # 参考 moveX：受 forceMoveX 覆盖后的有效水平输入
var move_y := 0.0 # 参考 Input.MoveY.Value：原始纵向输入
var dash_dir := Vector2.ZERO
var dash_started_on_ground := false
var before_dash_speed := Vector2.ZERO
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_attack_timer := 0.0
var last_technique := "None"
var corner_corrections := 0
var dash_corner_corrections := 0
var climb_hops := 0

var _jump_buffer := 0.0
var _dash_buffer := 0.0
var _grab_pressed := false
var _raw_move_x := 0.0
var _force_move_x := 0.0
var _force_move_x_timer := 0.0
var _dash_freeze := 0.0
var _hop_wait_x := 0
var _hop_wait_x_speed := 0.0
var _coyote := 0.0
var _var_jump_timer := 0.0
var _var_jump_speed := 0.0
var _climb_lock := 0.0
var _floor_last_frame := false
var _landed_this_move := false
var _wall_direction := 0
var _half_width := 6.0
var _top_offset := -21.0
var _event_text := ""
var _event_timer := 0.0

@onready var visuals: Node2D = $Visuals
@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var carry_anchor: Marker2D = $CarryAnchor
@onready var grab_detector: Area2D = $GrabDetector
@onready var dash_pips: Array[ColorRect] = [$UI/DashPip1, $UI/DashPip2, $UI/DashPip3]
@onready var stamina_fill: ColorRect = $UI/StaminaBar/Fill
@onready var debug_label: Label = get_node_or_null("ControllerDebug")
var carried_item: CarryItem

func _ready() -> void:
	var config := get_node_or_null("/root/Config")
	if config: config.apply_to(self)
	var rect := collider.shape as RectangleShape2D
	if rect:
		_half_width = rect.size.x * 0.5
		_top_offset = collider.position.y - rect.size.y * 0.5
	dash_count = max_dashes
	stamina = max_stamina
	_floor_last_frame = is_on_floor()
	if debug_label: debug_label.visible = show_controller_debug
	_update_indicators()

# 按下事件在这里捕获：InputEvent 不受物理帧节奏影响，
# 一次两帧之间按下又松开的快速点按也不会被 is_action_just_pressed 漏掉。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"): _jump_buffer = jump_buffer_time
	elif event.is_action_pressed("dash"): _dash_buffer = dash_buffer_time
	elif event.is_action_pressed("grab"): _grab_pressed = true
	elif event.is_action_pressed("reload_config"):
		var config := get_node_or_null("/root/Config")
		if config: config.reload_and_apply(self)

func _physics_process(delta: float) -> void:
	_poll_input(delta)
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

# 物理帧补采样：与 _unhandled_input 写同一个缓存计时器，两条路径任一命中都算按下，
# 这样 headless 回归的 Input.action_press（不产生 InputEvent）也能驱动。
func _poll_input(delta: float) -> void:
	if Input.is_action_just_pressed("jump"): _jump_buffer = jump_buffer_time
	if Input.is_action_just_pressed("dash"): _dash_buffer = dash_buffer_time
	if Input.is_action_just_pressed("grab"): _grab_pressed = true
	_raw_move_x = signf(Input.get_axis("move_left", "move_right"))
	move_y = signf(Input.get_axis("move_up", "move_down"))
	# 参考 Update 的 forceMoveX 段：墙跳 / 翻墙 hop 后短时间内接管水平输入。
	if _force_move_x_timer > 0.0:
		_force_move_x_timer = maxf(0.0, _force_move_x_timer - delta)
		move_x = _force_move_x
	else:
		move_x = _raw_move_x
	if _grab_pressed:
		_grab_pressed = false
		if carried_item: throw_carried_item()
		elif has_nearby_item(): pick_up_nearest_item()

func _tick_timers(delta: float) -> void:
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_dash_buffer = maxf(0.0, _dash_buffer - delta)
	# 参考 Celeste.Freeze：冻结期只有输入继续走，游戏内计时器全部停住。
	if _dash_freeze > 0.0:
		_dash_freeze = maxf(0.0, _dash_freeze - delta)
		return
	_coyote = maxf(0.0, _coyote - delta)
	_var_jump_timer = maxf(0.0, _var_jump_timer - delta)
	_climb_lock = maxf(0.0, _climb_lock - delta)
	dash_attack_timer = maxf(0.0, dash_attack_timer - delta)
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	_event_timer = maxf(0.0, _event_timer - delta)
	if mode == Mode.DASH: dash_timer = maxf(0.0, dash_timer - delta)
	# 参考 Update 的 Climb hop 段：翻墙时水平速度先压住，越过墙沿才推上平台。
	if _hop_wait_x != 0:
		if signf(velocity.x) == -float(_hop_wait_x) or velocity.y > 0.0:
			_hop_wait_x = 0
		elif not test_move(global_transform, Vector2(_hop_wait_x, 0.0)):
			velocity.x = _hop_wait_x_speed
			_hop_wait_x = 0

# 参考 Update 的 Facing 段：除 Climb 外所有状态（含 Dash）都跟随 moveX，
# 这是反向 Super / 反向 Hyper 的唯一来源 —— Dash 途中回拉方向即可反向起跳。
func _update_facing() -> void:
	if mode == Mode.CLIMB: return
	if move_x != 0.0: facing = move_x
	visuals.scale.x = facing

# 参考 NormalUpdate 帧序：先水平移动与重力，最后跳跃判定，跳跃速度不会再被摩擦吃掉。
func _normal_update(delta: float) -> void:
	if _try_start_dash(): return
	if _try_start_climb(): return
	if is_ducking and is_on_floor() and move_y <= 0.0:
		is_ducking = false
	_apply_horizontal(delta)
	_apply_gravity(delta)
	_try_jump()

# 参考 DashUpdate：Dash 期间速度只在起手写一次，本函数只做冻结、起速与跳跃派生技巧。
func _dash_update() -> void:
	# 参考 DashBegin 的 Celeste.Freeze(.05)：冻结期原地不动，方向键还能继续补按。
	if _dash_freeze > 0.0:
		velocity = Vector2.ZERO
		return
	# 参考 DashCoroutine 开头的 yield return null：方向留到冻结结束才采样，
	# 所以 K 与方向键同帧按下（或方向晚一两帧）都能吃到正确的八向方向。
	if dash_dir == Vector2.ZERO: _launch_dash()
	if _jump_buffer <= 0.0: return
	if dash_dir.y == 0.0 and _coyote > 0.0:
		_super_jump()
		return
	_try_dash_wall_jump()

# 参考 DashUpdate 的墙跳分支：先右后左检测；纯上 Dash 撞墙走 SuperWallJump。
func _try_dash_wall_jump() -> bool:
	var super_wall := dash_dir.x == 0.0 and dash_dir.y < 0.0
	if _wall_jump_check(1):
		_wall_jump(-1, super_wall)
		return true
	if _wall_jump_check(-1):
		_wall_jump(1, super_wall)
		return true
	return false

# 参考 ClimbUpdate：target 默认 0（抓住不动），只有 SlipCheck 命中（手高过墙沿）才下滑。
func _climb_update(delta: float) -> void:
	if _try_start_dash(): return
	var wall := int(facing)
	if not Input.is_action_pressed("grab") or stamina <= 0.0:
		mode = Mode.NORMAL
		_event("Climb end")
		return
	if _jump_buffer > 0.0:
		# 参考 Wall Jump 分支：拉离墙 = 墙跳弹开，其余 = 垂直爬墙跳。
		if move_x == -float(wall):
			_wall_jump(-wall, false)
		else:
			_climb_jump()
		return
	# 参考 No wall to hold：贴墙检测只看 1px；上升中失去墙面视为翻过墙沿。
	if not test_move(global_transform, Vector2(wall, 0.0)):
		if velocity.y < 0.0:
			_climb_hop()
		else:
			mode = Mode.NORMAL
			_event("Climb end")
		return
	var vertical := move_y
	var target := 0.0
	var try_slip := true
	if _climb_lock <= 0.0:
		if vertical < 0.0:
			target = -climb_up_speed
			try_slip = false
			# 参考 Up Limit：头顶顶住就停住；手已过墙沿则直接翻上去。
			if test_move(global_transform, Vector2.UP):
				if velocity.y < 0.0: velocity.y = 0.0
				target = 0.0
				try_slip = true
			elif _slip_check():
				_climb_hop()
				return
		elif vertical > 0.0:
			target = climb_down_speed
			try_slip = false
			if is_on_floor():
				if velocity.y > 0.0: velocity.y = 0.0
				target = 0.0
	if try_slip and _slip_check(): target = climb_slip_speed
	velocity.y = move_toward(velocity.y, target, climb_acceleration * delta)
	# 参考 Down Limit：不是主动下爬且脚边墙面到头了，立刻停住，不沿墙滑落。
	if vertical <= 0.0 and velocity.y > 0.0 and not test_move(global_transform, Vector2(wall, 1.0)):
		velocity.y = 0.0
	if _climb_lock <= 0.0:
		if vertical < 0.0: stamina = maxf(0.0, stamina - climb_up_stamina_cost * delta)
		elif vertical == 0.0: stamina = maxf(0.0, stamina - climb_still_stamina_cost * delta)

# 参考 SlipCheck：探针在面墙一侧的头顶与其下 4px（×1.875）处，两点都空才算手高过墙沿。
func _slip_check(add_y := 0.0) -> bool:
	var probe_x := global_position.x + facing * (_half_width + 1.0)
	var top := global_position.y + _top_offset + add_y
	return not _point_is_solid(Vector2(probe_x, top + slip_check_depth)) \
		and not _point_is_solid(Vector2(probe_x, top))

func _point_is_solid(point: Vector2) -> bool:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = point
	params.collision_mask = collision_mask
	params.collide_with_areas = false
	params.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_point(params, 1).is_empty()

func _apply_horizontal(delta: float) -> void:
	var grounded := is_on_floor()
	if is_ducking and grounded:
		velocity.x = move_toward(velocity.x, 0.0, duck_friction * delta)
		return
	var direction := move_x
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
	velocity.x += jump_speed_boost * move_x
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
	visuals.scale.x = facing
	# 参考 WallJump / SuperWallJump：短时间接管水平输入，防止刚弹开就被拉回墙上。
	if move_x != 0.0:
		_force_move_x = float(direction)
		_force_move_x_timer = super_wall_jump_force_time if super_wall else wall_jump_force_time
	_event("SuperWallJump" if super_wall else "WallJump")
	mode = Mode.NORMAL

# 参考 ClimbJump：垂直起跳、不推离墙面，离地时才扣体力。
func _climb_jump() -> void:
	mode = Mode.NORMAL
	if not is_on_floor():
		stamina = maxf(0.0, stamina - climb_jump_stamina_cost)
	_jump()
	_event("ClimbJump")

# 参考 ClimbHop：翻墙沿是免费动作 —— 不扣体力、不算跳跃。
# 水平速度先由 hopWaitX 压住，越过墙沿才推上平台；forceMoveX 期间不吃水平输入。
func _climb_hop() -> void:
	if test_move(global_transform, Vector2(facing, 0.0)):
		_hop_wait_x = int(facing)
		_hop_wait_x_speed = climb_hop_x * facing
		velocity.x = 0.0
	else:
		_hop_wait_x = 0
		velocity.x = climb_hop_x * facing
	velocity.y = minf(velocity.y, -climb_hop_y)
	_force_move_x = 0.0
	_force_move_x_timer = climb_hop_force_time
	climb_hops += 1
	mode = Mode.NORMAL
	_event("ClimbHop")

func _consume_jump() -> void:
	_jump_buffer = 0.0
	_coyote = 0.0
	dash_attack_timer = 0.0
	_var_jump_timer = var_jump_time

# 参考 DashBegin：起手只清速度与方向并进入冻结，真正起速留给 _launch_dash。
func _try_start_dash() -> bool:
	if _dash_buffer <= 0.0 or dash_count <= 0 or dash_cooldown_timer > 0.0: return false
	_dash_buffer = 0.0
	dash_count -= 1
	dash_started_on_ground = is_on_floor() or _coyote > 0.0
	before_dash_speed = velocity
	dash_dir = Vector2.ZERO
	velocity = Vector2.ZERO
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_attack_timer = dash_attack_time
	_dash_freeze = dash_freeze_time
	mode = Mode.DASH
	if not is_on_floor(): is_ducking = false
	_event("Dash")
	return true

# 参考 DashCoroutine：冻结结束后才读方向、写速度，同向更快的旧速度保留，绝不降速。
func _launch_dash() -> void:
	dash_dir = get_dash_direction()
	var new_speed := dash_dir * dash_speed
	if signf(before_dash_speed.x) == signf(new_speed.x) and absf(before_dash_speed.x) > absf(new_speed.x):
		new_speed.x = before_dash_speed.x
	velocity = new_speed
	if dash_dir.x != 0.0:
		facing = signf(dash_dir.x)
		visuals.scale.x = facing
	if is_on_floor() and dash_dir.x != 0.0 and dash_dir.y > 0.0 and velocity.y > 0.0:
		_dash_slide()

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
	if not Input.is_action_pressed("grab") or carried_item != null or stamina <= 0.0 or is_ducking:
		return false
	# 参考 NormalUpdate 的 Climbing 段：上升中或正在离墙时不许抓墙。
	# 缺这条，翻墙 hop 刚起跳就会被重新抓住 → 反复 hop 把体力抽干。
	if velocity.y < 0.0 or signf(velocity.x) == -facing: return false
	# 参考 ClimbCheck：只检测面朝一侧，距离用 ClimbCheckDist。
	var wall := get_climb_wall_direction()
	if wall == 0: return false
	mode = Mode.CLIMB
	facing = wall
	visuals.scale.x = facing
	is_ducking = false
	velocity.x = 0.0
	velocity.y *= climb_grab_y_mult
	_climb_lock = climb_no_move_time
	_snap_to_wall(wall)
	_event("Climb")
	return true

# 参考 ClimbBegin 末尾：逐像素贴向墙面，抓墙后角色与墙之间不留空隙。
func _snap_to_wall(direction: int) -> void:
	var step := Vector2(direction, 0.0)
	for _i in range(int(ceilf(climb_check_distance))):
		if test_move(global_transform, step): return
		global_position += step

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
	# 参考 Input.GetAimVector：无方向输入时退回面朝方向；用原始输入，不受 forceMoveX 影响。
	var direction := Vector2(_raw_move_x, move_y)
	return (direction if direction != Vector2.ZERO else Vector2(facing, 0.0)).normalized()

# 参考 WallJumpCheck：以 WallJumpCheckDist 做整箱检测。
func _wall_jump_check(direction: int) -> bool:
	return test_move(global_transform, Vector2(direction, 0.0) * wall_check_distance)

func get_wall_direction() -> int:
	if _wall_jump_check(1): return 1
	if _wall_jump_check(-1): return -1
	return 0

# 抓墙用 ClimbCheckDist（比墙跳的 WallJumpCheckDist 短），且只认面朝方向。
func get_climb_wall_direction() -> int:
	var direction := int(facing)
	if test_move(global_transform, Vector2(direction, 0.0) * climb_check_distance): return direction
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
