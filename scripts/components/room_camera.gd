extends Node
signal room_changed(index: int)
## 蔚蓝式房间相机：
## - 房间是矩形（RoomArea）；玩家进入另一个房间时切换
## - 切换节奏：先停顿 PAUSE_TIME，再用 PAN_TIME 平滑滑动到新房间目标
## - 小房间锁定居中；大房间跟随玩家并夹在房间边界内

const PAN_TIME := 0.40
const PAUSE_TIME := 0.20
# 大房间内跟随玩家的平滑时间常数（秒），越大越"拖"
const FOLLOW_TIME := 0.16

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
	_cam.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	_current = _room_at(_player.global_position)
	room_changed.emit(_current)
	_to = _target_for(_current)
	_cam.global_position = _snap(_to)
	_cam.reset_physics_interpolation()


func _process(delta: float) -> void:
	if _cam == null or _player == null or _rects.is_empty():
		return
	_view = get_viewport().get_visible_rect().size / _cam.zoom
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_t = 0.0
		return
	if _t < 1.0:
		_t = minf(1.0, _t + delta / PAN_TIME)
		var k := _t * _t * (3.0 - 2.0 * _t)
		_cam.global_position = _snap(_from.lerp(_to, k))
		return
	var idx := _room_at(_player.global_position)
	if idx != _current:
		_current = idx
		room_changed.emit(idx)
		_from = _cam.global_position
		_to = _target_for(idx)
		_wait = PAUSE_TIME
		return
	var target := _target_for(_current)
	var room: Rect2 = _rects[_current]
	if room.size.x > _view.x or room.size.y > _view.y:
		# 大房间：平滑跟随（指数平滑，和帧率无关）
		var k := 1.0 - exp(-delta / FOLLOW_TIME)
		_cam.global_position = _snap(_cam.global_position.lerp(target, k))
	else:
		_cam.global_position = _snap(target)


func _snap(v: Vector2) -> Vector2:
	# 按"屏幕像素"取整：世界像素 * zoom * 窗口缩放 对齐到整数屏幕像素，
	# 跟随滚动时步进更细，避免整数取整造成的顿挫
	var z := _cam.zoom
	if z.x <= 0.0 or z.y <= 0.0:
		return v.round()
	var scale := 1.0
	var win := get_window()
	if win != null:
		var vis := get_viewport().get_visible_rect().size
		if vis.x > 0.0:
			scale = maxf(1.0, floorf(win.size.x / vis.x))
	return (v * z * scale).round() / (z * scale)


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
