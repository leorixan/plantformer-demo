@tool
class_name RoomsDefinition
extends Node2D
## 更方便的房间定义：一个节点 + Inspector 里的 Rect2 数组。
## position = 关卡原点偏移；rooms 内每个 Rect2 = 房间矩形（世界像素坐标）。
## 选中节点点 Inspector 里的「按屏幕网格自动生成房间」会扫描 Terrain 覆盖范围，
## 按 room_size 生成网格房间，之后可手动删改。

@export var room_size := Vector2i(320, 180)
@export var rooms: Array[Rect2] = []
@export var color := Color(0.3, 0.75, 1.0, 0.9)

@export_tool_button("按屏幕网格自动生成房间", "generate_rooms")
var _generate_action


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	for r in rooms:
		draw_rect(r, color, false, 1.0)


func generate_rooms() -> void:
	var terrain := get_parent().get_node_or_null("Terrain") as TileMapLayer
	if terrain == null:
		push_warning("同级节点里找不到 Terrain (TileMapLayer)")
		return
	var cells := terrain.get_used_cells()
	if cells.is_empty():
		push_warning("Terrain 还没有画地形")
		return
	var min_cell := Vector2i(1 << 20, 1 << 20)
	var max_cell := Vector2i(-(1 << 20), -(1 << 20))
	for c in cells:
		min_cell.x = mini(min_cell.x, c.x)
		min_cell.y = mini(min_cell.y, c.y)
		max_cell.x = maxi(max_cell.x, c.x)
		max_cell.y = maxi(max_cell.y, c.y)
	var tile := 8
	var room_tiles := Vector2i(room_size.x / tile, room_size.y / tile)
	var start_cell := Vector2i(floori(min_cell.x / float(room_tiles.x)) * room_tiles.x,
			floori(min_cell.y / float(room_tiles.y)) * room_tiles.y)
	var new_rooms: Array[Rect2] = []
	var y := start_cell.y
	while y <= max_cell.y:
		var x := start_cell.x
		while x <= max_cell.x:
			new_rooms.append(Rect2(Vector2(x * tile, y * tile), Vector2(room_size)))
			x += room_tiles.x
		y += room_tiles.y
	rooms = new_rooms
	print("[rooms] 自动生成 ", rooms.size(), " 个房间")
