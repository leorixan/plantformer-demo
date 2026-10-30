extends Node

func _ready() -> void:
	var kinds := ["hazard", "crystal", "spring_up", "breakable8", "breakable16", "dream",
		"oneway_up", "oneway_down", "oneway_left", "oneway_right", "checkpoint",
		"hazard_hidden", "trophy", "spring_down", "spring_left", "spring_right"]
	var colors := {
		"hazard": Color(0.78, 0.24, 0.28), "crystal": Color(0.282, 0.745, 0.784),
		"breakable8": Color(0.36, 0.39, 0.45), "breakable16": Color(0.30, 0.33, 0.39),
		"dream": Color(0.59, 0.39, 0.86), "checkpoint": Color(0.95, 0.80, 0.25),
		"hazard_hidden": Color(1.0, 0.55, 0.55), "trophy": Color(0.96, 0.66, 0.16),
	}
	var oak := Color(0.49, 0.36, 0.22)
	var steel := Color(0.25, 0.36, 0.41)
	var img := Image.create(kinds.size() * 4, 4, false, Image.FORMAT_RGBA8)
	for i in kinds.size():
		var k: String = kinds[i]
		for y in 4:
			for x in 4:
				var c := Color(0.42, 0.42, 0.45)
				if colors.has(k):
					c = colors[k]
				elif k.begins_with("spring_"):
					c = Color(0, 0, 0, 0)
				img.set_pixel(i * 4 + x, y, c)
		if k.begins_with("spring_"):
			for y in 4:
				for x in 4:
					var near_edge := false
					match k:
						"spring_up": near_edge = y <= 1
						"spring_down": near_edge = y >= 2
						"spring_left": near_edge = x <= 1
						"spring_right": near_edge = x >= 2
					var c2 := oak if near_edge else steel
					img.set_pixel(i * 4 + x, y, c2)
	# 单向墙：地形色边
	var edge := Color(0.24, 0.26, 0.31, 1.0)
	var dirs := {"oneway_up": "up", "oneway_down": "down", "oneway_left": "left", "oneway_right": "right"}
	for i in kinds.size():
		var k: String = kinds[i]
		if not dirs.has(k):
			continue
		var x0 := i * 4
		match dirs[k]:
			"up":
				for x in 4:
					img.set_pixel(x0 + x, 0, edge)
					img.set_pixel(x0 + x, 1, edge)
			"down":
				for x in 4:
					img.set_pixel(x0 + x, 2, edge)
					img.set_pixel(x0 + x, 3, edge)
			"left":
				for y in 4:
					img.set_pixel(x0, y, edge)
					img.set_pixel(x0 + 1, y, edge)
			"right":
				for y in 4:
					img.set_pixel(x0 + 2, y, edge)
					img.set_pixel(x0 + 3, y, edge)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(4, 4)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "kind")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
	var s := TileSetAtlasSource.new()
	s.texture = ImageTexture.create_from_image(img)
	s.texture_region_size = Vector2i(4, 4)
	for i in kinds.size():
		s.create_tile(Vector2i(i, 0))
	ts.add_source(s, 0)
	for i in kinds.size():
		s.get_tile_data(Vector2i(i, 0), 0).set_custom_data("kind", kinds[i])
	var err := ResourceSaver.save(ts, "res://assets/graybox/entity_tileset_v6.tres")
	print("GEN_V6 err=", err)
	get_tree().quit()
