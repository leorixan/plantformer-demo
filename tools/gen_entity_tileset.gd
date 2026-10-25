extends Node

func _ready() -> void:
	var kinds := ["hazard", "crystal", "spring", "breakable", "jelly", "checkpoint", "oneway"]
	var colors := [Color(0.78,0.24,0.28), Color(0.28,0.78,0.82), Color(0.35,0.75,0.35), Color(0.67,0.51,0.35), Color(0.59,0.39,0.86), Color(0.95,0.8,0.25), Color(0.45,0.75,0.95)]
	var img := Image.create(kinds.size() * 4, 4, false, Image.FORMAT_RGBA8)
	for i in kinds.size():
		for y in 4:
			for x in 4:
				img.set_pixel(i * 4 + x, y, colors[i])
	var tex := ImageTexture.create_from_image(img)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(4, 4)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "kind")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
	var s := TileSetAtlasSource.new()
	s.texture = tex
	s.texture_region_size = Vector2i(4, 4)
	for i in kinds.size():
		s.create_tile(Vector2i(i, 0))
	ts.add_source(s, 0)
	for i in kinds.size():
		s.get_tile_data(Vector2i(i, 0), 0).set_custom_data("kind", kinds[i])
	print("GEN_ENTITY_TILESET err=", ResourceSaver.save(ts, "res://assets/graybox/entity_tileset.tres"))
	get_tree().quit()
