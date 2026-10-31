class_name Player
extends CharacterBody2D
## Celeste Player.cs 帧逻辑移植。单一模拟所有者，帧序固定：
## 采样输入 -> 计时器 -> 状态更新（移动/重力/跳跃） -> 一次 move_and_slide -> 碰撞结算。
## 尺度与 Celeste 一致：1 砖 = 8px，站立碰撞盒 8x11，蹲下 8x6，所有参数直接照搬原值。

enum Mode { NORMAL, DASH, CLIMB }

## Godot 的碰撞检测默认留 0.08 的安全边距，会把"刚好贴合"判成命中：
## 8px 宽的角色钻 1 砖（8px）宽的缝、或贴墙吸附最后 1px，都会被误判卡住。
## 需要接触级精度的检测统一用这个极小边距，其余检测保持默认（贴住即算命中反而更稳）。
const CONTACT_MARGIN := 0.001
## 整箱检测与物理盒统一的内缩量，用来抵掉 Godot 的零间隙不可通行限制。
## Celeste 的坐标是整数，8px 宽的身体钻 8px 宽的缝是"严丝合缝"地过；Godot 里坐标是浮点，
## 缝隙与身体等宽时要求亚像素级对齐，角落修正因此大多数时候找不到可行位置。
## 内缩 1px（物理盒 7 宽）给 1 砖缝留出 1px 余量，角落修正才能像参考那样稳定命中。
const SHAPE_INSET := 1.0

const JUMP_DUST := preload("res://scripts/fx/jump_dust.gd")

@export_category("Body")
const BODY_CRYSTAL_COLOR := Color(0.28, 0.78, 0.82, 1.0)
const BODY_NO_DASH_COLOR := Color(0.35, 0.49, 0.57, 1.0)
const CRYSTAL_COLOR := Color(0.28, 0.78, 0.82, 1.0)
@export var body_width := 8.0 # normalHitbox 宽
@export var stand_height := 11.0 # normalHitbox 高
@export var duck_height := 6.0 # duckHitbox 高

@export_category("Movement")
@export var max_speed := 90.0 # MaxRun
@export var acceleration := 1000.0 # RunAccel
@export var over_speed_decel := 400.0 # RunReduce
@export var air_accel_mult := 0.65 # AirMult
@export var duck_friction := 500.0 # DuckFriction
@export var duck_correct_check := 4 # DuckCorrectCheck
@export var duck_correct_slide := 50.0 # DuckCorrectSlide

@export_category("Jump")
@export var jump_speed := 105.0 # JumpSpeed
@export var jump_speed_boost := 40.0 # JumpHBoost
@export var var_jump_time := 0.20 # VarJumpTime
@export var coyote_time := 0.10 # JumpGraceTime
@export var jump_buffer_time := 0.12
@export var ceiling_var_jump_grace := 0.05 # CeilingVarJumpGrace

@export_category("Gravity")
@export var gravity := 900.0 # Gravity
@export var max_fall_speed := 160.0 # MaxFall
@export var fast_max_fall_speed := 240.0 # FastMaxFall
@export var fast_max_accel := 300.0 # FastMaxAccel
@export var half_gravity_threshold := 40.0 # HalfGravThreshold

@export_category("Dash")
@export var max_dashes := 1
@export var dash_speed := 240.0 # DashSpeed
@export var dream_dash_speed := 200.0 # 紫块内 Dream Dash 速度
@export var dream_jump_h_speed := 220.0 # 出紫块 Super（Dream Jump）的水平速度上限
@export var dash_end_speed := 160.0 # EndDashSpeed
@export var end_dash_up_mult := 0.75 # EndDashUpMult
@export var dash_duration := 0.15 # DashTime
@export var dash_freeze_time := 0.05 # DashBegin 的 Celeste.Freeze(.05)
@export var dash_cooldown := 0.20 # DashCooldown
@export var dash_refill_cooldown := 0.10 # DashRefillCooldown；落地补 dash 的冷却，Extended Dash 的来源
@export var dash_attack_time := 0.30 # DashAttackTime
@export var attack_speed_threshold := 240.0 # is_attacking 速度阈值（蔚蓝 8px 标准）
@export var dash_buffer_time := 0.12
@export var super_jump_speed := 260.0 # SuperJumpH
@export var dodge_slide_speed_mult := 1.2 # DodgeSlideSpeedMult
@export var duck_super_jump_x_mult := 1.25 # DuckSuperJumpXMult
@export var duck_super_jump_y_mult := 0.5 # DuckSuperJumpYMult
@export var super_wall_jump_speed := 160.0 # SuperWallJumpSpeed
@export var super_wall_jump_horizontal := 170.0 # MaxRun + JumpHBoost * 2

@export_category("Climb")
@export var max_stamina := 110.0 # ClimbMaxStamina
@export var climb_grab_y_mult := 0.2 # ClimbGrabYMult
@export var climb_no_move_time := 0.10 # ClimbNoMoveTime
@export var climb_up_speed := 45.0 # ClimbUpSpeed
@export var climb_down_speed := 80.0 # ClimbDownSpeed
@export var climb_slip_speed := 30.0 # ClimbSlipSpeed
@export var climb_acceleration := 900.0 # ClimbAccel
@export var climb_up_stamina_cost := 45.45 # ClimbUpCost 100/2.2
@export var climb_still_stamina_cost := 10.0 # ClimbStillCost 100/10
@export var climb_jump_stamina_cost := 27.5 # ClimbJumpCost 110/4
@export var climb_check_distance := 2.0 # ClimbCheckDist；抓墙检测 + 贴墙吸附距离
@export var wall_check_distance := 0.5 # WallJumpCheckDist（普通墙跳检测距离，越小越严格）
@export var dash_wall_check_distance := 3.0 # 冲刺中墙跳检测距离（比普通墙跳宽松）
@export var slip_check_depth := 4.0 # SlipCheck 的探针深度
@export var wall_jump_speed := 130.0 # WallJumpHSpeed = MaxRun + JumpHBoost
@export var climb_hop_x := 100.0 # ClimbHopX
@export var climb_hop_y := 120.0 # ClimbHopY
@export var climb_hop_force_time := 0.20 # ClimbHopForceTime
@export var climb_jump_boost_time := 0.20 # ClimbJumpBoostTime；Wallboost 窗口
@export var wall_slide_start_max := 20.0 # WallSlideStartMax
@export var wall_slide_time := 1.2 # WallSlideTime

@export_category("Feel")
@export var corner_correction_px := 4 # UpwardCornerCorrection
@export var dash_corner_correction_px := 4 # DashCornerCorrection
@export var wall_jump_force_time := 0.16 # WallJumpForceTime
@export var super_wall_jump_force_time := 0.20 # SuperWallJumpForceTime
@export var wall_speed_retention_time := 0.06 # WallSpeedRetentionTime；Cornerboost 的来源

@export_category("Carry")
@export var throw_speed := 160.0
@export var throw_lift := 120.0

@export_category("Debug")
@export var show_controller_debug := false

var mode := Mode.NORMAL
var dash_count := 1
var stamina := 110.0
var facing := 1.0
var is_ducking := false
var dream_dashing := false
var dream_dir := Vector2.ZERO
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
var climb_hops := 0

var _jump_buffer := 0.0
var _dash_buffer := 0.0
var _input_locked := false
var _spring_boost_timer := 0.0
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
var _max_fall := 160.0 # 参考 maxFall：会渐进到 FastMaxFall 的当前下落上限
var _wall_slide_timer := 1.2
var _wall_slide_dir := 0
var _wall_boost_timer := 0.0
var _wall_boost_dir := 0
var _wall_speed_retained := 0.0
var _wall_speed_retention_timer := 0.0
var _dash_refill_cooldown_timer := 0.0
var _floor_last_frame := false
var _event_text := ""
var _event_timer := 0.0

@onready var visuals: Node2D = $Visuals
@onready var body_rect: ColorRect = $Visuals/Body
@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var carry_anchor: Marker2D = $CarryAnchor
@onready var grab_detector: Area2D = $GrabDetector
@onready var hurtbox: Area2D = $Hurtbox
@onready var dash_pips: Array[ColorRect] = [$UI/DashPip1, $UI/DashPip2, $UI/DashPip3]
@onready var stamina_fill: ColorRect = $UI/StaminaBar/Fill
@onready var debug_label: Label = get_node_or_null("DebugLayer/ControllerDebug")
var carried_item: CarryItem

func _ready() -> void:
	# 圆形碰撞箱 = 玩家的伤害判定 hurtbox（关卡组件用 area 检测它）
	hurtbox.add_to_group("player_hurtbox")
	var ui_node := get_node_or_null("UI")
	if ui_node:
		ui_node.visible = false
	var config := get_node_or_null("/root/Config")
	if config: config.apply_to(self)
	if collider.shape: collider.shape = collider.shape.duplicate()
	_apply_hitbox()
	dash_count = max_dashes
	stamina = max_stamina
	_max_fall = max_fall_speed
	_wall_slide_timer = wall_slide_time
	_floor_last_frame = _on_ground()
	if debug_label: debug_label.visible = show_controller_debug
	_update_indicators()

# 按下事件在这里捕获：InputEvent 不受物理帧节奏影响，
# 一次两帧之间按下又松开的快速点按也不会被 is_action_just_pressed 漏掉。
func _unhandled_input(event: InputEvent) -> void:
	if not _input_locked:
		if event.is_action_pressed("jump"): _jump_buffer = jump_buffer_time
		elif event.is_action_pressed("dash"): _dash_buffer = dash_buffer_time
		elif event.is_action_pressed("grab"): _grab_pressed = true
	if event.is_action_pressed("reload_config"):
		var config := get_node_or_null("/root/Config")
		if config:
			config.reload_and_apply(self)
			_apply_hitbox()

func hitstop_frames(frames: int) -> void:
	# 用真实时间而不是渲染帧数计：高刷新率屏幕下"帧数"会短到看不见
	Engine.time_scale = 0.0
	var until := Time.get_ticks_msec() + int(round(float(frames) * 1000.0 / 60.0))
	_hitstop_end_msec = maxi(_hitstop_end_msec, until)


func freeze_frames(frames: int) -> void:
	_dash_freeze = maxf(_dash_freeze, float(frames) / 60.0)


func _physics_process(delta: float) -> void:
	# 冻结帧（hitstop）期间直接跳过玩家物理，避免 Engine.time_scale 生效前又吃到一帧重力
	if _hitstop_end_msec > 0 and Time.get_ticks_msec() < _hitstop_end_msec:
		return
	_dream_dash_lifecycle()
	if is_dashing():
		_spawn_afterimage_tick()
	if _dream_exit_timer > 0.0:
		_dream_exit_timer = maxf(0.0, _dream_exit_timer - delta)
		# 紫块冲刺出来后的短窗口内按跳 = 蔚蓝的 Dream Jump（Super）：
		# 保留冲刺水平速度，只给普通跳跃的向上速度 + JumpHBoost。
		if _jump_buffer > 0.0 and absf(dream_dir.x) > 0.01:
			_jump_buffer = 0.0
			_dream_exit_timer = 0.0
			velocity.y = -jump_speed
			# 出紫块 Super 的水平速度固定为 dream_jump_h_speed（保留冲刺方向）
			velocity.x = signf(dream_dir.x) * dream_jump_h_speed
			_var_jump_speed = velocity.y
			_var_jump_timer = var_jump_time
			_var_jump_timer = maxf(_var_jump_timer, 0.1)
			dash_count = max_dashes
			_event("DreamJump")
	if dream_dashing and _dream_time > 0.05:
		var space := get_world_2d().direct_space_state
		var from := global_position - Vector2(0, 5.5)   # 身体中心
		for _i in 4:
			var q := PhysicsRayQueryParameters2D.create(from, from + dream_dir * 10.0, 0xFFFFFFFF, [get_rid()])
			q.hit_from_inside = true
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			var hc = hit.get("collider")
			if hc != null and hc is Node and ((hc as Node).is_in_group("dream_blocks") or _is_passable_oneway(hc)):
				# 跳过紫块/可穿过的单向墙，继续向前探测（后面可能紧挨墙）
				from = (hit.get("position") as Vector2) + dream_dir * 0.5
				continue
			var hn: Vector2 = hit.get("normal", Vector2.ZERO)
			if hn.dot(dream_dir) < -0.2:
				if not _dream_try_corner_correction(hc):
					_dream_hit_solid()
				return
			break
		# 防隧穿：前方 4px 处做点查询，已经嵌进墙体也算撞墙
		if dream_dashing:
			var pq := PhysicsPointQueryParameters2D.new()
			pq.position = from + dream_dir * 4.0
			pq.collision_mask = 0xFFFFFFFF
			pq.exclude = [get_rid()]
			for r in space.intersect_point(pq, 8):
				var rc = r.get("collider")
				if rc != null and rc is Node and (rc as Node).is_in_group("dream_blocks"):
					continue
				if _is_passable_oneway(rc):
					continue
				if _dream_try_corner_correction(rc):
					return
				_dream_dash_die()
				break
	_poll_input(delta)
	_tick_timers(delta)
	_update_facing()
	match mode:
		Mode.DASH: _dash_update()
		Mode.CLIMB: _climb_update(delta)
		_: _normal_update(delta)
	if dream_dashing and _dream_dash_would_hit_solid(delta):
		if not _dream_try_corner_correction():
			_dream_hit_solid()
			velocity = Vector2.ZERO
	var pre_move_velocity := velocity
	move_and_slide()
	_resolve_collisions(pre_move_velocity)
	_resolve_collisions(pre_move_velocity)
	_update_indicators()
	_update_debug()

# 物理帧补采样：与 _unhandled_input 写同一个缓存计时器，两条路径任一命中都算按下，
# 这样 headless 回归的 Input.action_press（不产生 InputEvent）也能驱动。
func _is_passable_oneway(collider) -> bool:
	# Dream Dash 期间：单向墙的"可通过方向"在冲刺方向上的投影为正 -> 可穿过
	# （即 dot(dream_dir, pass_dir) > 0；垂直方向的单向墙投影为 0 -> 不可穿）
	if collider == null or not (collider is Node):
		return false
	if not (collider as Node).is_in_group("oneway_platforms"):
		return false
	var pd = collider.get("pass_dir")
	if pd is Vector2:
		return (pd as Vector2).dot(dream_dir) > 0.0
	return false


func _dream_dash_would_hit_solid(delta: float) -> bool:
	# 前向形状探测：下一帧身体会碰到的非紫块实体地形
	var h := _body_height()
	var center := global_position + Vector2(0.0, -h * 0.5)
	var next_center := center + dream_dir * (dream_dash_speed * delta + 0.5)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(body_width, h) - Vector2(SHAPE_INSET, SHAPE_INSET)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = rect
	params.transform = Transform2D(0.0, next_center)
	params.collision_mask = 1
	params.exclude = [get_rid()]
	for r in get_world_2d().direct_space_state.intersect_shape(params, 8):
		var c = r.get("collider")
		if c is Node and (c as Node).is_in_group("dream_blocks"):
			continue
		if _is_passable_oneway(c):
			continue
		return true
	return false


func _poll_input(delta: float) -> void:
	if not _input_locked:
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
	_spring_boost_timer = maxf(0.0, _spring_boost_timer - delta)
	# 参考 Celeste.Freeze：冻结期只有输入继续走，游戏内计时器全部停住。
	if _dash_freeze > 0.0:
		_dash_freeze = maxf(0.0, _dash_freeze - delta)
		return
	_coyote = maxf(0.0, _coyote - delta)
	_var_jump_timer = maxf(0.0, _var_jump_timer - delta)
	if _var_jump_timer <= 0.0:
		_climb_lock = maxf(0.0, _climb_lock - delta)
	dash_attack_timer = maxf(0.0, dash_attack_timer - delta)
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	_event_timer = maxf(0.0, _event_timer - delta)
	_dash_refill_cooldown_timer = maxf(0.0, _dash_refill_cooldown_timer - delta)
	if mode == Mode.DASH: dash_timer = maxf(0.0, dash_timer - delta)
	# 参考 Update 的 Wall Slide 段：wallSlideDir 每帧由重力段重新置位，这里消耗一次并衰减计时器。
	if _wall_slide_dir != 0:
		_wall_slide_timer = maxf(0.0, _wall_slide_timer - delta)
		_wall_slide_dir = 0
	# 参考 Update 顶部：空中下落时只要头顶有空间就自动站起来。
	# 离开低矮区域（头顶有空间）时立刻站起：不等到下落，上升中也会马上解除蹲姿
	if is_ducking and not _on_ground() and _can_unduck():
		_set_duck(false)
	# 参考 Update 的 Wall Boost 段：中立爬墙跳后短时间内推离墙面 = 补回体力并转成墙跳。
	# 这就是 Wallboost（无体力连续上墙）的来源；不设 forceMoveX，所以还能马上再推回墙面。
	if _wall_boost_timer > 0.0:
		_wall_boost_timer = maxf(0.0, _wall_boost_timer - delta)
		if _raw_move_x == float(_wall_boost_dir):
			velocity.x = wall_jump_speed * _raw_move_x
			stamina += climb_jump_stamina_cost
			_wall_boost_timer = 0.0
			_event("WallBoost")
	# 参考 Update 的 Wall Speed Retention 段：撞墙前的水平速度短时间内保留，离墙即还原。
	if _wall_speed_retention_timer > 0.0:
		if signf(velocity.x) == -signf(_wall_speed_retained):
			_wall_speed_retention_timer = 0.0
		elif not test_move(global_transform, Vector2(signf(_wall_speed_retained), 0.0)):
			velocity.x = _wall_speed_retained
			_wall_speed_retention_timer = 0.0
		else:
			_wall_speed_retention_timer = maxf(0.0, _wall_speed_retention_timer - delta)
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
	_update_ducking(delta)
	_apply_horizontal(delta)
	_apply_gravity(delta)
	_try_jump()

# 参考 NormalUpdate 的 Ducking 段：地面按下方向即蹲；松开后能站起来才站起，
# 站不起来且完全静止时横向挪一点让位（DuckCorrectSlide）。
func _update_ducking(delta: float) -> void:
	if is_ducking:
		if not _on_ground() or move_y > 0.0: return
		if _can_unduck():
			_set_duck(false)
			return
		if velocity.x != 0.0: return
		for i in range(duck_correct_check, 0, -1):
			if _can_unduck_at(global_position + Vector2(i, 0.0)):
				_slide_h(duck_correct_slide * delta)
				return
			if _can_unduck_at(global_position - Vector2(i, 0.0)):
				_slide_h(-duck_correct_slide * delta)
				return
	elif _on_ground() and move_y > 0.0 and velocity.y >= 0.0:
		_set_duck(true)

func _slide_h(amount: float) -> void:
	var motion := Vector2(amount, 0.0)
	if not test_move(global_transform, motion): global_position += motion

func _try_unduck() -> bool:
	# 只有在头顶有空间时才站起来：一格高的通道里强行站起来会把碰撞盒撑进天花板/墙里卡住
	if not is_ducking:
		return true
	if _can_unduck():
		_set_duck(false)
		return true
	return false


func _set_duck(value: bool) -> void:
	if is_ducking == value: return
	is_ducking = value
	_apply_hitbox()

func _body_height() -> float:
	return duck_height if is_ducking else stand_height

# 参考 Ducking 的 setter：碰撞盒底边固定在脚下，只换高度，所以蹲伏切换不会挪动角色。
# 物理盒宽度比逻辑宽度内缩 SHAPE_INSET：Godot 不允许零间隙通行，8px 宽的身体钻 1 砖宽的缝
# 会被两侧同时贴住而卡死；留 0.1px/侧 的间隙即可通过，检测仍按 body_width 的整数语义走。
func _apply_hitbox() -> void:
	var height := _body_height()
	var rect := collider.shape as RectangleShape2D
	if rect: rect.size = Vector2(body_width - SHAPE_INSET, height)
	collider.position = Vector2(0.0, -height * 0.5)
	if is_instance_valid(body_rect):
		body_rect.offset_left = -body_width * 0.5
		body_rect.offset_right = body_width * 0.5
		body_rect.offset_top = -height

# 参考 CanUnDuck / CanUnDuckAt：把碰撞盒换成站立尺寸，看头顶是否被顶住。
func _can_unduck() -> bool:
	return _can_unduck_at(global_position)

func _can_unduck_at(at: Vector2) -> bool:
	if not is_ducking: return true
	return not _box_is_solid(at + Vector2(0.0, -stand_height * 0.5), Vector2(body_width, stand_height))

# 参考 Update 顶部的 onGround：`Speed.Y >= 0 && CollideCheck<Solid>(Position + UnitY)` —— 是**几何探针**，
# 不是"本帧有没有撞到地面"。Godot 的 is_on_floor() 属于后者：水平 Dash（vy=0 且关重力）、
# 贴地滑行这类帧里根本没有向下位移，is_on_floor() 会变 false，于是 dash 次数、体力、土狼全都补不回来
# —— Super / Hyper / Wavedash 之后 dash 不恢复就是这个原因。所有"是否站在地上"的判定统一走这里。
func _on_ground() -> bool:
	if velocity.y < 0.0: return false
	return _box_is_solid(global_position + Vector2(0.0, 1.0 - _body_height() * 0.5), Vector2(body_width, _body_height()))

# 参考 CollideCheck<Solid>：把当前碰撞盒整箱挪到 at 处，看是否无阻挡。
func _body_fits_at(at: Vector2) -> bool:
	var height := _body_height()
	return not _box_is_solid(at + Vector2(0.0, -height * 0.5), Vector2(body_width, height))

func _box_is_solid(center: Vector2, size: Vector2) -> bool:
	var rect := RectangleShape2D.new()
	rect.size = size - Vector2(SHAPE_INSET, SHAPE_INSET)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = rect
	params.transform = Transform2D(0.0, center)
	params.collision_mask = collision_mask
	params.collide_with_areas = false
	params.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()

# 参考 DashUpdate：Dash 期间速度只在起手写一次，本函数只做冻结、起速与跳跃派生技巧。
func _dash_update() -> void:
	# 参考 DashBegin 的 Celeste.Freeze(.05)：冻结期原地不动，方向键还能继续补按。
	if _dash_freeze > 0.0 and not dream_dashing:
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
	if _wall_jump_check_dash(1):
		_wall_jump(-1, super_wall)
		return true
	if _wall_jump_check_dash(-1):
		_wall_jump(1, super_wall)
		return true
	return false


func _wall_jump_check_dash(direction: int) -> bool:
	if velocity.x * float(direction) < -20.0:
		return false
	return test_move(global_transform, Vector2(direction, 0.0) * dash_wall_check_distance)

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
			if _on_ground():
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

# 参考 SlipCheck：探针在面墙一侧的头顶与其下 4px 处，两点都空才算手已高过墙沿。
func _slip_check(add_y := 0.0) -> bool:
	var probe_x := global_position.x + facing * (body_width * 0.5 + 1.0)
	var top := global_position.y - _body_height() + add_y
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
	# 弹簧弹出后的短时间内不被空中加速度/摩擦力吃掉水平速度
	if _spring_boost_timer > 0.0:
		return
	var grounded := _on_ground()
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
	# 参考 Vertical 段的 maxFall：按住下方向且已达 MaxFall 时，下落上限渐进到 FastMaxFall。
	var target_max_fall := max_fall_speed
	if move_y > 0.0 and velocity.y >= max_fall_speed:
		target_max_fall = fast_max_fall_speed
	_max_fall = move_toward(_max_fall, target_max_fall, fast_max_accel * delta)
	if not _on_ground():
		var limit := _max_fall
		# 参考 Wall Slide：推向墙面（或无方向按住抓取）且没按下时，沿墙下落被压到 WallSlideStartMax。
		if (move_x == facing or (move_x == 0.0 and Input.is_action_pressed("grab"))) and move_y <= 0.0:
			if velocity.y >= 0.0 and _wall_slide_timer > 0.0 and carried_item == null \
					and _can_unduck() and test_move(global_transform, Vector2(facing, 0.0)):
				_set_duck(false)
				_wall_slide_dir = int(facing)
				if _wall_slide_dir != 0:
					limit = lerpf(max_fall_speed, wall_slide_start_max, _wall_slide_timer / wall_slide_time)
		var mult := 1.0
		if absf(velocity.y) < half_gravity_threshold and Input.is_action_pressed("jump"):
			mult = 0.5
		velocity.y = move_toward(velocity.y, limit, gravity * mult * delta)
	if _var_jump_timer > 0.0:
		if Input.is_action_pressed("jump"): velocity.y = minf(velocity.y, _var_jump_speed)
		else: _var_jump_timer = 0.0

func _try_jump() -> void:
	if is_ducking: return
	if _jump_buffer <= 0.0: return
	if _coyote > 0.0:
		_jump()
		return
	# 参考 NormalUpdate 的 Jumping 段：墙跳要求能站起来；检测顺序先右后左。
	if not _can_unduck(): return
	if _wall_jump_check(1): _jump_off_wall(1)
	elif _wall_jump_check(-1): _jump_off_wall(-1)

# 参考 NormalUpdate 的墙跳分支：面朝墙且按住抓取还有体力 = 垂直爬墙跳（不会被弹离墙面），
# 纯上 Dash 攻击中撞墙 = SuperWallJump，其余才是普通墙跳。
func _jump_off_wall(wall: int) -> void:
	if facing == float(wall) and Input.is_action_pressed("grab") and stamina > 0.0 and carried_item == null:
		_climb_jump()
	elif dash_attack_timer > 0.0 and dash_dir.x == 0.0 and dash_dir.y < 0.0:
		_wall_jump(-wall, true)
	else:
		_wall_jump(-wall, false)

func _jump() -> void:
	_consume_jump()
	_try_unduck()
	velocity.y = -jump_speed
	velocity.x += jump_speed_boost * move_x
	_var_jump_speed = velocity.y
	_spawn_jump_dust(0.0)
	_event("Jump")

# 参考 SuperJump：Ducking 时乘 Duck 倍率，这就是 Hyper / Ultra 的真实来源。
func _super_jump() -> void:
	_consume_jump()
	velocity.x = super_jump_speed * facing
	velocity.y = -jump_speed
	if is_ducking:
		_try_unduck()
		velocity.x *= duck_super_jump_x_mult
		velocity.y *= duck_super_jump_y_mult
		_event("Hyper" if dash_started_on_ground else "Ultra")
	else:
		_event("Super")
	_spawn_jump_dust(float(facing))
	_var_jump_speed = velocity.y
	mode = Mode.NORMAL

func _wall_jump(direction: int, super_wall: bool) -> void:
	_consume_jump()
	_try_unduck()
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
	_spawn_jump_dust(float(direction))
	_event("SuperWallJump" if super_wall else "WallJump")
	mode = Mode.NORMAL

# 参考 ClimbJump：垂直起跳、不推离墙面，离地时才扣体力。
# 无方向输入的中立爬墙跳会武装 Wallboost 窗口：窗口内推离墙面即退回这次体力消耗。
func _climb_jump() -> void:
	mode = Mode.NORMAL
	if not _on_ground():
		stamina = maxf(0.0, stamina - climb_jump_stamina_cost)
	_jump()
	if move_x == 0.0:
		_wall_boost_dir = -int(facing)
		_wall_boost_timer = climb_jump_boost_time
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

func _spawn_jump_dust(dir: float) -> void:
	if not is_instance_valid(self) or get_parent() == null:
		return
	var dust := JUMP_DUST.new()
	get_parent().add_child(dust)
	if dust.has_method("setup"):
		dust.call("setup", global_position + Vector2(0, -1), dir, 6)


func _consume_jump() -> void:
	_jump_buffer = 0.0
	_coyote = 0.0
	dash_attack_timer = 0.0
	_var_jump_timer = var_jump_time
	# 参考各 Jump 函数末尾：每次起跳都把沿墙下滑计时器重置满、并作废 Wallboost 窗口。
	_wall_slide_timer = wall_slide_time
	_wall_boost_timer = 0.0

# 参考 DashBegin：起手只清速度与方向并进入冻结，真正起速留给 _launch_dash。
func _try_start_dash() -> bool:
	if dream_dashing:
		return false
	if _dash_buffer <= 0.0 or dash_count <= 0 or dash_cooldown_timer > 0.0: return false
	_dash_buffer = 0.0
	dash_count -= 1
	# 参考 DashBegin 3445：`dashStartedOnGround = onGround`，只看几何探针，不吃土狼时间
	# （多算土狼会把"跑出台沿再斜下冲"误判成 Hyper，也会关掉 Dash 撞地角落修正）
	dash_started_on_ground = _on_ground()
	before_dash_speed = velocity
	dash_dir = Vector2.ZERO
	velocity = Vector2.ZERO
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_attack_timer = dash_attack_time
	_dash_freeze = 5.0 / 60.0   # 冲刺起手冻结 5 帧
	_dash_refill_cooldown_timer = dash_refill_cooldown
	_wall_slide_timer = wall_slide_time
	mode = Mode.DASH
	# 参考 DashBegin：空中起手的 Dash 只要能站起来就取消蹲伏。
	if not _on_ground() and _can_unduck(): _set_duck(false)
	_event("Dash")
	return true

# 参考 DashCoroutine：冻结结束后才读方向、写速度，同向更快的旧速度保留，绝不降速。
func _on_dream_block_below() -> bool:
	# 站在紫块上：脚底下方 1px 的点落在紫块内
	var foot_probe := global_position + Vector2(0.0, 1.0)
	for db in get_tree().get_nodes_in_group("dream_blocks"):
		if db.has_method("contains_center") and bool(db.call("contains_center", foot_probe)):
			return true
	return false


func _launch_dash() -> void:
	dash_dir = get_dash_direction()
	var new_speed := dash_dir * dash_speed
	if signf(before_dash_speed.x) == signf(new_speed.x) and absf(before_dash_speed.x) > absf(new_speed.x):
		new_speed.x = before_dash_speed.x
	velocity = new_speed
	if dash_dir.x != 0.0:
		facing = signf(dash_dir.x)
		visuals.scale.x = facing
	if _on_ground() and dash_dir.x != 0.0 and dash_dir.y > 0.0 and velocity.y > 0.0 \
			and not _on_dream_block_below():
		_dash_slide()

# 参考 Dash Slide：斜下 Dash 触地转为水平 Dash 并提速，绝不清零水平速度。
func _dash_slide() -> void:
	dash_dir = Vector2(signf(dash_dir.x), 0.0)
	velocity.y = 0.0
	velocity.x *= dodge_slide_speed_mult
	_set_duck(true)
	_event("DashSlide")

func _finish_dash() -> void:
	if dash_dir.y <= 0.0: velocity = dash_dir * dash_end_speed
	if velocity.y < 0.0: velocity.y *= end_dash_up_mult
	mode = Mode.NORMAL
	_event("Dash end")

func _try_start_climb() -> bool:
	# 参考 NormalUpdate 的 Climbing 段：持物、体力耗尽或蹲着起不来时不能抓墙。
	if not Input.is_action_pressed("grab") or carried_item != null or stamina <= 0.0 or not _can_unduck():
		return false
	# 上升中或正在离墙时不许抓墙。缺这条，翻墙 hop 刚起跳就会被重新抓住 → 反复 hop 把体力抽干。
	if velocity.y < 0.0 or signf(velocity.x) == -facing: return false
	# 参考 ClimbCheck：只检测面朝一侧，距离用 ClimbCheckDist。
	var wall := get_climb_wall_direction()
	if wall == 0: return false
	mode = Mode.CLIMB
	facing = wall
	visuals.scale.x = facing
	_set_duck(false)
	velocity.x = 0.0
	velocity.y *= climb_grab_y_mult
	_climb_lock = climb_no_move_time
	_wall_slide_timer = wall_slide_time
	_snap_to_wall(wall)
	_event("Climb")
	return true

# 参考 ClimbBegin 末尾：贴向墙面，抓墙后角色与墙之间不留空隙。
# Godot 的 test_move 默认 safe_margin 0.08 会把"刚好贴上"也算命中，所以这里用 move_and_collide
# 直接推到接触为止；差一像素会让 SlipCheck 的探针落在墙面边界上，判成手已过墙沿而下滑。
func _snap_to_wall(direction: int) -> void:
	var col := move_and_collide(Vector2(direction, 0.0) * climb_check_distance, false, CONTACT_MARGIN)
	if col:
		# 物理碰撞盒比视觉窄 SHAPE_INSET（每侧 0.5px），直接贴墙会让角色视觉插进墙 1px
		# （刚好是地形描边宽度）。贴墙后按半个 inset 往回让一点，让视觉边缘正好贴住墙面。
		global_position.x -= float(direction) * SHAPE_INSET * 0.5

func _resolve_collisions(pre_move_velocity: Vector2) -> void:
	# landed 用 onGround 的前后沿：水平 Dash 期间 onGround 一直为真，所以不会被误判成刚落地。
	var on_ground := _on_ground()
	var landed := on_ground and not _floor_last_frame
	var corrected := false
	if pre_move_velocity.y < 0.0 and is_on_ceiling():
		_upward_corner_correction(pre_move_velocity)
	elif landed and pre_move_velocity.y > 0.0 and mode == Mode.DASH:
		if not dash_started_on_ground and _dash_corner_correction(pre_move_velocity):
			corrected = true
		elif dash_dir.x != 0.0 and dash_dir.y > 0.0:
			_dash_slide()
	var grounded := on_ground and not corrected
	if grounded:
		_coyote = coyote_time
		# 参考 Update 的 Dashes 段：落地补 dash 要等 DashRefillCooldown，这是 Extended Dash 的窗口。
		if _dash_refill_cooldown_timer <= 0.0: dash_count = max_dashes
		# 参考 After Dash 段：攀爬状态不吃地面回体力。
		if mode != Mode.CLIMB:
			stamina = max_stamina
			_wall_slide_timer = wall_slide_time
	# 参考 OnCollideH 的 Speed retention：撞墙瞬间存下水平速度，Cornerboost 的来源。
	if is_on_wall() and _wall_speed_retention_timer <= 0.0 and pre_move_velocity.x != 0.0:
		_wall_speed_retained = pre_move_velocity.x
		_wall_speed_retention_timer = wall_speed_retention_time
	if mode == Mode.DASH and dash_timer <= 0.0: _finish_dash()
	_floor_last_frame = grounded

# 参考 OnCollideV 的 UpwardCornerCorrection：上升撞顶时逐像素横移穿过角落。
# 参考里用的是 CollideCheck（目标位置整箱重叠），不是扫掠检测：8px 宽的角色钻 8px 宽的缝
# 在扫掠里会被两侧墙擦到而判定失败，整箱重叠检测才能穿过。
func _upward_corner_correction(pre_move_velocity: Vector2) -> void:
	var directions: Array[int] = []
	if pre_move_velocity.x <= 0.0: directions.append(-1)
	if pre_move_velocity.x >= 0.0: directions.append(1)
	for direction in directions:
		for i in range(1, corner_correction_px + 1):
			var at := global_position + Vector2(direction * i, -1.0)
			if _body_fits_at(at):
				global_position = at
				velocity.y = pre_move_velocity.y
				corner_corrections += 1
				_event("CornerCorrect")
				return
	if _var_jump_timer < var_jump_time - ceiling_var_jump_grace:
		_var_jump_timer = 0.0

# 参考 OnCollideV 的 DashCornerCorrection：空中起手的 Dash 撞地角时横移让位。
func _dash_corner_correction(pre_move_velocity: Vector2) -> bool:
	var directions: Array[int] = []
	if pre_move_velocity.x <= 0.0: directions.append(-1)
	if pre_move_velocity.x >= 0.0: directions.append(1)
	for direction in directions:
		for i in range(1, dash_corner_correction_px + 1):
			var at := global_position + Vector2(direction * i, 1.0)
			if _body_fits_at(at):
				global_position = at
				velocity = pre_move_velocity
				_event("DashCorner")
				return true
	return false

func get_move_input() -> Vector2:
	return Vector2(move_x, move_y)


func get_dash_direction() -> Vector2:
	# 参考 Input.GetAimVector：无方向输入时退回面朝方向；用原始输入，不受 forceMoveX 影响。
	var direction := Vector2(_raw_move_x, move_y)
	return (direction if direction != Vector2.ZERO else Vector2(facing, 0.0)).normalized()

# 参考 WallJumpCheck：以 WallJumpCheckDist 做整箱检测。
func _wall_jump_check(direction: int) -> bool:
	# 预输入保护：如果人已经在往远离墙的方向移动，就不再判定为墙跳
	if velocity.x * float(direction) < -20.0:
		return false
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
	if is_instance_valid(body_rect):
		body_rect.color = BODY_CRYSTAL_COLOR if dash_count > 0 else BODY_NO_DASH_COLOR
	if not is_instance_valid(stamina_fill): return
	for index in dash_pips.size():
		dash_pips[index].visible = index < max_dashes
		dash_pips[index].color = Color("f7d65a") if index < dash_count else Color("4d5261")
	var bar: ColorRect = stamina_fill.get_parent()
	stamina_fill.size.x = bar.size.x * clampf(stamina / maxf(max_stamina, 0.001), 0.0, 1.0)

func is_attacking() -> bool:
	# 可破坏方块判定：冲刺攻击窗口内 或 速度超过阈值
	return dash_attack_timer > 0.0 or velocity.length() >= attack_speed_threshold


func set_facing(direction: float) -> void:
	facing = signf(direction)
	if visuals:
		visuals.scale.x = facing


func apply_spring_boost(duration: float = 0.25) -> void:
	_spring_boost_timer = maxf(_spring_boost_timer, duration)
	# 弹簧发射时打断冲刺/爬墙：否则冲刺结束会重置速度、爬墙每帧覆写竖直速度
	mode = Mode.NORMAL
	_dash_freeze = 0.0
	_force_move_x_timer = 0.0
	_wall_slide_timer = wall_slide_time


func set_input_locked(value: bool) -> void:
	_input_locked = value
	if value:
		_jump_buffer = 0.0
		_dash_buffer = 0.0
		_grab_pressed = false


func refill_dash() -> void:
	# 冲刺水晶：完全恢复冲刺次数与体力
	dash_count = max_dashes
	stamina = max_stamina

var _dream_block: Node = null
var _dream_exceptions: Array = []
var _dream_last_pos := Vector2.ZERO
var _dream_stall := 0.0
var _dream_time := 0.0
var _dream_entered := false
var _dream_saved_mask := 1
var _dream_exit_timer := 0.0
var _dream_correct_timer := 0.0
var _hitstop_end_msec := 0
var _stamina_flash_timer := 0.0
var _afterimage_tick := 0
var _stamina_flash_red := false


func dash_input_dir() -> Vector2:
	return Vector2(move_x, move_y)


func is_dash_pressed() -> bool:
	# 冲刺按下的缓冲窗口（顶头贴块时 dash 可能被立刻取消，但按键仍在缓冲里）
	return _dash_buffer > 0.0


func is_dream_dashing() -> bool:
	return dream_dashing


func is_dashing() -> bool:
	return mode == Mode.DASH and dash_timer > 0.0


func start_dream_dash(dir: Vector2, block: Node = null) -> void:
	# Dream Block：冲刺穿过时保持方向持续冲刺；只对这个方块加碰撞例外（其他碰撞照常）
	dream_dashing = true
	_dream_block = block
	dream_dir = dir.normalized() if dir.length() > 0.01 else Vector2(facing, 0.0)
	mode = Mode.DASH
	dash_dir = dream_dir
	dash_timer = 999.0
	_dash_buffer = 0.0
	_jump_buffer = 0.0   # 清掉进入紫块前残留的跳跃缓冲，避免不按跳也自动跳出
	_dash_freeze = 0.0   # 进紫块不保留冲刺冻结帧
	_dream_saved_mask = collision_mask
	# 冲刺穿过期间无视碰撞（紫块由例外处理）；实体地形用每帧前向形状探测挡住，
	# 保证身体不会进入墙里（见 _dream_dash_would_hit_solid）。
	collision_mask = 0
	_dream_time = 0.0
	_dream_entered = false
	_dream_correct_timer = 0.0
	# 清理攀爬/贴墙/外力残留，避免先回弹再冲进去
	_grab_pressed = false
	_wall_slide_dir = 0
	_force_move_x = 0.0
	_force_move_x_timer = 0.0
	_wall_boost_timer = 0.0
	_wall_speed_retention_timer = 0.0
	velocity = dream_dir * dream_dash_speed
	_dream_last_pos = global_position
	_dream_stall = 0.0
	_dream_exceptions.clear()
	for db in get_tree().get_nodes_in_group("dream_blocks"):
		if db is CollisionObject2D:
			add_collision_exception_with(db)
			_dream_exceptions.append(db)
	if block is CollisionObject2D and not _dream_exceptions.has(block):
		add_collision_exception_with(block)
		_dream_exceptions.append(block)


func end_dream_dash(block: Node = null) -> void:
	if not dream_dashing:
		return
	dream_dashing = false
	_dream_exit_timer = 0.12
	collision_mask = _dream_saved_mask if _dream_saved_mask != 0 else 1
	dash_timer = 0.0
	mode = Mode.NORMAL
		# 出块保持原速；跳跃按普通跳跃规则处理（不再有特殊的超级跳）
	velocity = dream_dir * dream_dash_speed   # 离开方块保持原速
	dash_count = max_dashes
	stamina = max_stamina
	for db in _dream_exceptions:
		if is_instance_valid(db):
			remove_collision_exception_with(db)
	_dream_exceptions.clear()
	_dream_block = null
	# 若结束时身体已经和实体地形重叠（冲刺方向撞进墙），直接死亡
	if is_inside_tree() and _body_overlaps_solid():
		_dream_dash_die()


func _dream_dash_die() -> void:
	if dream_dashing:
		end_dream_dash()
	dash_timer = 0.0
	mode = Mode.NORMAL
	var lvl := get_parent()
	if lvl and lvl.has_method("respawn_player"):
		lvl.call("respawn_player")


func _try_dream_reverse_grab() -> bool:
	# 紫块冲刺结束瞬间：反方向 + 抓 → 取消冲刺并反向抓在紫块侧面上
	if absf(dream_dir.x) < 0.01:
		return false
	if not Input.is_action_pressed("grab"):
		return false
	var back := -signf(dream_dir.x)
	var raw := Input.get_axis("move_left", "move_right")
	if signf(raw) != back:
		return false
	end_dream_dash()
	_dream_exit_timer = 0.0
	velocity = Vector2.ZERO
	facing = back
	visuals.scale.x = facing
	if _try_start_climb():
		_event("DreamReverseGrab")
		return true
	return false


func _dream_inside_block() -> bool:
	for db in get_tree().get_nodes_in_group("dream_blocks"):
		if db.has_method("player_inside") and bool(db.call("player_inside", self)):
			return true
	return false


func _dream_body_fits(at: Vector2) -> bool:
	# 用 saved mask（dream dash 期间 collision_mask 为 0，不能直接用它查询）
	var mask := _dream_saved_mask if _dream_saved_mask != 0 else 1
	var h := _body_height()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(body_width, h) - Vector2(SHAPE_INSET, SHAPE_INSET)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = rect
	params.transform = Transform2D(0.0, at + Vector2(0.0, -h * 0.5))
	params.collision_mask = mask
	params.collide_with_areas = false
	params.exclude = [get_rid()]
	for r in get_world_2d().direct_space_state.intersect_shape(params, 8):
		var c = r.get("collider")
		if c is Node and (c as Node).is_in_group("dream_blocks"):
			continue
		if _is_passable_oneway(c):
			continue
		return false
	return true


func _dream_try_corner_correction(blocking: Node = null) -> bool:
	# 参考蔚蓝 DreamDashCheck：在紫块内撞到角落时，垂直方向最多让 4px 对齐通道。
	# 只在身体仍与紫块重叠时生效，避免在普通墙壁前"滑"过去。
	if blocking != null and (blocking.is_in_group("dream_blocks") or _is_passable_oneway(blocking)):
		# 紫块/可穿过单向墙不作为角落修正对象
		return false
	if _dream_correct_timer > 0.0:
		# 刚修正完又被挡住：说明这不是"错位"而是真撞墙，交给撞墙判定
		return false
	if not _dream_inside_block():
		return false
	var perp := Vector2(absf(dream_dir.y), absf(dream_dir.x))
	if perp.length() < 0.01:
		return false
	var pref := 0.0
	if perp.y > 0.5:
		pref = signf(move_y)
	else:
		pref = signf(move_x)
	var offsets: Array = []
	if pref < 0.0:
		offsets = [-1, -2, -3, -4, 1, 2, 3, 4]
	elif pref > 0.0:
		offsets = [1, 2, 3, 4, -1, -2, -3, -4]
	else:
		offsets = [-1, 1, -2, 2, -3, 3, -4, 4]
	for step in offsets:
		var cand: Vector2 = global_position + perp * float(step)
		if not _dream_body_fits(cand):
			continue
		if not _dream_body_fits(cand + dream_dir * 2.0):
			continue
		global_position = cand
		_dream_last_pos = cand
		_dream_correct_timer = 3.0 / 60.0   # 修正后 3 帧内不再尝试，避免对角微修正死循环
		_event("DreamCorner")
		return true
	return false


func _dream_dash_lifecycle() -> void:
	# Dream Dash 只有在完全离开所有紫块后才结束（对厚墙/贴脸/斜向都适用）
	if not dream_dashing:
		return
	_dream_correct_timer = maxf(0.0, _dream_correct_timer - get_physics_process_delta_time())
	velocity = dream_dir * dream_dash_speed
	_dream_time += get_physics_process_delta_time()
	var moved := global_position.distance_to(_dream_last_pos)
	_dream_last_pos = global_position
	if moved < 0.15:
		_dream_stall += get_physics_process_delta_time()
		if _dream_stall > 0.12:
			_dream_dash_die()
			return
	else:
		_dream_stall = 0.0
	# 刚触发时人在方块外（接近范围）→ 先允许它进入方块；
	# 进入过方块后才以"是否为玩家在方块内"作为结束条件，防止刚触发就结束
	var near := false
	var inside := false
	for db in get_tree().get_nodes_in_group("dream_blocks"):
		if db.has_method("player_near") and bool(db.call("player_near", self)):
			near = true
		if db.has_method("player_inside") and bool(db.call("player_inside", self)):
			inside = true
	if inside:
		_dream_entered = true
	if _dream_entered:
		if not inside:
			# 出块瞬间：按住反方向 + 抓 → 反向抓住紫块，而不是保持原速冲出去
			if _try_dream_reverse_grab():
				return
			end_dream_dash()
	else:
		if not near:
			end_dream_dash()


func _wall_is_dream_block() -> bool:
	# 攀爬在紫块上往里冲刺时，is_on_wall 指向的其实是紫块本身，不能算撞墙
	var wn := get_wall_normal()
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var c := col.get_collider()
		if c != null and c.is_in_group("dream_blocks") and col.get_normal().dot(wn) > 0.7:
			return true
	return false


func _body_overlaps_solid() -> bool:
	# 只统计"硬实体"：紫块和当前冲刺方向上可穿过的单向墙不算卡墙
	var h := _body_height()
	var center := global_position + Vector2(0.0, -h * 0.5)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(body_width, h) - Vector2(SHAPE_INSET, SHAPE_INSET)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = rect
	params.transform = Transform2D(0.0, center)
	params.collision_mask = collision_mask
	params.collide_with_areas = false
	params.exclude = [get_rid()]
	for r in get_world_2d().direct_space_state.intersect_shape(params, 8):
		var c = r.get("collider")
		if c is Node and (c as Node).is_in_group("dream_blocks"):
			continue
		if _is_passable_oneway(c):
			continue
		return true
	return false


func _dream_hit_solid() -> void:
	# 身体中心在紫块内 → 撞墙死亡；否则只是身体一部分擦到地形，应被挡住
	var c := global_position - Vector2(0, 5.5)
	for db in get_tree().get_nodes_in_group("dream_blocks"):
		if db.has_method("contains_center") and bool(db.call("contains_center", c)):
			_dream_dash_die()
			return
	end_dream_dash()
	# 撞出紫块时已经嵌进地形：直接死亡，避免卡在墙里
	if _body_overlaps_solid():
		_dream_dash_die()


func _process(_delta: float) -> void:
	_update_stamina_flash(_delta)
	if _hitstop_end_msec > 0 and Time.get_ticks_msec() >= _hitstop_end_msec:
		_hitstop_end_msec = 0
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _update_stamina_flash(delta: float) -> void:
	# 体力 <=30%：每 0.4s 红闪一次；<=10%：每 0.2s 红闪一次
	if visuals == null:
		return
	var ratio := stamina / maxf(max_stamina, 0.001)
	if ratio <= 0.3:
		var period := 0.2 if ratio <= 0.1 else 0.4
		_stamina_flash_timer += delta
		if _stamina_flash_timer >= period * 0.5:
			_stamina_flash_timer = 0.0
			_stamina_flash_red = not _stamina_flash_red
		visuals.modulate = Color(1.0, 0.35, 0.35) if _stamina_flash_red else Color.WHITE
	else:
		if _stamina_flash_red:
			_stamina_flash_red = false
			visuals.modulate = Color.WHITE
		_stamina_flash_timer = 0.0


func _spawn_afterimage_tick() -> void:
	# 致敬历史上 1ecaa21 的冲刺残影：每 3 帧留一个半透明淡出残像
	_afterimage_tick += 1
	if _afterimage_tick % 3 != 0:
		return
	if visuals == null or get_parent() == null:
		return
	var holder := Node2D.new()
	holder.z_index = z_index - 1
	for src in visuals.get_children():
		if src is ColorRect:
			var dup: ColorRect = src.duplicate()
			dup.color = Color(0.55, 0.82, 1.0, 0.5)
			holder.add_child(dup)
	get_parent().add_child(holder)
	holder.global_transform = visuals.global_transform
	var tween := holder.create_tween()
	tween.tween_property(holder, "modulate:a", 0.0, 0.22)
	tween.tween_callback(holder.queue_free)
