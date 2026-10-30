extends Node2D
## 跳跃小粒子（参考蔚蓝的 jump dust）：几颗像素小方块向外扩散、轻微上飘、淡出

const LIFE := 0.28

var _parts: Array = []
var _t := 0.0


func setup(pos: Vector2, dir: float, amount: int, color: Color = Color(0.92, 0.96, 1.0, 0.9)) -> void:
	global_position = pos
	z_index = 15
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in amount:
		var rect := ColorRect.new()
		rect.size = Vector2(1, 1)
		rect.color = color
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.position = Vector2(0, 0) + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-1.0, 1.0))
		add_child(rect)
		var vx := rng.randf_range(-22.0, 22.0) + dir * 26.0
		var vy := rng.randf_range(-34.0, -8.0)
		_parts.append({"node": rect, "vel": Vector2(vx, vy), "life": 0.0})


func _process(delta: float) -> void:
	_t += delta
	for p in _parts:
		p.life = float(p.life) + delta
		var vel: Vector2 = p.vel
		vel.y += 150.0 * delta
		p.vel = vel
		var n: ColorRect = p.node
		n.position += vel * delta
		var k := clampf(1.0 - float(p.life) / LIFE, 0.0, 1.0)
		var c := n.color
		c.a = 0.85 * k
		n.color = c
		n.scale = Vector2.ONE * (1.0 + float(p.life) * 2.5)
	if _t >= LIFE:
		queue_free()
