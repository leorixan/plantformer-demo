extends Node

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/graybox_template.tscn")
	var lvl: Node = ps.instantiate()
	var terr: TileMapLayer = lvl.get_node("Terrain")
	var data: PackedByteArray = terr.tile_map_data
	print("FMT bytes=", data.size())
	var hx := ""
	for i in mini(48, data.size()):
		hx += "%02x" % data[i]
	print("FMT head=", hx)
	var cells := terr.get_used_cells()
	print("FMT cell_count=", cells.size())
	for i in mini(4, cells.size()):
		var c: Vector2i = cells[i]
		print("FMT cell ", c, " src=", terr.get_cell_source_id(c), " atlas=", terr.get_cell_atlas_coords(c))
	get_tree().quit()
