class_name Player
extends CharacterBody2D
## 玩家角色。手感参数全部 @export 化（TDD §4.2），供参数仪表盘绑定。
## 状态逻辑在 states/ 下；本脚本提供共享的移动/跳跃/重力/修正等物理帮助函数。
## 物理规则须满足 TDD §4.6 高级技巧涌现条件（冲刺保速、起跳+40、落地宽限等）。

@export_category("Movement")
@export var max_speed: float = 180.0         ## 地面最高速度 = 12 格/秒（调大 → 跑得更快）
@export var acceleration: float = 2000.0     ## 地面加速度（0.09s 到满速，大 → 起步更干脆）
@export var deceleration: float = 2400.0     ## 地面减速度（0.075s 刹停，大 → 停止更干脆）
@export var air_accel_mult: float = 0.9      ## 空中加速度倍率（<1 → 空中操控略钝）
@export var over_speed_decel: float = 300.0  ## 超速衰减：>|max_speed| 时的缓慢衰减（保动量，兔子跳的土壤）

@export_category("Jump")
@export var jump_force: float = 450.0        ## 起跳速度（调大 → 跳得更高；当前约 4.5 格）
@export var jump_cut_mult: float = 0.45      ## 松键截断：上升中松开跳跃键 vy *= 此值（0~1，越小可变跳高范围越大）
@export var jump_speed_boost: float = 40.0   ## 起跳水平加成（TDD §4.6 兔子跳根源，Celeste 参考 +40）

@export_category("Gravity")
@export var gravity: float = 1500.0          ## 基础重力（大 → 跳跃更锐利不飘）
@export var fall_gravity_mult: float = 1.6   ## 下落重力倍率（>1 → 下落更快更扎实）
@export var apex_gravity_mult: float = 0.55  ## 顶点重力倍率（<1 → 顶点悬浮感）
@export var apex_threshold: float = 50.0     ## 顶点判定：|vy| 小于此值视为处于顶点
@export var max_fall_speed: float = 400.0    ## 最大下落速度

@export_category("Dash")
@export var max_dashes: int = 1             ## 最大冲刺次数（落地时恢复）
@export var dash_speed: float = 420.0       ## 冲刺速度（大 → 位移更远）
@export var dash_duration: float = 0.15     ## 冲刺固定持续时间（秒）
@export var dash_freeze_time: float = 0.04  ## 冲刺起手停顿（秒；仅冻结玩家）
@export var dash_end_speed: float = 240.0   ## 冲刺结束保留速度（保 Super/动量）
@export var dash_attack_time: float = 0.3   ## 冲刺攻击窗口（支持 Super / 墙跳）
@export var super_jump_speed: float = 260.0 ## 水平冲刺期间跳跃速度（Celeste Super）
@export var ultra_min_speed: float = 170.0  ## Ultra 生效的最低水平速度
@export var ultra_speed_mult: float = 1.2   ## 斜下冲刺落地水平速度倍率
@export var cb_bonus_speed: float = 40.0    ## 冲刺墙跳保速奖励

@export_category("Climb")
@export var max_stamina: float = 110.0          ## 最大体力（落地恢复）
@export var climb_grab_y_mult: float = 0.2      ## 抓墙瞬间纵向速度保留倍率
@export var climb_no_move_time: float = 0.1     ## 抓墙后短暂滑落延迟
@export var climb_up_speed: float = 45.0        ## 向上攀爬速度
@export var climb_down_speed: float = 80.0      ## 向下攀爬速度
@export var climb_slip_speed: float = 30.0      ## 无输入时滑落速度
@export var climb_acceleration: float = 900.0   ## 攀爬纵向加速度
@export var climb_up_stamina_cost: float = 45.0 ## 向上攀爬每秒体力消耗
@export var climb_still_stamina_cost: float = 10.0 ## 静止/滑落每秒体力消耗
@export var climb_jump_stamina_cost: float = 27.5 ## 爬墙跳体力消耗
@export var wall_check_distance: float = 3.0    ## 墙体探测距离
@export var wall_jump_speed: float = 220.0      ## 墙跳水平弹射速度
@export var wall_jump_force: float = 450.0      ## 墙跳向上速度
@export var climb_hop_x: float = 100.0          ## 翻越墙顶时的水平推出速度
@export var climb_hop_y: float = 120.0          ## 翻越墙顶时的向上速度

@export_category("Feel")
@export var coyote_time: float = 0.1         ## 土狼时间：走出边缘后仍可起跳的宽限（秒）
@export var jump_buffer_time: float = 0.12   ## 输入缓存：落地前按跳，落地瞬间自动起跳（秒）
@export var corner_correction_px: float = 8.0 ## 角落修正：跳跃撞头时横向可挤出的最大像素

@export_category("Carry")
@export var throw_speed: float = 300.0      ## 抛出水平速度
@export var throw_lift: float = 220.0       ## 抛出初始向上速度

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var dash_count: int = 1
var stamina: float = 110.0
var facing: float = 1.0
var dash_direction := Vector2.ZERO
var dash_attack_timer: float = 0.0
var _ultra_pending := false
var _climb_no_move_timer: float = 0.0

@onready var state_machine: Node = $StateMachine
@onready var visuals: Node2D = $Visuals
@onready var carry_anchor: Marker2D = $CarryAnchor
@onready var grab_detector: Area2D = $GrabDetector

var carried_item: CarryItem

func _ready() -> void:
	_load_config()
	dash_count = max_dashes
	stamina = max_stamina

func _physics_process(delta: float) -> void:
	_update_timers(delta)

func _unhandled_input(event: InputEvent) -> void:
	# F5：热重载 CSV 参数（无需重启 Godot）
	if event.is_action_pressed("reload_config"):
		var config := get_node_or_null("/root/Config")
		if config:
			config.reload_and_apply(self)
		return
	# 持物时 Shift 优先抛出；否则拾取最近物品。墙抓由 Air 在无持物、无可拾取物时处理。
	if event.is_action_pressed("grab"):
		if carried_item:
			throw_carried_item()
		else:
			pick_up_nearest_item()
		return
	# 跳跃按下：写入输入缓存（由地面/空中状态消费）
	if event.is_action_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	# 跳跃松开：上升中截断 → 可变跳高
	elif event.is_action_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_mult

func _load_config() -> void:
	var config := get_node_or_null("/root/Config")
	if config:
		config.apply_to(self)
	else:
		push_warning("Player: Config autoload 未找到，使用 @export 默认值")

func _update_timers(delta: float) -> void:
	_coyote_timer = maxf(0.0, _coyote_timer - delta)
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	dash_attack_timer = maxf(0.0, dash_attack_timer - delta)
	_climb_no_move_timer = maxf(0.0, _climb_no_move_timer - delta)
	# 在地面持续刷新土狼时间（本帧读取的是上一帧 move 后的碰撞结果，时序正确）
	if is_on_floor():
		_coyote_timer = coyote_time
		dash_count = max_dashes
		stamina = max_stamina
	# 朝向翻转（灰盒期仅翻转 Visuals 指示）
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		facing = signf(dir)
	if dir != 0.0 and visuals:
		visuals.scale.x = facing

# --- 跳跃 ---

## 是否满足起跳条件：有输入缓存 且（在地面 或 土狼时间内）
func wants_jump() -> bool:
	return _jump_buffer_timer > 0.0 and (is_on_floor() or _coyote_timer > 0.0)

## 是否有未消费的跳跃缓存（落地瞬间消费 → 兔子跳窗口）
func has_jump_buffer() -> bool:
	return _jump_buffer_timer > 0.0

## 执行起跳：消费缓存与土狼，附水平加成（§4.6 兔子跳）
func do_jump() -> void:
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	dash_attack_timer = 0.0
	velocity.y = -jump_force
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0 and signf(velocity.x) != -signf(dir):
		var cap := max_speed + jump_speed_boost
		velocity.x = clampf(velocity.x + dir * jump_speed_boost, -cap, cap)

func do_super_jump() -> void:
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	dash_attack_timer = 0.0
	velocity.x = super_jump_speed * facing
	velocity.y = -jump_force

func start_dash(direction: Vector2) -> void:
	consume_dash()
	dash_direction = direction
	dash_attack_timer = dash_attack_time
	velocity = Vector2.ZERO
	if direction.x != 0.0:
		facing = signf(direction.x)
		visuals.scale.x = facing

func finish_dash() -> void:
	_ultra_pending = dash_direction.y > 0.0 and absf(velocity.x) >= ultra_min_speed
	if dash_direction.y <= 0.0:
		velocity = dash_direction * dash_end_speed
	dash_direction = Vector2.ZERO

func apply_ultra() -> void:
	if not _ultra_pending:
		return
	velocity.x *= ultra_speed_mult
	_ultra_pending = false

func begin_climb(wall_direction: int) -> void:
	facing = wall_direction
	velocity.x = 0.0
	velocity.y *= climb_grab_y_mult
	_climb_no_move_timer = climb_no_move_time

func can_move_climb() -> bool:
	return _climb_no_move_timer <= 0.0


## 读取八向冲刺输入；无方向时沿当前朝向冲刺。
func get_dash_direction() -> Vector2:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction == Vector2.ZERO:
		direction = Vector2(facing, 0.0)
	return direction.normalized()

func can_dash() -> bool:
	return dash_count > 0

func consume_dash() -> void:
	dash_count = maxi(0, dash_count - 1)

## 靠近左右墙体检测，返回墙所在方向：-1 左、1 右、0 无墙。
func get_wall_direction() -> int:
	if test_move(global_transform, Vector2.LEFT * wall_check_distance):
		return -1
	if test_move(global_transform, Vector2.RIGHT * wall_check_distance):
		return 1
	return 0

func can_climb() -> bool:
	return stamina > 0.0 and get_wall_direction() != 0

# --- 携带 ---

func has_nearby_item() -> bool:
	return _get_nearest_item() != null

func pick_up_nearest_item() -> bool:
	var item := _get_nearest_item()
	if item == null:
		return false
	item.pick_up(carry_anchor)
	carried_item = item
	return true

func throw_carried_item() -> void:
	if carried_item == null:
		return
	var item := carried_item
	carried_item = null
	item.throw_into(get_tree().current_scene, Vector2(facing, 0.0), throw_speed, throw_lift)

func _get_nearest_item() -> CarryItem:
	var nearest: CarryItem
	var nearest_distance := INF
	for area in grab_detector.get_overlapping_bodies():
		if area is CarryItem and not area.is_carried():
			var distance := global_position.distance_squared_to(area.global_position)
			if distance < nearest_distance:
				nearest = area
				nearest_distance = distance
	return nearest

## 普通墙跳：direction 指向离墙方向，保留 FSM 外的冲刺动量规则由 Dash 结束速度处理。
func do_wall_jump(direction: int) -> void:
	var retains_dash_speed := dash_attack_timer > 0.0
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	dash_attack_timer = 0.0
	velocity.x = wall_jump_speed * direction
	if retains_dash_speed:
		velocity.x = direction * maxf(absf(velocity.x), dash_speed + cb_bonus_speed)
	velocity.y = -wall_jump_force
	stamina = maxf(0.0, stamina - climb_jump_stamina_cost)

func do_climb_hop(wall_direction: int) -> void:
	velocity.x = climb_hop_x * wall_direction
	velocity.y = minf(velocity.y, -climb_hop_y)

# --- 移动 ---

## 地面水平移动：加速度模型；超速时缓慢衰减而非硬切（保动量）
func apply_ground_movement(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		if absf(velocity.x) > max_speed and signf(velocity.x) == signf(dir):
			velocity.x = move_toward(velocity.x, dir * max_speed, over_speed_decel * delta)
		else:
			velocity.x = move_toward(velocity.x, dir * max_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)

## 空中水平移动：加速度略钝；无输入不减速（保住动量，§4.6 约束1）
func apply_air_movement(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		if absf(velocity.x) > max_speed and signf(velocity.x) == signf(dir):
			velocity.x = move_toward(velocity.x, dir * max_speed, over_speed_decel * delta)
		else:
			velocity.x = move_toward(velocity.x, dir * max_speed, acceleration * air_accel_mult * delta)

## 重力：上升用基础重力，顶点减轻（悬浮感），下落加重（扎实），限制最大下落速度
func apply_gravity(delta: float) -> void:
	var g := gravity
	if velocity.y > 0.0:
		g *= fall_gravity_mult
	elif absf(velocity.y) < apex_threshold:
		g *= apex_gravity_mult
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)

## 角落修正（Celeste Player.cs 精确算法，TDD §4.2）。
## 核心：撞头后，先探测"横向 i 像素 + 向上 1 像素"的位置是否为空；
## 若空则移动过去。多出的这 1 像素避免角色被吸进天花板内部。
## pre_move_vy：移动前的垂直速度（撞头后 velocity.y 会被碰撞清零）。
func apply_corner_correction(pre_move_vy: float) -> void:
	if pre_move_vy >= 0.0 or not is_on_ceiling():
		return

	var vx := velocity.x
	# Celeste：若速度向左（或为零），先尝试向左挤出；若向右，再尝试向右。
	if vx <= 0:
		for i in range(1, int(corner_correction_px) + 1):
			var offset := Vector2(-i, -1)
			if not test_move(global_transform.translated(offset), Vector2.ZERO):
				global_position += offset
				return
	if vx >= 0:
		for i in range(1, int(corner_correction_px) + 1):
			var offset := Vector2(i, -1)
			if not test_move(global_transform.translated(offset), Vector2.ZERO):
				global_position += offset
				return
