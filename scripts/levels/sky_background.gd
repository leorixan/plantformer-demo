extends Node2D
## 运行时构建多层视差天空背景：
## 天空纯色渐变（固定）+ 云层 + 远山 + 中景山 + 近景山（各自视差）
## 纯色剪影风格，方便灰盒阶段替换成正式美术

@export var sky_top := Color(0.38, 0.66, 0.92, 1.0)
@export var sky_horizon := Color(0.98, 0.86, 0.68, 1.0)
@export var cloud_color := Color(1.0, 1.0, 1.0, 0.55)
@export var far_color := Color(0.44, 0.57, 0.72, 1.0)
@export var mid_color := Color(0.31, 0.43, 0.57, 1.0)
@export var near_color := Color(0.19, 0.29, 0.41, 1.0)
@export var view_size := Vector2(480, 270)

const SKY_LAYER := -10


func _ready() -> void:
	var pbg := ParallaxBackground.new()
	pbg.name = "ParallaxBackground"
	pbg.layer = SKY_LAYER
	add_child(pbg)
	_add_sky(pbg)
	_add_clouds(pbg)
	_add_hills(pbg, 0.10, far_color, 190.0, 22.0, 0.0)
	_add_hills(pbg, 0.25, mid_color, 214.0, 30.0, 1.7)
	_add_hills(pbg, 0.45, near_color, 242.0, 38.0, 3.1)


func _add_sky(pbg: ParallaxBackground) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2.ZERO
	pbg.add_child(layer)
	var grad := Gradient.new()
	grad.set_color(0, sky_top)
	grad.set_color(1, sky_horizon)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = int(view_size.x)
	tex.height = int(view_size.y)
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.position = Vector2.ZERO
	rect.size = view_size
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)


func _add_clouds(pbg: ParallaxBackground) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(0.04, 0.0)
	layer.motion_mirroring = Vector2(view_size.x, 0.0)
	pbg.add_child(layer)
	var holder := Node2D.new()
	layer.add_child(holder)
	var spots := [
		[Vector2(60, 46), Vector2(46, 14)],
		[Vector2(190, 30), Vector2(34, 10)],
		[Vector2(320, 62), Vector2(52, 16)],
		[Vector2(430, 38), Vector2(30, 9)],
	]
	for s in spots:
		var cloud := _blob(s[0], s[1], cloud_color)
		holder.add_child(cloud)


func _blob(center: Vector2, radius: Vector2, color: Color) -> Polygon2D:
	var pts := PackedVector2Array()
	var n := 14
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = color
	return poly


func _add_hills(pbg: ParallaxBackground, scroll: float, color: Color,
		base_y: float, amp: float, phase: float) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(scroll, 0.0)
	layer.motion_mirroring = Vector2(view_size.x, 0.0)
	pbg.add_child(layer)
	var poly := Polygon2D.new()
	poly.color = color
	var pts := PackedVector2Array()
	var steps := 36
	pts.append(Vector2(0.0, view_size.y + 60.0))
	for i in steps + 1:
		var t := float(i) / float(steps)
		var x := view_size.x * t
		var y := base_y
		y -= sin(t * TAU * 1.3 + phase) * amp
		y -= sin(t * TAU * 3.1 + phase * 2.0) * amp * 0.35
		pts.append(Vector2(x, y))
	pts.append(Vector2(view_size.x, view_size.y + 60.0))
	poly.polygon = pts
	layer.add_child(poly)
