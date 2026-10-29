extends Node

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/graybox_template.tscn")
	var lvl: Node = ps.instantiate()
	var rooms: Node = lvl.get_node("Rooms")
	for i in 2:
		var rr := ReferenceRect.new()
		rr.name = "Room%d" % (i + 1)
		rr.position = Vector2(i * 320, 0)
		rr.size = Vector2(320, 184)
		rooms.add_child(rr)
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	var found = null
	for ch in lvl.get_children():
		var sc = ch.get_script()
		if sc and String(sc.resource_path).ends_with("room_camera.gd"):
			found = ch
			break
	print("MANUAL_ROOMS camera_node=", found != null)
	if found:
		print("MANUAL_ROOMS rects_count=", (found.get("_rects") as Array).size(), " rects=", found.get("_rects"))
	get_tree().quit()
