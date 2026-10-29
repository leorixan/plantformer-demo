extends Node

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/graybox_template.tscn")
	var lvl: Node = ps.instantiate()
	var terr: TileMapLayer = lvl.get_node("Terrain")
	var ents: TileMapLayer = lvl.get_node("Entities")
	var v2: TileSet = load("res://assets/graybox/graybox_tileset_v2.tres")
	terr.tile_set = v2
	# 把实体层粉色（atlas 11）迁移到地形层（atlas 7）
	var pinks: Array = []
	for cell in ents.get_used_cells():
		if ents.get_cell_atlas_coords(cell) == Vector2i(11, 0):
			pinks.append(cell)
	for cell in pinks:
		ents.erase_cell(cell)
	if pinks.is_empty():
		pinks = [Vector2i(136, 40), Vector2i(140, 40)]
	for cell in pinks:
		var t := Vector2i(int(cell.x * 4 / 8), int(cell.y * 4 / 8))
		terr.set_cell(t, 0, Vector2i(7, 0))
	var packed := PackedScene.new()
	packed.pack(lvl)
	print("MIGRATE_SAVE err=", ResourceSaver.save(packed, "res://scenes/levels/graybox_template.tscn"))
	print("MIGRATE pinks=", pinks.size())
	get_tree().quit()
