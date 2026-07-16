class_name NightWorldReadability
extends RefCounted


const NIGHT_THEME := "night_artificial_forest"
const NIGHT_BACKGROUND_COLOR := Color(0.008, 0.012, 0.022)
const NIGHT_AMBIENT_COLOR := Color(0.32, 0.42, 0.60)
const NIGHT_AMBIENT_ENERGY := 0.38
const NIGHT_MOON_COLOR := Color(0.58, 0.70, 0.92)
const NIGHT_MOON_ENERGY := 0.32

var _world_environment: WorldEnvironment = null
var _moon: DirectionalLight3D = null
var _defaults: Dictionary = {}
var _active := false


func attach(world_environment: WorldEnvironment, moon: DirectionalLight3D) -> void:
	_world_environment = world_environment
	_moon = moon
	_capture_defaults()


func configure_for_metadata(metadata: Dictionary) -> void:
	set_active(_is_night_candidate(metadata))


func set_active(active: bool) -> void:
	_active = active
	if active:
		_apply_night_profile()
	else:
		_restore_defaults()


func is_active() -> bool:
	return _active


func debug_state() -> Dictionary:
	var environment := _environment()
	return {
		"active": _active,
		"environment_found": environment != null,
		"moon_found": _moon != null,
		"background_color": environment.background_color if environment != null else Color.BLACK,
		"ambient_color": environment.ambient_light_color if environment != null else Color.BLACK,
		"ambient_energy": environment.ambient_light_energy if environment != null else 0.0,
		"moon_color": _moon.light_color if _moon != null else Color.BLACK,
		"moon_energy": _moon.light_energy if _moon != null else 0.0,
	}


func _capture_defaults() -> void:
	_defaults.clear()
	var environment := _environment()
	if environment != null:
		_defaults["environment"] = {
			"background_mode": environment.background_mode,
			"background_color": environment.background_color,
			"ambient_light_source": environment.ambient_light_source,
			"ambient_light_color": environment.ambient_light_color,
			"ambient_light_energy": environment.ambient_light_energy,
		}
	if _moon != null:
		_defaults["moon"] = {
			"light_color": _moon.light_color,
			"light_energy": _moon.light_energy,
		}


func _apply_night_profile() -> void:
	var environment := _environment()
	if environment != null:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = NIGHT_BACKGROUND_COLOR
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = NIGHT_AMBIENT_COLOR
		environment.ambient_light_energy = NIGHT_AMBIENT_ENERGY
	if _moon != null:
		_moon.light_color = NIGHT_MOON_COLOR
		_moon.light_energy = NIGHT_MOON_ENERGY


func _restore_defaults() -> void:
	var environment := _environment()
	if environment != null and _defaults.has("environment"):
		var environment_defaults: Dictionary = _defaults["environment"]
		environment.background_mode = int(environment_defaults.get("background_mode", environment.background_mode))
		environment.background_color = environment_defaults.get("background_color", environment.background_color)
		environment.ambient_light_source = int(environment_defaults.get("ambient_light_source", environment.ambient_light_source))
		environment.ambient_light_color = environment_defaults.get("ambient_light_color", environment.ambient_light_color)
		environment.ambient_light_energy = float(environment_defaults.get("ambient_light_energy", environment.ambient_light_energy))
	if _moon != null and _defaults.has("moon"):
		var moon_defaults: Dictionary = _defaults["moon"]
		_moon.light_color = moon_defaults.get("light_color", _moon.light_color)
		_moon.light_energy = float(moon_defaults.get("light_energy", _moon.light_energy))


func _environment() -> Environment:
	if _world_environment == null:
		return null
	return _world_environment.environment


func _is_night_candidate(metadata: Dictionary) -> bool:
	var theme := String(metadata.get("theme", "")).strip_edges()
	if theme == NIGHT_THEME:
		return true
	var id := String(metadata.get("id", "")).to_lower()
	var layout := String(metadata.get("layout", "")).to_lower()
	return id.contains("night") or layout.contains("night")
