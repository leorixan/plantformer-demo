extends Node

const VIEW := Vector2(480, 270)


func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/graybox_template.tscn")
	var lvl: Node2D = ps.instantiate()
	var old := lvl.get_node_or_null("SkyBackground")
	if old:
		lvl.remove_child(old)
		old.free()
	var pbg := ParallaxBackground.new()
	pbg.name = "ParallaxBackground"
	pbg.layer = -10
	lvl.add_child(pbg)
	pbg.owner = lvl
	# 1) 天空渐变（固定）
	var sky := ParallaxLayer.new()
	sky.name = "SkyGradient"
	sky.motion_scale = Vector2.ZERO
	pbg.add_child(sky)
	sky.owner = lvl
	var grad := Gradient.new()
	grad.set_color(0, Color(0.38, 0.66, 0.92, 1.0))
	grad.set_color(1, Color(0.98, 0.86, 0.68, 1.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = int(VIEW.x)
	tex.height = int(VIEW.y)
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var spr := Sprite2D.new()
	spr.name = "Sky"
	spr.texture = tex
	spr.centered = false
	spr.position = Vector2.ZERO
	sky.add_child(spr)
	spr.owner = lvl
	# 2) 云
	var clouds := ParallaxLayer.new()
	clouds.name = "Clouds"
	clouds.motion_scale = Vector2(0.04, 0.0)
	clouds.motion_mirroring = Vector2(VIEW.x, 0.0)
	pbg.add_child(clouds)
	clouds.owner = lvl
	_add_cloud(clouds, Vector2(62, 46), Vector2(46, 14), lvl)
	_add_cloud(clouds, Vector2(192, 30), Vector2(34, 10), lvl)
	_add_cloud(clouds, Vector2(322, 62), Vector2(52, 16), lvl)
	_add_cloud(clouds, Vector2(432, 38), Vector2(30, 9), lvl)
	# 3) 远 / 中 / 近山
	_add_hills(pbg, lvl, "FarHills", 0.10, Color(0.44, 0.57, 0.72, 1.0), 190.0, 22.0, 0.0)
	_add_hills(pbg, lvl, "MidHills", 0.25, Color(0.31, 0.43, 0.57, 1.0), 214.0, 30.0, 1.7)
	_add_hills(pbg, lvl, "NearHills", 0.45, Color(0.19, 0.29, 0.41, 1.0), 242.0, 38.0, 3.1)
	var packed := PackedScene.new()
	packed.pack(lvl)
	print("SKY_SAVE err=", ResourceSaver.save(packed, "res://scenes/levels/graybox_template.tscn"))
	get_tree().quit()


func _add_cloud(layer: ParallaxLayer, center: Vector2, radius: Vector2, owner_node: Node) -> void:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	var n := 14
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	poly.polygon = pts
	poly.color = Color(1.0, 1.0, 1.0, 0.55)
	layer.add_child(poly)
	poly.owner = owner_node


func _add_hills(pbg: ParallaxBackground, root: Node, nm: String, scroll: float,
		color: Color, base_y: float, amp: float, phase: float) -> void:
	var layer := ParallaxLayer.new()
	layer.name = nm
	layer.motion_scale = Vector2(scroll, 0.0)
	layer.motion_mirroring = Vector2(VIEW.x, 0.0)
	pbg.add_child(layer)
	layer.owner = root
	var poly := Polygon2D.new()
	poly.name = nm + "Shape"
	poly.color = color
	var pts := PackedVector2Array()
	var steps := 36
	pts.append(Vector2(0.0, VIEW.y + 60.0))
	for i in steps + 1:
		var t := float(i) / float(steps)
		var x := VIEW.x * t
		var y := base_y
		y -= sin(t * TAU * 1.3 + phase) * amp
		y -= sin(t * TAU * 3.1 + phase * 2.0) * amp * 0.35
		pts.append(Vector2(x, y))
	pts.append(Vector2(VIEW.x, VIEW.y + 60.0))
	poly.polygon = pts
	layer.add_child(poly)
	poly.owner = root
