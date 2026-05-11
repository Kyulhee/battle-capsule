class_name ArtifactCatalog
extends RefCounted

static func starting_artifacts() -> Array[Dictionary]:
	return [
		{
			"id": "red_trigger",
			"label": "Red Trigger",
			"color": Color(1.0, 0.25, 0.25),
			"line1": "샷건 공격력 ×1.2  ·  근접 특화",
			"line2": "샷건 외 공격력 ×0.5\n샷건 외 탄퍼짐 극단적 (거의 난사)",
			"mods": {"red_trigger": true, "spread_all_shots": true},
		},
		{
			"id": "armor_sponge",
			"label": "Armor Sponge",
			"color": Color(0.35, 0.60, 1.0),
			"line1": "방어구 최대량 ×2.5  ·  힐→방어막",
			"line2": "이동 속도 -25%  ·  힐 사용 시 방어막 전환\n(붕대 +10 방어막 / 구급상자 +20 방어막)",
			"mods": {"max_shield_mult": 2.5, "heal_to_shield": true, "move_speed_mult": 0.75},
		},
		{
			"id": "silent_core",
			"label": "Silent Core",
			"color": Color(0.40, 0.95, 0.55),
			"line1": "달리기 소음 탐지 차단",
			"line2": "최대 HP / 방어막 -50%\n(들키면 즉시 위험)",
			"mods": {"footstep_radius_mult": 0.0, "max_health_mult": 0.5, "max_shield_mult": 0.5},
		},
		{
			"id": "zone_battery",
			"label": "Zone Battery",
			"color": Color(0.20, 0.85, 1.0),
			"line1": "자기장 내벽 8m 근방\n→ 방어막 +10/초 자동 충전",
			"line2": "힐·방어구 사용 불가",
			"mods": {
				"heal_mult": 0.0,
				"shield_recv_mult": 0.0,
				"zone_battery": true,
				"zone_battery_regen": 10.0,
				"zone_battery_range": 8.0,
			},
		},
	]
