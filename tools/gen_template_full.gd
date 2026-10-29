extends Node

func _ready() -> void:
	var terr_ts: TileSet = load("res://assets/graybox/graybox_tileset.tres")
	var ets: TileSet = load("res://assets/graybox/entity_tileset_v4.tres")
	var coord := {"hazard": 0, "crystal": 1, "spring": 2, "breakable8": 3, "breakable16": 4, "dream": 5, "oneway_up": 6, "oneway_down": 7, "oneway_left": 8, "oneway_right": 9, "checkpoint": 10, "hazard_hidden": 11}
	var root := Node2D.new()
	root.name = "GrayboxLevel"
	root.set_script(load("res://scripts/levels/graybox_level.gd"))
	var terr := TileMapLayer.new()
	terr.name = "Terrain"
	terr.tile_set = terr_ts
	root.add_child(terr)
	var ents := TileMapLayer.new()
	ents.name = "Entities"
	ents.tile_set = ets
	root.add_child(ents)
	var spawn := Marker2D.new()
	spawn.name = "Spawn"
	var goal := Marker2D.new()
	goal.name = "Goal"
	root.add_child(spawn)
	root.add_child(goal)
	for n in [terr, ents, spawn, goal]:
		n.owner = root
	# 地形铺满两个房间（0~640px，80 个 8px 格）
	for x in range(0, 80):
		terr.set_cell(Vector2i(x, 22), 0, Vector2i(0, 0))
		terr.set_cell(Vector2i(x, 23), 0, Vector2i(0, 0))
	# 第二房间高台
	for x in range(52, 64):
		terr.set_cell(Vector2i(x, 18), 0, Vector2i(0, 0))
	for x in range(66, 74):
		terr.set_cell(Vector2i(x, 16), 0, Vector2i(0, 0))
	var place := func(kind: String, x0: int, y0: int, w: int, h: int) -> void:
		for xx in range(x0, x0 + w):
			for yy in range(y0, y0 + h):
				ents.set_cell(Vector2i(xx, yy), 0, Vector2i(int(coord[kind]), 0))
	# 第一房间示例
	place.call("hazard", 6, 21, 2, 1)
	place.call("crystal", 12, 21, 1, 1)
	place.call("spring", 16, 21, 2, 1)
	place.call("breakable8", 22, 20, 2, 2)
	place.call("breakable16", 28, 18, 4, 4)
	place.call("dream", 36, 20, 2, 2)
	place.call("checkpoint", 42, 21, 1, 1)
	# 第二房间示例
	place.call("oneway_up", 50, 20, 2, 1)
	place.call("oneway_down", 56, 20, 2, 1)
	place.call("oneway_left", 60, 19, 1, 2)
	place.call("oneway_right", 62, 19, 1, 2)
	place.call("hazard_hidden", 68, 20, 2, 1)
	place.call("dream", 70, 20, 2, 2)
	# Rooms
	var rooms := Node2D.new()
	rooms.name = "Rooms"
	rooms.set_script(load("res://scripts/components/rooms_definition.gd"))
	rooms.set("room_size", Vector2i(320, 184))
	var arr: Array[Rect2] = [Rect2(Vector2(0, 0), Vector2(320, 184)), Rect2(Vector2(320, 0), Vector2(320, 184))]
	rooms.set("rooms", arr)
	root.add_child(rooms)
	rooms.owner = root
	spawn.position = Vector2(16, 176)
	goal.position = Vector2(600, 160)
	var packed := PackedScene.new()
	packed.pack(root)
	print("TEMPLATE_FULL err=", ResourceSaver.save(packed, "res://scenes/levels/graybox_template.tscn"))
	get_tree().quit()
