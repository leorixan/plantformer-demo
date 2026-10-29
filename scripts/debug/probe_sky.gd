extends Node

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/level.tscn")
	var lvl: Node = ps.instantiate()
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	var sky: Node = lvl.get_node_or_null("SkyBackground")
	var pbg: Node = sky.get_node_or_null("ParallaxBackground") if sky else null
	var layers: Array = []
	if pbg:
		for ch in pbg.get_children():
			layers.append("%s(scale=%s)" % [ch.name, ch.motion_scale])
	print("SKY has_node=", sky != null, " pbg=", pbg != null, " layer_count=", layers.size())
	print("SKY layers=", layers)
	get_tree().quit()
