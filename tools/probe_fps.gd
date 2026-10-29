extends SceneTree

func _initialize() -> void:
	print("PROBE max_fps=", Engine.max_fps)
	print("PROBE physics_ticks=", Engine.physics_ticks_per_second)
	quit()
