extends SceneTree
## 素材库组件回归：验证 spike / breakable_block / spring / checkpoint / kill_plane
## 运行：godot --headless --path . --script res://scripts/debug/component_regression.gd

func _initialize() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var rows := [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"..........P.....",
		"..S..B..^..C....",
		"################",
	]
	var result := SceneBuilder.build(rows, load("res://scenes/player/player.tscn"))
	world.add_child(result["container"])
	var player: Player = result["player"]
	player.global_position = result["spawn"]
	player.kill_plane_y = result["kill_plane_y"]
	world.add_child(player)
	var driver := Tester.new()
	driver.p = player
	driver.world = world
	root.add_child(driver)

class Tester extends Node:
	var p: Player
	var world: Node
	var passes := 0
	var failures: Array[String] = []

	func _ready() -> void:
		await get_tree().physics_frame
		await run()
		get_tree().quit()

	func _step(n := 1) -> void:
		for _i in range(n): await get_tree().physics_frame

	func _release() -> void:
		for a in ["move_left","move_right","move_up","move_down","jump","dash","grab"]:
			Input.action_release(a)

	func _check(name: String, ok: bool, detail := "") -> void:
		if ok: passes += 1
		else: failures.append("%s | %s" % [name, detail])

	func _teleport(at: Vector2) -> void:
		_release()
		p.global_position = at
		p.velocity = Vector2.ZERO
		p.mode = Player.Mode.NORMAL
		p.dash_count = 1
		p.stamina = p.max_stamina
		await _step(2)

	func run() -> void:
		# 1. Checkpoint：进入存盘点记录重生位置（存盘点中心 (92,108)）
		await _teleport(Vector2(80.0, 112.0))
		p.set_checkpoint(Vector2(10.0, 10.0))
		Input.action_press("move_right")
		await _step(12)
		Input.action_release("move_right")
		_check("存盘点记录重生位置", p.last_checkpoint == Vector2(92.0, 108.0), "last=%s" % p.last_checkpoint)

		# 2. Spike：碰刺 → take_damage → 回存盘点
		p.set_checkpoint(Vector2(80.0, 112.0))
		await _teleport(Vector2(24.0, 112.0))
		await _step(2)
		_check("尖刺触发 take_damage 回存盘点", p.global_position.is_equal_approx(Vector2(80.0, 112.0)), "pos=%s" % p.global_position)

		# 3. BreakableBlock：普通状态撞不碎
		await _teleport(Vector2(30.0, 112.0))
		p.dash_count = 0
		var block: Node = world.get_node("Generated/BreakableBlock")
		Input.action_press("move_right")
		await _step(8)
		Input.action_release("move_right")
		_check("普通状态撞可破坏方块不碎", is_instance_valid(block) and not block.is_queued_for_deletion())

		# 4. BreakableBlock：attacking（Dash）撞碎
		await _teleport(Vector2(28.0, 112.0))
		block = world.get_node("Generated/BreakableBlock")
		Input.action_press("dash")
		await _step(1)
		Input.action_release("dash")
		await _step(15)
		_check("attacking 状态撞碎可破坏方块", not is_instance_valid(block) or block.is_queued_for_deletion())

		# 5. Spring：踩弹簧弹起
		await _teleport(Vector2(56.0, 112.0))
		Input.action_press("move_right")
		await _step(10)
		Input.action_release("move_right")
		await _step(1)
		_check("弹簧将玩家弹起", p.velocity.y < -150.0, "vy=%.1f" % p.velocity.y)

		# 6. kill_plane：掉出死亡线重生（重生点避开弹簧/尖刺）
		p.set_checkpoint(Vector2(80.0, 112.0))
		await _teleport(Vector2(80.0, 300.0))
		await _step(4)
		_check("掉出 kill_plane 重生", p.global_position.is_equal_approx(Vector2(80.0, 112.0)), "pos=%s" % p.global_position)

		print("---- COMPONENT REGRESSION %d passed, %d failed ----" % [passes, failures.size()])
		for f in failures: print("FAIL ", f)
		if failures.is_empty():
			print("ALL OK")
