class_name PlayerNightReadability
extends RefCounted


const NIGHT_THEME := "night_artificial_forest"
const NIGHT_SPOT_COLOR := Color(1.0, 0.92, 0.74)
const NIGHT_PROXIMITY_COLOR := Color(0.42, 0.62, 0.95)

var _host: Node3D = null
var _spot: SpotLight3D = null
var _proximity: OmniLight3D = null
var _defaults: Dictionary = {}
var _active := false


func attach(host: Node3D, spot: SpotLight3D, proximity: OmniLight3D) -> void:
	_host = host
	_spot = spot
	_proximity = proximity
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
	var spot_forward := Vector3.ZERO
	var host_forward := Vector3.ZERO
	var forward_dot := 0.0
	if _spot != null and _host != null:
		var spot_basis := _spot.global_transform.basis if _spot.is_inside_tree() else _spot.transform.basis
		var host_basis := _host.global_transform.basis if _host.is_inside_tree() else _host.transform.basis
		spot_forward = -spot_basis.z.normalized()
		host_forward = -host_basis.z.normalized()
		forward_dot = spot_forward.dot(host_forward)
	return {
		"active": _active,
		"spot_found": _spot != null,
		"proximity_found": _proximity != null,
		"spot_visible": _spot != null and _spot.visible,
		"proximity_visible": _proximity != null and _proximity.visible,
		"spot_energy": _spot.light_energy if _spot != null else 0.0,
		"spot_range": _spot.spot_range if _spot != null else 0.0,
		"spot_angle": _spot.spot_angle if _spot != null else 0.0,
		"proximity_energy": _proximity.light_energy if _proximity != null else 0.0,
		"proximity_range": _proximity.omni_range if _proximity != null else 0.0,
		"forward_dot": forward_dot,
	}


func _capture_defaults() -> void:
	_defaults.clear()
	if _spot != null:
		_defaults["spot"] = {
			"visible": _spot.visible,
			"position": _spot.position,
			"light_color": _spot.light_color,
			"light_energy": _spot.light_energy,
			"shadow_enabled": _spot.shadow_enabled,
			"spot_range": _spot.spot_range,
			"spot_angle": _spot.spot_angle,
		}
	if _proximity != null:
		_defaults["proximity"] = {
			"visible": _proximity.visible,
			"position": _proximity.position,
			"light_color": _proximity.light_color,
			"light_energy": _proximity.light_energy,
			"omni_range": _proximity.omni_range,
		}


func _apply_night_profile() -> void:
	if _spot != null:
		_spot.visible = true
		_spot.position = Vector3(0.0, 1.15, -0.25)
		_spot.light_color = NIGHT_SPOT_COLOR
		_spot.light_energy = 7.2
		_spot.shadow_enabled = true
		_spot.spot_range = 32.0
		_spot.spot_angle = 48.0
	if _proximity != null:
		_proximity.visible = true
		_proximity.position = Vector3(0.0, 0.9, 0.0)
		_proximity.light_color = NIGHT_PROXIMITY_COLOR
		_proximity.light_energy = 0.55
		_proximity.omni_range = 3.2


func _restore_defaults() -> void:
	if _spot != null and _defaults.has("spot"):
		var spot_defaults: Dictionary = _defaults["spot"]
		_spot.visible = bool(spot_defaults.get("visible", true))
		_spot.position = spot_defaults.get("position", _spot.position)
		_spot.light_color = spot_defaults.get("light_color", _spot.light_color)
		_spot.light_energy = float(spot_defaults.get("light_energy", _spot.light_energy))
		_spot.shadow_enabled = bool(spot_defaults.get("shadow_enabled", _spot.shadow_enabled))
		_spot.spot_range = float(spot_defaults.get("spot_range", _spot.spot_range))
		_spot.spot_angle = float(spot_defaults.get("spot_angle", _spot.spot_angle))
	if _proximity != null and _defaults.has("proximity"):
		var proximity_defaults: Dictionary = _defaults["proximity"]
		_proximity.visible = bool(proximity_defaults.get("visible", true))
		_proximity.position = proximity_defaults.get("position", _proximity.position)
		_proximity.light_color = proximity_defaults.get("light_color", _proximity.light_color)
		_proximity.light_energy = float(proximity_defaults.get("light_energy", _proximity.light_energy))
		_proximity.omni_range = float(proximity_defaults.get("omni_range", _proximity.omni_range))


func _is_night_candidate(metadata: Dictionary) -> bool:
	var theme := String(metadata.get("theme", "")).strip_edges()
	if theme == NIGHT_THEME:
		return true
	var id := String(metadata.get("id", "")).to_lower()
	var layout := String(metadata.get("layout", "")).to_lower()
	return id.contains("night") or layout.contains("night")
