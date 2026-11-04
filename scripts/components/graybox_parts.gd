class_name GrayboxParts
extends RefCounted
## 红=伤害 青=冲刺水晶 绿=弹簧(按地形自动判朝向) 褐=可破坏 紫=Dream Block(冲刺激活) 金=存档点


class Hazard extends Area2D:
	## 四向伤害区：只允许"完全沿可通过方向"穿过；侧面接触 / 停在里面 / 斜向穿过都会死亡。
	## 用逐帧持续判定（不是进入事件），避免穿过途中停下后卡在伤害区里。
	var level: Node
	var size := Vector2(8, 8)
	var pass_dir := Vector2.ZERO
	var _passing: CharacterBody2D = null
	var _kill_latched := false
	var _pass_grace := 0.0

	func _ready() -> void:
		# 伤害判定用玩家 player.tscn 里的圆形 hurtbox（不再用身体矩形）
		collision_mask = 8
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
		add_child(cs)

	func _intended_velocity(body: CharacterBody2D) -> Vector2:
		if body.velocity.length() > 15.0:
			return body.velocity
		if body.has_method("get_move_input"):
			var mi = body.call("get_move_input")
			if mi is Vector2:
				return (mi as Vector2) * 200.0
		return Vector2.ZERO

	func _can_pass(body: CharacterBody2D) -> bool:
		if pass_dir == Vector2.ZERO:
			return false
		if body == _passing:
			# 已在通过中：只要不是逆着可通过方向运动就继续（冲刺结束后下坠/侧滑也算通过）
			return body.velocity.dot(pass_dir) >= 0.0
		# 首次接触：必须从背面进入（不能从侧面顶上来），斜向通过是允许的
		var rel := body.global_position - global_position
		if rel.dot(pass_dir) >= 0.0:
			return false
		return _intended_velocity(body).dot(pass_dir) > 0.0

	func _physics_process(_delta: float) -> void:
		if level == null:
			return
		_pass_grace = maxf(0.0, _pass_grace - _delta)
		var hit: CharacterBody2D = null
		for a in get_overlapping_areas():
			if not a.is_in_group("player_hurtbox"):
				continue
			var b := a.get_parent()
			if b is CharacterBody2D:
				hit = b as CharacterBody2D
				break
		if hit == null:
			_passing = null
			_kill_latched = false
			return
		if _can_pass(hit):
			_passing = hit
			_kill_latched = false
			_pass_grace = 0.30   # 成功通过后 0.3s 内从出口侧再擦到不再判死
			return
		if _pass_grace > 0.0 and hit.velocity.dot(pass_dir) >= -1.0:
			# 刚从出口侧出来（例如穿过竖条后下坠/贴边）不算侧向进入
			_passing = hit
			_kill_latched = false
			return
		_passing = null
		# 已经和伤害区重叠、但正沿着可通过方向"往外"运动（例如站在出口侧向外走/冲），
		# 只是离开而不是进入，不判死。只看 pass_dir 轴上的分量，避免下坠速度干扰。
		var h: float = 11.0
		if hit.has_method("_body_height"):
			h = float(hit.call("_body_height"))
		var body_center: Vector2 = hit.global_position + Vector2(0.0, -h * 0.5)
		var side: float = (body_center - global_position).dot(pass_dir)
		if side * hit.velocity.dot(pass_dir) > 0.0:
			return
		if not _kill_latched:
			_kill_latched = true
			level.call("respawn_player")


class Crystal extends Area2D:
	## 冲刺水晶：单张 8x8 贴图，无任何动画；拾取后留下白色虚线勾边，2.5 秒后恢复
	const RESPAWN_TIME := 2.5
	const BURST_COLOR := Color(0.6, 0.95, 0.95, 0.9)
	const DUST := preload("res://scripts/fx/jump_dust.gd")
	const TEXTURE := preload("res://assets/graybox/crystal_diamond.png")
	const DASH_COLOR := Color(1.0, 1.0, 1.0, 0.8)
	const ROWS := [[3, 4], [2, 5], [1, 6], [0, 7], [0, 7], [1, 6], [2, 5], [3, 4]]

	var size := Vector2(8, 8)
	var _sprite: Sprite2D
	var _outline: Node2D
	var _monitor: CollisionShape2D
	var _cooldown := false


	func _ready() -> void:
		collision_mask = 2
		_monitor = CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		_monitor.shape = rect
		add_child(_monitor)
		body_entered.connect(_on_body)
		_sprite = Sprite2D.new()
		_sprite.texture = TEXTURE
		_sprite.centered = true
		add_child(_sprite)
		_outline = Node2D.new()
		_outline.name = "DashedOutline"
		add_child(_outline)
		_build_outline()
		_outline.visible = false


	func _build_outline() -> void:
		var edge_cells: Array = []
		for y in 8:
			for x in range(int(ROWS[y][0]), int(ROWS[y][1]) + 1):
				var is_edge := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var np: Vector2i = Vector2i(x, y) + d
					var in_rows := np.y >= 0 and np.y < 8 and np.x >= int(ROWS[np.y][0]) and np.x <= int(ROWS[np.y][1])
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
				var r := ColorRect.new()
				r.color = DASH_COLOR
				r.position = Vector2(pt.x - 4, pt.y - 4)
				r.size = Vector2(1, 1)
				r.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_outline.add_child(r)


	func _on_body(body: Node2D) -> void:
		if _cooldown or not (body is CharacterBody2D) or _monitor.disabled:
			return
		if body.has_method("refill_dash"):
			body.call("refill_dash")
		if body.has_method("hitstop_frames"):
			body.call("hitstop_frames", 3)
		_cooldown = true
		_monitor.set_deferred("disabled", true)
		_sprite.visible = false
		_outline.visible = true
		_spawn_burst()
		await get_tree().create_timer(RESPAWN_TIME).timeout
		if not is_instance_valid(self):
			return
		_cooldown = false
		_sprite.visible = true
		_outline.visible = false
		_monitor.set_deferred("disabled", false)


	func _spawn_burst() -> void:
		var dust: Node = DUST.new()
		var parent := get_parent()
		if parent == null:
			return
		parent.add_child(dust)
		if dust.has_method("setup"):
			dust.call("setup", global_position, 0.0, 10, BURST_COLOR)


class Spring extends StaticBody2D:
	## 四向单向弹簧：木色边是实体挡板（类似单向墙），从木色一侧靠近会被挡住/弹起，
	## 从背面朝木色方向移动时可以穿过；只在弹射侧接触时施加向上/对应方向的初速度
	var size := Vector2(8, 8)
	var dir := Vector2.UP
	var launch := 300.0
	var up_boost := 200.0   # 水平弹簧额外给的向上速度
	var horizontal_speed := 240.0   # 水平弹簧的水平速度
	var _area: Area2D
	var _player: CharacterBody2D = null
	var _exception := false
	var _cooldown := 0.0
	var _launch_player: CharacterBody2D = null
	var _launch_grace := 0.0
	var _launched_body: CharacterBody2D = null
	var _pending_body: CharacterBody2D = null
	var _climb_area: Area2D


	func _ready() -> void:
		var vertical := absf(dir.y) > 0.5
		var thick := maxf(2.0, (size.y if vertical else size.x) * 0.5)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(size.x, thick) if vertical else Vector2(thick, size.y)
		cs.shape = rect
		cs.position = dir * ((size.y if vertical else size.x) * 0.5 - thick * 0.5)
		add_child(cs)
		_area = Area2D.new()
		_area.collision_mask = 2
		var acs := CollisionShape2D.new()
		var arect := RectangleShape2D.new()
		# 只在弹射面一侧外扩 4px：踩上去/落到上面才算接触，贴边不会触发
		arect.size = size + Vector2(absf(dir.x), absf(dir.y)) * 4.0
		acs.shape = arect
		acs.position = dir * 2.0
		_area.add_child(acs)
		add_child(_area)
		_area.body_entered.connect(_on_body_entered)
		# 攀爬用的大检测框：在侧面/背面贴着弹簧往上爬或下滑时也能触发
		_climb_area = Area2D.new()
		_climb_area.collision_mask = 2
		var cacs := CollisionShape2D.new()
		var carect := RectangleShape2D.new()
		carect.size = size + Vector2(4, 4)   # 每侧只外扩 2px，够检测"贴着爬"即可
		cacs.shape = carect
		_climb_area.add_child(cacs)
		add_child(_climb_area)


	func _is_climbing(body: Node2D) -> bool:
		if body.get("mode") != null and int(body.get("mode")) == 2:
			return true
		return Input.is_action_pressed("grab")


	func _want_pass(body: CharacterBody2D) -> bool:
		if _is_climbing(body):
			return true
		if body.velocity.dot(dir) > 0.1:
			return true
		if body.has_method("get_move_input"):
			return (body.call("get_move_input") as Vector2).dot(dir) > 0.3
		return false


	func _overlap_player() -> CharacterBody2D:
		for b in _area.get_overlapping_bodies():
			if b is CharacterBody2D:
				return b
		return null


	func _on_spring_tile(body: Node2D) -> bool:
		# 非攀爬触发时要求身体确实在弹簧这一格的正上方/正贴面，
		# 只是站在旁边（横向错开一格）不会触发。
		var c: Vector2 = body.global_position + Vector2(0.0, -5.5)
		var half := size * 0.5
		if absf(dir.y) > 0.5:
			# 横向：身体和弹簧格有重叠即可（落在边缘也算踩上）
			if absf(c.x - global_position.x) > half.x + 4.0:
				return false
			# 纵向：脚必须在弹簧顶面附近或以上（站在旁边地面上不算）
			var feet_y: float = body.global_position.y
			return feet_y <= global_position.y - half.y + 1.0
		if absf(c.y - global_position.y) > half.y + 6.0:
			return false
		return true


	func _from_valid_side(body: Node2D) -> bool:
		var body_center: Vector2 = body.global_position + Vector2(0.0, -5.5)
		return (body_center - global_position).dot(dir) >= 0.0


	func _physics_process(delta: float) -> void:
		if _launch_grace > 0.0:
			_launch_grace = maxf(0.0, _launch_grace - delta)
			if _launch_grace <= 0.0 and is_instance_valid(_launch_player):
				_launch_player.remove_collision_exception_with(self)
				_launch_player = null
			return
		if _cooldown > 0.0:
			_cooldown = maxf(0.0, _cooldown - delta)
		if _pending_body != null and _cooldown <= 0.0:
			var pb := _pending_body
			_pending_body = null
			if is_instance_valid(pb) and _area.overlaps_body(pb) and (_is_climbing(pb) or _from_valid_side(pb)):
				_on_body_entered(pb)
				return
		# 攀爬状态：贴着弹簧侧面往上爬/下滑时也触发
		if _cooldown <= 0.0:
			for cb in _climb_area.get_overlapping_bodies():
				if cb is CharacterBody2D and _is_climbing(cb):
					_on_body_entered(cb)
					return
		var p := _overlap_player()
		# 持续判定：冷却结束后只要玩家还在弹簧上/正压向弹簧就再次弹射。
		# 只靠 body_entered 会漏掉"低矮天花板下弹一次又落回弹簧"的情况（没有再次进出区域）。
		if p != null and _cooldown <= 0.0:
			var approaching: bool = p.velocity.dot(dir) < -1.0
			if _is_climbing(p) or (_from_valid_side(p) and approaching):
				_on_body_entered(p)
				return
		if p == null:
			_launched_body = null
			_pending_body = null
			if _exception and is_instance_valid(_player):
				_player.remove_collision_exception_with(self)
			_exception = false
			_player = null
			return
		if _exception:
			if not _want_pass(p):
				p.remove_collision_exception_with(self)
				_exception = false
				_player = null
			return
		if _want_pass(p):
			p.add_collision_exception_with(self)
			_exception = true
			_player = p


	func _on_body_entered(body: Node2D) -> void:
		if not (body is CharacterBody2D):
			return
		if _cooldown > 0.0:
			# 冷却中落地：记下来，等冷却结束若还贴着弹簧就补一次弹射
			_pending_body = body as CharacterBody2D
			return
		if not _from_valid_side(body) and not _is_climbing(body):
			return
		if not _is_climbing(body) and not _on_spring_tile(body):
			return
		_cooldown = 0.25
		_launched_body = body as CharacterBody2D
		_exception = false
		_player = null
		if body.has_method("refill_dash"):
			body.call("refill_dash")
		if body.has_method("apply_spring_boost"):
			# 只有横向弹簧锁定水平输入方向；竖直弹簧不锁方向
			var force_x := 0.0
			if absf(dir.x) > 0.5:
				force_x = dir.x
			body.call("apply_spring_boost", 0.25, force_x)
		if body is CharacterBody2D:
			var cb := body as CharacterBody2D
			if _launch_player != null and is_instance_valid(_launch_player) and _launch_player != cb:
				_launch_player.remove_collision_exception_with(self)
			cb.add_collision_exception_with(self)
			_launch_player = cb
			_launch_grace = 0.2
		var v: Vector2 = body.velocity
		if dir.y < 0.0:
			body.velocity = Vector2(v.x, -launch)
		elif dir.y > 0.0:
			body.velocity = Vector2(v.x, launch)
		elif dir.x < 0.0:
			body.velocity = Vector2(-horizontal_speed, minf(v.y, -up_boost))
			if body.has_method("set_facing"):
				body.call("set_facing", -1.0)
		else:
			body.velocity = Vector2(horizontal_speed, minf(v.y, -up_boost))
			if body.has_method("set_facing"):
				body.call("set_facing", 1.0)


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
		var dirs8: Array = [
			Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
			Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		]
		for i in 3:
			var idx := rng.randi_range(0, dirs8.size() - 1)
			var length := rng.randi_range(maxi(3, w / 2), maxi(4, w - 2))
			var pt := center
			for step in range(length):
				# mostly keep direction, sometimes turn 45 degrees -> jagged random lines
				if rng.randf() < 0.35:
					idx = (idx + rng.randi_range(-1, 1) + dirs8.size()) % dirs8.size()
				var d: Vector2i = dirs8[idx]
				pt += d
				if pt.x < 1 or pt.y < 1 or pt.x >= w - 1 or pt.y >= h - 1:
					break
				img.set_pixel(pt.x, pt.y, CRACK)
				# occasional short 1px side branch
				if rng.randf() < 0.3:
					var bi := (idx + rng.randi_range(1, 3)) % dirs8.size()
					var bp: Vector2i = pt + dirs8[bi]
					if bp.x >= 1 and bp.y >= 1 and bp.x < w - 1 and bp.y < h - 1:
						img.set_pixel(bp.x, bp.y, CRACK)
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
		add_to_group("oneway_platforms")
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
			var aim_ok: bool = aim.length() > 0.01 and aim.normalized().dot(toward) > 0.25
			if pressed and not (dashing or just_dashed):
				# 没有冲刺充能时按冲刺键不能触发 Dream Dash
				var dc = b.get("dash_count")
				if dc != null and int(dc) <= 0:
					continue
				var cd = b.get("dash_cooldown_timer")
				if cd != null and float(cd) > 0.0:
					continue
			if dashing or just_dashed or (pressed and aim_ok):
				var dir: Vector2 = b.velocity
				if dashing or just_dashed:
					var dd = b.get("dash_dir")
					if dd is Vector2 and (dd as Vector2).length() > 0.01:
						dir = dd
					elif aim.length() > 0.01:
						# 冲刺冻结期 dash_dir 还未写入：用当前输入方向，避免变成水平滑行
						dir = aim
					else:
						# 方向还没采样到（同帧按下方向+冲刺）：等下一帧再判定
						continue
				elif pressed:
					# 关键：按住冲刺触发时优先用当前输入方向，避免读到上一次冲刺的 dash_dir（导致向上冲却向下走）
					if aim.length() > 0.01:
						dir = aim
					else:
						dir = toward
				# 冲刺必须真的会把身体扫进紫块才触发；
				# 紧贴紫块、沿着表面/旁边冲刺不应触发（否则会误触发 Dream Dash 效果）。
				if not dash_enters_block(b, dir):
					continue
				if b.has_method("dream_path_blocked") and bool(b.call("dream_path_blocked", dir)):
					continue
				if b.has_method("start_dream_dash"):
					print("[dream] trigger pressed=", pressed, " dir=", dir, " player=", b.global_position)
					b.call("start_dream_dash", dir, self)
				return

	func dash_enters_block(body: Node2D, dir: Vector2) -> bool:
		# 玩家身体（8x11，中心在脚底上方 5.5）沿冲刺方向扫掠，看是否真的会进入方块。
		# 只是"朝方块中心方向"还不够：站在顶面朝方块中心水平冲时也会满足该条件，
		# 但扫掠框一直在顶面上方，不会进入方块。
		if dir.length() < 0.01:
			return false
		var d := dir.normalized()
		var center: Vector2 = body.global_position + Vector2(0.0, -5.5)
		var block_rect := Rect2(global_position - size * 0.5, size)
		for i in range(1, 17):
			var c := center + d * (float(i) * 1.5)
			var body_rect := Rect2(c - Vector2(3.5, 5.0), Vector2(7.0, 10.0))
			if block_rect.intersects(body_rect):
				return true
		return false


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
		add_to_group("oneway_platforms")
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
		# 只按实际速度方向判断：按着方向键但人在下坠/被挡住时不能开例外，
		# 否则会"掉着掉着就穿过单向平台"
		return p.velocity.dot(pass_dir) > 0.1

	func _body_center(p: CharacterBody2D) -> Vector2:
		var h: float = 11.0
		if p.has_method("_body_height"):
			h = float(p.call("_body_height"))
		return p.global_position + Vector2(0.0, -h * 0.5)

	func _body_overlaps_wall(p: CharacterBody2D) -> bool:
		# 玩家碰撞箱是否还和单向墙实体重叠（用于决定何时恢复碰撞）
		var h: float = 11.0
		if p.has_method("_body_height"):
			h = float(p.call("_body_height"))
		var center := p.global_position + Vector2(0.0, -h * 0.5)
		var body_rect := Rect2(center - Vector2(4.0, h * 0.5), Vector2(8.0, h))
		var wall_rect := Rect2(global_position - size * 0.5, size)
		return wall_rect.intersects(body_rect)

	func _pass_side_ok(p: CharacterBody2D) -> bool:
		# 只允许从背面（朝可通过方向的前一侧）开始通过；
		# 从黑色实心一侧蹭着走不能开例外
		var rel := _body_center(p) - global_position
		return rel.dot(pass_dir) < 2.0

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
			# 碰撞箱完全离开单向墙之前一直保留例外，
			# 避免"通过一半松开方向/速度变化"时恢复碰撞把人卡在墙里
			if not _body_overlaps_wall(p):
				p.remove_collision_exception_with(self)
				_exception = false
				_player = null
			return
		if _want(p) and _pass_side_ok(p):
			p.add_collision_exception_with(self)
			_exception = true
			_player = p


class Trophy extends Area2D:
	## 奖杯：碰到后跟随玩家；站在地面累计 0.5 秒后结算（计数 +1）并消失
	var level: Node
	var size := Vector2(8, 8)
	const GOLD := Color(0.949, 0.698, 0.188, 1.0)
	const LIGHT := Color(1.0, 0.878, 0.510, 1.0)
	const DARK := Color(0.659, 0.392, 0.063, 1.0)
	const BOB_AMPLITUDE := 2.0
	const BOB_PERIOD := 1.6
	const GROUND_SETTLE_TIME := 0.5
	const FOLLOW_BACK := 10.0   # 跟在身后的水平距离
	const FOLLOW_HEIGHT := -6.0  # 相对脚底的竖直偏移
	const FOLLOW_LERP := 10.0

	var cells: Array = []
	var _base_y := 0.0
	var _t := 0.0
	var _visual: Node2D
	var _following := false
	var _follow_player: Node2D = null
	var _ground_timer := 0.0


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
		z_index = 1


	func _build_cup() -> void:
		# 12x12 设计图，居中到 10x8（x -5..+4, y -3..+4）
		for x in range(2, 10):
			_cell(x, 2, GOLD)
		for y in range(3, 6):
			for x in range(3, 9):
				_cell(x, y, GOLD)
		for x in range(4, 8):
			_cell(x, 6, GOLD)
		_cell(3, 3, LIGHT)
		_cell(4, 3, LIGHT)
		_cell(3, 4, LIGHT)
		_cell(5, 7, DARK)
		_cell(6, 7, DARK)
		for x in range(4, 8):
			_cell(x, 8, GOLD)
		for x in range(2, 10):
			_cell(x, 9, DARK)
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
		if _following and is_instance_valid(_follow_player):
			var bob := sin(_t * TAU / BOB_PERIOD) * BOB_AMPLITUDE
			var facing := 1.0
			var f = _follow_player.get("facing")
			if f != null and absf(float(f)) > 0.01:
				facing = signf(float(f))
			var target: Vector2 = _follow_player.global_position + Vector2(-facing * FOLLOW_BACK, FOLLOW_HEIGHT + bob)
			global_position = global_position.lerp(target, clampf(delta * FOLLOW_LERP, 0.0, 1.0))
			# 站地累计 0.5s 才结算
			var grounded := false
			if _follow_player.has_method("_on_ground"):
				grounded = bool(_follow_player.call("_on_ground"))
			if grounded:
				_ground_timer += delta
				if _ground_timer >= GROUND_SETTLE_TIME:
					_settle()
			else:
				_ground_timer = 0.0
		else:
			position.y = _base_y + sin(_t * TAU / BOB_PERIOD) * BOB_AMPLITUDE


	func _on_body(body: Node2D) -> void:
		if _following or not (body is CharacterBody2D):
			return
		_following = true
		_follow_player = body
		_ground_timer = 0.0
		set_deferred("monitoring", false)
		var facing := 1.0
		var f = body.get("facing")
		if f != null and absf(float(f)) > 0.01:
			facing = signf(float(f))
		global_position = body.global_position + Vector2(-facing * FOLLOW_BACK, FOLLOW_HEIGHT)


	func _settle() -> void:
		_following = false
		_follow_player = null
		if level:
			level.call("collect_trophy", cells)
		queue_free()
