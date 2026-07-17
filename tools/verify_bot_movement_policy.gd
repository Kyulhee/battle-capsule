extends SceneTree


const POLICY := preload("res://src/entities/bot/BotMovementPolicy.gd")


func _init() -> void:
	var desired := Vector3(0.0, 0.0, -1.0)
	if POLICY.separated_direction(desired, []) != desired:
		_fail("Movement without local neighbors must remain unchanged.")
		return

	var pushed := POLICY.separated_direction(desired, [Vector3(1.0, 0.0, 0.0)])
	if pushed.x <= 0.0 or pushed.z >= 0.0:
		_fail("A close neighbor must steer movement away without reversing its goal.")
		return
	if pushed.length() > 1.0001:
		_fail("Local separation must not exceed full movement input.")
		return

	var far_neighbor := Vector3(POLICY.LOCAL_SEPARATION_RADIUS + 0.1, 0.0, 0.0)
	if POLICY.separated_direction(desired, [far_neighbor]) != desired:
		_fail("A neighbor outside the local radius must not affect movement.")
		return

	var balanced := POLICY.separated_direction(
		desired,
		[Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0)]
	)
	if not balanced.is_equal_approx(desired):
		_fail("Balanced neighbors must not introduce an arbitrary drift.")
		return

	var stationary_push := POLICY.separated_direction(Vector3.ZERO, [Vector3(1.0, 0.0, 0.0)])
	if stationary_push.x <= 0.0:
		_fail("A stationary combatant must still release a close overlap.")
		return

	print("Bot movement policy smoke passed: local separation.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
