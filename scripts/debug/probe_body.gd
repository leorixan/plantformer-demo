extends Node

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/graybox_template.tscn")
	var lvl: Node = ps.instantiate()
	add_child(lvl)
	await get_tree().process_frame
	var p: Node2D = lvl.get_node("Player")
	var body: ColorRect = p.get_node("Visuals/Body")
	print("TEST_BODY dash_count=", p.get("dash_count"), " color=", body.color, " ui=", (p.get_node("UI") as Node2D).visible)
	p.set("dash_count", 0)
	p.call("_update_indicators")
	print("TEST_BODY after set0 color=", body.color)
	p.set("dash_count", 1)
	p.call("_update_indicators")
	print("TEST_BODY after set1 color=", body.color)
	get_tree().quit()
