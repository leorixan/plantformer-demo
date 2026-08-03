class_name MovingPlatform
extends AnimatableBody2D
## 素材库：移动平台。在 A/B 两点间往返，玩家站上随动。
## offset 为 B 点相对初始位置（A 点）的位移，speed 为移动速度 px/s。

@export var offset := Vector2(64.0, 0.0)
@export var speed := 40.0

var _from := Vector2.ZERO
var _to := Vector2.ZERO

func _ready() -> void:
	_from = global_position
	_to = _from + offset
	_start()

func _start() -> void:
	var duration := _from.distance_to(_to) / maxf(speed, 0.001)
	if duration <= 0.0: return
	var tween := create_tween().set_loops()
	tween.tween_property(self, "global_position", _to, duration)
	tween.tween_property(self, "global_position", _from, duration)
