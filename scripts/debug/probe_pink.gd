extends Node

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/level.tscn")
	var lvl: Node = ps.instantiate()
	add_child(lvl)
	await get_tree().process_frame
	var terr: TileMapLayer = lvl.get_node("Terrain")
	print("PROBE terrain_ts=", terr.tile_set.resource_path if terr.tile_set else "none")
	print("PROBE hidden_parts=", lvl.get("_dying") != null)
	get_tree().quit()
