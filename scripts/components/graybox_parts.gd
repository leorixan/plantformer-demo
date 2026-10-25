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
	## 蔚蓝 Dream Block：常态实心；冲刺接触时短暂失效让玩家穿过，并回复冲刺+体力
	var level: Node
	var size := Vector2(8, 8)
	var _cs: CollisionShape2D
	var _detector: Area2D
	var _cooldown := 0.0

	func _ready() -> void:
		collision_mask = 2
		_cs = CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		_cs.shape = rect
		add_child(_cs)
		_detector = Area2D.new()
		_detector.collision_mask = 2
		var dcs := CollisionShape2D.new()
		var drect := RectangleShape2D.new()
		drect.size = size + Vector2(10, 10)
		dcs.shape = drect
		_detector.add_child(dcs)
		add_child(_detector)

	func _physics_process(delta: float) -> void:
		if _cooldown > 0.0:
			_cooldown -= delta
			if _cooldown <= 0.0:
				_cs.set_deferred("disabled", false)
			return
		for b in _detector.get_overlapping_bodies():
			if not (b is CharacterBody2D):
				continue
			var attacking: bool = b.has_method("is_attacking") and bool(b.call("is_attacking"))
			if attacking:
				_cs.set_deferred("disabled", true)
				_cooldown = 0.25
				if b.has_method("refill_dash"):
					b.call("refill_dash")
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
