class_name PlayerArtifactRuntime
extends RefCounted

var _artifact_id: String = ""
var _artifact_label: String = ""
var _mods: Dictionary = {}
var _emergency_shell_used: bool = false


func configure(artifact: Dictionary) -> void:
	_artifact_id = String(artifact.get("id", ""))
	_artifact_label = String(artifact.get("label", ""))
	_mods = artifact.get("mods", {}).duplicate(true)
	_emergency_shell_used = false


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
	}
