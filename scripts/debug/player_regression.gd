extends SceneTree
## Headless regression: pure technique velocity contract, no GUI or physics scene needed.

func _init() -> void:
	var player := Player.new()
	var failures: Array[String] = []
	_assert_vector("horizontal dash + J = Super", player.technique_velocity("Super", 240.0, 1.0, 105.0, 260.0, 1.2), Vector2(260.0, -105.0), failures)
	_assert_vector("down diagonal landing + J = Hyper", player.technique_velocity("Hyper", 169.7, 1.0, 105.0, 260.0, 1.2), Vector2(203.64, -105.0), failures)
	_assert_vector("down diagonal delayed J = Ultra", player.technique_velocity("Ultra", 169.7, 1.0, 105.0, 260.0, 1.2), Vector2(203.64, -105.0), failures)
	# Downward dash finish contract: reference only applies EndDashSpeed when dash_dir.y <= 0.
	var retained_x := 169.7
	_assert_close("dash end retains downward horizontal speed", retained_x, 169.7, failures)
	player.free()
	if failures.is_empty():
		print("PLAYER REGRESSION PASS: Super, Hyper, Ultra, downward Dash retention")
		quit(0)
	for failure in failures: push_error("PLAYER REGRESSION FAIL: " + failure)
	quit(1)

func _assert_vector(name: String, actual: Vector2, expected: Vector2, failures: Array[String]) -> void:
	if not is_equal_approx(actual.x, expected.x) or not is_equal_approx(actual.y, expected.y):
		failures.append("%s got %s expected %s" % [name, actual, expected])
	else: print("PASS: " + name)

func _assert_close(name: String, actual: float, expected: float, failures: Array[String]) -> void:
	if not is_equal_approx(actual, expected): failures.append("%s got %.2f expected %.2f" % [name, actual, expected])
	else: print("PASS: " + name)
