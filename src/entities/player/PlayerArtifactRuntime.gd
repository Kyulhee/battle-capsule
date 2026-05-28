class_name PlayerArtifactRuntime
extends RefCounted

var _artifact_id: String = ""
var _artifact_label: String = ""
var _mods: Dictionary = {}
var _emergency_shell_used: bool = false
var _ghost_grass_timer: float = 0.0
var _ghost_grass_cooldown: float = 0.0


func configure(artifact: Dictionary) -> void:
	_artifact_id = String(artifact.get("id", ""))
	_artifact_label = String(artifact.get("label", ""))
	_mods = artifact.get("mods", {}).duplicate(true)
	_emergency_shell_used = false
	_ghost_grass_timer = 0.0
	_ghost_grass_cooldown = 0.0


func tick(delta: float) -> void:
	if _ghost_grass_timer > 0.0:
		_ghost_grass_timer = maxf(0.0, _ghost_grass_timer - delta)
	if _ghost_grass_cooldown > 0.0:
		_ghost_grass_cooldown = maxf(0.0, _ghost_grass_cooldown - delta)


func evaluate_after_damage(
	current_health: float,
	max_health: float,
	current_shield: float,
	max_shield: float
) -> Dictionary:
	if not bool(_mods.get("emergency_shell", false)):
		return {}
	if _emergency_shell_used:
		return {}
	if max_health <= 0.0 or current_health <= 0.0:
		return {}

	var threshold_ratio = float(_mods.get("emergency_shell_hp_ratio", 0.3))
	if current_health / max_health > threshold_ratio:
		return {}

	var shield_amount = minf(
		float(_mods.get("emergency_shell_shield", 0.0)),
		maxf(0.0, max_shield - current_shield)
	)
	if shield_amount <= 0.0:
		return {}

	_emergency_shell_used = true
	return {
		"artifact_id": _artifact_id,
		"label": _artifact_label,
		"event": "emergency_shell_triggered",
		"shield": shield_amount,
		"ammo_purge": bool(_mods.get("emergency_shell_ammo_purge", false)),
	}


func on_bush_changed(was_in_bush: bool, is_now_in_bush: bool) -> Dictionary:
	if not bool(_mods.get("ghost_grass", false)):
		return {}
	if is_now_in_bush:
		_ghost_grass_timer = 0.0
		return {}
	if not was_in_bush:
		return {}
	if _ghost_grass_cooldown > 0.0:
		return {}

	var duration = maxf(0.0, float(_mods.get("ghost_grass_duration", 0.0)))
	if duration <= 0.0:
		return {}

	_ghost_grass_timer = duration
	_ghost_grass_cooldown = maxf(duration, float(_mods.get("ghost_grass_cooldown", duration)))
	return {
		"artifact_id": _artifact_id,
		"label": _artifact_label,
		"event": "ghost_grass_started",
		"duration": duration,
	}


func is_ghost_grass_active() -> bool:
	return bool(_mods.get("ghost_grass", false)) and _ghost_grass_timer > 0.0


func cancel_ghost_grass() -> void:
	_ghost_grass_timer = 0.0


func get_ghost_grass_cooldown_remaining() -> float:
	return _ghost_grass_cooldown


func get_ghost_grass_stealth_modifier() -> float:
	if not is_ghost_grass_active():
		return 1.0
	return maxf(0.0, float(_mods.get("ghost_grass_stealth_mult", 1.0)))


func get_ghost_grass_incoming_damage_mult() -> float:
	if not is_ghost_grass_active():
		return 1.0
	return maxf(0.0, float(_mods.get("ghost_grass_incoming_damage_mult", 1.0)))


func get_footstep_radius_mult(base_mult: float) -> float:
	if not is_ghost_grass_active():
		return base_mult
	return base_mult * maxf(0.0, float(_mods.get("ghost_grass_footstep_mult", 1.0)))
