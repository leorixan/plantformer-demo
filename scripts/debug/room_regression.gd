extends SceneTree
## 测试房几何回归：①区 4 / 5 / 6 的坑必须"普通跳与普通冲刺跨不过、目标技巧跨得过"
## ②掉坑立刻死并回到本区存档点 ③每个存档点站得住、每道分隔墙的门洞走得通。
## 改 test_room.gd 的 ZONES 之后要跑这个，否则坑宽会悄悄失效。
## 运行：godot --headless --path . --script res://scripts/debug/room_regression.gd

func _initialize() -> void:
	var room: Node2D = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	var driver := Driver.new()
	driver.room = room
	root.add_child(driver)

class Driver extends Node:
	var room: Node2D
	var player: Player

	func _ready() -> void:
		await get_tree().physics_frame
		await get_tree().physics_frame
		player = room.get_node("Player")
		await run()

	func _step(count := 1) -> void:
		for _i in range(count):
			await get_tree().physics_frame

	func _release() -> void:
		for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "grab"]:
			Input.action_release(action)

	func _put(pos: Vector2) -> void:
		_release()
		player.global_position = pos
		player.velocity = Vector2.ZERO
		player.mode = Player.Mode.NORMAL
		player.dash_count = player.max_dashes
		player.stamina = player.max_stamina
		player.dash_timer = 0.0
		player.dash_dir = Vector2.ZERO
		player.dash_cooldown_timer = 0.0
		player._dash_refill_cooldown_timer = 0.0
		player._set_duck(false)
		player.last_technique = "None"
		await _step(4)

	## 从 ZONES 的地面行里解析坑的左右边界（世界坐标）
	func _pit(zone_index: int) -> Vector2:
		var rows: Array = room.ZONES[zone_index]["rows"]
		var floor_row: String = rows[room.FLOOR_ROW]
		var base: float = room._zone_bounds[zone_index].x
		var start := -1
		for col in floor_row.length():
			if floor_row[col] == "." and start < 0:
				start = col
			elif floor_row[col] == "#" and start >= 0:
				return Vector2(base + start * room.TILE, base + col * room.TILE)
		return Vector2.ZERO

	## 跑到坑沿附近起手，返回 [是否落到坑对面, 落点x, 技巧名]
	func _attempt(zone_index: int, kind: String, lead_override := -1.0) -> Array:
		var pit := _pit(zone_index)
		var spawn: Vector2 = room._zone_spawns[zone_index]
		# 台子右端（有的区在地面上还压着一层台子，例如区 6 的 Ultra 起跳台）
		var rows: Array = room.ZONES[zone_index]["rows"]
		var upper: String = rows[room.FLOOR_ROW - 2]
		var block_end := 0.0
		for col in upper.length():
			if upper[col] == "#":
				block_end = room._zone_bounds[zone_index].x + (col + 1) * room.TILE
		if kind == "ultra":
			await _put(spawn)
		elif block_end > 0.0:
			# 台子上起跳是最"占便宜"的跨坑姿势，普通跳 / 跳+空中冲都从这里试
			await _put(Vector2(block_end - 64.0, (room.FLOOR_ROW - 2) * room.TILE))
		else:
			# 其余情况统一从坑沿前 64px 的地面起跑
			await _put(Vector2(pit.x - 64.0, room.FLOOR_ROW * room.TILE))
		# 技巧不同，起手点离坑沿的距离也不同（wavedash / ultra 要提前起手）
		var lead := 4.0
		if kind == "hyper":
			lead = 24.0
		elif kind == "wavedash":
			lead = 40.0
		if lead_override >= 0.0:
			lead = lead_override
		Input.action_press("move_right")
		var guard := 0
		while guard < 400:
			guard += 1
			await _step()
			if player.global_position.y > room.DEATH_ROW * room.TILE:
				return [false, player.global_position.x, "掉坑(助跑段)", 0.0]
			if kind == "ultra":
				# 区 6：先跳上台子（撞墙就跳），跑出台子右端且离地才算起手
				if player._on_ground() and absf(player.velocity.x) < 5.0 and guard > 6:
					Input.action_press("jump")
					await _step(10)
					Input.action_release("jump")
				if not player._on_ground() and player.global_position.x > block_end - 4.0:
					break
			elif block_end > 0.0:
				# 台子上起跳（最占便宜的跨坑姿势）：跑到台子右端就起手
				if player._on_ground() and player.global_position.x >= block_end - 4.0:
					break
			elif player._on_ground() and player.global_position.x >= pit.x - lead:
				break
		var launch := player.global_position.x
		match kind:
			"jump":
				Input.action_press("jump")
				await _step(14)
				Input.action_release("jump")
			"jumpdash":
				Input.action_press("jump")
				await _step(5)
				Input.action_release("jump")
				Input.action_press("dash")
				await _step(2)
				Input.action_release("dash")
			"super":
				Input.action_press("dash")
				await _step(4)
				Input.action_release("dash")
				Input.action_press("jump")
				await _step(12)
				Input.action_release("jump")
			"hyper":
				Input.action_press("move_down")
				Input.action_press("dash")
				await _step(4)
				Input.action_release("dash")
				Input.action_press("jump")
				await _step(4)
				Input.action_release("move_down")
				await _step(8)
				Input.action_release("jump")
			"wavedash":
				Input.action_press("jump")
				await _step(3)
				Input.action_release("jump")
				Input.action_press("move_down")
				Input.action_press("dash")
				await _step(4)
				Input.action_release("dash")
				Input.action_press("jump")
				await _step(6)
				Input.action_release("move_down")
				await _step(6)
				Input.action_release("jump")
			"ultra":
				Input.action_press("move_down")
				Input.action_press("dash")
				await _step(4)
				Input.action_release("dash")
				# 撞地那一帧才按 J：离墙太近时提前按会被墙跳截走（WallJumpCheckDist 3px）
				var wait := 0
				while wait < 12 and not player._on_ground():
					wait += 1
					await _step()
				Input.action_press("jump")
				await _step(4)
				Input.action_release("move_down")
				await _step(8)
				Input.action_release("jump")
		var tech: String = player.last_technique
		if kind == "ultra":
			print("   ultra 起手后：tech=%s v=(%.1f,%.1f) x=%.1f y=%.1f" % [
				tech, player.velocity.x, player.velocity.y, player.global_position.x, player.global_position.y])
		guard = 0
		while guard < 240:
			guard += 1
			await _step()
			if player.global_position.y > room.DEATH_ROW * room.TILE:
				_release()
				return [false, player.global_position.x, tech, launch]
			if player._on_ground() and player.global_position.x > pit.y:
				_release()
				return [true, player.global_position.x, tech, launch]
		_release()
		return [false, player.global_position.x, tech, launch]

	func _report(zone_index: int, kind: String, want: bool, lead_override := -1.0) -> void:
		var pit := _pit(zone_index)
		var result := await _attempt(zone_index, kind, lead_override)
		var ok: bool = result[0] == want
		print("%s 区%d %-9s 起手 x=%.1f → 落点 x=%.1f 坑=[%.0f,%.0f] 跨过=%s tech=%s 期望=%s" % [
			"OK  " if ok else "FAIL", zone_index + 1, kind, result[3], result[1], pit.x, pit.y,
			result[0], result[2], want])

	func run() -> void:
		print("=== 坑宽把关（区 4 Super / 区 5 Hyper·Wavedash / 区 6 Ultra）===")
		# 区 4 Super：普通跳与跳+空中冲都要失败，Super 要成功
		await _report(3, "jump", false)
		await _report(3, "jumpdash", false)
		await _report(3, "super", true)
		# 区 5 Hyper / Wavedash
		await _report(4, "jump", false)
		await _report(4, "jumpdash", false)
		await _report(4, "hyper", true)
		await _report(4, "wavedash", true, 16.0)
		await _report(4, "wavedash", true, 24.0)
		await _report(4, "wavedash", true, 32.0)
		# 区 6 Ultra
		await _report(5, "jump", false)
		await _report(5, "jumpdash", false)
		await _report(5, "ultra", true)
		# 死亡判定 + 存档点复活
		var spawn: Vector2 = room._zone_spawns[4]
		await _put(spawn + Vector2(0.0, -4.0))
		player.global_position = Vector2(_pit(4).x + 20.0, 100.0)
		var frames := 0
		while frames < 120:
			frames += 1
			await _step()
			if absf(player.global_position.x - spawn.x) < 2.0 and absf(player.global_position.y - spawn.y) < 2.0:
				break
		print("死亡复活：%d 帧回到区 5 存档点 (%.0f,%.0f) dash=%d" % [
			frames, player.global_position.x, player.global_position.y, player.dash_count])
		# 存档点是否落在实体里 + 分隔墙的门洞是否走得通
		print("=== 存档点与门洞 ===")
		for index in room._zone_spawns.size():
			var point: Vector2 = room._zone_spawns[index]
			await _put(point)
			await _step(4)
			var standable: bool = player._on_ground() and absf(player.global_position.y - point.y) < 2.0
			var divider_end: float = room._zone_bounds[index].y + room.ZONE_GAP * room.TILE
			# 出口侧：分区最后一列上方的第一个空格（有的区右端压着台子）
			var rows: Array = room.ZONES[index]["rows"]
			var last_col: int = (rows[room.FLOOR_ROW] as String).length() - 1
			var exit_y: float = room.FLOOR_ROW * room.TILE
			for row in range(room.FLOOR_ROW - 1, 0, -1):
				if rows[row][last_col] == "." and rows[row + 1][last_col] == "#":
					exit_y = (row + 1) * room.TILE
					break
			await _put(Vector2(room._zone_bounds[index].y - 12.0, exit_y))
			Input.action_press("move_right")
			await _step(60)
			var through: bool = player.global_position.x > divider_end + 8.0
			_release()
			var last_zone: bool = index == room._zone_spawns.size() - 1
			print("%s 区%d 存档点(%.0f,%.0f) 站得住=%s 门洞通行=%s x=%.1f" % [
				"OK  " if standable and (through or last_zone) else "FAIL", index + 1,
				point.x, point.y, standable, through, player.global_position.x])
		quit()

	func quit() -> void:
		get_tree().quit()
