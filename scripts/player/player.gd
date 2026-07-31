class_name Player
extends CharacterBody2D
## CharacterBody2D controller. Press actions enter one buffer here; states only consume it.

@export_category("Movement")
@export var max_speed := 180.0
@export var acceleration := 2000.0
@export var deceleration := 2400.0
@export var air_accel_mult := 0.9
@export var over_speed_decel := 300.0

@export_category("Jump")
@export var jump_force := 450.0
@export var jump_cut_mult := 0.45
@export var jump_speed_boost := 40.0

@export_category("Gravity")
@export var gravity := 1500.0
@export var fall_gravity_mult := 1.6
@export var apex_gravity_mult := 0.55
@export var apex_threshold := 50.0
@export var max_fall_speed := 400.0

@export_category("Dash")
@export var max_dashes := 1
@export var dash_speed := 420.0
@export var dash_duration := 0.15
@export var dash_freeze_time := 0.04
@export var dash_end_speed := 240.0
@export var dash_attack_time := 0.3
@export var dash_buffer_time := 0.12
@export var super_jump_speed := 260.0
@export var hyper_speed_mult := 1.2
@export var ultra_min_speed := 170.0
@export var ultra_speed_mult := 1.2
@export var ultra_window_time := 0.10
@export var cb_bonus_speed := 40.0

@export_category("Climb")
@export var max_stamina := 110.0
@export var climb_grab_y_mult := 0.2
@export var climb_no_move_time := 0.1
@export var climb_up_speed := 45.0
@export var climb_down_speed := 80.0
@export var climb_slip_speed := 30.0
@export var climb_acceleration := 900.0
@export var climb_up_stamina_cost := 45.0
@export var climb_still_stamina_cost := 10.0
@export var climb_jump_stamina_cost := 27.5
@export var wall_check_distance := 3.0
@export var wall_jump_speed := 220.0
@export var wall_jump_force := 450.0
@export var climb_hop_x := 100.0
@export var climb_hop_y := 120.0

@export_category("Feel")
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12
@export var corner_correction_px := 8.0

@export_category("Carry")
@export var throw_speed := 300.0
@export var throw_lift := 220.0

var dash_count := 1
var stamina := 110.0
var facing := 1.0
var dash_direction := Vector2.ZERO
var dash_attack_timer := 0.0
var before_dash_velocity := Vector2.ZERO
var dash_momentum_x := 0.0
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _dash_buffer_timer := 0.0
var _ultra_timer := 0.0
var _ultra_speed_x := 0.0
var _climb_no_move_timer := 0.0

@onready var state_machine: StateMachine = $StateMachine
@onready var visuals: Node2D = $Visuals
@onready var carry_anchor: Marker2D = $CarryAnchor
@onready var grab_detector: Area2D = $GrabDetector
@onready var dash_pips: Array[ColorRect] = [$UI/DashPip1, $UI/DashPip2, $UI/DashPip3]
@onready var stamina_fill: ColorRect = $UI/StaminaBar/Fill

var carried_item: CarryItem

func _ready() -> void:
	_load_config()
	dash_count = max_dashes
	stamina = max_stamina
	_update_indicators()

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_indicators()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload_config"):
		var config := get_node_or_null("/root/Config")
		if config:
			config.reload_and_apply(self)
		return
	if event.is_action_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	elif event.is_action_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_mult
	if event.is_action_pressed("dash"):
		_dash_buffer_timer = dash_buffer_time
	if event.is_action_pressed("grab"):
		if carried_item:
			throw_carried_item()
		else:
			pick_up_nearest_item()

func _load_config() -> void:
	var config := get_node_or_null("/root/Config")
	if config:
		config.apply_to(self)

func _update_timers(delta: float) -> void:
	_coyote_timer = maxf(0.0, _coyote_timer - delta)
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	_dash_buffer_timer = maxf(0.0, _dash_buffer_timer - delta)
	dash_attack_timer = maxf(0.0, dash_attack_timer - delta)
	_ultra_timer = maxf(0.0, _ultra_timer - delta)
	_climb_no_move_timer = maxf(0.0, _climb_no_move_timer - delta)
	if is_on_floor():
		_coyote_timer = coyote_time
		dash_count = max_dashes
		stamina = max_stamina
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		facing = signf(direction)
		visuals.scale.x = facing

func has_jump_buffer() -> bool:
	return _jump_buffer_timer > 0.0

func consume_jump_buffer() -> bool:
	if not has_jump_buffer():
		return false
	_jump_buffer_timer = 0.0
	return true

func has_dash_buffer() -> bool:
	return _dash_buffer_timer > 0.0

func consume_dash_buffer() -> bool:
	if not has_dash_buffer() or not can_dash():
		return false
	_dash_buffer_timer = 0.0
	return true

func wants_jump() -> bool:
	return has_jump_buffer() and (is_on_floor() or _coyote_timer > 0.0)

func do_jump() -> void:
	consume_jump_buffer()
	_coyote_timer = 0.0
	dash_attack_timer = 0.0
	velocity.y = -jump_force
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0 and signf(velocity.x) != -signf(direction):
		velocity.x = clampf(velocity.x + direction * jump_speed_boost, -(max_speed + jump_speed_boost), max_speed + jump_speed_boost)

func do_super_jump() -> void:
	consume_jump_buffer()
	_coyote_timer = 0.0
	dash_attack_timer = 0.0
	velocity = Vector2(super_jump_speed * facing, -jump_force)

func do_hyper_jump() -> void:
	consume_jump_buffer()
	_coyote_timer = 0.0
	dash_attack_timer = 0.0
	velocity.x = signf(dash_direction.x if dash_direction.x != 0.0 else facing) * maxf(absf(velocity.x), dash_speed * absf(dash_direction.x)) * hyper_speed_mult
	velocity.y = -jump_force

func prepare_ultra(speed_x: float) -> void:
	_ultra_speed_x = speed_x
	_ultra_timer = ultra_window_time

func can_ultra_jump() -> bool:
	return _ultra_timer > 0.0 and absf(_ultra_speed_x) >= ultra_min_speed

func do_ultra_jump() -> void:
	consume_jump_buffer()
	_coyote_timer = 0.0
	dash_attack_timer = 0.0
	velocity.x = _ultra_speed_x * ultra_speed_mult
	velocity.y = -jump_force
	_ultra_timer = 0.0

func start_dash(direction: Vector2) -> void:
	consume_dash_buffer()
	dash_count = maxi(0, dash_count - 1)
	before_dash_velocity = velocity
	dash_momentum_x = velocity.x
	dash_direction = direction.normalized()
	dash_attack_timer = dash_attack_time
	velocity = Vector2.ZERO
	if dash_direction.x != 0.0:
		facing = signf(dash_direction.x)
		visuals.scale.x = facing

func activate_dash() -> void:
	var new_velocity := dash_direction * dash_speed
	# Celeste keeps faster same-direction horizontal speed instead of killing momentum.
	if signf(before_dash_velocity.x) == signf(new_velocity.x) and absf(before_dash_velocity.x) > absf(new_velocity.x):
		new_velocity.x = before_dash_velocity.x
	velocity = new_velocity
	dash_momentum_x = velocity.x

func finish_dash() -> void:
	if dash_direction != Vector2.ZERO:
		velocity = dash_direction * dash_end_speed
	dash_direction = Vector2.ZERO

func get_dash_direction() -> Vector2:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return (direction if direction != Vector2.ZERO else Vector2(facing, 0.0)).normalized()

func can_dash() -> bool:
	return dash_count > 0

func begin_climb(wall_direction: int) -> void:
	facing = wall_direction
	velocity.x = 0.0
	velocity.y *= climb_grab_y_mult
	_climb_no_move_timer = climb_no_move_time

func can_move_climb() -> bool:
	return _climb_no_move_timer <= 0.0

func get_wall_direction() -> int:
	if test_move(global_transform, Vector2.LEFT * wall_check_distance):
		return -1
	if test_move(global_transform, Vector2.RIGHT * wall_check_distance):
		return 1
	return 0

func can_climb() -> bool:
	return stamina > 0.0 and get_wall_direction() != 0

func do_wall_jump(direction: int) -> void:
	var cb_speed := absf(dash_momentum_x) + cb_bonus_speed if dash_attack_timer > 0.0 else 0.0
	consume_jump_buffer()
	_coyote_timer = 0.0
	dash_attack_timer = 0.0
	velocity.x = direction * maxf(wall_jump_speed, cb_speed)
	velocity.y = -wall_jump_force
	stamina = maxf(0.0, stamina - climb_jump_stamina_cost)

func do_climb_hop(wall_direction: int) -> void:
	velocity.x = climb_hop_x * wall_direction
	velocity.y = minf(velocity.y, -climb_hop_y)

func apply_ground_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		var rate := over_speed_decel if absf(velocity.x) > max_speed and signf(velocity.x) == signf(direction) else acceleration
		velocity.x = move_toward(velocity.x, direction * max_speed, rate * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)

func apply_air_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		var rate := over_speed_decel if absf(velocity.x) > max_speed and signf(velocity.x) == signf(direction) else acceleration * air_accel_mult
		velocity.x = move_toward(velocity.x, direction * max_speed, rate * delta)

func apply_gravity(delta: float) -> void:
	var current_gravity := gravity
	if velocity.y > 0.0:
		current_gravity *= fall_gravity_mult
	elif absf(velocity.y) < apex_threshold:
		current_gravity *= apex_gravity_mult
	velocity.y = minf(velocity.y + current_gravity * delta, max_fall_speed)

func apply_corner_correction(pre_move_vy: float) -> void:
	if pre_move_vy >= 0.0 or not is_on_ceiling():
		return
	var start := -1 if velocity.x <= 0.0 else 1
	for direction in [start, -start]:
		if direction != start and velocity.x == 0.0:
			continue
		for distance in range(1, int(corner_correction_px) + 1):
			var offset := Vector2(direction * distance, -1)
			if not test_move(global_transform.translated(offset), Vector2.ZERO):
				global_position += offset
				return

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
	for body in grab_detector.get_overlapping_bodies():
		if body is CarryItem and not body.is_carried():
			var distance := global_position.distance_squared_to(body.global_position)
			if distance < nearest_distance:
				nearest = body
				nearest_distance = distance
	return nearest

func _update_indicators() -> void:
	if not is_instance_valid(stamina_fill):
		return
	for index in dash_pips.size():
		var pip := dash_pips[index]
		pip.visible = index < max_dashes
		pip.color = Color("f7d65a") if index < dash_count else Color("4d5261")
	stamina_fill.size.x = 30.0 * clampf(stamina / maxf(max_stamina, 0.001), 0.0, 1.0)
	stamina_fill.color = Color("79dc8d") if stamina > max_stamina * 0.2 else Color("ef8b62")
