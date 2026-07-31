extends SceneTree
## Headless 物理回归：真实实例化 player.tscn + StaticBody2D 地形，
## 用 Input.action_press 逐物理帧驱动。尺度与 Celeste 一致（1 砖 = 8px，角色 8x11）。
## 运行：godot --headless --path . --script res://scripts/debug/player_regression.gd

const PLAYER_SCENE := "res://scenes/player/player.tscn"

func _initialize() -> void:
	var world := Node2D.new()
	world.name = "World"
	root.add_child(world)
	# 地板顶面 y=0，x -512..1024
	world.add_child(_solid(Vector2(256.0, 4.0), Vector2(1536.0, 8.0)))
	# 左侧墙，x -112..-104，y -64..0
	world.add_child(_solid(Vector2(-108.0, -32.0), Vector2(8.0, 64.0)))
	# 天花板 y -32..-24，中间留 796..804 的 1 格缝给角落修正用
	world.add_child(_solid(Vector2(598.0, -28.0), Vector2(396.0, 8.0)))
	world.add_child(_solid(Vector2(1002.0, -28.0), Vector2(396.0, 8.0)))
	# 悬空 1 格平台，x 320..328 / y -32..-24，用来测上冲蹭平台边缘墙跳
	world.add_child(_solid(Vector2(324.0, -28.0), Vector2(8.0, 8.0)))
	# 低矮通道：底面 y=-8，只有蹲下（6px）能进，站立（11px）进不去
	world.add_child(_solid(Vector2(600.0, -12.0), Vector2(64.0, 8.0)))

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
		await _case_dash_freeze_direction()
		await _case_climb_hop_no_drain()
		await _case_dash_up_wall_jump()
		await _case_wall_jump_var_height()
		await _case_climb_jump_from_normal()
		await _case_wall_boost()
		await _case_wall_slide()
		await _case_fast_fall()
		await _case_dash_refill_cooldown()
		await _case_dash_refill_after_super()
		await _case_dash_refill_after_hyper()
		await _case_carryable_not_solid()
		await _case_wall_speed_retention()
		await _case_duck()
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
		player._set_duck(false)
		player.dash_count = player.max_dashes
		player.stamina = player.max_stamina
		player.dash_timer = 0.0
		player.dash_cooldown_timer = 0.0
		player.dash_attack_timer = 0.0
		player.dash_dir = Vector2.ZERO
		player.facing = 1.0
		player.last_technique = "None"
		player.move_x = 0.0
		player.move_y = 0.0
		player._coyote = 0.0
		player._jump_buffer = 0.0
		player._dash_buffer = 0.0
		player._var_jump_timer = 0.0
		player._climb_lock = 0.0
		player._dash_freeze = 0.0
		player._force_move_x_timer = 0.0
		player._hop_wait_x = 0
		player._floor_last_frame = false
		player._max_fall = player.max_fall_speed
		player._wall_slide_timer = player.wall_slide_time
		player._wall_slide_dir = 0
		player._wall_boost_timer = 0.0
		player._wall_speed_retention_timer = 0.0
		player._wall_speed_retained = 0.0
		player._dash_refill_cooldown_timer = 0.0
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

	# Dash 起手有 dash_freeze_time 的冻结期，速度与方向要等冻结结束才写入。
	func _wait_dash_launch() -> bool:
		return await _wait_until(func() -> bool: return player.mode == Player.Mode.DASH and player.dash_dir != Vector2.ZERO, 12)

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
		var dashing: bool = await _wait_dash_launch()
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
		await _wait_dash_launch()
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
		await _reset(Vector2(160.0, -27.0))
		Input.action_press("move_right")
		await _step(4)
		Input.action_press("move_down")
		Input.action_press("dash")
		await _wait_dash_launch()
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
		await _wait_dash_launch()
		Input.action_release("dash")
		await _wait_until(func() -> bool: return player.mode != Player.Mode.DASH, 20)
		_check("Dash 结束后仍高于跑速", player.velocity.x > player.max_speed, "vx=%.1f max_speed=%.1f" % [player.velocity.x, player.max_speed])
		_check("Dash 结束速度=EndDashSpeed", absf(player.velocity.x - player.dash_end_speed) < 2.0, "vx=%.1f 期望≈%.1f" % [player.velocity.x, player.dash_end_speed])

	# 可变跳高：按住明显高于点按
	func _case_var_jump() -> void:
		var tap: float = await _measure_jump(2)
		var hold: float = await _measure_jump(30)
		_check("按住跳明显高于点按", hold > tap * 1.3, "点按=%.1fpx 按住=%.1fpx" % [tap, hold])
		_check("按住跳高约 3-4 格", hold > 20.0 and hold < 48.0, "按住=%.1fpx = %.1f 格" % [hold, hold / 8.0])

	func _measure_jump(hold_frames: int) -> float:
		await _reset(Vector2(213.0, 0.0))
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

	# 上升撞天花板角落时逐像素横移穿过缺口（缝 x 796..804，起跳点故意偏 3px）
	func _case_corner_correction() -> void:
		await _reset(Vector2(803.0, 0.0))
		var before: int = player.corner_corrections
		var peak: float = player.global_position.y
		Input.action_press("jump")
		for _i in range(30):
			await _step(1)
			peak = minf(peak, player.global_position.y)
		Input.action_release("jump")
		_check("角落修正触发", player.corner_corrections > before, "corner_corrections=%d" % player.corner_corrections)
		_check("修正后穿过天花板缺口", peak < -21.0, "peak_y=%.1f（无修正会卡在 -13 附近）" % peak)

	# 抓墙静止：不下滑、贴住墙面无空隙
	func _case_climb_no_slip() -> void:
		await _reset(Vector2(-99.0, -21.0))
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
		await _reset(Vector2(-99.0, -21.0))
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
		await _reset(Vector2(-99.0, -21.0))
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
		await _wait_dash_launch()
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

	# 冻结期补按方向：K 先按、方向键晚一帧，仍要吃到正确的八向方向
	func _case_dash_freeze_direction() -> void:
		await _reset(Vector2(0.0, 0.0))
		Input.action_press("dash")
		var started: bool = await _wait_dash_start()
		_check("Dash 起手立刻进入冻结", started and player._dash_freeze > 0.0 and player.dash_dir == Vector2.ZERO, "freeze=%.3f dash_dir=(%.2f, %.2f)" % [player._dash_freeze, player.dash_dir.x, player.dash_dir.y])
		_check("冻结期速度归零", player.velocity == Vector2.ZERO, "v=(%.1f, %.1f)" % [player.velocity.x, player.velocity.y])
		Input.action_release("dash")
		await _step(1)
		Input.action_press("move_up")
		await _wait_dash_launch()
		_check("冻结期补按的方向被采纳", player.dash_dir.y < -0.9 and absf(player.dash_dir.x) < 0.1, "dash_dir=(%.2f, %.2f)" % [player.dash_dir.x, player.dash_dir.y])
		_check("上冲速度写入 DashSpeed", player.velocity.y < -player.dash_speed + 1.0, "vy=%.1f 期望≈%.1f" % [player.velocity.y, -player.dash_speed])
		_release_all()

	# 墙沿持续按上：ClimbHop 只触发一次，且不扣体力
	func _case_climb_hop_no_drain() -> void:
		await _reset(Vector2(-99.0, -48.0))
		player.facing = -1.0
		player.climb_hops = 0
		Input.action_press("grab")
		await _wait_until(func() -> bool: return player.mode == Player.Mode.CLIMB)
		var before: float = player.stamina
		Input.action_press("move_up")
		var hopped: bool = await _wait_until(func() -> bool: return player.climb_hops > 0, 60)
		_check("到墙沿触发 ClimbHop", hopped, "climb_hops=%d" % player.climb_hops)
		var after_hop: float = player.stamina
		await _step(60)
		_check("ClimbHop 不重复触发", player.climb_hops == 1, "climb_hops=%d" % player.climb_hops)
		_check("ClimbHop 本身不扣体力", after_hop > before - 20.0, "hop 前=%.1f hop 后=%.1f" % [before, after_hop])
		_check("持续按上不会抽干体力", player.stamina > player.max_stamina * 0.5, "stamina=%.1f / %.1f" % [player.stamina, player.max_stamina])
		_release_all()

	# 上冲蹭 1 格平台侧面 = SuperWallJump
	func _case_dash_up_wall_jump() -> void:
		await _reset(Vector2(315.0, 0.0))
		Input.action_press("move_up")
		Input.action_press("dash")
		await _wait_dash_launch()
		Input.action_release("dash")
		_check("纯上 Dash 方向正确", absf(player.dash_dir.x) < 0.1 and player.dash_dir.y < -0.9, "dash_dir=(%.2f, %.2f)" % [player.dash_dir.x, player.dash_dir.y])
		Input.action_press("jump")
		var jumped: bool = await _wait_until(func() -> bool: return player.mode != Player.Mode.DASH, 14)
		Input.action_release("jump")
		_check("上冲蹭平台边缘触发墙跳", jumped and player.last_technique == "SuperWallJump", "tech=%s" % player.last_technique)
		_check("墙跳方向背离平台", player.velocity.x < -1.0 and player.velocity.y < 0.0, "v=(%.1f, %.1f)" % [player.velocity.x, player.velocity.y])
		_release_all()

	# 墙跳同样受按键时长控制（varJumpTimer）—— 覆盖空中墙跳、攀爬中墙跳、攀爬中垂直爬墙跳三条路径
	func _case_wall_jump_var_height() -> void:
		var tap: float = await _measure_wall_jump(2)
		var hold: float = await _measure_wall_jump(30)
		_check("空中墙跳按住明显高于点按", hold > tap * 1.3, "点按=%.1fpx 按住=%.1fpx" % [tap, hold])
		var climb_tap: float = await _measure_climb_jump(2, true)
		var climb_hold: float = await _measure_climb_jump(30, true)
		_check("攀爬中墙跳按住明显高于点按", climb_hold > climb_tap * 1.3, "点按=%.1fpx 按住=%.1fpx" % [climb_tap, climb_hold])
		var cj_tap: float = await _measure_climb_jump(2, false)
		var cj_hold: float = await _measure_climb_jump(30, false)
		_check("垂直爬墙跳按住明显高于点按", cj_hold > cj_tap * 1.3, "点按=%.1fpx 按住=%.1fpx" % [cj_tap, cj_hold])

	func _measure_climb_jump(hold_frames: int, away_from_wall: bool) -> float:
		await _reset(Vector2(-99.0, -32.0))
		player.facing = -1.0
		Input.action_press("grab")
		var climbing: bool = await _wait_until(func() -> bool: return player.mode == Player.Mode.CLIMB)
		if not climbing:
			_check("抓墙成功（测量用）", false, "mode=%s" % Player.Mode.keys()[player.mode])
			_release_all()
			return 0.0
		await _step(4)
		var start_y: float = player.global_position.y
		var peak: float = start_y
		if away_from_wall: Input.action_press("move_right")
		Input.action_press("jump")
		await _wait_until(func() -> bool: return player.mode != Player.Mode.CLIMB, 6)
		for _i in range(hold_frames):
			await _step(1)
			peak = minf(peak, player.global_position.y)
		Input.action_release("jump")
		for _i in range(40):
			await _step(1)
			peak = minf(peak, player.global_position.y)
		_release_all()
		return start_y - peak

	func _measure_wall_jump(hold_frames: int) -> float:
		await _reset(Vector2(-99.0, -21.0))
		player.facing = -1.0
		await _step(1)
		var start_y: float = player.global_position.y
		var peak: float = start_y
		Input.action_press("jump")
		var jumped: bool = await _wait_until(func() -> bool: return player.last_technique == "WallJump", 6)
		if not jumped:
			_check("墙跳触发（测量用）", false, "tech=%s wall=%d" % [player.last_technique, player.get_wall_direction()])
			_release_all()
			return 0.0
		for _i in range(hold_frames):
			await _step(1)
			peak = minf(peak, player.global_position.y)
		Input.action_release("jump")
		for _i in range(40):
			await _step(1)
			peak = minf(peak, player.global_position.y)
		_release_all()
		return start_y - peak

	# 非攀爬状态下面朝墙 + 按住抓取 + 有体力时按跳 = 垂直爬墙跳，不是被弹开的墙跳
	func _case_climb_jump_from_normal() -> void:
		await _reset(Vector2(-99.0, -21.0))
		player.facing = -1.0
		# 上升中不许抓墙（参考 NormalUpdate 的 Climbing 守卫），所以只会走 NormalUpdate 的跳跃分支
		player.velocity = Vector2(0.0, -50.0)
		Input.action_press("grab")
		Input.action_press("jump")
		await _wait_until(func() -> bool: return player.last_technique != "None", 6)
		_check("面朝墙按住抓取按跳 = 爬墙跳", player.last_technique == "ClimbJump", "tech=%s mode=%s" % [player.last_technique, Player.Mode.keys()[player.mode]])
		_check("爬墙跳不会被弹离墙面", absf(player.velocity.x) < 1.0, "vx=%.1f（普通墙跳会是 %.1f）" % [player.velocity.x, player.wall_jump_speed])
		_release_all()

	# Wallboost：中立爬墙跳后窗口内推离墙面 = 退还体力并转成墙跳（无体力连续上墙的来源）
	func _case_wall_boost() -> void:
		await _reset(Vector2(-99.0, -32.0))
		player.facing = -1.0
		Input.action_press("grab")
		var climbing: bool = await _wait_until(func() -> bool: return player.mode == Player.Mode.CLIMB)
		_check("Wallboost 前置：进入攀爬", climbing, "mode=%s" % Player.Mode.keys()[player.mode])
		await _step(4)
		var before: float = player.stamina
		Input.action_press("jump")
		await _wait_until(func() -> bool: return player.last_technique == "ClimbJump", 6)
		Input.action_release("jump")
		var after_jump: float = player.stamina
		_check("Wallboost 前置：中立爬墙跳扣体力", before - after_jump > 20.0, "扣=%.1f" % (before - after_jump))
		Input.action_press("move_right")
		var boosted: bool = await _wait_until(func() -> bool: return player.last_technique == "WallBoost", 12)
		_check("窗口内推离墙面触发 Wallboost", boosted, "tech=%s" % player.last_technique)
		_check("Wallboost 退还爬墙跳体力", player.stamina > after_jump + player.climb_jump_stamina_cost - 1.0, "boost 前=%.1f 后=%.1f" % [after_jump, player.stamina])
		# 触发帧写入 WallJumpHSpeed，同帧的超速减速会吃掉 RunReduce*AirMult/60≈4.3，留 6 的余量
		_check("Wallboost 给出墙跳水平速度", absf(player.velocity.x - player.wall_jump_speed) < 6.0, "vx=%.1f 期望≈%.1f" % [player.velocity.x, player.wall_jump_speed])
		_check("Wallboost 后不锁输入（可立刻回墙）", player._force_move_x_timer <= 0.0, "force_timer=%.3f" % player._force_move_x_timer)
		_release_all()

	# Wall Slide：推向墙面时下落被摩擦压到 WallSlideStartMax
	func _case_wall_slide() -> void:
		await _reset(Vector2(-100.0, -56.0))
		Input.action_press("move_left")
		await _step(20)
		_check("贴墙下落被压到 WallSlideStartMax 附近", player.velocity.y < player.max_fall_speed * 0.4, "vy=%.1f max_fall=%.1f" % [player.velocity.y, player.max_fall_speed])
		_check("贴墙下滑 20 帧仍在墙面高度内", player.global_position.y < -40.0, "y=%.1f（无摩擦会掉到 -10 以下）" % player.global_position.y)
		_release_all()

	# Fastfalling：按住下方向时下落上限渐进到 FastMaxFall
	func _case_fast_fall() -> void:
		await _reset(Vector2(213.0, -160.0))
		Input.action_press("move_down")
		await _step(40)
		_check("按住下落速度超过 MaxFall", player.velocity.y > player.max_fall_speed + 40.0, "vy=%.1f MaxFall=%.1f" % [player.velocity.y, player.max_fall_speed])
		_check("下落速度不超过 FastMaxFall", player.velocity.y <= player.fast_max_fall_speed + 1.0, "vy=%.1f FastMaxFall=%.1f" % [player.velocity.y, player.fast_max_fall_speed])
		_release_all()

	# DashRefillCooldown：落地补 dash 有 0.1s 冷却（Extended Dash 的窗口）
	func _case_dash_refill_cooldown() -> void:
		await _reset(Vector2(0.0, 0.0))
		Input.action_press("move_right")
		await _step(10)
		Input.action_press("dash")
		await _wait_dash_launch()
		Input.action_release("dash")
		_check("Dash 起手扣掉次数", player.dash_count == 0, "dash_count=%d" % player.dash_count)
		_check("冷却期内在地面也不补 dash", player.is_on_floor() and player.dash_count == 0, "on_floor=%s count=%d cooldown=%.3f" % [player.is_on_floor(), player.dash_count, player._dash_refill_cooldown_timer])
		await _step(12)
		_check("冷却结束后落地补回 dash", player.dash_count == player.max_dashes, "dash_count=%d cooldown=%.3f" % [player.dash_count, player._dash_refill_cooldown_timer])
		_release_all()

	# Super / Hyper / Wavedash 之后 dash 必须恢复。
	# 参考 Update 顶部的 onGround 是几何探针（脚下 1px 有实体且 vy>=0），水平 Dash 期间照样算站在地上，
	# 所以 DashRefillCooldown 一过就补回 dash。用 Godot 的 is_on_floor() 则永远补不上（Dash 帧没有向下位移）。
	func _case_dash_refill_after_super() -> void:
		await _reset(Vector2(0.0, 0.0))
		Input.action_press("move_right")
		await _step(25)
		Input.action_press("dash")
		await _wait_dash_launch()
		Input.action_release("dash")
		_check("水平地面 Dash 期间仍算站在地上", player._on_ground(), "on_ground=%s is_on_floor=%s vy=%.1f" % [player._on_ground(), player.is_on_floor(), player.velocity.y])
		_check("Dash 起手扣掉次数（冷却中不补）", player.dash_count == 0, "count=%d cd=%.3f" % [player.dash_count, player._dash_refill_cooldown_timer])
		await _step(8)
		_check("地面 Dash 中冷却结束即补回 dash", player.dash_count == player.max_dashes, "count=%d cd=%.3f" % [player.dash_count, player._dash_refill_cooldown_timer])
		Input.action_press("jump")
		await _wait_dash_exit()
		Input.action_release("jump")
		_check("Super 起飞后仍持有 dash", player.last_technique == "Super" and player.dash_count == player.max_dashes, "tech=%s count=%d" % [player.last_technique, player.dash_count])
		_release_all()

	# Hyper / Ultra（斜下 Dash 触地滑行 + 跳）之后 dash 同样要恢复
	func _case_dash_refill_after_hyper() -> void:
		await _reset(Vector2(0.0, 0.0))
		Input.action_press("move_right")
		await _step(25)
		Input.action_press("move_down")
		Input.action_press("dash")
		await _wait_dash_launch()
		Input.action_release("dash")
		Input.action_release("move_down")
		_check("触地滑行期间仍算站在地上", player._on_ground() and player.is_ducking, "on_ground=%s ducking=%s" % [player._on_ground(), player.is_ducking])
		await _step(8)
		Input.action_press("jump")
		await _wait_dash_exit()
		Input.action_release("jump")
		_check("Hyper 起飞后仍持有 dash", player.last_technique == "Hyper" and player.dash_count == player.max_dashes, "tech=%s count=%d" % [player.last_technique, player.dash_count])
		var landed_refill: bool = await _wait_until(func() -> bool: return player._on_ground() and player.dash_count == player.max_dashes, 60)
		_check("Hyper 落地后 dash 保持满", landed_refill, "count=%d on_ground=%s" % [player.dash_count, player._on_ground()])
		_release_all()

	# 可携带物不能挡住角色（参考 Celeste：玩家只与 Solid 碰撞，Theo 是 Actor）。
	# 同层时角色会被 Theo 的圆形碰撞体卡在半空，is_on_floor() 为假 → dash 与体力都补不回来。
	func _case_carryable_not_solid() -> void:
		var theo: Node2D = load("res://scenes/components/theo.tscn").instantiate()
		theo.global_position = Vector2(60.0, -6.0)
		get_parent().add_child(theo)
		await _reset(Vector2(0.0, 0.0))
		Input.action_press("move_right")
		await _step(80)
		_check("可携带物不阻挡角色", player.global_position.x > 100.0, "x=%.1f（被 Theo 卡住会停在 50 附近）" % player.global_position.x)
		_check("经过可携带物时仍算站在地上", player._on_ground(), "on_ground=%s y=%.1f" % [player._on_ground(), player.global_position.y])
		_release_all()
		theo.queue_free()
		await _step(2)

	# Wall Speed Retention：撞墙瞬间存下水平速度（Cornerboost 的来源）
	func _case_wall_speed_retention() -> void:
		await _reset(Vector2(-70.0, 0.0))
		Input.action_press("move_left")
		var armed: bool = await _wait_until(func() -> bool: return player._wall_speed_retention_timer > 0.0, 40)
		_check("撞墙武装速度保留窗口", armed, "timer=%.3f" % player._wall_speed_retention_timer)
		_check("保留的是撞墙前的跑速", player._wall_speed_retained < -player.max_speed * 0.8, "retained=%.1f max_speed=%.1f" % [player._wall_speed_retained, player.max_speed])
		_release_all()

	# 下蹲：地面按下变矮、松开站起、低通道内站不起来
	func _case_duck() -> void:
		await _reset(Vector2(0.0, 0.0))
		Input.action_press("move_down")
		var ducked: bool = await _wait_until(func() -> bool: return player.is_ducking, 6)
		var rect: RectangleShape2D = player.collider.shape
		_check("地面按下进入下蹲", ducked, "ducking=%s" % player.is_ducking)
		_check("下蹲碰撞盒变矮", absf(rect.size.y - player.duck_height) < 0.01, "h=%.2f 期望=%.2f" % [rect.size.y, player.duck_height])
		_check("下蹲碰撞盒底边不动", absf(player.collider.position.y + player.duck_height * 0.5) < 0.01 and absf(player.global_position.y) < 0.6, "shape_y=%.2f 脚底 y=%.2f" % [player.collider.position.y, player.global_position.y])
		Input.action_press("move_right")
		await _step(20)
		_check("下蹲时地面摩擦压住水平速度", absf(player.velocity.x) < player.max_speed * 0.5, "vx=%.1f" % player.velocity.x)
		Input.action_release("move_right")
		Input.action_release("move_down")
		var stood: bool = await _wait_until(func() -> bool: return not player.is_ducking, 6)
		_check("松开下方向自动站起", stood and absf(rect.size.y - player.stand_height) < 0.01, "ducking=%s h=%.2f" % [player.is_ducking, rect.size.y])
		# 低矮通道（净空 8px）：蹲着能待、站不起来
		player.global_position = Vector2(600.0, 0.0)
		player.velocity = Vector2.ZERO
		player._set_duck(true)
		await _step(3)
		_check("低通道内站不起来", player.is_ducking and not player._can_unduck(), "ducking=%s can_unduck=%s" % [player.is_ducking, player._can_unduck()])
		_release_all()
