extends Node

func _ready() -> void:
	var cell := 4
	var row0 := ["hazard", "crystal", "breakable8", "breakable16", "dream", "checkpoint", "hazard_hidden", "trophy"]
	var row1 := ["spring_up", "spring_down", "spring_left", "spring_right", "oneway_up", "oneway_down", "oneway_left", "oneway_right"]
	var colors := {
		"hazard": Color(0.78, 0.24, 0.28), "crystal": Color(0.282, 0.745, 0.784),
		"breakable8": Color(0.36, 0.39, 0.45), "breakable16": Color(0.30, 0.33, 0.39),
		"dream": Color(0.59, 0.39, 0.86), "checkpoint": Color(0.95, 0.80, 0.25),
		"hazard_hidden": Color(1.0, 0.55, 0.55), "trophy": Color(0.96, 0.66, 0.16),
	}
	var oak := Color(0.49, 0.36, 0.22)
	var steel := Color(0.25, 0.36, 0.41)
	var oneway_base := Color(0.42, 0.42, 0.45)
	var oneway_edge := Color(0.24, 0.26, 0.31)
	var img := Image.create(16 * cell, 2 * cell, false, Image.FORMAT_RGBA8)
	for i in row0.size():
		for y in cell:
			for x in cell:
				img.set_pixel(i * cell + x, y, colors[row0[i]])
	for i in row1.size():
		var k: String = row1[i]
		for y in cell:
			for x in cell:
				var c := Color(0, 0, 0, 0)
				if k.begins_with("spring_"):
					var wood_side := false
					match k:
						"spring_up": wood_side = y <= 1
						"spring_down": wood_side = y >= 2
						"spring_left": wood_side = x <= 1
						"spring_right": wood_side = x >= 2
					c = oak if wood_side else steel
				else:
					var edge_side := false
					match k:
						"oneway_up": edge_side = y <= 1
						"oneway_down": edge_side = y >= 2
						"oneway_left": edge_side = x <= 1
						"oneway_right": edge_side = x >= 2
					c = oneway_edge if edge_side else oneway_base
				img.set_pixel(i * cell + x, cell + y, c)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(cell, cell)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "kind")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
	var s := TileSetAtlasSource.new()
	s.texture = ImageTexture.create_from_image(img)
	s.texture_region_size = Vector2i(cell, cell)
	var entries: Array = []
	for i in row0.size():
		entries.append([Vector2i(i, 0), row0[i]])
	for i in row1.size():
		entries.append([Vector2i(i, 1), row1[i]])
	for e in entries:
		s.create_tile(e[0])
	ts.add_source(s, 0)
	for e in entries:
		s.get_tile_data(e[0], 0).set_custom_data("kind", e[1])
	var err := ResourceSaver.save(ts, "res://assets/graybox/entity_tileset_v7.tres")
	print("GEN_V7 err=", err)
	get_tree().quit()
