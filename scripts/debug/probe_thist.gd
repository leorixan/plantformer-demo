extends Node

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/graybox_template.tscn")
	var lvl: Node = ps.instantiate()
	add_child(lvl)
	await get_tree().process_frame
	for ln in ["Terrain", "Entities"]:
		var layer: TileMapLayer = lvl.get_node(ln)
		var hist: Dictionary = {}
		for cell in layer.get_used_cells():
			var key := "%s/%s" % [layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell)]
			hist[key] = int(hist.get(key, 0)) + 1
		print("THIST ", ln, " total=", layer.get_used_cells().size(), " => ", hist)
	get_tree().quit()
