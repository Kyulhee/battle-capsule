extends RefCounted

const PLAN_STRAFE := "strafe"
const PLAN_ADVANCE := "advance"
const PLAN_KITE := "kite"
const PLAN_PEEK_COVER := "peek_cover"
const PLAN_REPOSITION := "reposition"
const PLAN_HOLD_ANGLE := "hold_angle"

const ARCHETYPE_NAMES := ["AGGRESSIVE", "DEFENSIVE", "SNIPER", "OPPORTUNIST"]

const BASE_PROFILE := {
	"archetype_id": 0,
	"archetype_name": "AGGRESSIVE",
	"attack_range_mult": 1.0,
	"vision_range_mult": 1.0,
	"disengage_threshold": 2,
	"fire_rate_mult": 1.0,
	"footstep_range": 12.0,
	"loot_radius": 70.0,
	"combat_loot_threshold": 0.0,
	"combat_loot_radius": 15.0,
	"flee_hp_ratio": 0.25,
	"sniper_min_engage_range": 0.0,
	"reaction_delay": 0.0,
	"aim_spread_mult": 1.0,
	"awareness_level": 0,
	"scan_interval_max": 3.0,
	"patrol_preference": "random",
	"strategic_preference": "mixed",
	"safety": {
		"zone_escape_locked": true,
		"death_guard_locked": true,
		"no_ammo_guard_locked": true,
		"stuck_guard_locked": true,
		"los_guard_locked": true,
	},
	"combat": {
		"plan_seconds_min": 0.9,
		"plan_seconds_max": 1.8,
		"survival_cover_hp_buffer": 0.18,
		"outnumbered_visible_enemies": 2,
		"shotgun_advance_range_mult": 0.75,
		"shotgun_advance_min_hp": 0.45,
		"hold_angle_weapons": ["railgun"],
		"prefers_hold_angle": false,
		"hold_angle_kite_range_mult": 0.85,
		"low_ammo_cover_ratio": 0.35,
		"cover_probe_chance": 0.28,
		"reposition_probe_chance": 0.22,
		"advance_probe_chance": 0.0,
		"kite_probe_chance": 0.0,
		"reposition_min_hp": 0.55,
		"advance_min_hp": 0.55,
		"reposition_forward_bias": false,
		"finish_low_hp_targets": false,
		"finish_target_hp_ratio": 0.35,
	},
	"supply": {
		"telegraph_interest_dist": 0.0,
		"spawn_interest_dist": 0.0,
		"need_hp_ratio": 0.45,
		"low_ammo_ratio": 0.25,
		"need_interest_dist": 40.0,
		"bucket_mod": 4,
		"bucket_value": 0,
		"bucket_interest_dist": 28.0,
	},
	"target": {
		"distance_weight": 1.0,
		"hp_weight": 0.0,
	},
	"engagement": {
		"join_capacity": 2,
		"local_combatant_limit": 6,
	},
}

const ARCHETYPE_OVERLAYS := {
	0: {
		"archetype_name": "AGGRESSIVE",
		"attack_range_mult": 0.75,
		"disengage_threshold": 3,
		"fire_rate_mult": 0.8,
		"footstep_range": 10.0,
		"loot_radius": 70.0,
		"combat_loot_threshold": 0.0,
		"flee_hp_ratio": 0.15,
		"strategic_preference": "loot_hub",
		"combat": {
			"survival_cover_hp_buffer": 0.12,
			"outnumbered_visible_enemies": 3,
			"cover_probe_chance": 0.18,
			"reposition_probe_chance": 0.18,
			"advance_probe_chance": 0.24,
			"advance_min_hp": 0.45,
			"reposition_forward_bias": true,
		},
		"engagement": {
			"join_capacity": 3,
			"local_combatant_limit": 8,
		},
	},
	1: {
		"archetype_name": "DEFENSIVE",
		"attack_range_mult": 1.2,
		"disengage_threshold": 1,
		"fire_rate_mult": 1.0,
		"footstep_range": 15.0,
		"loot_radius": 80.0,
		"combat_loot_threshold": 0.20,
		"flee_hp_ratio": 0.35,
		"patrol_preference": "bush",
		"strategic_preference": "cover",
		"combat": {
			"cover_probe_chance": 0.42,
			"reposition_probe_chance": 0.14,
			"advance_probe_chance": 0.0,
		},
		"engagement": {
			"join_capacity": 1,
			"local_combatant_limit": 4,
		},
	},
	2: {
		"archetype_name": "SNIPER",
		"attack_range_mult": 2.0,
		"vision_range_mult": 1.6,
		"disengage_threshold": 1,
		"fire_rate_mult": 1.3,
		"footstep_range": 20.0,
		"loot_radius": 60.0,
		"combat_loot_threshold": 0.0,
		"flee_hp_ratio": 0.40,
		"sniper_min_engage_range": 14.0,
		"strategic_preference": "transit",
		"combat": {
			"prefers_hold_angle": true,
			"kite_probe_chance": 0.18,
			"reposition_probe_chance": 0.12,
		},
		"engagement": {
			"join_capacity": 1,
			"local_combatant_limit": 5,
		},
	},
	3: {
		"archetype_name": "OPPORTUNIST",
		"disengage_threshold": 2,
		"fire_rate_mult": 1.0,
		"footstep_range": 18.0,
		"loot_radius": 90.0,
		"combat_loot_threshold": 0.25,
		"flee_hp_ratio": 0.25,
		"patrol_preference": "hotspot",
		"strategic_preference": "loot_hub",
		"supply": {
			"telegraph_interest_dist": 70.0,
			"spawn_interest_dist": 80.0,
		},
		"combat": {
			"finish_low_hp_targets": true,
			"finish_target_hp_ratio": 0.40,
			"reposition_probe_chance": 0.34,
			"advance_probe_chance": 0.10,
		},
		"target": {
			"distance_weight": 0.4,
			"hp_weight": 0.6,
		},
		"engagement": {
			"join_capacity": 2,
			"local_combatant_limit": 6,
		},
	},
}

static func build_profile(archetype_id: int, difficulty_params: Dictionary = {}) -> Dictionary:
	var id = clampi(archetype_id, 0, ARCHETYPE_NAMES.size() - 1)
	var profile = BASE_PROFILE.duplicate(true)
	profile["archetype_id"] = id

	if ARCHETYPE_OVERLAYS.has(id):
		_deep_merge(profile, ARCHETYPE_OVERLAYS[id])

	_apply_difficulty_scalars(profile, difficulty_params)
	profile["difficulty_params"] = difficulty_params.duplicate(true)
	return profile

static func archetype_id(archetype_name: String) -> int:
	var normalized = archetype_name.strip_edges().to_upper()
	var idx = ARCHETYPE_NAMES.find(normalized)
	return idx if idx >= 0 else 0

static func archetype_name(archetype_id: int) -> String:
	var id = clampi(archetype_id, 0, ARCHETYPE_NAMES.size() - 1)
	return ARCHETYPE_NAMES[id]

static func _apply_difficulty_scalars(profile: Dictionary, difficulty_params: Dictionary) -> void:
	# Difficulty is a final scalar pass so archetype identity and difficulty both survive the merge.
	if difficulty_params.has("vision_mult"):
		profile["vision_range_mult"] = float(profile.get("vision_range_mult", 1.0)) * float(difficulty_params.vision_mult)
	if difficulty_params.has("reaction_delay"):
		profile["reaction_delay"] = float(difficulty_params.reaction_delay)
	if difficulty_params.has("aim_spread"):
		profile["aim_spread_mult"] = float(difficulty_params.aim_spread)
	if difficulty_params.has("loot_break_mult"):
		profile["combat_loot_threshold"] = float(profile.get("combat_loot_threshold", 0.0)) * float(difficulty_params.loot_break_mult)
	if difficulty_params.has("combat_loot_floor"):
		profile["combat_loot_threshold"] = maxf(
			float(profile.get("combat_loot_threshold", 0.0)),
			float(difficulty_params.combat_loot_floor)
		)
	if difficulty_params.has("combat_loot_radius"):
		profile["combat_loot_radius"] = float(difficulty_params.combat_loot_radius)
	if difficulty_params.has("idle_scan_interval_max"):
		profile["scan_interval_max"] = float(difficulty_params.idle_scan_interval_max)
	if difficulty_params.has("awareness_level"):
		profile["awareness_level"] = int(difficulty_params.awareness_level)

static func choose_combat_plan(context: Dictionary, profile: Dictionary) -> String:
	var combat = profile.get("combat", {})
	var has_cover = bool(context.get("has_cover", false))
	var can_see = bool(context.get("can_see", false))
	var has_last_known = bool(context.get("has_last_known", false))
	var hp_ratio = float(context.get("hp_ratio", 1.0))
	var ammo_ratio = float(context.get("ammo_ratio", 1.0))
	var visible_enemies = int(context.get("visible_enemies", 0))
	var losing_trade = bool(context.get("losing_trade", false))
	var weapon_type = String(context.get("weapon_type", ""))
	var dist = float(context.get("distance", 0.0))
	var pref_range = maxf(0.1, float(context.get("preferred_range", 1.0)))
	var reserve_ammo = int(context.get("reserve_ammo", 0))
	var target_hp_ratio = float(context.get("target_hp_ratio", 1.0))

	if not can_see and has_last_known:
		return PLAN_REPOSITION

	var flee_threshold = float(profile.get("flee_hp_ratio", 0.25)) + float(combat.get("survival_cover_hp_buffer", 0.18))
	if hp_ratio < flee_threshold or losing_trade or visible_enemies >= int(combat.get("outnumbered_visible_enemies", 2)):
		return PLAN_PEEK_COVER if has_cover else PLAN_KITE

	if weapon_type == "shotgun" and dist > pref_range * float(combat.get("shotgun_advance_range_mult", 0.75)) \
			and hp_ratio > float(combat.get("shotgun_advance_min_hp", 0.45)):
		return PLAN_ADVANCE

	if bool(combat.get("finish_low_hp_targets", false)) \
			and target_hp_ratio <= float(combat.get("finish_target_hp_ratio", 0.35)) \
			and hp_ratio > float(combat.get("advance_min_hp", 0.45)):
		return PLAN_REPOSITION

	var hold_weapons: Array = combat.get("hold_angle_weapons", [])
	if bool(combat.get("prefers_hold_angle", false)) or weapon_type in hold_weapons:
		if dist < pref_range * float(combat.get("hold_angle_kite_range_mult", 0.85)):
			return PLAN_KITE
		return PLAN_PEEK_COVER if has_cover else PLAN_HOLD_ANGLE

	if ammo_ratio <= float(combat.get("low_ammo_cover_ratio", 0.35)) and reserve_ammo > 0:
		return PLAN_PEEK_COVER if has_cover else PLAN_KITE

	if can_see and hp_ratio > float(combat.get("advance_min_hp", 0.55)) \
			and bool(context.get("advance_probe", false)):
		return PLAN_ADVANCE

	if can_see and has_cover and bool(context.get("cover_probe", false)):
		return PLAN_PEEK_COVER

	if can_see and bool(context.get("kite_probe", false)):
		return PLAN_KITE

	if can_see and hp_ratio > float(combat.get("reposition_min_hp", 0.55)) \
			and bool(context.get("reposition_probe", false)):
		return PLAN_REPOSITION

	return PLAN_STRAFE

static func choose_supply_decision(context: Dictionary, profile: Dictionary) -> String:
	var supply = profile.get("supply", {})
	var dist = float(context.get("distance", INF))
	var hp_ratio = float(context.get("hp_ratio", 1.0))
	var ammo_ratio = float(context.get("ammo_ratio", 1.0))
	var bucket = int(context.get("bucket", 0))

	if bool(context.get("telegraphed", false)):
		if dist < float(supply.get("telegraph_interest_dist", 0.0)):
			return "telegraph"
		return "deny"

	if bool(context.get("spawned", false)):
		if dist < float(supply.get("spawn_interest_dist", 0.0)):
			return "archetype"
		if hp_ratio < float(supply.get("need_hp_ratio", 0.45)) or ammo_ratio <= float(supply.get("low_ammo_ratio", 0.25)):
			if dist < float(supply.get("need_interest_dist", 40.0)):
				return "need"
		var mod = maxi(1, int(supply.get("bucket_mod", 4)))
		if bucket % mod == int(supply.get("bucket_value", 0)) and dist < float(supply.get("bucket_interest_dist", 28.0)):
			return "bucket"

	return "deny"

static func explain_profile(profile: Dictionary) -> Dictionary:
	return {
		"archetype": profile.get("archetype_name", "unknown"),
		"range": {
			"attack_mult": profile.get("attack_range_mult", 1.0),
			"vision_mult": profile.get("vision_range_mult", 1.0),
		},
		"safety": profile.get("safety", {}).duplicate(true),
		"base": {
			"disengage_threshold": profile.get("disengage_threshold", 2),
			"flee_hp_ratio": profile.get("flee_hp_ratio", 0.25),
			"loot_radius": profile.get("loot_radius", 70.0),
			"combat_loot_threshold": profile.get("combat_loot_threshold", 0.0),
		},
		"difficulty": {
			"reaction_delay": profile.get("reaction_delay", 0.0),
			"aim_spread_mult": profile.get("aim_spread_mult", 1.0),
			"awareness_level": profile.get("awareness_level", 0),
			"scan_interval_max": profile.get("scan_interval_max", 3.0),
		},
		"combat": profile.get("combat", {}).duplicate(true),
		"supply": profile.get("supply", {}).duplicate(true),
		"target": profile.get("target", {}).duplicate(true),
		"engagement": profile.get("engagement", {}).duplicate(true),
	}

static func _deep_merge(dst: Dictionary, src: Dictionary) -> void:
	for key in src:
		if dst.has(key) and dst[key] is Dictionary and src[key] is Dictionary:
			_deep_merge(dst[key], src[key])
		else:
			dst[key] = src[key].duplicate(true) if src[key] is Dictionary or src[key] is Array else src[key]
