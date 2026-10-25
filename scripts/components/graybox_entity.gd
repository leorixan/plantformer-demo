@tool
class_name GrayboxEntity
extends Node2D

const COLORS := {
	"hazard": Color(0.78, 0.24, 0.28),
	"crystal": Color(0.28, 0.78, 0.82),
	"spring": Color(0.35, 0.75, 0.35),
	"breakable": Color(0.67, 0.51, 0.35),
	"jelly": Color(0.59, 0.39, 0.86),
	"checkpoint": Color(0.95, 0.8, 0.25),
}

@export_enum("hazard", "crystal", "spring", "breakable", "jelly", "checkpoint") var kind := "hazard"
@export var size_px := Vector2(8, 8)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var c: Color = COLORS.get(kind, Color.WHITE)
	var rect := Rect2(-size_px * 0.5, size_px)
	draw_rect(rect, Color(c.r, c.g, c.b, 0.35), true)
	draw_rect(rect, c, false, 1.0)
