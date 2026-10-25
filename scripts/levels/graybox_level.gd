extends Node2D
## 灰盒关卡：Terrain(TileMapLayer) 里每个 tile 就是可拖拽放置的组件。
## tile 自定义数据 "kind"：terrain / hazard / crystal / spring / breakable / jelly
## 运行管线：读取 tile → 建地形碰撞(合并成矩形) + 生成对应机关节点（纯代码，无 tscn）

const TILE := 8.0
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const KIND_ORDER := ["terrain", "hazard", "crystal", "spring", "breakable", "jelly"]

var player: CharacterBody2D
var spawn_pos := Vector2.ZERO
var _kinds: Dictionary = {}


func _ready() -> void:
	_scan_cells()
	_build_collision()
	_build_parts()
	var marker := get_node_or_null("Spawn") as Node2D
	spawn_pos = marker.global_position if marker else Vector2(16, 0)
	_spawn_player()
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


func _scan_cells() -> void:
	var terrain := get_node_or_null("Terrain") as TileMapLayer
	if terrain == null:
		push_error("缺少 Terrain TileMapLayer")
		return
	for cell in terrain.get_used_cells():
		var kind := ""
		var data := terrain.get_cell_tile_data(cell)
		if data and data.has_custom_data("kind"):
			kind = String(data.get_custom_data("kind"))
		if kind.is_empty():
			var coord := terrain.get_cell_atlas_coords(cell)
			kind = KIND_ORDER[coord.x] if coord.y == 0 and coord.x < KIND_ORDER.size() else "terrain"
		_kinds[cell] = kind


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "TerrainBody"
	add_child(body)
	var rows: Dictionary = {}
	for cell in _kinds:
		if _kinds[cell] == "terrain":
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


func _build_parts() -> void:
	var parts := load("res://scripts/components/graybox_parts.gd")
	for cell in _kinds:
		var kind: String = _kinds[cell]
		var pos := Vector2(float(cell.x) * TILE + TILE * 0.5, float(cell.y) * TILE + TILE * 0.5)
		var node: Node2D = null
		match kind:
			"hazard":
				var h = parts.Hazard.new()
				h.level = self
				node = h
			"crystal":
				node = parts.Crystal.new()
			"spring":
				node = parts.Spring.new()
			"breakable":
				node = parts.Breakable.new()
			"jelly":
				node = parts.Jelly.new()
		if node:
			node.position = pos
			add_child(node)


func _spawn_player() -> void:
	player = load(PLAYER_SCENE).instantiate()
	player.global_position = spawn_pos
	add_child(player)


func respawn_player() -> void:
	if player == null:
		return
	player.global_position = spawn_pos
	player.velocity = Vector2.ZERO
