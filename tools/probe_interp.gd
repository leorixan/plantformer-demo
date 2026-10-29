extends SceneTree

func _initialize() -> void:
	print("PROBE interp_setting=", ProjectSettings.get_setting("physics/common/physics_interpolation", "MISSING"))
	print("PROBE engine_has=", Engine.has_method("get_physics_interpolation_fraction"))
	print("PROBE scene_has=", ClassDB.class_has_method("Node", "reset_physics_interpolation"))
	quit()
