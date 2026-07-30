class_name CarryItem
extends RigidBody2D
## 可被 Player 携带与抛出的刚体物品。场景实例设定各物品重力与外观。

@export var throw_speed_multiplier: float = 1.0
@export var throw_rise_time: float = 0.0
@export var throw_float_gravity_scale: float = -1.0

var _saved_collision_layer := 1
var _saved_collision_mask := 1
var _saved_gravity_scale := 1.0
var _is_carried := false
var _rise_timer := 0.0

func pick_up(anchor: Node2D) -> void:
	if _is_carried:
		return
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	_saved_gravity_scale = gravity_scale
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	collision_layer = 0
	collision_mask = 0
	reparent(anchor, true)
	position = Vector2.ZERO
	_is_carried = true

func throw_into(world: Node, direction: Vector2, speed: float, lift: float) -> void:
	if not _is_carried:
		return
	reparent(world, true)
	freeze = false
	gravity_scale = _saved_gravity_scale
	collision_layer = _saved_collision_layer
	collision_mask = _saved_collision_mask
	linear_velocity = Vector2(direction.x * speed * throw_speed_multiplier, -lift)
	_rise_timer = throw_rise_time
	_is_carried = false

func _physics_process(delta: float) -> void:
	if _rise_timer <= 0.0:
		return
	_rise_timer = maxf(0.0, _rise_timer - delta)
	if _rise_timer <= 0.0 and throw_float_gravity_scale >= 0.0:
		gravity_scale = throw_float_gravity_scale

func is_carried() -> bool:
	return _is_carried
