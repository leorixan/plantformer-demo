extends SceneTree
func _initialize() -> void:
	_run()
func _run() -> void:
	var lvl = load("res://scenes/levels/level.tscn").instantiate()
	root.add_child(lvl)
	await process_frame
	await process_frame
	var player = lvl.get("player")
	var cam = player.get_node("Camera2D")
	var rc = lvl.get_node_or_null("RoomCamera")
	print("children ", lvl.get_children())
	for c in lvl.get_children():
		if c.get_script() and "room_camera" in str(c.get_script().resource_path): print("RC ", c.name)
		c.set_process(false) if c.get_script() and "room_camera" in str(c.get_script().resource_path) else null
	var s = lvl.get_node("background/BackdropImage")
	var p = lvl.get_node("background")
	print("before cam=", cam.global_position, " sglobal=", s.global_position)
	cam.global_position += Vector2(200, 0)
	await process_frame
	await process_frame
	print("after cam=", cam.global_position, " sglobal=", s.global_position, " p_global=", p.global_position)
	quit()
