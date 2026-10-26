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
					if b is CharacterBody2D and b.has_method("is_attacking") and b.call("is_attacking"):
						queue_free()
						return


class DreamBlock extends StaticBody2D:
	## 蔚蓝 Dream Block：常态实心；冲刺状态接触时进入 Dream Dash（保持方向原速），
	## 只对本方块加碰撞例外（不关闭碰撞，方块内撞墙/机关照常），离开后结束
	var level: Node
	var size := Vector2(8, 8)
	var _detector: Area2D
	var _active := false
	var _player: CharacterBody2D

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
		drect.size = size + Vector2(24, 24)
		dcs.shape = drect
		_detector.add_child(dcs)
		add_child(_detector)

	func _physics_process(_delta: float) -> void:
		var overlapping := _detector.get_overlapping_bodies()
		if _active:
			for b in overlapping:
				if b == _player:
					return
			_active = false
			if is_instance_valid(_player) and _player.has_method("end_dream_dash"):
				_player.call("end_dream_dash", self)
			_player = null
			return
		for b in overlapping:
			if not (b is CharacterBody2D):
				continue
			# 紧贴方块时冲刺可能先被碰撞挡住（速度被清），除 is_dashing 外也接受冲刺起手窗口
			var dashing: bool = b.has_method("is_dashing") and bool(b.call("is_dashing"))
			var just_dashed: bool = b.get("dash_attack_timer") != null and float(b.get("dash_attack_timer")) > 0.0
			if dashing or just_dashed:
				_player = b
				_active = true
				var dir: Vector2 = b.velocity
				var dd = b.get("dash_dir")
				if dd is Vector2 and (dd as Vector2).length() > 0.01:
					dir = dd
				if b.has_method("start_dream_dash"):
					b.call("start_dream_dash", dir, self)
				return


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
			if not full.has_point(p.global_position):
				p.remove_collision_exception_with(self)
				_exception = false
				_player = null
			return
		if p.velocity.dot(pass_dir) > 1.0:
			p.add_collision_exception_with(self)
			_exception = true
			_player = p
