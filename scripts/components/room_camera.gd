extends Node
## 蔚蓝式房间相机：
## - 房间是矩形（RoomArea）；玩家进入另一个房间时切换
## - 切换节奏：先停顿 PAUSE_TIME，再用 PAN_TIME 平滑滑动到新房间目标
## - 小房间锁定居中；大房间跟随玩家并夹在房间边界内

const PAN_TIME := 0.16
const PAUSE_TIME := 0.16

var _cam: Camera2D
var _player: Node2D
var _rects: Array = []
var _view := Vector2(320, 180)
var _current := 0
var _wait := 0.0
var _t := 1.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO


func attach(cam: Camera2D, player: Node2D, rects: Array) -> void:
	_cam = cam
	_player = player
	_rects = rects
	_view = get_viewport().get_visible_rect().size / _cam.zoom
	_cam.position_smoothing_enabled = false
	_cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	_current = _room_at(_player.global_position)
	_to = _target_for(_current)
	_cam.global_position = _to.round()


func _physics_process(delta: float) -> void:
	if _cam == null or _player == null or _rects.is_empty():
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_t = 0.0
		return
	if _t < 1.0:
		_t = minf(1.0, _t + delta / PAN_TIME)
		var k := _t * _t * (3.0 - 2.0 * _t)
		_cam.global_position = _from.lerp(_to, k).round()
		return
	var idx := _room_at(_player.global_position)
	if idx != _current:
		_current = idx
		_from = _cam.global_position
		_to = _target_for(idx)
		_wait = PAUSE_TIME
		return
	_cam.global_position = _target_for(_current).round()


func _room_at(pos: Vector2) -> int:
	for i in _rects.size():
		if (_rects[i] as Rect2).has_point(pos):
			return i
	return _current


func _target_for(idx: int) -> Vector2:
	var r: Rect2 = _rects[idx]
	var pos := _player.global_position
	var target := Vector2.ZERO
	if r.size.x <= _view.x:
		target.x = r.position.x + r.size.x * 0.5
	else:
		target.x = clampf(pos.x, r.position.x + _view.x * 0.5, r.position.x + r.size.x - _view.x * 0.5)
	if r.size.y <= _view.y:
		target.y = r.position.y + r.size.y * 0.5
	else:
		target.y = clampf(pos.y, r.position.y + _view.y * 0.5, r.position.y + r.size.y - _view.y * 0.5)
	return target
