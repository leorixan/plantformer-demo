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
	var size := Vector2(8, 8)
	var entity_layer: TileMapLayer
	var cooldown_layer: TileMapLayer
	var cells: Array = []
	var _monitor: CollisionShape2D

	func _ready() -> void:
		collision_mask = 2
		_monitor = CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		_monitor.shape = rect
		add_child(_monitor)
		body_entered.connect(_on_body)

	func _on_body(body: Node2D) -> void:
		if not (body is CharacterBody2D) or _monitor.disabled:
			return
		if body.has_method("refill_dash"):
			body.call("refill_dash")
		if body.has_method("hitstop_frames"):
			body.call("hitstop_frames", 2)
		_monitor.set_deferred("disabled", true)
		# 冷却视觉：水晶从 Entities 层移到灰色层
		if entity_layer and cooldown_layer:
			for e in cells:
				entity_layer.erase_cell(e[0])
				cooldown_layer.set_cell(e[0], int(e[1]), e[2])
		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(_monitor):
			_monitor.set_deferred("disabled", false)
		if entity_layer and cooldown_layer:
			for e in cells:
				cooldown_layer.erase_cell(e[0])
				entity_layer.set_cell(e[0], int(e[1]), e[2])

class Spring extends Area2D:
	var size := Vector2(8, 8)
	var dir := Vector2.UP
	var launch := 300.0

	func _ready() -> void:
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(body: Node2D) -> void:
		if not (body is CharacterBody2D):
			return
		var v: Vector2 = body.velocity
		if dir.y < 0.0:
			body.velocity = Vector2(v.x, -launch)
		elif dir.y > 0.0:
			body.velocity = Vector2(v.x, launch)
		elif dir.x < 0.0:
			body.velocity = Vector2(-launch, -launch * 0.5)
		else:
			body.velocity = Vector2(launch, -launch * 0.5)


class Breakable extends StaticBody2D:
	var size := Vector2(8, 8)

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
