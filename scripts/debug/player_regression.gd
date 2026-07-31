extends SceneTree
## Headless 物理回归：真实实例化 player.tscn + StaticBody2D 地形，
## 用 Input.action_press 逐物理帧驱动，断言 Super / Hyper / Ultra / Dash 保速 /
## 可变跳高 / 上升角落修正 / 爬墙跳体力消耗。
## 运行：godot --headless --path . --script res://scripts/debug/player_regression.gd

const PLAYER_SCENE := "res://scenes/player/player.tscn"

func _initialize() -> void:
	var world := Node2D.new()
	world.name = "World"
	root.add_child(world)
	# 地板顶面 y=0，x -1000..2000
	world.add_child(_solid(Vector2(500.0, 7.5), Vector2(3000.0, 15.0)))
	# 左侧墙，x -207.5..-192.5，y -120..0
	world.add_child(_solid(Vector2(-200.0, -60.0), Vector2(15.0, 120.0)))
	# 天花板 y -60..-45，中间留 1494..1510 的缺口给角落修正用
	world.add_child(_solid(Vector2(1147.0, -52.5), Vector2(694.0, 15.0)))
	world.add_child(_solid(Vector2(1855.0, -52.5), Vector2(690.0, 15.0)))

	var player: Player = load(PLAYER_SCENE).instantiate()
	player.global_position = Vector2(0.0, 0.0)
	world.add_child(player)

	var harness := Harness.new()
	harness.player = player
	world.add_child(harness)

func _solid(center: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = center
	var rect := RectangleShape2D.new()
	rect.size = size
	var shape := CollisionShape2D.new()
	shape.shape = rect
	body.add_child(shape)
	return body

class Harness extends Node:
	const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "grab"]

	var player: Player
	var failures: Array[String] = []
	var passes := 0

	func _ready() -> void:
		run()

	func run() -> void:
		await _case_super()
		await _case_hyper()
		await _case_ultra()
		await _case_dash_end_keeps_speed()
		await _case_var_jump()
		await _case_corner_correction()
		await _case_climb_no_slip()
		await _case_climb_jump_stamina()
		await _case_climb_wall_jump()
		await _case_reverse_hyper()
		print("---- PLAYER REGRESSION %d passed, %d failed ----" % [passes, failures.size()])
		if failures.is_empty():
			get_tree().quit(0)
			return
		for failure in failures:
			push_error("PLAYER REGRESSION FAIL: " + failure)
		get_tree().quit(1)

	func _step(count := 1) -> void:
		for _i in range(count):
			await get_tree().physics_frame

	func _release_all() -> void:
		for action in ACTIONS:
			Input.action_release(action)

	func _reset(position: Vector2) -> void:
		_release_all()
		player.global_position = position
		player.velocity = Vector2.ZERO
		player.mode = Player.Mode.NORMAL
		player.is_ducking = false
		player.dash_count = player.max_dashes
		player.stamina = player.max_stamina
		player.dash_timer = 0.0
		player.dash_cooldown_timer = 0.0
		player.dash_attack_timer = 0.0
		player.dash_dir = Vector2.ZERO
		player.facing = 1.0
		player.last_technique = "None"
		player._coyote = 0.0
		player._jump_buffer = 0.0
		player._dash_buffer = 0.0
		player._var_jump_timer = 0.0
		player._climb_lock = 0.0
		player._floor_last_frame = false
		await _step(3)

	# Input.action_press 到玩家 is_action_just_pressed 之间存在一帧延迟，
	# 所以断言前一律等到目标状态真的发生，而不是假设固定帧数。
	func _wait_until(condition: Callable, max_frames := 8) -> bool:
		var frames := 0
		while frames < max_frames:
			if condition.call():
				return true
			await _step(1)
			frames += 1
		return condition.call()

	func _wait_dash_start() -> bool:
		return await _wait_until(func() -> bool: return player.mode == Player.Mode.DASH)

	func _wait_dash_exit() -> bool:
		return await _wait_until(func() -> bool: return player.mode != Player.Mode.DASH)

	func _check(check_name: String, ok: bool, detail: String) -> void:
		if ok:
			passes += 1
			print("PASS  %s  |  %s" % [check_name, detail])
		else:
			failures.append("%s | %s" % [check_name, detail])
			print("FAIL  %s  |  %s" % [check_name, detail])

	# 地面水平 Dash 中按跳 = Super
	func _case_super() -> void:
		await _reset(Vector2(0.0, 0.0))
		Input.action_press("move_right")
		await _step(25)
		Input.action_press("dash")
		var dashing: bool = await _wait_dash_start()
		Input.action_release("dash")
		_check("水平 Dash 起手", dashing, "mode=%s" % Player.Mode.keys()[player.mode])
		var dash_vx: float = player.velocity.x
		_check("Dash 起手写入 DashSpeed", dash_vx >= player.dash_speed - 1.0, "vx=%.1f dash_speed=%.1f" % [dash_vx, player.dash_speed])
		Input.action_press("jump")
		await _wait_dash_exit()
		Input.action_release("jump")
		_check("Super 触发", player.last_technique == "Super", "last_technique=%s mode=%s" % [player.last_technique, Player.Mode.keys()[player.mode]])
		_check("Super 水平速度=SuperJumpH", absf(player.velocity.x - player.super_jump_speed) < 2.0, "vx=%.1f 期望≈%.1f" % [player.velocity.x, player.super_jump_speed])
		_check("Super 未重置跳跃纵速", player.velocity.y <= -player.jump_speed + 1.0, "vy=%.1f 期望≈%.1f" % [player.velocity.y, -player.jump_speed])

	# 地面斜下 Dash（起手即触地滑行）+ 跳 = Hyper
	func _case_hyper() -> void:
		await _reset(Vector2(0.0, 0.0))
		Input.action_press("move_right")
		await _step(25)
		Input.action_press("move_down")
		Input.action_press("dash")
		await _wait_dash_start()
		Input.action_release("dash")
		Input.action_release("move_down")
		var slide_vx: float = player.velocity.x
		_check("斜下 Dash 触地转水平滑行", player.is_ducking and player.dash_dir.y == 0.0, "ducking=%s dash_dir=(%.2f, %.2f)" % [player.is_ducking, player.dash_dir.x, player.dash_dir.y])
		_check("斜下 Dash 触地不重置水平速度", slide_vx > player.dash_speed * 0.7, "vx=%.1f" % slide_vx)
		Input.action_press("jump")
		await _wait_dash_exit()
		Input.action_release("jump")
		var expected_x: float = player.super_jump_speed * player.duck_super_jump_x_mult
		var expected_y: float = -player.jump_speed * player.duck_super_jump_y_mult
		_check("Hyper 触发", player.last_technique == "Hyper", "last_technique=%s" % player.last_technique)
		_check("Hyper 水平速度", absf(player.velocity.x - expected_x) < 2.0, "vx=%.1f 期望≈%.1f" % [player.velocity.x, expected_x])
		_check("Hyper 为低跳", absf(player.velocity.y - expected_y) < 2.0, "vy=%.1f 期望≈%.1f" % [player.velocity.y, expected_y])
		_check("Hyper 快于滑行速度", player.velocity.x > slide_vx, "slide=%.1f -> hyper=%.1f" % [slide_vx, player.velocity.x])

	# 空中斜下 Dash 撞地 + 跳 = Ultra
	func _case_ultra() -> void:
		await _reset(Vector2(300.0, -50.0))
		Input.action_press("move_right")
		await _step(4)
		Input.action_press("move_down")
		Input.action_press("dash")
		await _wait_dash_start()
		Input.action_release("dash")
		_check("Dash 起手在空中", not player.dash_started_on_ground, "dash_started_on_ground=%s" % player.dash_started_on_ground)
		await _wait_until(func() -> bool: return player.is_ducking, 12)
		Input.action_release("move_down")
		var landed_vx: float = player.velocity.x
		_check("空中斜下 Dash 触地滑行", player.is_ducking and player.mode == Player.Mode.DASH, "ducking=%s mode=%s" % [player.is_ducking, Player.Mode.keys()[player.mode]])
		_check("触地后水平速度未被清零", landed_vx > player.dash_speed * 0.7, "vx=%.1f" % landed_vx)
		Input.action_press("jump")
		await _wait_dash_exit()
		Input.action_release("jump")
		_check("Ultra 触发", player.last_technique == "Ultra", "last_technique=%s" % player.last_technique)
		_check("Ultra 水平速度", player.velocity.x > landed_vx, "landed=%.1f -> ultra=%.1f" % [landed_vx, player.velocity.x])

	# 水平 Dash 自然结束不清零水平速度
	func _case_dash_end_keeps_speed() -> void:
		await _reset(Vector2(0.0, 0.0))
		Input.action_press("move_right")
		await _step(25)
		Input.action_press("dash")
		await _wait_dash_start()
		Input.action_release("dash")
		await _wait_until(func() -> bool: return player.mode != Player.Mode.DASH, 20)
		_check("Dash 结束后仍高于跑速", player.velocity.x > player.max_speed, "vx=%.1f max_speed=%.1f" % [player.velocity.x, player.max_speed])
		_check("Dash 结束速度=EndDashSpeed", absf(player.velocity.x - player.dash_end_speed) < 2.0, "vx=%.1f 期望≈%.1f" % [player.velocity.x, player.dash_end_speed])

	# 可变跳高：按住明显高于点按
	func _case_var_jump() -> void:
		var tap: float = await _measure_jump(2)
		var hold: float = await _measure_jump(30)
		_check("按住跳明显高于点按", hold > tap * 1.3, "点按=%.1fpx 按住=%.1fpx" % [tap, hold])
		_check("按住跳高约 3-4 格", hold > 40.0 and hold < 90.0, "按住=%.1fpx = %.1f 格" % [hold, hold / 15.0])

	func _measure_jump(hold_frames: int) -> float:
		await _reset(Vector2(400.0, 0.0))
		var start_y: float = player.global_position.y
		var peak: float = start_y
		Input.action_press("jump")
		for _i in range(hold_frames):
			await _step(1)
			peak = minf(peak, player.global_position.y)
		Input.action_release("jump")
		var frames := 0
		while frames < 120:
			await _step(1)
			frames += 1
			peak = minf(peak, player.global_position.y)
			if frames > 3 and player.is_on_floor():
				break
		return start_y - peak

	# 上升撞天花板角落时逐像素横移穿过缺口
	func _case_corner_correction() -> void:
		await _reset(Vector2(1508.0, 0.0))
		var before: int = player.corner_corrections
		var peak: float = player.global_position.y
		Input.action_press("jump")
		for _i in range(30):
			await _step(1)
			peak = minf(peak, player.global_position.y)
		Input.action_release("jump")
		_check("角落修正触发", player.corner_corrections > before, "corner_corrections=%d" % player.corner_corrections)
		_check("修正后穿过天花板缺口", peak < -40.0, "peak_y=%.1f（无修正会卡在 -24 附近）" % peak)

	# 抓墙静止：不下滑、贴住墙面无空隙
	func _case_climb_no_slip() -> void:
		await _reset(Vector2(-183.0, -40.0))
		player.facing = -1.0
		Input.action_press("grab")
		var climbing: bool = await _wait_until(func() -> bool: return player.mode == Player.Mode.CLIMB)
		_check("抓墙进入 CLIMB", climbing, "mode=%s" % Player.Mode.keys()[player.mode])
		var flush: bool = player.test_move(player.global_transform, Vector2.LEFT)
		_check("抓墙后紧贴墙面无空隙", flush, "x=%.2f 左移 1px 是否命中墙=%s" % [player.global_position.x, flush])
		await _step(5)
		var settled_y: float = player.global_position.y
		await _step(40)
		var drift: float = player.global_position.y - settled_y
		_check("抓墙静止不下滑", absf(drift) < 1.0 and absf(player.velocity.y) < 1.0, "drift=%.2fpx vy=%.2f" % [drift, player.velocity.y])
		_release_all()

	# 无方向输入的爬墙跳 = 垂直起跳并扣体力
	func _case_climb_jump_stamina() -> void:
		await _reset(Vector2(-183.0, -40.0))
		player.facing = -1.0
		Input.action_press("grab")
		await _wait_until(func() -> bool: return player.mode == Player.Mode.CLIMB)
		await _step(8)
		var before: float = player.stamina
		Input.action_press("jump")
		await _wait_until(func() -> bool: return player.mode != Player.Mode.CLIMB)
		Input.action_release("jump")
		var spent: float = before - player.stamina
		_check("爬墙跳扣体力", absf(spent - player.climb_jump_stamina_cost) < 1.5, "spent=%.2f 期望=%.2f" % [spent, player.climb_jump_stamina_cost])
		_check("爬墙跳为垂直跳", player.last_technique == "ClimbJump" and absf(player.velocity.x) < 1.0 and player.velocity.y < 0.0, "tech=%s v=(%.1f, %.1f)" % [player.last_technique, player.velocity.x, player.velocity.y])
		_release_all()

	# 攀爬中拉离墙 + 跳 = 墙跳弹开，且不扣体力
	func _case_climb_wall_jump() -> void:
		await _reset(Vector2(-183.0, -40.0))
		player.facing = -1.0
		Input.action_press("grab")
		await _wait_until(func() -> bool: return player.mode == Player.Mode.CLIMB)
		await _step(8)
		var before: float = player.stamina
		Input.action_press("move_right")
		Input.action_press("jump")
		await _wait_until(func() -> bool: return player.mode != Player.Mode.CLIMB)
		Input.action_release("jump")
		_check("拉离墙 + 跳 = 墙跳", player.last_technique == "WallJump", "tech=%s" % player.last_technique)
		_check("墙跳水平弹开", absf(player.velocity.x - player.wall_jump_speed) < 2.0, "vx=%.1f 期望≈%.1f" % [player.velocity.x, player.wall_jump_speed])
		_check("墙跳不扣体力", absf(before - player.stamina) < 0.5, "spent=%.2f" % (before - player.stamina))
		_release_all()

	# Dash 途中回拉方向 = 反向 Hyper
	func _case_reverse_hyper() -> void:
		await _reset(Vector2(0.0, 0.0))
		Input.action_press("move_right")
		await _step(25)
		Input.action_press("move_down")
		Input.action_press("dash")
		await _wait_dash_start()
		Input.action_release("dash")
		Input.action_release("move_down")
		_check("反向 Hyper 前置：已进入触地滑行", player.is_ducking, "ducking=%s" % player.is_ducking)
		Input.action_release("move_right")
		Input.action_press("move_left")
		var flipped: bool = await _wait_until(func() -> bool: return player.facing < 0.0, 4)
		_check("Dash 途中可反向朝向", flipped, "facing=%.0f mode=%s" % [player.facing, Player.Mode.keys()[player.mode]])
		Input.action_press("jump")
		await _wait_dash_exit()
		Input.action_release("jump")
		var expected_x: float = -player.super_jump_speed * player.duck_super_jump_x_mult
		_check("反向 Hyper 触发", player.last_technique == "Hyper", "tech=%s" % player.last_technique)
		_check("反向 Hyper 水平速度反向", absf(player.velocity.x - expected_x) < 2.0, "vx=%.1f 期望≈%.1f" % [player.velocity.x, expected_x])
		_release_all()
