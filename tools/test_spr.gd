extends Node

func _ready() -> void:
	var lvl: Node = load("res://scenes/levels/level.tscn").instantiate()
	add_child(lvl)
	for i in 8:
		await get_tree().physics_frame
	var springs: Array = []
	for n in lvl.get_children():
		if n.has_method("_from_valid_side"):
			springs.append(n)
	print("SPRINGS count=", springs.size())
	var space := get_world_2d().direct_space_state
	for s in springs:
		var p: Vector2 = (s as Node2D).global_position
		var d = s.get("dir")
		var sz = s.get("size")
		# 检查周围有没有实体地形（用点查询在四边外 2px）
		var walls := []
		for probe in [Vector2(0,-1), Vector2(0,1), Vector2(-1,0), Vector2(1,0)]:
			var pt: Vector2 = p + probe * (sz * 0.5 + 2.0)
			var pq := PhysicsPointQueryParameters2D.new()
			pq.position = pt
			pq.collision_mask = 1
			pq.collide_with_areas = false
			if not space.intersect_point(pq, 4).is_empty():
				walls.append(probe)
		print("SP ", p, " dir=", d, " size=", sz, " walls=", walls)
	get_tree().quit()
