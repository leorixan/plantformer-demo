extends Node

func _ready() -> void:
	var ets: TileSet = load("res://assets/graybox/entity_tileset_v4.tres")
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Arial"])
	var root := Node2D.new()
	root.name = "HazardHiddenDemo"
	var ents := TileMapLayer.new()
	ents.name = "Entities"
	ents.tile_set = ets
	root.add_child(ents)
	ents.owner = root
	for x in range(4, 12):
		ents.set_cell(Vector2i(x, 4), 0, Vector2i(11, 0))
	var lab := Label.new()
	lab.text = "浅红 hazard_hidden：编辑器可见，游戏中不可见（碰到死亡）"
	lab.position = Vector2(16, 48)
	lab.add_theme_font_override("font", font)
	lab.add_theme_font_size_override("font_size", 7)
	lab.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75))
	root.add_child(lab)
	lab.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	print("DEMO err=", ResourceSaver.save(packed, "res://scenes/levels/hazard_hidden_demo.tscn"))
	get_tree().quit()
