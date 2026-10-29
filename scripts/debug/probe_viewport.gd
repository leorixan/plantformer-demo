extends Node

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/graybox_template.tscn")
	var lvl: Node = ps.instantiate()
	add_child(lvl)
	await get_tree().process_frame
	var cam: Camera2D = lvl.get_node("Player/Camera2D")
	var rc: Node = null
	for ch in lvl.get_children():
		var sc = ch.get_script()
		if sc and String(sc.resource_path).ends_with("room_camera.gd"):
			rc = ch
	print("PROBE viewport=", get_viewport().get_visible_rect().size, " cam_zoom=", cam.zoom,
		" room_view=", rc.get("_view") if rc else "n/a")
	get_tree().quit()
