extends Node
## 测量：满跳高度、八向冲刺位移、满体力爬墙高度（8px 与 4px 格）

const TILE := 8.0
var _world: Node2D
var _player_scene: PackedScene


func _ready() -> void:
	_player_scene = load("res://scenes/player/player.tscn")
	_world = Node2D.new()
	add_child(_world)
	_build_world()
	await _frames(3)
	await _test_jump()
	await _test_dashes()
	await _test_run_jump()
	await _test_climb()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _solid(center: Vector2, size: Vector2, layer: int) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = layer
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	b.add_child(cs)
	b.position = center
	_world.add_child(b)
	return b


func _build_world() -> void:
	_solid(Vector2(400, 604), Vector2(4000, 8), 1)      # 地板 top y=600
	_solid(Vector2(604, 200), Vector2(8, 900), 5)       # 墙 layer1+4，供抓墙


func _spawn(pos: Vector2) -> Node2D:
	var p: Node2D = _player_scene.instantiate()
	_world.add_child(p)
	p.global_position = pos
	return p


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "grab"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)


func _test_jump() -> void:
	var p := _spawn(Vector2(200, 600))
	await _frames(20)
	var y0: float = p.global_position.y
	Input.action_press("jump")
	var miny := y0
	for i in 120:
		await get_tree().physics_frame
		miny = minf(miny, p.global_position.y)
	Input.action_release("jump")
	var h := y0 - miny
	print("MEASURE_JUMP height_px=", snappedf(h, 0.1), " cells8=", snappedf(h / TILE, 0.01), " cells4=", snappedf(h / 4.0, 0.01))
	_release_all()
	await _frames(30)
	p.queue_free()
	await _frames(3)


func _dash_one(name: String, dirs: Array) -> void:
	var p := _spawn(Vector2(200, 300))
	await _frames(5)
	for d in dirs:
		Input.action_press(d)
	Input.action_press("dash")
	await _frames(1)
	var start: Vector2 = p.global_position
	Input.action_release("dash")
	var dash_delta := Vector2.ZERO
	var got_dash := false
	for i in 60:
		await get_tree().physics_frame
		if not got_dash and float(p.get("dash_timer")) <= 0.0 and float(p.get("_dash_freeze")) <= 0.0:
			dash_delta = p.global_position - start
			got_dash = true
	var total: Vector2 = p.global_position - start
	_release_all()
	print("MEASURE_DASH ", name, " dash_px=", snappedf(dash_delta.length(), 0.1),
		" dash_cells8=", snappedf(dash_delta.length() / TILE, 0.01),
		" dir=", snappedf(dash_delta.x / TILE, 0.01), ",", snappedf(dash_delta.y / TILE, 0.01),
		" total_after60=", snappedf(total.length(), 0.1))
	p.queue_free()
	await _frames(3)


func _test_dashes() -> void:
	await _dash_one("R", ["move_right"])
	await _dash_one("L", ["move_left"])
	await _dash_one("U", ["move_up"])
	await _dash_one("D", ["move_down"])
	await _dash_one("UR", ["move_up", "move_right"])
	await _dash_one("UL", ["move_up", "move_left"])
	await _dash_one("DR", ["move_down", "move_right"])
	await _dash_one("DL", ["move_down", "move_left"])


func _test_climb() -> void:
	var p := _spawn(Vector2(599, 600))
	await _frames(20)
	var y0: float = p.global_position.y
	Input.action_press("grab")
	Input.action_press("move_up")
	var frames := 0
	while frames < 600 and float(p.get("stamina")) > 0.5:
		await get_tree().physics_frame
		frames += 1
	var h: float = y0 - p.global_position.y
	Input.action_release("grab")
	Input.action_release("move_up")
	print("MEASURE_CLIMB height_px=", snappedf(h, 0.1), " cells8=", snappedf(h / TILE, 0.01), " cells4=", snappedf(h / 4.0, 0.01),
		" frames=", frames)
	p.queue_free()
	await _frames(3)


func _test_run_jump() -> void:
	var p := _spawn(Vector2(200, 600))
	await _frames(20)
	Input.action_press("move_right")
	await _frames(30)   # 加速到最大速度
	var start: Vector2 = p.global_position
	Input.action_press("jump")
	var air := 0
	while air < 200:
		await get_tree().physics_frame
		air += 1
		if air > 5 and bool(p.call("_on_ground")):
			break
	var dx: float = p.global_position.x - start.x
	var dy: float = p.global_position.y - start.y
	Input.action_release("jump")
	Input.action_release("move_right")
	print("MEASURE_RUNJUMP dx_px=", snappedf(dx, 0.1), " cells8=", snappedf(dx / TILE, 0.01),
		" frames=", air, " dy=", snappedf(dy, 0.1))
	p.queue_free()
	await _frames(3)
