class_name GrayboxParts
extends RefCounted
## 灰盒组件：全部用代码构建（不使用 tscn）。
## 放置方式：在 TileMap 里刷对应的 tile（tile 只是占位图；运行时按 cell 生成这些节点）。


class Hazard extends Area2D:
	var level: Node

	func _ready() -> void:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(8, 8)
		cs.shape = rect
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(body: Node2D) -> void:
		if level and body is CharacterBody2D:
			level.call("respawn_player")


class Crystal extends Area2D:
	func _ready() -> void:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(8, 8)
		cs.shape = rect
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(body: Node2D) -> void:
		if body is CharacterBody2D:
			body.set("dash_count", int(body.get("max_dashes")))
			queue_free()


class Spring extends Area2D:
	var bounce := 260.0

	func _ready() -> void:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(8, 6)
		cs.shape = rect
		cs.position = Vector2(0, 1)
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(body: Node2D) -> void:
		if body is CharacterBody2D:
			var v: Vector2 = body.velocity
			if v.y >= -0.01:
				body.velocity = Vector2(v.x, -bounce)


class Jelly extends Area2D:
	var bounce := 300.0

	func _ready() -> void:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(8, 8)
		cs.shape = rect
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(body: Node2D) -> void:
		if body is CharacterBody2D:
			var v: Vector2 = body.velocity
			if v.y >= 0.0:
				body.velocity = Vector2(v.x, -bounce)


class Breakable extends StaticBody2D:
	func _ready() -> void:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(8, 8)
		cs.shape = rect
		add_child(cs)

	func _physics_process(_delta: float) -> void:
		for child in get_children():
			if child is Area2D:
				for b in child.get_overlapping_bodies():
					if b is CharacterBody2D and float(b.get("dash_attack_timer")) > 0.0:
						queue_free()
						return


class Checkpoint extends Area2D:
	var level: Node

	func _ready() -> void:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(8, 8)
		cs.shape = rect
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(body: Node2D) -> void:
		if body is CharacterBody2D:
			level.call("set_checkpoint", global_position)
