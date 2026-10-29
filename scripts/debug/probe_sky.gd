extends Node

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/level.tscn")
	var lvl: Node = ps.instantiate()
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	var pbg: Node = lvl.get_node_or_null("ParallaxBackground")
	var layers: Array = []
	if pbg:
		for ch in pbg.get_children():
			layers.append(ch.name)
	print("SKY has_pbg=", pbg != null, " layer_count=", layers.size(), " layers=", layers)
	get_tree().quit()
