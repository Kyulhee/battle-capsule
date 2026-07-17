extends SceneTree


const POLICY := preload("res://src/entities/bot/BotMovementPolicy.gd")


func _init() -> void:
	if not POLICY.should_separate(true, true, false):
		_fail("A player-target ATTACK must apply local separation.")
		return
	if not POLICY.should_separate(true, false, true):
		_fail("A player-target combat CHASE must apply local separation.")
		return
	if POLICY.should_separate(false, true, false):
		_fail("Bot-only combat must preserve its existing movement contract.")
		return
	if POLICY.should_separate(true, false, false):
		_fail("Player-target movement outside combat states must not separate.")
		return
	if not POLICY.should_refresh_navigation_target(
		false,
		Vector3.ZERO,
		Vector3(10.0, 0.0, 0.0),
		true,
		10.0,
		1.5
	):
		_fail("A navigation agent without a target must request its first path.")
		return
	if POLICY.should_refresh_navigation_target(
		true,
		Vector3(10.0, 0.0, 0.0),
		Vector3(10.2, 0.0, 0.0),
		false,
		5.0,
		1.5
	):
		_fail("Small target movement must reuse the active navigation path.")
		return
	if not POLICY.should_refresh_navigation_target(
		true,
		Vector3(10.0, 0.0, 0.0),
		Vector3(10.4, 0.0, 0.0),
		false,
		5.0,
		1.5
	):
		_fail("Material target movement must request a fresh navigation path.")
		return
	if not POLICY.should_refresh_navigation_target(
		true,
		Vector3(10.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 0.0),
		true,
		3.0,
		1.5
	):
		_fail("A finished path must restart when the actor is pushed away.")
		return
	if POLICY.should_refresh_navigation_target(
		true,
		Vector3(10.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 0.0),
		true,
		1.0,
		1.5
	):
		_fail("A finished path inside target tolerance must stay complete.")
		return

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
