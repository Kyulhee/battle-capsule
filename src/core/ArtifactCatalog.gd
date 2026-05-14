class_name ArtifactCatalog
extends RefCounted

const ZONE_BATTERY_REGEN_BY_DIFFICULTY := [10.0, 10.0, 5.0, 2.0]

static func starting_artifacts(difficulty_index: int = 1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for artifact in _base_starting_artifacts():
		result.append(prepare_for_difficulty(artifact, difficulty_index))
	return result

static func prepare_for_difficulty(artifact: Dictionary, difficulty_index: int) -> Dictionary:
	if artifact.is_empty():
		return artifact

	var prepared = artifact.duplicate(true)
	if prepared.get("id", "") == "zone_battery":
		var mods = prepared.get("mods", {}).duplicate(true)
		mods["zone_battery_regen"] = _zone_battery_regen_for_difficulty(difficulty_index)
		prepared["mods"] = mods
	return _with_description(prepared)

static func _base_starting_artifacts() -> Array[Dictionary]:
	return [
		{
			"id": "red_trigger",
			"label": "Red Trigger",
			"color": Color(1.0, 0.25, 0.25),
			"mods": {
				"red_trigger": true,
				"spread_all_shots": true,
				"shotgun_damage_mult": 1.2,
				"non_shotgun_damage_mult": 0.5,
				"non_shotgun_spread": 4.0,
				"melee_damage_mult": 0.5,
			},
		},
		{
			"id": "armor_sponge",
			"label": "Armor Sponge",
			"color": Color(0.35, 0.60, 1.0),
			"mods": {
				"max_shield_mult": 2.5,
				"heal_to_shield": true,
				"heal_to_shield_common": 10.0,
				"heal_to_shield_advanced": 20.0,
				"move_speed_mult": 0.75,
			},
		},
		{
			"id": "silent_core",
			"label": "Silent Core",
			"color": Color(0.40, 0.95, 0.55),
			"mods": {"footstep_radius_mult": 0.0, "max_health_mult": 0.5, "max_shield_mult": 0.5},
		},
		{
			"id": "zone_battery",
			"label": "Zone Battery",
			"color": Color(0.20, 0.85, 1.0),
			"mods": {
				"heal_mult": 0.0,
				"shield_recv_mult": 0.0,
				"zone_battery": true,
				"zone_battery_regen": 10.0,
				"zone_battery_range": 8.0,
			},
		},
	]

static func _with_description(artifact: Dictionary) -> Dictionary:
	var mods = artifact.get("mods", {})
	match artifact.get("id", ""):
		"red_trigger":
			artifact["line1"] = "샷건 공격력 %s  ·  근접 특화" % _fmt_mult(mods.get("shotgun_damage_mult", 1.0))
			artifact["line2"] = "샷건 외 공격력 %s\n샷건 외 탄퍼짐 ±%s (거의 난사)" % [
				_fmt_mult(mods.get("non_shotgun_damage_mult", 1.0)),
				_fmt_num(mods.get("non_shotgun_spread", 0.0)),
			]
		"armor_sponge":
			artifact["line1"] = "방어구 최대량 %s  ·  힐→방어막" % _fmt_mult(mods.get("max_shield_mult", 1.0))
			artifact["line2"] = "이동 속도 %s  ·  힐 사용 시 방어막 전환\n(붕대 +%s 방어막 / 구급상자 +%s 방어막)" % [
				_fmt_percent_delta(mods.get("move_speed_mult", 1.0)),
				_fmt_num(mods.get("heal_to_shield_common", 0.0)),
				_fmt_num(mods.get("heal_to_shield_advanced", 0.0)),
			]
		"silent_core":
			artifact["line1"] = "달리기 소음 탐지 차단"
			artifact["line2"] = "%s\n(들키면 즉시 위험)" % _fmt_health_shield_delta(mods)
		"zone_battery":
			artifact["line1"] = "자기장 내벽 %s 근방\n→ 방어막 +%s/초 자동 충전" % [
				_fmt_meter(mods.get("zone_battery_range", 0.0)),
				_fmt_num(mods.get("zone_battery_regen", 0.0)),
			]
			artifact["line2"] = "힐·방어구 사용 불가"
	return artifact

static func _zone_battery_regen_for_difficulty(difficulty_index: int) -> float:
	var idx = clampi(difficulty_index, 0, ZONE_BATTERY_REGEN_BY_DIFFICULTY.size() - 1)
	return ZONE_BATTERY_REGEN_BY_DIFFICULTY[idx]

static func _fmt_mult(value: Variant) -> String:
	return "×%s" % _fmt_num(float(value))

static func _fmt_meter(value: Variant) -> String:
	return "%sm" % _fmt_num(float(value))

static func _fmt_percent_delta(mult: Variant) -> String:
	var delta = (float(mult) - 1.0) * 100.0
	if absf(delta) < 0.01:
		return "±0%"
	var sign = "+" if delta > 0.0 else ""
	return "%s%s%%" % [sign, _fmt_num(delta)]

static func _fmt_health_shield_delta(mods: Dictionary) -> String:
	var hp_delta = _fmt_percent_delta(mods.get("max_health_mult", 1.0))
	var shield_delta = _fmt_percent_delta(mods.get("max_shield_mult", 1.0))
	if hp_delta == shield_delta:
		return "최대 HP / 방어막 %s" % hp_delta
	return "최대 HP %s / 방어막 %s" % [hp_delta, shield_delta]

static func _fmt_num(value: Variant) -> String:
	var n = float(value)
	var rounded = roundf(n)
	if absf(n - rounded) < 0.001:
		return str(int(rounded))
	return "%.1f" % n
