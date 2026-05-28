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
			"visual_id": "red_trigger",
			"mods": {
				"red_trigger": true,
				"spread_all_shots": true,
				"shotgun_damage_mult": 1.2,
				"non_shotgun_damage_mult": 0.5,
				"non_shotgun_spread": 4.0,
				"melee_damage_mult": 0.5,
				"red_trigger_reveal_duration": 3.0,
			},
		},
		{
			"id": "armor_sponge",
			"label": "Armor Sponge",
			"color": Color(0.35, 0.60, 1.0),
			"visual_id": "armor_sponge",
			"mods": {
				"max_shield_mult": 2.5,
				"heal_to_shield": true,
				"heal_to_shield_ratio": 0.5,
				"heal_to_shield_cap": 50.0,
				"heal_to_shield_common_base": 30.0,
				"heal_to_shield_advanced_base": 60.0,
				"armor_sponge_move_speed_min": 0.75,
			},
		},
		{
			"id": "silent_core",
			"label": "Silent Core",
			"color": Color(0.40, 0.95, 0.55),
			"visual_id": "silent_core",
			"mods": {
				"footstep_radius_mult": 0.0,
				"silent_core_first_shot_miss": true,
			},
		},
		{
			"id": "ghost_grass",
			"label": "Ghost Grass",
			"color": Color(0.55, 1.0, 0.65),
			"visual_id": "ghost_grass",
			"mods": {
				"ghost_grass": true,
				"ghost_grass_duration": 1.25,
				"ghost_grass_cooldown": 5.0,
				"ghost_grass_stealth_mult": 0.45,
				"ghost_grass_footstep_mult": 0.6,
				"ghost_grass_incoming_damage_mult": 1.5,
			},
		},
		{
			"id": "zone_battery",
			"label": "Zone Battery",
			"color": Color(0.20, 0.85, 1.0),
			"visual_id": "zone_battery",
			"mods": {
				"heal_mult": 0.0,
				"shield_recv_mult": 0.0,
				"zone_battery": true,
				"zone_battery_regen": 10.0,
				"zone_battery_range": 8.0,
			},
		},
		{
			"id": "emergency_shell",
			"label": "Escape Capsule",
			"color": Color(1.0, 0.72, 0.28),
			"visual_id": "emergency_shell",
			"mods": {
				"emergency_shell": true,
				"emergency_shell_hp_ratio": 0.3,
				"emergency_shell_shield": 35.0,
				"emergency_shell_ammo_purge": true,
			},
		},
	]

static func _with_description(artifact: Dictionary) -> Dictionary:
	var mods = artifact.get("mods", {})
	match artifact.get("id", ""):
		"red_trigger":
			artifact["summary"] = "샷건 강화, 노출 증가"
			artifact["line1"] = "샷건 공격력 %s  ·  근접 피해 %s" % [
				_fmt_mult(mods.get("shotgun_damage_mult", 1.0)),
				_fmt_mult(mods.get("melee_damage_mult", 1.0)),
			]
			artifact["line2"] = "발사 노출 %s초  ·  샷건 외 공격력 %s\n샷건 외 탄퍼짐 ±%s (거의 난사)" % [
				_fmt_num(mods.get("red_trigger_reveal_duration", 2.0)),
				_fmt_mult(mods.get("non_shotgun_damage_mult", 1.0)),
				_fmt_num(mods.get("non_shotgun_spread", 0.0)),
			]
		"armor_sponge":
			artifact["summary"] = "쉴드 탱킹, 무거워짐"
			artifact["line1"] = "방어구 최대량 %s  ·  힐→방어막" % _fmt_mult(mods.get("max_shield_mult", 1.0))
			artifact["line2"] = "방어막 비례 이동 속도 %s까지\n힐 %s 전환, 방어막 최대 %s" % [
				_fmt_percent_delta(mods.get("armor_sponge_move_speed_min", 1.0)),
				_fmt_percent(mods.get("heal_to_shield_ratio", 0.0)),
				_fmt_num(mods.get("heal_to_shield_cap", 0.0)),
			]
		"silent_core":
			artifact["summary"] = "무소음 이동, 첫 총격 불발"
			artifact["line1"] = "달리기 소음 탐지 차단"
			artifact["line2"] = "은신 중 첫 비근접 사격은 빗나감\n칼은 즉시 공격 가능"
		"ghost_grass":
			artifact["summary"] = "부쉬 이탈 은신, 피격 취약"
			artifact["line1"] = "부쉬 이탈 후 %s초 은신\n재사용 대기 %s초" % [
				_fmt_num(mods.get("ghost_grass_duration", 0.0)),
				_fmt_num(mods.get("ghost_grass_cooldown", 0.0)),
			]
			artifact["line2"] = "은신 중 총탄 피해 %s, 즉시 해제\n발소리 반경 %s" % [
				_fmt_mult(mods.get("ghost_grass_incoming_damage_mult", 1.0)),
				_fmt_percent_delta(mods.get("ghost_grass_footstep_mult", 1.0)),
			]
		"zone_battery":
			artifact["summary"] = "존 경계 충전, 힐 봉인"
			artifact["line1"] = "자기장 내벽 %s 근방\n→ 방어막 +%s/초 자동 충전" % [
				_fmt_meter(mods.get("zone_battery_range", 0.0)),
				_fmt_num(mods.get("zone_battery_regen", 0.0)),
			]
			artifact["line2"] = "힐·방어구 사용 불가"
		"emergency_shell":
			artifact["summary"] = "위기 쉴드, 탄약 소실"
			artifact["line1"] = "HP %s 이하 진입 시\n방어막 +%s 1회 생성" % [
				_fmt_percent(mods.get("emergency_shell_hp_ratio", 0.0)),
				_fmt_num(mods.get("emergency_shell_shield", 0.0)),
			]
			artifact["line2"] = "발동 후 모든 총알 소실\n치명타 방지는 아님"
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

static func _fmt_percent(ratio: Variant) -> String:
	return "%s%%" % _fmt_num(float(ratio) * 100.0)

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
