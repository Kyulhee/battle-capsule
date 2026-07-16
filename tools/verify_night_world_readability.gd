extends SceneTree


func _init():
	var readability_script = load("res://src/environment/NightWorldReadability.gd")
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.background_color = Color(0.12, 0.14, 0.18)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.1
	world_environment.environment = environment
	var moon := DirectionalLight3D.new()
	moon.light_color = Color.WHITE
	moon.light_energy = 0.2

	var readability = readability_script.new()
	readability.attach(world_environment, moon)
	readability.configure_for_metadata({"theme": "night_artificial_forest"})
	var state: Dictionary = readability.debug_state()
	if not bool(state.get("active", false)):
		_fail("Night world readability should activate for the night theme.")
		return
	if environment.background_mode != Environment.BG_COLOR:
		_fail("Night world readability should use a controlled dark background.")
		return
	if not is_equal_approx(float(state.get("ambient_energy", 0.0)), 0.38):
		_fail("Night world ambient energy should expose terrain silhouettes.")
		return
	if not is_equal_approx(float(state.get("moon_energy", 0.0)), 0.32):
		_fail("Night moon energy should expose cover edges.")
		return

	readability.configure_for_metadata({"theme": "default"})
	if environment.background_mode != Environment.BG_SKY:
		_fail("Non-night maps should restore their background mode.")
		return
	if not is_equal_approx(environment.ambient_light_energy, 0.1):
		_fail("Non-night maps should restore ambient energy.")
		return
	if not is_equal_approx(moon.light_energy, 0.2):
		_fail("Non-night maps should restore directional light energy.")
		return

	world_environment.free()
	moon.free()
	print("Night world readability smoke passed: ambient=0.38 moon=0.32.")
	quit(0)


func _fail(message: String):
	push_error(message)
	quit(1)
