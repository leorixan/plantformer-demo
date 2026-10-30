class_name GrayboxParts
extends RefCounted
## 红=伤害 青=冲刺水晶 绿=弹簧(按地形自动判朝向) 褐=可破坏 紫=Dream Block(冲刺激活) 金=存档点


class Hazard extends Area2D:
	var level: Node
	var size := Vector2(8, 8)

	func _ready() -> void:
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(body: Node2D) -> void:
		if level and body is CharacterBody2D:
			level.call("respawn_player")


class Crystal extends Area2D:
	## 冲刺水晶：8x8 45°菱形（备选 #1），呼吸缩放；拾取后消失并留下白色虚线勾边，2.5s 恢复
	const SIZE := Vector2(8, 8)
	const RESPAWN_TIME := 2.5
	const BASE := Color(0.28, 0.78, 0.82, 1.0)
	const LIGHT := Color(0.65, 0.95, 0.98, 1.0)
	const WHITE := Color(0.90, 0.99, 1.0, 1.0)
	const DARK := Color(0.12, 0.45, 0.55, 1.0)
	const OUTLINE := Color(0.05, 0.22, 0.30, 1.0)
	const DASH_COLOR := Color(1.0, 1.0, 1.0, 0.8)
	const BURST_COLOR := Color(0.60, 0.95, 0.95, 0.9)
	const DUST := preload("res://scripts/fx/jump_dust.gd")
	const ROWS := [[3, 4], [2, 5], [1, 6], [0, 7], [0, 7], [1, 6], [2, 5], [3, 4]]

	var size := SIZE
	var _monitor: CollisionShape2D
	var _visual: Node2D
	var _outline: Node2D
	var _cooldown := false
	var _breath: Tween


	func _ready() -> void:
		collision_mask = 2
		_monitor = CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = SIZE
		_monitor.shape = rect
		add_child(_monitor)
		body_entered.connect(_on_body)
		_visual = Node2D.new()
		_visual.name = "Visual"
		add_child(_visual)
		_build_visual()
		_outline = Node2D.new()
		_outline.name = "DashedOutline"
		add_child(_outline)
		_build_outline()
		_outline.visible = false
		_play_appear()


	func _play_appear() -> void:
		if _breath and _breath.is_valid():
			_breath.kill()
		_visual.scale = Vector2(0.01, 0.01)
		_visual.modulate.a = 0.0
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(_visual, "scale", Vector2(1.12, 1.12), 0.15)
		t.tween_property(_visual, "modulate:a", 1.0, 0.15)
		t.set_parallel(false)
		t.tween_property(_visual, "scale", Vector2(1.0, 1.0), 0.10)
		t.finished.connect(_start_breathing)


	func _start_breathing() -> void:
		if _breath and _breath.is_valid():
			_breath.kill()
		_breath = create_tween()
		_breath.set_loops()
		_breath.tween_property(_visual, "scale", Vector2(1.12, 1.12), 0.6)
		_breath.tween_property(_visual, "scale", Vector2(1.0, 1.0), 0.6)


	func _cell(gx: int, gy: int, color: Color, parent: Node2D) -> void:
		var r := ColorRect.new()
		r.color = color
		r.position = Vector2(gx - 4, gy - 4)
		r.size = Vector2(1, 1)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(r)


	func _build_visual() -> void:
		for y in 8:
			for x in range(int(ROWS[y][0]), int(ROWS[y][1]) + 1):
				_cell(x, y, BASE, _visual)
		for pt in [Vector2i(3, 1), Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]:
			_cell(pt.x, pt.y, LIGHT, _visual)


	func _build_outline() -> void:
		# 菱形边缘格子，每隔一格画一个白点形成虚线勾边
		var edge_cells: Array = []
		for y in 8:
			for x in range(int(ROWS[y][0]), int(ROWS[y][1]) + 1):
				var is_edge := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var np: Vector2i = Vector2i(x, y) + d
					var cx := np.x
					var cy := np.y
					var in_rows := cy >= 0 and cy < 8 and cx >= int(ROWS[cy][0]) and cx <= int(ROWS[cy][1])
					if not in_rows:
						is_edge = true
						break
				if is_edge:
					edge_cells.append(Vector2i(x, y))
		edge_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return atan2(float(a.y) - 3.5, float(a.x) - 3.5) < atan2(float(b.y) - 3.5, float(b.x) - 3.5))
		for i in edge_cells.size():
			if i % 2 == 0:
				var pt: Vector2i = edge_cells[i]
				_cell(pt.x, pt.y, DASH_COLOR, _outline)


	func _on_body(body: Node2D) -> void:
		if _cooldown or not (body is CharacterBody2D) or _monitor.disabled:
			return
		if body.has_method("refill_dash"):
			body.call("refill_dash")
		if body.has_method("hitstop_frames"):
			body.call("hitstop_frames", 2)
		_cooldown = true
		_monitor.set_deferred("disabled", true)
		_visual.visible = false
		_outline.visible = true
		_spawn_burst()
		await get_tree().create_timer(RESPAWN_TIME).timeout
		if not is_instance_valid(self):
			return
		_cooldown = false
		_visual.visible = true
		_outline.visible = false
		_play_appear()
		_monitor.set_deferred("disabled", false)


	func _spawn_burst() -> void:
		var dust: Node = DUST.new()
		var parent := get_parent()
		if parent == null:
			return
		parent.add_child(dust)
		if dust.has_method("setup"):
			dust.call("setup", global_position, 0.0, 10, BURST_COLOR)


class Spring extends Area2D:
	## 四向单向弹簧：只从弹射方向一侧接触才触发；木色半边朝向弹射方向
	var size := Vector2(8, 8)
	var dir := Vector2.UP
	var launch := 300.0
	var _cooldown := 0.0


	func _ready() -> void:
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
		add_child(cs)
		body_entered.connect(_on_body)


	func _physics_process(delta: float) -> void:
		if _cooldown > 0.0:
			_cooldown = maxf(0.0, _cooldown - delta)
			return
		for body in get_overlapping_bodies():
			if body is CharacterBody2D and _from_valid_side(body):
				_launch(body)
				break


	func _from_valid_side(body: Node2D) -> bool:
		var body_center: Vector2 = body.global_position + Vector2(0.0, -5.5)
		return (body_center - global_position).dot(dir) >= 0.0


	func _on_body(body: Node2D) -> void:
		if _cooldown > 0.0 or not (body is CharacterBody2D):
			return
		if _from_valid_side(body):
			_launch(body)


	func _launch(body: Node2D) -> void:
		var v: Vector2 = body.velocity
		if dir.y < 0.0:
			body.velocity = Vector2(v.x, -launch)
		elif dir.y > 0.0:
			body.velocity = Vector2(v.x, launch)
		elif dir.x < 0.0:
			body.velocity = Vector2(-launch, v.y)
		else:
			body.velocity = Vector2(launch, v.y)
		_cooldown = 0.25


class Breakable extends StaticBody2D:
	const BASE := Color(0.36, 0.39, 0.45, 1.0)
	const LIGHT := Color(0.45, 0.48, 0.55, 1.0)
	const DARK := Color(0.25, 0.28, 0.33, 1.0)
	const CRACK := Color(0.16, 0.18, 0.22, 1.0)
	var size := Vector2(8, 8)
	var _visual: Node2D

	func _ready() -> void:
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
		add_child(cs)
		var area := Area2D.new()
		area.collision_mask = 2
		var acs := CollisionShape2D.new()
		var arect := RectangleShape2D.new()
		arect.size = size + Vector2(4, 4)
		acs.shape = arect
		area.add_child(acs)
		add_child(area)
		_build_visual()

	func _build_visual() -> void:
		var w := maxi(2, int(round(size.x)))
		var h := maxi(2, int(round(size.y)))
		_visual = Node2D.new()
		_visual.name = "Visual"
		add_child(_visual)
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				img.set_pixel(x, y, BASE)
		for x in w:
			img.set_pixel(x, 0, LIGHT)
			img.set_pixel(x, h - 1, DARK)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		# 中心三分叉短裂纹（备选方案 2）
		var center := Vector2i(w / 2, h / 2)
		var dirs: Array = [Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
		dirs.shuffle()
		for i in 3:
			var d: Vector2i = dirs[i]
			var length := rng.randi_range(3, maxi(3, mini(w, h) * 2 / 3))
			var pt := center
			for step in range(length):
				pt += d
				if pt.x < 1 or pt.y < 1 or pt.x >= w - 1 or pt.y >= h - 1:
					break
				img.set_pixel(pt.x, pt.y, CRACK)
				# 抖动：让裂纹呈折线而不是直线
				if rng.randf() < 0.65:
					var jitter := Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
					if jitter != Vector2i.ZERO:
						var jt := pt + jitter
						if jt.x >= 1 and jt.y >= 1 and jt.x < w - 1 and jt.y < h - 1:
							img.set_pixel(jt.x, jt.y, CRACK)
				if rng.randf() < 0.3:
					d += Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
					if d == Vector2i.ZERO:
						d = dirs[i]
		for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			img.set_pixel(center.x + off.x, center.y + off.y, CRACK)
		# 更多随机 1px 边缘缺损
		var chips := maxi(6, int(w * 0.6) + 4)
		for i in chips:
			var side := rng.randi_range(0, 3)
			var pt2 := Vector2i.ZERO
			if side == 0:
				pt2 = Vector2i(rng.randi_range(0, w - 1), 0)
			elif side == 1:
				pt2 = Vector2i(rng.randi_range(0, w - 1), h - 1)
			elif side == 2:
				pt2 = Vector2i(0, rng.randi_range(0, h - 1))
			else:
				pt2 = Vector2i(w - 1, rng.randi_range(0, h - 1))
			img.set_pixel(pt2.x, pt2.y, Color(0, 0, 0, 0))
		var spr := Sprite2D.new()
		spr.texture = ImageTexture.create_from_image(img)
		spr.centered = true
		_visual.add_child(spr)

	func _physics_process(_delta: float) -> void:
		for child in get_children():
			if child is Area2D:
				for b in child.get_overlapping_bodies():
					if not (b is CharacterBody2D) or not b.has_method("is_attacking") or not b.call("is_attacking"):
						continue
					var dir: Vector2 = b.velocity
					if b.has_method("get_dash_dir"):
						var dd: Vector2 = b.call("get_dash_dir")
						if dd.length() > 0.01:
							dir = dd
					if dir.length() < 0.01:
						continue
					var to_block: Vector2 = global_position - b.global_position
					if to_block.length() < 0.01 or dir.normalized().dot(to_block.normalized()) > 0.2:
						queue_free()
						return


class DreamBlock extends StaticBody2D:
	## 只负责"触发"：冲刺状态接触即通知玩家进入 Dream Dash。
	## Dream Dash 的持续/结束由 player 统一管理（对组内所有紫块加碰撞例外，
	## 直到完全离开全部紫块才结束），避免厚墙/贴脸时被卡住。
	var level: Node
	var size := Vector2(8, 8)
	var _detector: Area2D

	func _ready() -> void:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
		add_child(cs)
		_detector = Area2D.new()
		_detector.collision_mask = 2
		var dcs := CollisionShape2D.new()
		var drect := RectangleShape2D.new()
		drect.size = size + Vector2(16, 16)
		dcs.shape = drect
		_detector.add_child(dcs)
		add_child(_detector)

	func _physics_process(_delta: float) -> void:
		for b in _detector.get_overlapping_bodies():
			if not (b is CharacterBody2D):
				continue
			if b.has_method("is_dream_dashing") and bool(b.call("is_dream_dashing")):
				return
			# 刚离开紫块 0.12s 内不重新触发，避免"结束→再触发"循环
			var exit_t = b.get("_dream_exit_timer")
			if exit_t != null and float(exit_t) > 0.0:
				return
			var dashing: bool = b.has_method("is_dashing") and bool(b.call("is_dashing"))
			var just_dashed: bool = b.get("dash_attack_timer") != null and float(b.get("dash_attack_timer")) > 0.0
			var pressed: bool = (b.has_method("is_dash_pressed") and bool(b.call("is_dash_pressed"))) or Input.is_action_pressed("dash")
			if not player_near(b):
				continue
			var toward: Vector2 = (global_position - b.global_position).normalized()
			var aim: Vector2 = Vector2.ZERO
			if b.has_method("dash_input_dir"):
				aim = b.call("dash_input_dir")
			var aim_ok: bool = aim.length() < 0.01 or aim.normalized().dot(toward) > 0.25
			if dashing or just_dashed or (pressed and aim_ok):
				var dir: Vector2 = b.velocity
				if dashing or just_dashed:
					var dd = b.get("dash_dir")
					if dd is Vector2 and (dd as Vector2).length() > 0.01:
						dir = dd
				elif pressed:
					# 关键：按住冲刺触发时优先用当前输入方向，避免读到上一次冲刺的 dash_dir（导致向上冲却向下走）
					if aim.length() > 0.01:
						dir = aim
					else:
						dir = toward
				if b.has_method("start_dream_dash"):
					print("[dream] trigger pressed=", pressed, " dir=", dir, " player=", b.global_position)
					b.call("start_dream_dash", dir, self)
				return

	func contains_center(c: Vector2) -> bool:
		return Rect2(global_position - size * 0.5, size).has_point(c)

	func player_near(p: Node2D) -> bool:
		# 触发用：离方块 8px 内（贴脸也包含）
		var r := Rect2(global_position - size * 0.5 - Vector2(8, 8), size + Vector2(16, 16))
		return r.has_point(p.global_position - Vector2(0, 5.5))

	func player_inside(p: Node2D) -> bool:
		# 持续判定：玩家身体（8x11）还有一部分在方块内就继续保持 Dream Dash，
		# 避免提前恢复碰撞导致头顶/身体卡在方块边缘
		var half := Vector2(4, 5.5)
		var r := Rect2(global_position - size * 0.5 - half, size + half * 2.0)
		return r.has_point(p.global_position - Vector2(0, 5.5))


class Checkpoint extends Area2D:
	var level: Node
	var size := Vector2(8, 8)

	func _ready() -> void:
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(body: Node2D) -> void:
		if body is CharacterBody2D and level:
			level.call("set_checkpoint", body.global_position)


class OneWay extends StaticBody2D:
	var size := Vector2(8, 8)
	var pass_dir := Vector2.UP
	var _detector: Area2D
	var _player: CharacterBody2D = null
	var _exception := false

	func _ready() -> void:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
		add_child(cs)
		_detector = Area2D.new()
		_detector.collision_mask = 2
		var dcs := CollisionShape2D.new()
		var drect := RectangleShape2D.new()
		drect.size = size + Vector2(28, 28)
		dcs.shape = drect
		_detector.add_child(dcs)
		add_child(_detector)

	func _want(p: CharacterBody2D) -> bool:
		if p.velocity.dot(pass_dir) > 0.1:
			return true
		if p.has_method("get_move_input"):
			return (p.call("get_move_input") as Vector2).dot(pass_dir) > 0.3
		return false

	func _physics_process(_delta: float) -> void:
		var p: CharacterBody2D = null
		for b in _detector.get_overlapping_bodies():
			if b is CharacterBody2D:
				p = b
				break
		if p == null:
			if _exception and is_instance_valid(_player):
				_player.remove_collision_exception_with(self)
			_exception = false
			_player = null
			return
		if _exception:
			# 只要还在朝通行方向移动就保留例外（不能因为"身体还没进墙"就移除，
			# 否则靠近阶段就被取消，导致下向墙穿不过去）
			if not _want(p):
				p.remove_collision_exception_with(self)
				_exception = false
				_player = null
			return
		if _want(p):
			p.add_collision_exception_with(self)
			_exception = true
			_player = p
			print("[oneway] pass dir=", pass_dir)


class Trophy extends Area2D:
	## 奖杯（备选图案 #2 双耳杯）：固定大小 10x8 视觉，碰到计数 +1 并消失
	var level: Node
	var size := Vector2(8, 8)
	const GOLD := Color(0.949, 0.698, 0.188, 1.0)
	const LIGHT := Color(1.0, 0.878, 0.510, 1.0)
	const DARK := Color(0.659, 0.392, 0.063, 1.0)
	const BOB_AMPLITUDE := 2.0
	const BOB_PERIOD := 1.6

	var cells: Array = []
	var _base_y := 0.0
	var _t := 0.0
	var _visual: Node2D


	func _ready() -> void:
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(8, 8)
		cs.shape = rect
		add_child(cs)
		_base_y = position.y
		_t = position.x * 0.15
		_visual = Node2D.new()
		_visual.name = "Visual"
		add_child(_visual)
		_build_cup()
		body_entered.connect(_on_body)


	func _build_cup() -> void:
		# 12x12 设计图，居中到 10x8（x -5..+4, y -3..+4）
		# 杯口
		for x in range(2, 10):
			_cell(x, 2, GOLD)
		# 杯身
		for y in range(3, 6):
			for x in range(3, 9):
				_cell(x, y, GOLD)
		# 杯身收底
		for x in range(4, 8):
			_cell(x, 6, GOLD)
		# 高光
		_cell(3, 3, LIGHT)
		_cell(4, 3, LIGHT)
		_cell(3, 4, LIGHT)
		# 杯柄
		_cell(5, 7, DARK)
		_cell(6, 7, DARK)
		# 底座
		for x in range(4, 8):
			_cell(x, 8, GOLD)
		for x in range(2, 10):
			_cell(x, 9, DARK)
		# 双耳
		_cell(1, 3, GOLD)
		_cell(1, 4, GOLD)
		_cell(2, 5, GOLD)
		_cell(10, 3, GOLD)
		_cell(10, 4, GOLD)
		_cell(9, 5, GOLD)


	func _cell(gx: int, gy: int, color: Color) -> void:
		var r := ColorRect.new()
		r.color = color
		r.position = Vector2(gx - 5, gy - 5)
		r.size = Vector2(1, 1)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_visual.add_child(r)


	func _process(delta: float) -> void:
		_t += delta
		position.y = _base_y + sin(_t * TAU / BOB_PERIOD) * BOB_AMPLITUDE


	func _on_body(body: Node2D) -> void:
		if body is CharacterBody2D and level:
			level.call("collect_trophy", cells)
		queue_free()
