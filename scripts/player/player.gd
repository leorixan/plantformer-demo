class_name Player
extends CharacterBody2D
## Celeste-style controller. One simulation owner: input -> timers -> decisions -> move -> collision facts -> landing decisions.

enum Mode { NORMAL, DASH, CLIMB }

@export_category("Movement")
@export var max_speed := 90.0 # px/s: Celeste MaxRun, six 15px cells/s.
@export var acceleration := 1000.0 # px/s²: Celeste RunAccel.
@export var deceleration := 400.0 # px/s²: Celeste RunReduce.
@export var air_accel_mult := 0.65
@export var over_speed_decel := 400.0

@export_category("Jump")
@export var jump_speed := 105.0 # px/s upward: Celeste JumpSpeed.
@export var jump_speed_boost := 40.0 # px/s: Celeste JumpHBoost.
@export var var_jump_time := 0.20
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.12

@export_category("Gravity")
@export var gravity := 900.0 # px/s²: Celeste Gravity.
@export var max_fall_speed := 160.0 # px/s: Celeste MaxFall.
@export var half_gravity_threshold := 40.0

@export_category("Dash")
@export var max_dashes := 1
@export var dash_speed := 240.0 # px/s: Celeste DashSpeed.
@export var dash_end_speed := 160.0 # px/s: Celeste EndDashSpeed.
@export var dash_duration := 0.15
@export var dash_cooldown := 0.20
@export var dash_attack_time := 0.30
@export var dash_buffer_time := 0.12
@export var super_jump_speed := 260.0 # px/s: Celeste SuperJumpH.
@export var hyper_speed_mult := 1.20
@export var ultra_speed_mult := 1.20
@export var ultra_window_time := 0.10
@export var super_wall_jump_speed := 160.0 # px/s upward: Celeste SuperWallJumpSpeed.
@export var super_wall_jump_horizontal := 170.0 # px/s: MaxRun + JumpHBoost * 2.

@export_category("Climb")
@export var max_stamina := 110.0
@export var climb_grab_y_mult := 0.2
@export var climb_no_move_time := 0.10
@export var climb_up_speed := 45.0
@export var climb_down_speed := 80.0
@export var climb_slip_speed := 30.0
@export var climb_acceleration := 900.0
@export var climb_up_stamina_cost := 45.45
@export var climb_still_stamina_cost := 10.0
@export var climb_jump_stamina_cost := 27.5
@export var wall_check_distance := 3.0
@export var wall_jump_speed := 130.0 # px/s: MaxRun + JumpHBoost.
@export var climb_hop_x := 100.0
@export var climb_hop_y := 120.0

@export_category("Feel")
@export var corner_correction_px := 4.0
@export var corner_kick_window := 0.08
@export var bunnyhop_grace_time := 0.06

@export_category("Carry")
@export var throw_speed := 300.0
@export var throw_lift := 220.0

@export_category("Debug")
@export var show_controller_debug := false

var dash_count := 1
var stamina := 110.0
var facing := 1.0
var mode := Mode.NORMAL
var dash_dir := Vector2.ZERO
var dash_speed_x := 0.0
var before_dash_speed := Vector2.ZERO
var dash_attack_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_started_on_ground := false
var last_technique := "None"

var _jump_buffer := 0.0
var _dash_buffer := 0.0
var _coyote := 0.0
var _var_jump := 0.0
var _var_jump_speed := 0.0
var _ultra_window := 0.0
var _ultra_speed_x := 0.0
var _climb_lock := 0.0
var _corner_kick := 0.0
var _corner_wall := 0
var _bunnyhop := 0.0
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
	_load_config()
	dash_count = max_dashes
	stamina = max_stamina
	_floor_last_frame = is_on_floor()
	if debug_label:
		debug_label.visible = show_controller_debug
	_update_indicators()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload_config"):
		var config := get_node_or_null("/root/Config")
		if config: config.reload_and_apply(self)
		return
	if event.is_action_pressed("jump"): _jump_buffer = jump_buffer_time
	if event.is_action_released("jump"): _var_jump = 0.0
	if event.is_action_pressed("dash"): _dash_buffer = dash_buffer_time
	if event.is_action_pressed("grab"):
		if carried_item: throw_carried_item()
		else: pick_up_nearest_item()

func _physics_process(delta: float) -> void:
	# Stage 1: buffered input already captured in _unhandled_input. Stage 2: timers.
	_tick_timers(delta)
	_update_facing()
	# Stage 3: pre-move decisions. No state node writes velocity.
	if mode == Mode.DASH:
		_dash_pre_move(delta)
	elif mode == Mode.CLIMB:
		_climb_pre_move(delta)
	else:
		_normal_pre_move(delta)
	# Stage 4: one movement call. Stage 5: facts created by this exact movement.
	var pre_move_vy := velocity.y
	move_and_slide()
	_collect_collision_facts(pre_move_vy)
	# Stage 6: landing techniques consume collision facts, never stale is_on_floor.
	_post_move_techniques()
	_update_indicators()
	_update_debug()

func _tick_timers(delta: float) -> void:
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_dash_buffer = maxf(0.0, _dash_buffer - delta)
	_coyote = maxf(0.0, _coyote - delta)
	_var_jump = maxf(0.0, _var_jump - delta)
	_ultra_window = maxf(0.0, _ultra_window - delta)
	_corner_kick = maxf(0.0, _corner_kick - delta)
	_bunnyhop = maxf(0.0, _bunnyhop - delta)
	_climb_lock = maxf(0.0, _climb_lock - delta)
	dash_attack_timer = maxf(0.0, dash_attack_timer - delta)
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	dash_timer = maxf(0.0, dash_timer - delta) if mode == Mode.DASH else dash_timer
	_event_timer = maxf(0.0, _event_timer - delta)

func _update_facing() -> void:
	var x := Input.get_axis("move_left", "move_right")
	if x != 0.0:
		facing = signf(x)
		visuals.scale.x = facing

func _normal_pre_move(delta: float) -> void:
	if _try_start_dash(): return
	if Input.is_action_pressed("grab") and carried_item == null and stamina > 0.0 and get_wall_direction() != 0:
		mode = Mode.CLIMB
		velocity.y *= climb_grab_y_mult
		_climb_lock = climb_no_move_time
		return
	if _jump_buffer > 0.0:
		if _ultra_window > 0.0:
			_do_ultra()
		elif _coyote > 0.0:
			_do_normal_jump()
		elif get_wall_direction() != 0:
			_do_wall_jump(-get_wall_direction(), false)
		elif _corner_kick > 0.0 and _wall_direction == _corner_wall:
			_do_wall_jump(-_corner_wall, false)
	_apply_horizontal(delta, is_on_floor())
	_apply_gravity(delta)

func _dash_pre_move(_delta: float) -> void:
	# Dash attack wall jumps happen before move. Ground Super uses resolved grace, never prior floor flag.
	var wall := get_wall_direction()
	if _jump_buffer > 0.0 and wall != 0:
		_do_wall_jump(-wall, dash_dir == Vector2.UP)
		return
	if _jump_buffer > 0.0 and dash_dir.y == 0.0 and _coyote > 0.0:
		_do_super()
		return
	velocity = dash_dir * dash_speed
	if signf(before_dash_speed.x) == signf(velocity.x) and absf(before_dash_speed.x) > absf(velocity.x): velocity.x = before_dash_speed.x
	dash_speed_x = velocity.x

func _climb_pre_move(delta: float) -> void:
	if _try_start_dash(): return
	var wall := get_wall_direction()
	if not Input.is_action_pressed("grab") or stamina <= 0.0 or wall == 0:
		mode = Mode.NORMAL
		if wall == 0 and velocity.y < 0.0: velocity.x = climb_hop_x * facing
		return
	facing = wall
	if _jump_buffer > 0.0:
		_do_wall_jump(-wall, false)
		return
	velocity.x = 0.0
	var vertical := Input.get_axis("move_up", "move_down")
	var target := climb_slip_speed
	if _climb_lock <= 0.0:
		if vertical < 0.0: target = -climb_up_speed
		elif vertical > 0.0: target = climb_down_speed
	velocity.y = move_toward(velocity.y, target, climb_acceleration * delta)
	if _climb_lock <= 0.0:
		stamina = maxf(0.0, stamina - (climb_up_stamina_cost if vertical < 0.0 else climb_still_stamina_cost if vertical == 0.0 else 0.0) * delta)

func _post_move_techniques() -> void:
	if mode == Mode.DASH:
		if _landed_this_move:
			if _is_down_diagonal_dash():
				if _jump_buffer > 0.0: _do_hyper()
				else:
					_ultra_speed_x = dash_speed_x
					_ultra_window = ultra_window_time
					_event("Ultra armed")
			elif dash_dir.y == 0.0 and _jump_buffer > 0.0:
				_do_super()
		if mode == Mode.DASH and dash_timer <= 0.0: _finish_dash()
	elif _landed_this_move:
		if _jump_buffer > 0.0:
			if _ultra_window > 0.0: _do_ultra()
			else: _do_normal_jump()

func _collect_collision_facts(pre_move_vy: float) -> void:
	_landed_this_move = is_on_floor() and not _floor_last_frame
	_wall_direction = get_wall_direction()
	if is_on_floor():
		_coyote = coyote_time
		dash_count = max_dashes
		stamina = max_stamina
	elif _floor_last_frame:
		_coyote = coyote_time
	if _landed_this_move: _bunnyhop = bunnyhop_grace_time
	if _wall_direction != 0 and pre_move_vy < 0.0 and dash_attack_timer > 0.0 and dash_dir.x != 0.0:
		_corner_kick = corner_kick_window
		_corner_wall = _wall_direction
	_floor_last_frame = is_on_floor()

func _try_start_dash() -> bool:
	if _dash_buffer <= 0.0 or dash_count <= 0 or dash_cooldown_timer > 0.0: return false
	_dash_buffer = 0.0
	dash_count -= 1
	dash_started_on_ground = _coyote > 0.0
	before_dash_speed = velocity
	dash_dir = get_dash_direction()
	dash_speed_x = 0.0
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_attack_timer = dash_attack_time
	mode = Mode.DASH
	if dash_dir.x != 0.0: facing = signf(dash_dir.x)
	_event("Dash")
	return true

func _finish_dash() -> void:
	# Reference DashCoroutine: downward dash retains current velocity. Never touch x on down dash.
	if dash_dir.y <= 0.0:
		velocity = dash_dir * dash_end_speed
		if velocity.y < 0.0: velocity.y *= 0.75
	mode = Mode.NORMAL
	_event("Dash end")

func _do_normal_jump() -> void:
	_consume_jump()
	velocity.y = -jump_speed
	var x := Input.get_axis("move_left", "move_right")
	velocity.x += jump_speed_boost * x
	_event("Jump")

func _do_super() -> void:
	_consume_jump()
	velocity = technique_velocity("Super", dash_speed_x, facing, jump_speed, super_jump_speed, hyper_speed_mult)
	mode = Mode.NORMAL
	_event("Super")

func _do_hyper() -> void:
	_consume_jump()
	velocity = technique_velocity("Hyper", dash_speed_x, facing, jump_speed, super_jump_speed, hyper_speed_mult)
	mode = Mode.NORMAL
	_event("Hyper")

func _do_ultra() -> void:
	_consume_jump()
	velocity = technique_velocity("Ultra", _ultra_speed_x, facing, jump_speed, super_jump_speed, ultra_speed_mult)
	_ultra_window = 0.0
	_event("Ultra")

func _do_wall_jump(direction: int, super_wall: bool) -> void:
	_consume_jump()
	velocity.x = direction * (super_wall_jump_horizontal if super_wall else wall_jump_speed)
	velocity.y = -(super_wall_jump_speed if super_wall else jump_speed)
	_var_jump = var_jump_time
	mode = Mode.NORMAL
	_event("SuperWallJump" if super_wall else "WallJump")

func _consume_jump() -> void:
	_jump_buffer = 0.0
	_coyote = 0.0
	dash_attack_timer = 0.0
	_var_jump = var_jump_time
	_var_jump_speed = -jump_speed

func _apply_horizontal(delta: float, grounded: bool) -> void:
	if grounded and _bunnyhop > 0.0 and _jump_buffer > 0.0: return
	var direction := Input.get_axis("move_left", "move_right")
	var rate := acceleration * (1.0 if grounded else air_accel_mult)
	if absf(velocity.x) > max_speed and signf(velocity.x) == signf(direction): rate = over_speed_decel
	velocity.x = move_toward(velocity.x, direction * max_speed, (rate if direction != 0.0 else deceleration) * delta)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var mult := 0.5 if absf(velocity.y) < half_gravity_threshold and Input.is_action_pressed("jump") else 1.0
		velocity.y = minf(velocity.y + gravity * mult * delta, max_fall_speed)
	if _var_jump > 0.0 and Input.is_action_pressed("jump") and velocity.y < 0.0:
		velocity.y = minf(velocity.y, _var_jump_speed)

func _is_down_diagonal_dash() -> bool:
	return dash_dir.x != 0.0 and dash_dir.y > 0.0

func get_dash_direction() -> Vector2:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return (direction if direction != Vector2.ZERO else Vector2(facing, 0.0)).normalized()

func get_wall_direction() -> int:
	if test_move(global_transform, Vector2.LEFT * wall_check_distance): return -1
	if test_move(global_transform, Vector2.RIGHT * wall_check_distance): return 1
	return 0

func technique_velocity(technique: String, source_speed_x: float, direction: float, standard_jump_speed: float, super_horizontal_speed: float, boost_multiplier: float) -> Vector2:
	match technique:
		"Super": return Vector2(signf(direction) * super_horizontal_speed, -standard_jump_speed)
		"Hyper", "Ultra": return Vector2(source_speed_x * boost_multiplier, -standard_jump_speed)
	return Vector2.ZERO

func _event(name: String) -> void:
	last_technique = name
	_event_text = name
	_event_timer = 1.2

func _update_debug() -> void:
	if not debug_label: return
	debug_label.visible = show_controller_debug
	if show_controller_debug:
		debug_label.text = "MODE %s | V (%.1f, %.1f) | DASH (%.2f, %.2f) x %.1f\nTECH %s | EVENT %s" % [Mode.keys()[mode], velocity.x, velocity.y, dash_dir.x, dash_dir.y, dash_speed_x, last_technique, _event_text if _event_timer > 0.0 else "-"]

func _load_config() -> void:
	var config := get_node_or_null("/root/Config")
	if config: config.apply_to(self)

func has_nearby_item() -> bool: return _get_nearest_item() != null
func pick_up_nearest_item() -> bool:
	var item := _get_nearest_item()
	if item == null: return false
	item.pick_up(carry_anchor); carried_item = item; return true
func throw_carried_item() -> void:
	if carried_item == null: return
	var item := carried_item; carried_item = null
	item.throw_into(get_tree().current_scene, Vector2(facing, 0.0), throw_speed, throw_lift)
func _get_nearest_item() -> CarryItem:
	var nearest: CarryItem
	var distance := INF
	for body in grab_detector.get_overlapping_bodies():
		if body is CarryItem and not body.is_carried() and global_position.distance_squared_to(body.global_position) < distance:
			nearest = body; distance = global_position.distance_squared_to(body.global_position)
	return nearest
func _update_indicators() -> void:
	if not is_instance_valid(stamina_fill): return
	for index in dash_pips.size():
		dash_pips[index].visible = index < max_dashes
		dash_pips[index].color = Color("f7d65a") if index < dash_count else Color("4d5261")
	stamina_fill.size.x = 30.0 * clampf(stamina / maxf(max_stamina, 0.001), 0.0, 1.0)
