extends Node

func _ready() -> void:
	var kinds := ["hazard", "crystal", "spring", "breakable8", "breakable16", "dream", "oneway_up", "oneway_down", "oneway_left", "oneway_right", "checkpoint", "hazard_hidden", "trophy"]
	var colors := [Color(0.78,0.24,0.28), Color(0.28,0.78,0.82), Color(0.35,0.75,0.35), Color(0.67,0.51,0.35), Color(0.45,0.30,0.16), Color(0.59,0.39,0.86), Color(0.42,0.42,0.45), Color(0.42,0.42,0.45), Color(0.42,0.42,0.45), Color(0.42,0.42,0.45), Color(0.95,0.80,0.25), Color(1.0,0.55,0.55), Color(0.96,0.66,0.16)]
	var img := Image.create(kinds.size() * 4, 4, false, Image.FORMAT_RGBA8)
	for i in kinds.size():
		for y in 4:
			for x in 4:
				img.set_pixel(i * 4 + x, y, colors[i])
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
	var err := ResourceSaver.save(ts, "res://assets/graybox/entity_tileset_v5.tres")
	print("GEN_V5 err=", err)
	get_tree().quit()
