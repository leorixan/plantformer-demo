class_name SceneBuilder
## 素材库：ASCII 地图工厂。代码生成与 test_room.gd 同范式，支持素材库全部组件。
##
## 字符表：
##   '#' 墙体           'P' 玩家出生点      'x' 目标标记
##   'S' 尖刺           'B' 可破坏方块      'C' 存盘点
##   '^' 弹簧           'M' 移动平台(横向往返)
##   '.' 空
##
## 用法：
##   var result := SceneBuilder.build(rows, player_scene)
##   add_child(result["container"])
##   result["player"].global_position = result["spawn"]
##   result["player"].kill_plane_y = result["kill_plane_y"]

const TILE := 8.0
const FLOOR_COLOR := Color(0.22, 0.25, 0.32)
const TARGET_COLOR := Color(0.98, 0.85, 0.35, 0.55)

static func build(rows: Array, player_scene: PackedScene) -> Dictionary:
	var container := Node2D.new()
	container.name = "Generated"
	var terrain := StaticBody2D.new()
	terrain.name = "Terrain"
	container.add_child(terrain)
	var visuals := Node2D.new()
	visuals.name = "Visuals"
	container.add_child(visuals)

	var wall_scene: PackedScene = load("res://scenes/components/wall.tscn")
	var spike_scene: PackedScene = load("res://scenes/components/spike.tscn")
	var block_scene: PackedScene = load("res://scenes/components/breakable_block.tscn")
	var spring_scene: PackedScene = load("res://scenes/components/spring.tscn")
	var platform_scene: PackedScene = load("res://scenes/components/moving_platform.tscn")
	var checkpoint_scene: PackedScene = load("res://scenes/components/checkpoint.tscn")

	var player: Node2D = null
	var spawn := Vector2.ZERO
	var row_count := rows.size()

	for row_index in row_count:
		var row: String = rows[row_index]
		for col in row.length():
			var ch := row[col]
			if ch == "#" or ch == ".": continue
			var pos := Vector2(col * TILE + TILE * 0.5, row_index * TILE + TILE * 0.5)
			match ch:
				"P":
					spawn = Vector2(col * TILE + TILE * 0.5, (row_index + 1) * TILE)
					if player_scene:
						player = player_scene.instantiate()
				"x":
					_add_target(visuals, pos)
				"S":
					_add_instanced(container, spike_scene, pos)
				"B":
					_add_instanced(container, block_scene, pos)
				"^":
					_add_instanced(container, spring_scene, pos + Vector2(0.0, TILE * 0.25))
				"M":
					_add_instanced(container, platform_scene, pos)
				"C":
					_add_instanced(container, checkpoint_scene, pos)
	# 地面 + 墙体：先把 # 连续段合并成矩形
	for row_index in row_count:
		var row: String = rows[row_index]
		var col := 0
		while col < row.length():
			if row[col] == "#":
				var start := col
				while col < row.length() and row[col] == "#":
					col += 1
				var width := (col - start) * TILE
				var center := Vector2((start + col) * TILE * 0.5, row_index * TILE + TILE * 0.5)
				_add_solid(terrain, visuals, center, Vector2(width, TILE))
			else:
				col += 1

	var result := {
		"container": container,
		"player": player,
		"spawn": spawn,
		"kill_plane_y": row_count * TILE + TILE * 3.0,
	}
	return result

static func _add_instanced(parent: Node, scene: PackedScene, pos: Vector2) -> void:
	var node := scene.instantiate()
	node.global_position = pos
	parent.add_child(node)

static func _add_solid(terrain: StaticBody2D, visuals: Node2D, center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	terrain.add_child(body)
	var visual := ColorRect.new()
	visual.position = center - size * 0.5
	visual.size = size
	visual.color = FLOOR_COLOR
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visuals.add_child(visual)

static func _add_target(visuals: Node2D, center: Vector2) -> void:
	var visual := ColorRect.new()
	visual.position = center - Vector2(2.0, 2.0)
	visual.size = Vector2(4.0, 4.0)
	visual.color = TARGET_COLOR
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visuals.add_child(visual)
