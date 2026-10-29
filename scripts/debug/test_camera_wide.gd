extends Node

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/graybox_template.tscn")
	var lvl: Node = ps.instantiate()
	var rooms: Node = lvl.get_node("Rooms")
	# 清空旧子节点，放一个 640x184 的房间
	for ch in rooms.get_children():
		ch.queue_free()
	await get_tree().process_frame
	var rr := ReferenceRect.new()
	rr.name = "RoomWide"
	rr.position = Vector2(0, 0)
	rr.size = Vector2(640, 184)
	rooms.add_child(rr)
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	var rc: Node = null
	for ch in lvl.get_children():
		var sc = ch.get_script()
		if sc and String(sc.resource_path).ends_with("room_camera.gd"):
			rc = ch
	var cam: Camera2D = lvl.get_node("Player/Camera2D") if lvl.has_node("Player/Camera2D") else null
	if cam == null:
		cam = lvl.get_node("Player").get_node_or_null("Camera2D")
	print("TEST room_camera=", rc != null, " view=", rc.get("_view") if rc else "n/a")
	Input.action_press("move_right")
	var xs: Array = []
	var ymin := 1e9
	var ymax := -1e9
	for i in 180:
		await get_tree().physics_frame
		xs.append(cam.global_position.x)
		ymin = minf(ymin, cam.global_position.y)
		ymax = maxf(ymax, cam.global_position.y)
	Input.action_release("move_right")
	var flips := 0
	var neg := 0
	for i in range(1, xs.size()):
		var d: float = xs[i] - xs[i-1]
		if absf(d) < 0.001:
			continue
		if i > 1:
			var d0: float = xs[i-1] - xs[i-2]
			if (d > 0 and d0 < 0) or (d < 0 and d0 > 0):
				flips += 1
		if d < -0.001:
			neg += 1
	print("TEST cam_x_first=", xs[0], " last=", xs[xs.size()-1], " y_range=", ymax-ymin, " neg_steps=", neg, " sign_flips=", flips)
	var sample := ""
	for i in range(0, mini(40, xs.size())):
		sample += str(snappedf(xs[i] - xs[0], 0.1)) + " "
	print("TEST dx_sample=", sample)
	get_tree().quit()
