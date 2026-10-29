extends Node

func _ready() -> void:
	var ets: TileSet = load("res://assets/graybox/entity_tileset_v4.tres")
	var defs := [
		[0, "红：伤害区 —— 碰到即死亡，回最近存档点", Color(0.78,0.24,0.28)],
		[1, "青：冲刺水晶 —— 回满冲刺次数与体力（冷却 2.5s 变灰）", Color(0.28,0.78,0.82)],
		[2, "绿：弹簧 —— 自动判朝向，向上弹起", Color(0.35,0.75,0.35)],
		[3, "棕：可破坏块 —— 冲刺撞碎（8×8 一块）", Color(0.67,0.51,0.35)],
		[4, "深棕：可破坏块 —— 冲刺撞碎（16×16 一块）", Color(0.45,0.30,0.16)],
		[5, "紫：Dream Block —— 冲刺穿过，出块回满，撞墙死亡", Color(0.59,0.39,0.86)],
		[10, "金：存档点 —— 碰到记录位置，死亡在此复活", Color(0.95,0.80,0.25)],
		[11, "浅红：隐藏死亡区 —— 功能同红块，游戏中不可见", Color(1.0,0.55,0.55)],
	]
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Arial"])
	var root := Node2D.new()
	root.name = "Showcase"
	var ents := TileMapLayer.new()
	ents.name = "Entities"
	ents.tile_set = ets
	root.add_child(ents)
	ents.owner = root
	var row := 2
	for d in defs:
		for xx in range(2, 4):
			for yy in range(row, row + 2):
				ents.set_cell(Vector2i(xx, yy), 0, Vector2i(int(d[0]), 0))
		var lab := Label.new()
		lab.text = String(d[1])
		lab.position = Vector2(64, row * 8)
		lab.size = Vector2(300, 12)
		lab.add_theme_font_override("font", font)
		lab.add_theme_font_size_override("font_size", 7)
		lab.add_theme_color_override("font_color", d[2])
		root.add_child(lab)
		lab.owner = root
		row += 4
	# 单向墙四向并排一行
	var ow := [[6, "上"], [7, "下"], [8, "左"], [9, "右"]]
	for i in ow.size():
		var x := 2 + i * 3
		for yy in range(row, row + 2):
			ents.set_cell(Vector2i(x, yy), 0, Vector2i(int(ow[i][0]), 0))
		var dl := Label.new()
		dl.text = String(ow[i][1])
		dl.position = Vector2(x * 8 - 2, (row + 2) * 8)
		dl.add_theme_font_override("font", font)
		dl.add_theme_font_size_override("font_size", 7)
		dl.add_theme_color_override("font_color", Color(0.42, 0.42, 0.45))
		root.add_child(dl)
		dl.owner = root
	var ol := Label.new()
	ol.text = "深灰：单向墙 ×4 —— 地形色边所在侧 = 可通行方向（顺序上/下/左/右）"
	ol.position = Vector2(64, (row + 4) * 8)
	ol.size = Vector2(340, 12)
	ol.add_theme_font_override("font", font)
	ol.add_theme_font_size_override("font_size", 7)
	ol.add_theme_color_override("font_color", Color(0.42, 0.42, 0.45))
	root.add_child(ol)
	ol.owner = root
	var title := Label.new()
	title.text = "灰盒组件备忘 / Graybox Components Reference"
	title.position = Vector2(8, 0)
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 10)
	root.add_child(title)
	title.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	print("SHOWCASE err=", ResourceSaver.save(packed, "res://scenes/levels/graybox_showcase.tscn"))
	get_tree().quit()
