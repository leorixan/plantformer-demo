extends Node2D
## 灰盒关卡：
## - Terrain  (TileMapLayer, 8px)：地形 + 机关 tile（兼容旧方式）
## - Entities (TileMapLayer, 4px)：任意尺寸机关（画笔=Godot 自带 TileMap 画笔/矩形/油漆桶）
## 运行时按 tile 生成碰撞/机关节点（纯代码，无 tscn 组件）

const TILE := 8.0
const HALF := 4.0
const PLAYER_SCENE := "res://scenes/player/player.tscn"

signal trophy_collected(total: int)

var _initial_entity_data: PackedByteArray = PackedByteArray()
var _initial_terrain_data: PackedByteArray = PackedByteArray()
var _collected_trophy_cells: Dictionary = {}
var trophies_collected := 0
const KIND_ORDER := ["terrain", "hazard", "crystal", "spring", "breakable", "jelly", "checkpoint"]
const ENTITY_KINDS := ["hazard", "crystal", "spring", "breakable", "jelly", "checkpoint"]
const ENTITY_ATLAS := ["hazard", "crystal", "breakable8", "breakable16", "dream", "checkpoint", "hazard_hidden", "trophy", "spring_up", "spring_down", "spring_left", "spring_right", "oneway_up", "oneway_down", "oneway_left", "oneway_right"]
# 旧版图集坐标 → v7 双行坐标（运行时自动迁移旧地图）
const ENTITY_TILE_MIGRATION := {
	Vector2i(0, 0): Vector2i(0, 0), Vector2i(1, 0): Vector2i(1, 0),
	Vector2i(2, 0): Vector2i(0, 1), Vector2i(3, 0): Vector2i(2, 0),
	Vector2i(4, 0): Vector2i(3, 0), Vector2i(5, 0): Vector2i(4, 0),
	Vector2i(6, 0): Vector2i(4, 1), Vector2i(7, 0): Vector2i(5, 1),
	Vector2i(8, 0): Vector2i(6, 1), Vector2i(9, 0): Vector2i(7, 1),
	Vector2i(10, 0): Vector2i(5, 0), Vector2i(11, 0): Vector2i(6, 0),
	Vector2i(12, 0): Vector2i(7, 0), Vector2i(13, 0): Vector2i(1, 1),
	Vector2i(14, 0): Vector2i(2, 1), Vector2i(15, 0): Vector2i(3, 1),
}

var player: CharacterBody2D
var spawn_pos := Vector2.ZERO
var checkpoint_pos := Vector2.ZERO
var _terrain_cells: Dictionary = {}
var _dream_patches: Array = []


func _ready() -> void:
	# 复活重置用：初始 tile 快照
	var _el := _entity_layer()
	var _tl := _terrain_layer()
	if _el:
		_initial_entity_data = _el.tile_map_data
	if _tl:
		_initial_terrain_data = _tl.tile_map_data
	var legend := get_node_or_null("Legend")
	if legend:
		legend.visible = false
	_build_terrain()
	_build_tile_parts()
	_build_entity_rects()
	_hide_invisible_hazards()
	_setup_dream_visuals()
	_build_fake_terrain_masks()
	_build_node_entities()
	var marker := get_node_or_null("Spawn") as Node2D
	spawn_pos = marker.global_position if marker else Vector2(16, 0)
	checkpoint_pos = spawn_pos
	_spawn_player()
	_setup_room_camera()
	var goal := get_node_or_null("Goal") as Node2D
	if goal:
		var area := Area2D.new()
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(10, 10)
		cs.shape = rect
		area.add_child(cs)
		area.position = goal.position
		area.body_entered.connect(_on_goal)
		add_child(area)


func _on_goal(body: Node2D) -> void:
	if body is CharacterBody2D:
		print("LEVEL_COMPLETE")


func _terrain_layer() -> TileMapLayer:
	return get_node_or_null("Terrain") as TileMapLayer


func _entity_layer() -> TileMapLayer:
	return get_node_or_null("Entities") as TileMapLayer


func _migrate_entity_tiles() -> void:
	# 把旧版单行图集的格子迁移到 v7 双行图集坐标（弹簧/单向墙移到第二行）
	var ents := _entity_layer()
	if ents == null:
		return
	var moves: Array = []
	for cell in ents.get_used_cells():
		var coord := ents.get_cell_atlas_coords(cell)
		if coord.y == 0 and ENTITY_TILE_MIGRATION.has(coord):
			var target: Vector2i = ENTITY_TILE_MIGRATION[coord]
			if target != coord:
				moves.append([cell, target])
	for m in moves:
		var src: Vector2i = m[0]
		var dst: Vector2i = m[1]
		ents.set_cell(dst, 0, dst)
		ents.erase_cell(src)


func _kind_of(layer: TileMapLayer, cell: Vector2i) -> String:
	var data := layer.get_cell_tile_data(cell)
	if data and data.has_custom_data("kind"):
		var k := String(data.get_custom_data("kind"))
		if not k.is_empty():
			return k
	var coord := layer.get_cell_atlas_coords(cell)
	if coord.y == 0 and coord.x < KIND_ORDER.size():
		return KIND_ORDER[coord.x]
	return ""


func _build_terrain() -> void:
	var layer := _terrain_layer()
	if layer == null:
		return
	var body := StaticBody2D.new()
	body.name = "TerrainBody"
	add_child(body)
	var rows: Dictionary = {}
	for cell in layer.get_used_cells():
		if _kind_of(layer, cell) == "terrain":
			_terrain_cells[cell] = true
			if not rows.has(cell.y):
				rows[cell.y] = []
			rows[cell.y].append(cell.x)
	for row in rows:
		var cols: Array = rows[row]
		cols.sort()
		var start: int = cols[0]
		var prev: int = cols[0]
		for i in range(1, cols.size()):
			var cur: int = cols[i]
			if cur != prev + 1:
				_add_solid(body, row, start, prev)
				start = cur
			prev = cur
		_add_solid(body, row, start, prev)


func _add_solid(body: Node, row: int, start: int, end_col: int) -> void:
	var width := float(end_col - start + 1) * TILE
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, TILE)
	cs.shape = rect
	cs.position = Vector2(float(start) * TILE + width * 0.5, float(row) * TILE + TILE * 0.5)
	body.add_child(cs)


func _build_tile_parts() -> void:
	var layer := _terrain_layer()
	if layer == null:
		return
	for cell in layer.get_used_cells():
		var kind := _kind_of(layer, cell)
		if kind == "terrain" or kind.is_empty():
			continue
		var node := _make_part(kind, Vector2(TILE, TILE), Vector2(float(cell.x) * TILE + 4.0, float(cell.y) * TILE + 4.0))
		if node and kind == "breakable":
			var layer2 := _terrain_layer()
			var ccc: Vector2i = cell
			node.tree_exiting.connect(func() -> void:
				if is_instance_valid(layer2):
					layer2.erase_cell(ccc))


func _build_entity_rects() -> void:
	var layer := _entity_layer()
	if layer == null:
		return
	var by_kind: Dictionary = {}
	for cell in layer.get_used_cells():
		var kind := _kind_of(layer, cell)
		if kind.is_empty() or kind == "terrain":
			continue
		if not by_kind.has(kind):
			by_kind[kind] = {}
		by_kind[kind][cell] = true
	for kind in by_kind:
		var cells: Dictionary = by_kind[kind]
		var rows: Dictionary = {}
		for cell in cells:
			if not rows.has(cell.y):
				rows[cell.y] = []
			rows[cell.y].append(cell.x)
		var row_keys: Array = rows.keys()
		row_keys.sort()
		var active: Dictionary = {}
		for row in row_keys:
			var cols: Array = rows[row]
			cols.sort()
			var runs: Array = []
			var start: int = cols[0]
			var prev: int = cols[0]
			for i in range(1, cols.size()):
				var cur: int = cols[i]
				if cur != prev + 1:
					runs.append([start, prev])
					start = cur
				prev = cur
			runs.append([start, prev])
			var next_active: Dictionary = {}
			for run in runs:
				var key := "%d:%d" % [run[0], run[1]]
				if active.has(key):
					var r: Array = active[key]
					r[3] = row
					next_active[key] = r
				else:
					next_active[key] = [run[0], run[1], row, row]
			active = next_active
		# 从所有曾出现过的矩形收集（需要把结束的也收）
		var done: Dictionary = {}
		for row in row_keys:
			pass
		# 重新扫描：逐行找 run，向上追溯连续行得到矩形
		var seen: Dictionary = {}
		for row in row_keys:
			var cols: Array = rows[row]
			cols.sort()
			var runs: Array = []
			var start: int = cols[0]
			var prev: int = cols[0]
			for i in range(1, cols.size()):
				var cur: int = cols[i]
				if cur != prev + 1:
					runs.append([start, prev])
					start = cur
				prev = cur
			runs.append([start, prev])
			for run in runs:
				var key := "%d:%d:%d" % [run[0], run[1], row]
				if seen.has(key):
					continue
				var x0: int = run[0]
				var x1: int = run[1]
				var y0: int = row
				var y1: int = row
				while true:
					var nxt := y1 + 1
					var nc: Array = rows.get(nxt, [])
					if not _has_run(nc, x0, x1):
						break
					y1 = nxt
				for yy in range(y0, y1 + 1):
					seen["%d:%d:%d" % [x0, x1, yy]] = true
				var size := Vector2(float(x1 - x0 + 1) * HALF, float(y1 - y0 + 1) * HALF)
				var pos := Vector2(float(x0) * HALF + size.x * 0.5, float(y0) * HALF + size.y * 0.5)
				if kind == "breakable" or kind == "breakable8" or kind == "breakable16":
					# 可破坏块按 8x8 单位拆分，每次只碎一块
					var el := _entity_layer()
					var px0 := float(x0) * HALF
					var py0 := float(y0) * HALF
					var pw := float(x1 - x0 + 1) * HALF
					var ph := float(y1 - y0 + 1) * HALF
					var unit_sz := 16.0 if kind == "breakable16" else 8.0
					var nx := int(ceil(pw / unit_sz))
					var ny := int(ceil(ph / unit_sz))
					for iy in ny:
						for ix in nx:
							var usz := Vector2(minf(unit_sz, pw - float(ix) * unit_sz), minf(unit_sz, ph - float(iy) * unit_sz))
							var upos := Vector2(px0 + float(ix) * unit_sz + usz.x * 0.5, py0 + float(iy) * unit_sz + usz.y * 0.5)
							var unit := _make_part("breakable", usz, upos)
							if unit:
								var clear_cells: Array = []
								var cx0 := int((upos.x - usz.x * 0.5) / HALF)
								var cy0 := int((upos.y - usz.y * 0.5) / HALF)
								for yy in range(cy0, int((upos.y + usz.y * 0.5) / HALF)):
									for xx in range(cx0, int((upos.x + usz.x * 0.5) / HALF)):
										clear_cells.append(Vector2i(xx, yy))
								unit.tree_exiting.connect(func() -> void:
									if is_instance_valid(el):
										for cc in clear_cells:
											el.erase_cell(cc))
								# 立即擦除 tile，改用裂纹视觉节点渲染
								for cc in clear_cells:
									el.erase_cell(cc)
				elif kind == "trophy":
					var tro := _make_part(kind, Vector2(8, 8), pos)
					if tro:
						var tcell_list: Array = []
						for yy in range(y0, y1 + 1):
							for xx in range(x0, x1 + 1):
								var tc := Vector2i(xx, yy)
								tcell_list.append(tc)
								_entity_layer().erase_cell(tc)
						tro.set("cells", tcell_list)
				elif kind == "crystal":
					var cnode := _make_part(kind, Vector2(8, 8), pos)
					if cnode:
						for yy in range(y0, y1 + 1):
							for xx in range(x0, x1 + 1):
								_entity_layer().erase_cell(Vector2i(xx, yy))
				else:
					_make_part(kind, size, pos)


func _has_run(cols: Array, x0: int, x1: int) -> bool:
	for x in range(x0, x1 + 1):
		if not cols.has(x):
			return false
	return true


func _build_node_entities() -> void:
	for child in get_children():
		if not (child is Node2D) or child.get_script() == null:
			continue
		if not String(child.get_script().resource_path).ends_with("graybox_entity.gd"):
			continue
		_make_part(String(child.get("kind")), child.get("size_px"), child.position)
		child.visible = false


func _make_part(kind: String, size: Vector2, pos: Vector2) -> Node2D:
	var parts := load("res://scripts/components/graybox_parts.gd")
	var node: Node2D = null
	match kind:
		"hazard", "hazard_hidden":
			var h = parts.Hazard.new()
			h.level = self
			node = h
		"crystal":
			node = parts.Crystal.new()
		"spring", "spring_up":
			var sp = parts.Spring.new()
			sp.dir = Vector2.UP
			node = sp
		"spring_down":
			var spd = parts.Spring.new()
			spd.dir = Vector2.DOWN
			node = spd
		"spring_left":
			var spl = parts.Spring.new()
			spl.dir = Vector2.LEFT
			node = spl
		"spring_right":
			var spr = parts.Spring.new()
			spr.dir = Vector2.RIGHT
			node = spr
		"breakable", "breakable8", "breakable16":
			node = parts.Breakable.new()
		"jelly", "dream":
			var db = parts.DreamBlock.new()
			db.level = self
			db.add_to_group("dream_blocks")
			node = db
		"oneway", "oneway_up":
			var ow = parts.OneWay.new()
			ow.pass_dir = Vector2.UP
			node = ow
		"oneway_down":
			var ow2 = parts.OneWay.new()
			ow2.pass_dir = Vector2.DOWN
			node = ow2
		"oneway_left":
			var ow3 = parts.OneWay.new()
			ow3.pass_dir = Vector2.LEFT
			node = ow3
		"oneway_right":
			var ow4 = parts.OneWay.new()
			ow4.pass_dir = Vector2.RIGHT
			node = ow4
		"checkpoint":
			var cp = parts.Checkpoint.new()
			cp.level = self
			node = cp
		"trophy":
			var tr = parts.Trophy.new()
			tr.level = self
			node = tr
		_:
			return
	node.set("size", size)
	node.position = pos
	node.add_to_group("graybox_parts")
	add_child(node)
	return node


func _spawn_player() -> void:
	player = load(PLAYER_SCENE).instantiate()
	player.global_position = spawn_pos
	add_child(player)


var _dying := false


func respawn_player() -> void:
	# 死亡延迟：定格 0.24s（真实时间），期间角色闪烁，让玩家看清死亡瞬间
	if player == null or _dying:
		return
	_dying = true
	if player.has_method("end_dream_dash") and bool(player.get("dream_dashing")):
		player.call("end_dream_dash")
	player.set("_hitstop_frames", 0)
	player.set_physics_process(false)
	if player.has_method("set_input_locked"):
		player.call("set_input_locked", true)
	Engine.time_scale = 0.0
	# 死亡闪烁：周期 0.2s（灭 0.1s / 亮 0.1s），共闪 3 次 = 0.6s
	for i in 3:
		player.visible = false
		await get_tree().create_timer(0.1, true, false, true).timeout
		player.visible = true
		await get_tree().create_timer(0.1, true, false, true).timeout
	Engine.time_scale = 1.0
	player.set("collision_mask", 1)
	player.global_position = checkpoint_pos
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()
	player.visible = true
	await _reset_level_entities()
	player.visible = true
	if player.has_method("set_input_locked"):
		player.call("set_input_locked", false)
	player.set_physics_process(true)
	_dying = false


func collect_trophy(cells: Array = []) -> void:
	for c in cells:
		_collected_trophy_cells[c] = true
	trophies_collected += 1
	trophy_collected.emit(trophies_collected)
	print("[graybox] 奖杯计数: ", trophies_collected)


func set_checkpoint(pos: Vector2) -> void:
	checkpoint_pos = pos

func _solid_px(px: Vector2) -> bool:
	return _terrain_cells.has(Vector2i(int(floor(px.x / 8.0)), int(floor(px.y / 8.0))))


func _spring_dir(pos: Vector2, size: Vector2) -> Vector2:
	# 按周围地形自动判断弹簧朝向：下贴地→上弹，上贴顶→下弹，左贴墙→右弹，右贴墙→左弹
	if _solid_px(Vector2(pos.x, pos.y + size.y * 0.5 + 2.0)):
		return Vector2.UP
	if _solid_px(Vector2(pos.x, pos.y - size.y * 0.5 - 2.0)):
		return Vector2.DOWN
	if _solid_px(Vector2(pos.x - size.x * 0.5 - 2.0, pos.y)):
		return Vector2.RIGHT
	if _solid_px(Vector2(pos.x + size.x * 0.5 + 2.0, pos.y)):
		return Vector2.LEFT
	return Vector2.UP


func _setup_room_camera() -> void:
	# 若存在 Rooms 容器且子节点是 RoomArea，就启用蔚蓝式房间相机
	var rooms := get_node_or_null("Rooms")
	if rooms == null or player == null:
		return
	var rects: Array = []
	# 方式 0（推荐手动框选）：Rooms 下放 ReferenceRect 子节点，在 2D 视图里直接拖拽/缩放
	for ch in rooms.get_children():
		if ch is Control:
			var c := ch as Control
			rects.append(Rect2(c.global_position, c.size))
	# 方式 A：Rooms 节点自带 rooms 数组（仅在没有手动 ReferenceRect 时使用）
	var arr = rooms.get("rooms")
	if rects.is_empty() and arr is Array and not (arr as Array).is_empty():
		for r in arr:
			if r is Rect2:
				rects.append(Rect2(rooms.global_position + (r as Rect2).position, (r as Rect2).size))
	# 方式 B：Rooms 下挂 RoomArea 子节点
	if rects.is_empty():
		for ch in rooms.get_children():
			if ch is Node2D and ch.get("rect_size") != null:
				rects.append(Rect2(ch.global_position, ch.get("rect_size")))
	if rects.is_empty():
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.set("top_level", true)
	var rc: Node = load("res://scripts/components/room_camera.gd").new()
	add_child(rc)
	rc.call("attach", cam, player, rects)


func _build_dream_jelly_image(comp: Array, cells: Dictionary) -> Image:
	# C 方案：果冻核心 + 自动边缘光/阴影（角落不加黑）
	var core := Color8(141, 90, 207, 255)
	var hi := Color8(196, 131, 255, 255)
	var hi_soft := Color8(170, 110, 238, 255)
	var sh := Color8(116, 77, 171, 255)
	var sh_soft := Color8(133, 88, 196, 255)
	var minc := Vector2i(1 << 30, 1 << 30)
	var maxc := Vector2i(-(1 << 30), -(1 << 30))
	for cell in comp:
		var cv: Vector2i = cell
		minc = Vector2i(mini(minc.x, cv.x), mini(minc.y, cv.y))
		maxc = Vector2i(maxi(maxc.x, cv.x), maxi(maxc.y, cv.y))
	var w: int = (maxc.x - minc.x + 1) * 4
	var h: int = (maxc.y - minc.y + 1) * 4
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for cell in comp:
		var cv: Vector2i = cell
		var up := cells.has(Vector2i(cv.x, cv.y - 1))
		var down := cells.has(Vector2i(cv.x, cv.y + 1))
		var left := cells.has(Vector2i(cv.x - 1, cv.y))
		var right := cells.has(Vector2i(cv.x + 1, cv.y))
		var px: int = (cv.x - minc.x) * 4
		var py: int = (cv.y - minc.y) * 4
		img.fill_rect(Rect2i(px, py, 4, 4), core)
		if not up:
			img.fill_rect(Rect2i(px, py, 4, 1), hi)
		elif not left:
			img.fill_rect(Rect2i(px, py, 1, 4), hi_soft)
		if not down:
			img.fill_rect(Rect2i(px, py + 2, 4, 1), sh_soft)
			img.fill_rect(Rect2i(px, py + 3, 4, 1), sh)
		elif not right:
			img.fill_rect(Rect2i(px + 3, py, 1, 4), sh_soft)
		# 底角柔化：不要出现很黑的角
		if not down and not left:
			img.fill_rect(Rect2i(px, py + 3, 1, 1), sh_soft)
		if not down and not right:
			img.fill_rect(Rect2i(px + 3, py + 3, 1, 1), sh_soft)
	return img


func _setup_dream_visuals() -> void:
	# 紫色 Dream Block：所有 8 邻接连通的格子算作一个整体，
	# 每个连通块生成一张带自动高光/阴影的贴图（果冻核心风格）。
	var ents := _entity_layer()
	if ents == null:
		return
	var container := get_node_or_null("DreamVisual")
	if container == null:
		container = Node2D.new()
		container.name = "DreamVisual"
		add_child(container)
	container.z_index = 10
	container.modulate = Color(1, 1, 1, 0.65)
	for ch in container.get_children():
		ch.free()
	_dream_patches.clear()
	var cells: Dictionary = {}
	for cell in ents.get_used_cells():
		var kind := _kind_of(ents, cell)
		if kind == "dream" or kind == "jelly":
			cells[cell] = true
	if cells.is_empty():
		container.visible = false
		return
	container.visible = true
	# 8 邻接连通块
	var visited: Dictionary = {}
	var comps: Array = []
	for c in cells:
		if visited.has(c):
			continue
		var comp: Array = []
		var stack: Array = [c]
		visited[c] = true
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			comp.append(cur)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
					Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
				var n: Vector2i = cur + d
				if cells.has(n) and not visited.has(n):
					visited[n] = true
					stack.append(n)
		comps.append(comp)
	var minc := Vector2i(1 << 30, 1 << 30)
	for comp in comps:
		for cell in comp:
			var cv: Vector2i = cell
			minc = Vector2i(mini(minc.x, cv.x), mini(minc.y, cv.y))
	for comp in comps:
		var comp_min := Vector2i(1 << 30, 1 << 30)
		var comp_max := Vector2i(-(1 << 30), -(1 << 30))
		for cell in comp:
			var cv2: Vector2i = cell
			comp_min = Vector2i(mini(comp_min.x, cv2.x), mini(comp_min.y, cv2.y))
			comp_max = Vector2i(maxi(comp_max.x, cv2.x), maxi(comp_max.y, cv2.y))
		var img := _build_dream_jelly_image(comp, cells)
		# 每个连通块一个 patch：锚点在底部中心，缩放时像果冻从底部被压
		var patch := Node2D.new()
		patch.name = "Jelly"
		var w := float(img.get_width())
		var h := float(img.get_height())
		patch.position = Vector2(float(comp_min.x) * 4.0 + w * 0.5, float(comp_min.y) * 4.0 + h)
		var spr := Sprite2D.new()
		spr.texture = ImageTexture.create_from_image(img)
		spr.centered = false
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(-w * 0.5, -h)
		patch.add_child(spr)
		container.add_child(patch)
		_dream_patches.append({
			"node": patch,
			"rect": Rect2(Vector2(comp_min) * 4.0, Vector2(comp_max - comp_min + Vector2i.ONE) * 4.0),
			"inside": false,
		})
	# 实体层里的 dream 标记 tile 不再直接渲染（视觉由 DreamVisual 接管）
	for cell in cells:
		ents.erase_cell(cell)
	if not comps.is_empty():
		print("[graybox] DreamBlock 果冻块: ", comps.size(), " 块, ", cells.size(), " 格")

func _fake_terrain_cells() -> Array:
	var terr := _terrain_layer()
	if terr == null:
		return []
	var out: Array = []
	for cell in terr.get_used_cells():
		if _kind_of(terr, cell) == "fake_terrain":
			out.append(cell)
	return out


func _erase_fake_terrain_tiles() -> void:
	# 假地形的视觉由运行时 patch 接管，Terrain 层里不再保留原始 tile
	var terr := _terrain_layer()
	if terr == null:
		return
	for cell in terr.get_used_cells():
		if _kind_of(terr, cell) == "fake_terrain":
			terr.erase_cell(cell)


func _build_fake_terrain_masks() -> void:
	# 伪装地形：Terrain 层里 kind=fake_terrain 的 tile 看起来和真地形一样，
	# 运行时按连通块拆成独立视觉层 + 触发区域；玩家穿过时整块淡出消失（死亡不恢复）。
	var terr := _terrain_layer()
	if terr == null:
		return
	var cells: Dictionary = {}
	for c in terr.get_used_cells():
		if _kind_of(terr, c) == "fake_terrain":
			cells[c] = true
	if cells.is_empty():
		return
	var old := get_node_or_null("FakeTerrainRuntime")
	if old:
		old.queue_free()
	var root := Node2D.new()
	root.name = "FakeTerrainRuntime"
	add_child(root)
	# 8 邻接连通块（斜向相接也算同一块）
	var visited: Dictionary = {}
	var comps: Array = []
	for c in cells:
		if visited.has(c):
			continue
		var comp: Array = []
		var stack: Array = [c]
		visited[c] = true
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			comp.append(cur)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
				var n: Vector2i = cur + d
				if cells.has(n) and not visited.has(n):
					visited[n] = true
					stack.append(n)
		comps.append(comp)
	for comp in comps:
		var patch := TileMapLayer.new()
		patch.name = "Patch"
		patch.tile_set = terr.tile_set
		patch.collision_enabled = false
		# 遮罩要盖住玩家/实体（渲染在它们之上）
		patch.z_index = 20
		root.add_child(patch)
		var minc := Vector2i(1 << 30, 1 << 30)
		var maxc := Vector2i(-(1 << 30), -(1 << 30))
		for cell in comp:
			# 用基础 tile（alt=0）绘制：编辑器里假方块是半透明的，
			# 游戏内视觉块必须是完全不透明、和真实地形一模一样的 tile。
			patch.set_cell(cell, terr.get_cell_source_id(cell), terr.get_cell_atlas_coords(cell), 0)
			minc = Vector2i(mini(minc.x, cell.x), mini(minc.y, cell.y))
			maxc = Vector2i(maxi(maxc.x, cell.x), maxi(maxc.y, cell.y))
		var px := Vector2(float(minc.x) * TILE, float(minc.y) * TILE)
		var size_px := Vector2(float(maxc.x - minc.x + 1) * TILE, float(maxc.y - minc.y + 1) * TILE)
		var area := Area2D.new()
		area.name = "Trigger"
		area.collision_layer = 0
		area.collision_mask = 2
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size_px
		cs.shape = rect
		area.add_child(cs)
		area.position = px + size_px * 0.5
		area.body_entered.connect(_on_fake_terrain_entered.bind(patch))
		patch.add_child(area)
	# 原始假 tile 从 Terrain 层擦除（视觉由 patch 接管）
	for c in cells:
		terr.erase_cell(c)


func _on_fake_terrain_entered(body: Node2D, patch: Node) -> void:
	if not (body is CharacterBody2D) or not is_instance_valid(patch):
		return
	if patch.has_meta("triggered"):
		return
	patch.set_meta("triggered", true)
	# 整片淡出后移除
	var tw := create_tween()
	tw.tween_property(patch, "modulate:a", 0.0, 0.25)
	tw.tween_callback(patch.queue_free)


func _process(_delta: float) -> void:
	# 玩家进入紫块区域时整块压一下再弹回（果冻受压回弹）
	if _dream_patches.is_empty() or not is_instance_valid(player):
		return
	var center: Vector2 = player.global_position + Vector2(0.0, -5.5)
	var body_rect := Rect2(center - Vector2(4.0, 5.5), Vector2(8.0, 11.0))
	for info in _dream_patches:
		var patch: Node2D = info["node"]
		if not is_instance_valid(patch):
			continue
		var hit: bool = (info["rect"] as Rect2).intersects(body_rect)
		if hit and not bool(info["inside"]):
			_squash_dream_patch(patch)
		info["inside"] = hit


func _squash_dream_patch(patch: Node2D) -> void:
	var old_tw = patch.get_meta("squash_tween", null)
	if old_tw is Tween and is_instance_valid(old_tw):
		(old_tw as Tween).kill()
	patch.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_property(patch, "scale", Vector2(1.08, 0.90), 0.06)
	tw.tween_property(patch, "scale", Vector2(0.97, 1.04), 0.08)
	tw.tween_property(patch, "scale", Vector2.ONE, 0.08)
	patch.set_meta("squash_tween", tw)


func _hide_invisible_hazards() -> void:
	# 浅红死亡区：功能同红块，但运行时把 tile 从可见层擦掉（游戏中不可见）
	var ents := _entity_layer()
	if ents == null:
		return
	var count := 0
	for cell in ents.get_used_cells():
		var k := _kind_of(ents, cell)
		if k == "hazard_hidden" or k == "checkpoint":
			ents.erase_cell(cell)
			count += 1
	# 地形层（8px）：粉色 tile 由 _build_tile_parts 生成 Hazard，这里只擦除可见 tile
	var terr := _terrain_layer()
	if terr != null:
		for cell in terr.get_used_cells():
			if _kind_of(terr, cell) == "hazard_hidden":
				terr.erase_cell(cell)
				count += 1
	if count > 0:
		print("[graybox] 隐藏死亡区: ", count, " cells")


func _reset_level_entities() -> void:
	# 复活重置：删除运行时生成的机关节点 + 恢复初始 tile，再重建（奖杯已收集的格子不再出现）
	for n in get_tree().get_nodes_in_group("graybox_parts"):
		if is_ancestor_of(n):
			n.queue_free()
	var cd := get_node_or_null("CrystalCooldown")
	if cd:
		cd.queue_free()
	await get_tree().process_frame
	var ents := _entity_layer()
	var terr := _terrain_layer()
	if ents:
		ents.tile_map_data = _initial_entity_data
	if terr:
		terr.tile_map_data = _initial_terrain_data
	_erase_fake_terrain_tiles()
	if ents:
		for c in _collected_trophy_cells:
			ents.erase_cell(c)
	_build_tile_parts()
	_build_entity_rects()
	_hide_invisible_hazards()
	_setup_dream_visuals()
	_build_node_entities()
	# 区域状态重置（时间缓速、标签的一次性等）
	for trig in get_tree().get_nodes_in_group("resettable_triggers"):
		if is_ancestor_of(trig) and trig.has_method("reset_state"):
			trig.call("reset_state")
	Engine.time_scale = 1.0


func _ensure_cooldown_layer() -> TileMapLayer:
	var layer := get_node_or_null("CrystalCooldown") as TileMapLayer
	if layer != null:
		return layer
	layer = TileMapLayer.new()
	layer.name = "CrystalCooldown"
	layer.tile_set = _entity_layer().tile_set if _entity_layer() else null
	layer.modulate = Color(0.45, 0.45, 0.45, 0.75)
	layer.z_index = 2
	add_child(layer)
	return layer
