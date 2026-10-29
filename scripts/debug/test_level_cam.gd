extends Node

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/level.tscn")
	var lvl: Node = ps.instantiate()
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node2D = lvl.get_node("Player")
	var cam: Camera2D = lvl.get_node("Player/Camera2D")
	var rc: Node = null
	for ch in lvl.get_children():
		var sc = ch.get_script()
		if sc and String(sc.resource_path).ends_with("room_camera.gd"):
			rc = ch
	print("TEST rects=", rc.get("_rects") if rc else "n/a", " view=", rc.get("_view") if rc else "n/a")
	Input.action_press("move_right")
	var cxs: Array = []
	var cys: Array = []
	var pxs: Array = []
	var teleports := 0
	var lastp: Vector2 = player.global_position
	for i in 240:
		await get_tree().physics_frame
		cxs.append(cam.global_position.x)
		cys.append(cam.global_position.y)
		pxs.append(player.global_position.x)
		if player.global_position.distance_to(lastp) > 8.0:
			teleports += 1
		lastp = player.global_position
	Input.action_release("move_right")
	var flips := 0
	var ymin := 1e9
	var ymax := -1e9
	for i in range(1, cxs.size()):
		var d: float = cxs[i] - cxs[i-1]
		var d0: float = (cxs[i-1] - cxs[i-2]) if i > 1 else 0.0
		if (d > 0.001 and d0 < -0.001) or (d < -0.001 and d0 > 0.001):
			flips += 1
		ymin = minf(ymin, cys[i])
		ymax = maxf(ymax, cys[i])
	print("TEST camx_first=", cxs[0], " camx_last=", cxs[cxs.size()-1], " flips=", flips,
		" y_range=", ymax-ymin, " teleports=", teleports, " player_x=", player.global_position.x)
	var s := ""
	for i in range(0, mini(30, cxs.size())):
		s += str(snappedf(cxs[i] - cxs[0], 0.01)) + " "
	print("TEST camx_dx=", s)
	get_tree().quit()
