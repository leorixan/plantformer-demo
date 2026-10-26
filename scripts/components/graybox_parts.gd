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
		_monitor.set_deferred("disabled", true)
		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(_monitor):
			_monitor.set_deferred("disabled", false)


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
			var dashing: bool = b.has_method("is_dashing") and bool(b.call("is_dashing"))
			var just_dashed: bool = b.get("dash_attack_timer") != null and float(b.get("dash_attack_timer")) > 0.0
			var pressed: bool = (b.has_method("is_dash_pressed") and bool(b.call("is_dash_pressed"))) or Input.is_action_pressed("dash")
			if not player_inside(b):
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

	func player_inside(p: Node2D) -> bool:
		var r := Rect2(global_position - size * 0.5 - Vector2(8, 8), size + Vector2(16, 16))
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
	## 单向墙：只有沿 pass_dir 方向移动时穿过，其余情况实心。
	## pass_dir 由关卡按贴附地形自动判定（下贴地→向上穿，上贴顶→向下穿，左贴墙→向右穿，右贴墙→向左穿）
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
		drect.size = size + Vector2(16, 16)
		dcs.shape = drect
		_detector.add_child(dcs)
		add_child(_detector)

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
			# 必须整个角色完全离开墙体范围（含角色尺寸余量）才恢复碰撞
			var expand := Vector2(8.0, 11.0)
			var full := Rect2(global_position - size * 0.5 - expand * 0.5, size + expand)
			if not full.has_point(p.global_position - Vector2(0, 5.5)):
				p.remove_collision_exception_with(self)
				_exception = false
				_player = null
			return
		if p.velocity.dot(pass_dir) > 1.0:
			p.add_collision_exception_with(self)
			_exception = true
			_player = p
