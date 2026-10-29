extends Node

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/graybox_template.tscn")
	var lvl: Node = ps.instantiate()
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node2D = lvl.get_node("Player")
	var cp: Vector2 = lvl.get("checkpoint_pos")
	player.global_position = Vector2(120, 100)
	lvl.call("respawn_player")
	var ts_after: float = Engine.time_scale
	var frozen: bool = not player.is_physics_processing()
	await get_tree().create_timer(0.6, true, false, true).timeout
	var flash_ok := true
	var fl = lvl.get_node_or_null("DeathFlashLayer/Flash")
	if fl != null and (fl as ColorRect).visible:
		flash_ok = false
	var back: bool = player.global_position.is_equal_approx(cp)
	print("TEST_DEATH ts_after_call=", ts_after, " frozen=", frozen,
		" ts_later=", Engine.time_scale, " pos_back=", back,
		" flash_hidden=", flash_ok, " physics=", player.is_physics_processing())
	get_tree().quit()
