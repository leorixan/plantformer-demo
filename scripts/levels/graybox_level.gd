extends Node2D
## 灰盒关卡：
## - Terrain  (TileMapLayer, 8px)：地形 + 机关 tile（兼容旧方式）
## - Entities (TileMapLayer, 4px)：任意尺寸机关（画笔=Godot 自带 TileMap 画笔/矩形/油漆桶）
## 运行时按 tile 生成碰撞/机关节点（纯代码，无 tscn 组件）

const TILE := 8.0
const HALF := 4.0
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const KIND_ORDER := ["terrain", "hazard", "crystal", "spring", "breakable", "jelly", "checkpoint"]
const ENTITY_KINDS := ["hazard", "crystal", "spring", "breakable", "jelly", "checkpoint"]
const ENTITY_ATLAS := ["hazard", "crystal", "spring", "breakable8", "breakable16", "dream", "oneway_up", "oneway_down", "oneway_left", "oneway_right", "checkpoint"]

var player: CharacterBody2D
var spawn_pos := Vector2.ZERO
var checkpoint_pos := Vector2.ZERO
var _terrain_cells: Dictionary = {}


func _ready() -> void:
	var legend := get_node_or_null("Legend")
	if legend:
		legend.visible = false
	_build_terrain()
	_build_tile_parts()
	_build_entity_rects()
	_setup_dream_visuals()
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
		"hazard":
			var h = parts.Hazard.new()
			h.level = self
			node = h
		"crystal":
			node = parts.Crystal.new()
		"spring":
			var sp = parts.Spring.new()
			sp.dir = _spring_dir(pos, size)
			node = sp
		"breakable", "breakable8", "breakable16":
			node = parts.Breakable.new()
		"jelly", "dream":
			var db = parts.DreamBlock.new()
			db.level = self
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
		_:
			return
	node.set("size", size)
	node.position = pos
	add_child(node)
	return node


func _spawn_player() -> void:
	player = load(PLAYER_SCENE).instantiate()
	player.global_position = spawn_pos
	add_child(player)


func respawn_player() -> void:
	if player == null:
		return
	player.global_position = checkpoint_pos
	player.velocity = Vector2.ZERO


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
	# 方式 A：Rooms 节点自带 rooms 数组（RoomsDefinition，Inspector 编辑）
	var arr = rooms.get("rooms")
	if arr is Array and not (arr as Array).is_empty():
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


func _setup_dream_visuals() -> void:
	# 紫色 Dream Block 的显示层要高于玩家，且半透明
	var ents := _entity_layer()
	if ents == null:
		return
	var visual := TileMapLayer.new()
	visual.name = "DreamVisual"
	visual.tile_set = ents.tile_set
	visual.z_index = 10
	visual.modulate = Color(1, 1, 1, 0.65)
	add_child(visual)
	var moved := 0
	for cell in ents.get_used_cells():
		var kind := _kind_of(ents, cell)
		if kind == "dream" or kind == "jelly":
			visual.set_cell(cell, ents.get_cell_source_id(cell), ents.get_cell_atlas_coords(cell))
			ents.erase_cell(cell)
			moved += 1
	if moved == 0:
		visual.queue_free()
	else:
		print("[graybox] DreamBlock 高层半透明视觉: ", moved, " cells")
