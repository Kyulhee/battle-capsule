import argparse
import json
from collections import Counter
from pathlib import Path


def load_runs(run_dir: Path) -> list[dict]:
    summary = run_dir / "summary.json"
    if summary.exists():
        with summary.open("r", encoding="utf-8") as f:
            return json.load(f)
    runs = []
    for path in sorted(run_dir.glob("run_*.json")):
        with path.open("r", encoding="utf-8") as f:
            runs.append(json.load(f))
    return runs


def avg(values: list[float]) -> float:
    return sum(values) / max(1, len(values))


def combat_plan_total(run: dict) -> int:
    tactics = run.get("tactics", {})
    doctrine = run.get("doctrine", {})
    doctrine_total = sum(int(v) for v in doctrine.get("combat_plan_counts", {}).values())
    tactics_total = (
        int(tactics.get("cover_peek", 0))
        + int(tactics.get("combat_reposition", 0))
        + int(tactics.get("combat_kite", 0))
    )
    return max(tactics_total, doctrine_total)


def weapon_pickup_total(run: dict) -> int:
    return sum(int(v) for v in run.get("economy", {}).get("weapon_pickups", {}).values())


def non_pistol_pickup_total(run: dict) -> int:
    pickups = run.get("economy", {}).get("weapon_pickups", {})
    return sum(int(v) for weapon, v in pickups.items() if weapon != "pistol")


def disengage_entry_count(run: dict) -> int:
    tactics = run.get("tactics", {})
    if "disengage_entries" in tactics:
        return int(tactics.get("disengage_entries", 0))
    return int(tactics.get("disengage_triggered", 0))


def spawned_entity_count(run: dict) -> int:
    spawn = run.get("spawn", {})
    requested = int(spawn.get("requested_count", 0))
    if requested > 0:
        return requested
    archetype_distribution = run.get("archetype", {}).get("archetype_distribution", {})
    bot_count = sum(int(v) for v in archetype_distribution.values())
    if bot_count > 0:
        return bot_count + 1
    return 1


def per_spawned_entity_minute(runs: list[dict], value_fn) -> float:
    total_value = 0.0
    total_entity_minutes = 0.0
    for run in runs:
        duration_min = float(run.get("core", {}).get("duration", 0.0)) / 60.0
        entity_count = max(1, spawned_entity_count(run))
        total_value += float(value_fn(run))
        total_entity_minutes += duration_min * float(entity_count)
    return total_value / max(1.0, total_entity_minutes)


def per_match_minute(runs: list[dict], value_fn) -> float:
    total_value = 0.0
    total_minutes = 0.0
    for run in runs:
        total_value += float(value_fn(run))
        total_minutes += float(run.get("core", {}).get("duration", 0.0)) / 60.0
    return total_value / max(1.0, total_minutes)


def doctrine_state_totals(runs: list[dict]) -> Counter:
    totals = Counter()
    for run in runs:
        for states in run.get("doctrine", {}).get("state_time_by_archetype", {}).values():
            totals.update({state: float(seconds) for state, seconds in states.items()})
    return totals


def doctrine_state_mix(runs: list[dict]) -> dict[str, float]:
    totals = doctrine_state_totals(runs)
    total = sum(float(value) for value in totals.values())
    if total <= 0.0:
        return {}
    return {state: 100.0 * float(value) / total for state, value in totals.items()}


def doctrine_state_seconds(runs: list[dict], state_name: str) -> float:
    return float(doctrine_state_totals(runs).get(state_name, 0.0))


def doctrine_engage_range_totals(runs: list[dict]) -> dict[str, float]:
    result = {"count": 0.0, "total": 0.0, "min": 0.0, "max": 0.0}
    min_value = None
    max_value = 0.0
    for run in runs:
        for bucket in run.get("doctrine", {}).get("engage_range_by_archetype", {}).values():
            count = int(bucket.get("count", 0))
            if count <= 0:
                continue
            result["count"] += float(count)
            result["total"] += float(bucket.get("total", 0.0))
            bucket_min = float(bucket.get("min", 0.0))
            bucket_max = float(bucket.get("max", 0.0))
            min_value = bucket_min if min_value is None else min(min_value, bucket_min)
            max_value = max(max_value, bucket_max)
    result["min"] = 0.0 if min_value is None else float(min_value)
    result["max"] = max_value
    return result


def doctrine_engage_sample_count(run: dict) -> int:
    return sum(int(bucket.get("count", 0)) for bucket in run.get("doctrine", {}).get("engage_range_by_archetype", {}).values())


def chase_context_totals(runs: list[dict]) -> Counter:
    totals = Counter()
    for run in runs:
        for contexts in run.get("doctrine", {}).get("chase_context_time_by_archetype", {}).values():
            totals.update({context: float(seconds) for context, seconds in contexts.items()})
    return totals


def chase_context_mix(runs: list[dict]) -> dict[str, float]:
    totals = chase_context_totals(runs)
    total = sum(float(value) for value in totals.values())
    if total <= 0.0:
        return {}
    return {context: 100.0 * float(value) / total for context, value in totals.items()}


def disengage_reason_totals(runs: list[dict]) -> Counter:
    totals = Counter()
    for run in runs:
        totals.update(run.get("tactics", {}).get("disengage_reasons", {}))
    return totals


def disengage_reason_rates(runs: list[dict]) -> dict[str, float]:
    rates = {}
    for reason in disengage_reason_totals(runs):
        rates[reason] = per_spawned_entity_minute(
            runs,
            lambda r, key=reason: r.get("tactics", {}).get("disengage_reasons", {}).get(key, 0),
        )
    return rates


def combat_location_counter(runs: list[dict], key: str) -> Counter:
    counter = Counter()
    for run in runs:
        values = run.get("combat", {}).get(key, {})
        counter.update({name: float(value) for name, value in values.items()})
    return counter


def doctrine_context_counter(runs: list[dict], key: str, context: str) -> Counter:
    counter = Counter()
    for run in runs:
        values = run.get("doctrine", {}).get(key, {})
        context_values = values.get(context, {})
        if isinstance(context_values, dict):
            counter.update({name: float(value) for name, value in context_values.items()})
    return counter


def economy_kind_counter(runs: list[dict], key: str, kind: str) -> Counter:
    counter = Counter()
    for run in runs:
        values = run.get("economy", {}).get(key, {})
        kind_values = values.get(kind, {}) if isinstance(values, dict) else {}
        if isinstance(kind_values, dict):
            counter.update({name: float(value) for name, value in kind_values.items()})
    return counter


def counter_total(counter: Counter) -> float:
    return sum(float(value) for value in counter.values())


def counter_share(counter: Counter, key: str) -> float:
    total = counter_total(counter)
    if total <= 0.0:
        return 0.0
    return 100.0 * float(counter.get(key, 0.0)) / total


def counter_group_share(counter: Counter, keys: list[str]) -> float:
    total = counter_total(counter)
    if total <= 0.0:
        return 0.0
    return 100.0 * sum(float(counter.get(key, 0.0)) for key in keys) / total


def excluding_share(counter: Counter, excluded_keys: list[str]) -> float:
    total = counter_total(counter)
    if total <= 0.0:
        return 0.0
    excluded = sum(float(counter.get(key, 0.0)) for key in excluded_keys)
    return 100.0 * (total - excluded) / total


def non_key_share(counter: Counter, excluded_key: str) -> float:
    return excluding_share(counter, [excluded_key])


def summarize(runs: list[dict]) -> dict[str, float]:
    durations = [float(r.get("core", {}).get("duration", 0.0)) for r in runs]
    first_upgrade = [
        float(r.get("economy", {}).get("first_upgrade_time", -1.0))
        for r in runs
        if float(r.get("economy", {}).get("first_upgrade_time", -1.0)) >= 0.0
    ]
    spawn_runs = [
        r.get("spawn", {})
        for r in runs
        if int(r.get("spawn", {}).get("placed_count", 0)) > 0
    ]
    ai_samples = sum(int(r.get("ai", {}).get("update_samples", 0)) for r in runs)
    ai_total_usec = sum(int(r.get("ai", {}).get("update_total_usec", 0)) for r in runs)
    ai_max_usec = max((int(r.get("ai", {}).get("update_max_usec", 0)) for r in runs), default=0)
    disengage_entries = sum(disengage_entry_count(r) for r in runs)
    state_totals = doctrine_state_totals(runs)
    state_mix = doctrine_state_mix(runs)
    engage_range = doctrine_engage_range_totals(runs)
    chase_mix = chase_context_mix(runs)
    hit_poi_roles = combat_location_counter(runs, "hit_location_by_poi_role")
    damage_poi_roles = combat_location_counter(runs, "damage_location_by_poi_role")
    hit_route_roles = combat_location_counter(runs, "hit_location_by_route_role")
    damage_route_roles = combat_location_counter(runs, "damage_location_by_route_role")
    kill_route_roles = combat_location_counter(runs, "kill_location_by_route_role")
    combat_self_poi_roles = doctrine_context_counter(runs, "chase_self_poi_role_by_context", "combat")
    combat_target_poi_roles = doctrine_context_counter(runs, "chase_target_poi_role_by_context", "combat")
    combat_target_route_roles = doctrine_context_counter(runs, "chase_target_route_role_by_context", "combat")
    recover_target_poi_roles = doctrine_context_counter(runs, "chase_target_poi_role_by_context", "recover_loot")
    recover_target_route_roles = doctrine_context_counter(runs, "chase_target_route_role_by_context", "recover_loot")
    recover_target_kinds = doctrine_context_counter(runs, "chase_target_kind_by_context", "recover_loot")
    spawn_weapon_routes = economy_kind_counter(runs, "pickup_spawn_route_role_by_kind", "weapon")
    spawn_ammo_routes = economy_kind_counter(runs, "pickup_spawn_route_role_by_kind", "ammo")
    spawn_heal_routes = economy_kind_counter(runs, "pickup_spawn_route_role_by_kind", "heal")
    spawn_armor_routes = economy_kind_counter(runs, "pickup_spawn_route_role_by_kind", "armor")
    collect_weapon_routes = economy_kind_counter(runs, "pickup_collect_route_role_by_kind", "weapon")
    collect_ammo_routes = economy_kind_counter(runs, "pickup_collect_route_role_by_kind", "ammo")
    collect_heal_routes = economy_kind_counter(runs, "pickup_collect_route_role_by_kind", "heal")
    collect_armor_routes = economy_kind_counter(runs, "pickup_collect_route_role_by_kind", "armor")
    spawn_weapon_poi = economy_kind_counter(runs, "pickup_spawn_poi_role_by_kind", "weapon")
    spawn_ammo_poi = economy_kind_counter(runs, "pickup_spawn_poi_role_by_kind", "ammo")
    collect_weapon_poi = economy_kind_counter(runs, "pickup_collect_poi_role_by_kind", "weapon")
    collect_ammo_poi = economy_kind_counter(runs, "pickup_collect_poi_role_by_kind", "ammo")
    attack_minutes = float(state_totals.get("ATTACK", 0.0)) / 60.0
    summary = {
        "runs": float(len(runs)),
        "spawned_entities": avg([float(spawned_entity_count(r)) for r in runs]),
        "duration": avg(durations),
        "first_upgrade": avg(first_upgrade) if first_upgrade else -1.0,
        "damage_per_entity_min": per_spawned_entity_minute(
            runs, lambda r: r.get("combat", {}).get("total_damage_dealt", 0.0)
        ),
        "damage_per_match_min": per_match_minute(
            runs, lambda r: r.get("combat", {}).get("total_damage_dealt", 0.0)
        ),
        "shots_per_entity_min": per_spawned_entity_minute(
            runs, lambda r: r.get("combat", {}).get("shots_fired", 0)
        ),
        "shots_per_match_min": per_match_minute(runs, lambda r: r.get("combat", {}).get("shots_fired", 0)),
        "plans_per_entity_min": per_spawned_entity_minute(runs, combat_plan_total),
        "plans_per_match_min": per_match_minute(runs, combat_plan_total),
        "damage_per_attack_min": (
            sum(float(r.get("combat", {}).get("total_damage_dealt", 0.0)) for r in runs) / max(1.0, attack_minutes)
        ),
        "shots_per_attack_min": (
            sum(float(r.get("combat", {}).get("shots_fired", 0)) for r in runs) / max(1.0, attack_minutes)
        ),
        "engage_samples_per_entity_min": per_spawned_entity_minute(runs, doctrine_engage_sample_count),
        "engage_range_avg": float(engage_range.get("total", 0.0)) / max(1.0, float(engage_range.get("count", 0.0))),
        "weapon_pickups_per_entity_min": per_spawned_entity_minute(runs, weapon_pickup_total),
        "non_pistol_pickups_per_entity_min": per_spawned_entity_minute(runs, non_pistol_pickup_total),
        "rare_pickups_per_entity_min": per_spawned_entity_minute(
            runs, lambda r: r.get("economy", {}).get("rare_pickups", 0)
        ),
        "heals_per_entity_min": per_spawned_entity_minute(runs, lambda r: r.get("economy", {}).get("heals_used", 0)),
        "shields_per_entity_min": per_spawned_entity_minute(
            runs, lambda r: r.get("economy", {}).get("shields_picked", 0)
        ),
        "disengage_per_entity_min": per_spawned_entity_minute(
            runs, lambda r: r.get("tactics", {}).get("disengage_triggered", 0)
        ),
        "disengage_entry_per_entity_min": per_spawned_entity_minute(runs, disengage_entry_count),
        "stuck_per_entity_min": per_spawned_entity_minute(
            runs, lambda r: r.get("tactics", {}).get("stuck_triggered", 0)
        ),
        "zone_fire_per_entity_min": per_spawned_entity_minute(
            runs, lambda r: r.get("tactics", {}).get("zone_escape_fire", 0)
        ),
        "survival_per_entity_min": per_spawned_entity_minute(
            runs, lambda r: r.get("tactics", {}).get("survival_break", 0)
        ),
        "ai_avg_usec": ai_total_usec / ai_samples if ai_samples > 0 else 0.0,
        "ai_max_usec": float(ai_max_usec),
        "disengage_seconds_per_entry": float(state_totals.get("DISENGAGE", 0.0)) / max(1, disengage_entries),
        "disengage_reason_counts": dict(disengage_reason_totals(runs)),
        "disengage_reason_rates": disengage_reason_rates(runs),
        "state_zone_escape": state_mix.get("ZONE_ESCAPE", 0.0),
        "state_disengage": state_mix.get("DISENGAGE", 0.0),
        "state_attack": state_mix.get("ATTACK", 0.0),
        "state_chase": state_mix.get("CHASE", 0.0),
        "state_combat_active": state_mix.get("ATTACK", 0.0) + state_mix.get("CHASE", 0.0),
        "state_retreat_escape": state_mix.get("DISENGAGE", 0.0) + state_mix.get("ZONE_ESCAPE", 0.0),
        "state_idle": state_mix.get("IDLE", 0.0),
        "chase_combat": chase_mix.get("combat", 0.0),
        "chase_loot": chase_mix.get("loot", 0.0),
        "chase_recover_loot": chase_mix.get("recover_loot", 0.0),
        "chase_unknown": chase_mix.get("unknown", 0.0),
        "chase_combat_location_seconds": counter_total(combat_target_poi_roles),
        "chase_recover_location_seconds": counter_total(recover_target_kinds),
        "chase_combat_self_in_poi_pct": excluding_share(combat_self_poi_roles, ["open", "none"]),
        "chase_combat_target_in_poi_pct": excluding_share(combat_target_poi_roles, ["open", "none"]),
        "chase_combat_target_on_route_pct": excluding_share(combat_target_route_roles, ["off_route", "none"]),
        "chase_recover_target_in_poi_pct": excluding_share(recover_target_poi_roles, ["open", "none"]),
        "chase_recover_target_on_route_pct": excluding_share(recover_target_route_roles, ["off_route", "none"]),
        "chase_recover_target_transit_poi_pct": counter_share(recover_target_poi_roles, "transit_choke"),
        "chase_recover_target_loot_hub_pct": counter_share(recover_target_poi_roles, "loot_hub"),
        "chase_recover_target_concealment_pct": counter_share(recover_target_poi_roles, "concealment"),
        "chase_recover_target_recovery_pocket_pct": counter_share(recover_target_poi_roles, "recovery_pocket"),
        "chase_recover_target_primary_choke_pct": counter_share(recover_target_route_roles, "primary_choke"),
        "chase_recover_target_loot_flow_pct": counter_share(recover_target_route_roles, "loot_flow"),
        "chase_recover_target_recovery_exit_pct": counter_share(recover_target_route_roles, "recovery_exit"),
        "chase_recover_target_pickup_total_pct": counter_group_share(
            recover_target_kinds,
            ["pickup_weapon", "pickup_ammo", "pickup_heal", "pickup_armor", "pickup_unknown"],
        ),
        "chase_recover_target_pickup_weapon_pct": counter_share(recover_target_kinds, "pickup_weapon"),
        "chase_recover_target_pickup_ammo_pct": counter_share(recover_target_kinds, "pickup_ammo"),
        "chase_recover_target_pickup_heal_pct": counter_share(recover_target_kinds, "pickup_heal"),
        "chase_recover_target_pickup_armor_pct": counter_share(recover_target_kinds, "pickup_armor"),
        "pickup_spawn_weapon_count": counter_total(spawn_weapon_routes),
        "pickup_spawn_ammo_count": counter_total(spawn_ammo_routes),
        "pickup_collect_weapon_count": counter_total(collect_weapon_routes),
        "pickup_collect_ammo_count": counter_total(collect_ammo_routes),
        "pickup_spawn_weapon_on_route_pct": excluding_share(spawn_weapon_routes, ["off_route", "none"]),
        "pickup_spawn_ammo_on_route_pct": excluding_share(spawn_ammo_routes, ["off_route", "none"]),
        "pickup_collect_weapon_on_route_pct": excluding_share(collect_weapon_routes, ["off_route", "none"]),
        "pickup_collect_ammo_on_route_pct": excluding_share(collect_ammo_routes, ["off_route", "none"]),
        "pickup_spawn_weapon_recovery_exit_pct": counter_share(spawn_weapon_routes, "recovery_exit"),
        "pickup_spawn_ammo_recovery_exit_pct": counter_share(spawn_ammo_routes, "recovery_exit"),
        "pickup_collect_weapon_recovery_exit_pct": counter_share(collect_weapon_routes, "recovery_exit"),
        "pickup_collect_ammo_recovery_exit_pct": counter_share(collect_ammo_routes, "recovery_exit"),
        "pickup_spawn_weapon_primary_choke_pct": counter_share(spawn_weapon_routes, "primary_choke"),
        "pickup_spawn_ammo_primary_choke_pct": counter_share(spawn_ammo_routes, "primary_choke"),
        "pickup_collect_weapon_primary_choke_pct": counter_share(collect_weapon_routes, "primary_choke"),
        "pickup_collect_ammo_primary_choke_pct": counter_share(collect_ammo_routes, "primary_choke"),
        "pickup_spawn_weapon_in_poi_pct": excluding_share(spawn_weapon_poi, ["open", "none"]),
        "pickup_spawn_ammo_in_poi_pct": excluding_share(spawn_ammo_poi, ["open", "none"]),
        "pickup_collect_weapon_in_poi_pct": excluding_share(collect_weapon_poi, ["open", "none"]),
        "pickup_collect_ammo_in_poi_pct": excluding_share(collect_ammo_poi, ["open", "none"]),
        "pickup_collect_heal_recovery_exit_pct": counter_share(collect_heal_routes, "recovery_exit"),
        "pickup_collect_armor_recovery_exit_pct": counter_share(collect_armor_routes, "recovery_exit"),
        "pickup_spawn_heal_recovery_exit_pct": counter_share(spawn_heal_routes, "recovery_exit"),
        "pickup_spawn_armor_recovery_exit_pct": counter_share(spawn_armor_routes, "recovery_exit"),
        "combat_hit_in_poi_pct": non_key_share(hit_poi_roles, "open"),
        "combat_damage_in_poi_pct": non_key_share(damage_poi_roles, "open"),
        "combat_hit_on_route_pct": non_key_share(hit_route_roles, "off_route"),
        "combat_damage_on_route_pct": non_key_share(damage_route_roles, "off_route"),
        "combat_kill_on_route_pct": non_key_share(kill_route_roles, "off_route"),
        "damage_primary_choke_pct": counter_share(damage_route_roles, "primary_choke"),
        "damage_flank_pct": counter_share(damage_route_roles, "flank"),
        "damage_loot_flow_pct": counter_share(damage_route_roles, "loot_flow"),
        "damage_recovery_exit_pct": counter_share(damage_route_roles, "recovery_exit"),
        "damage_transit_choke_poi_pct": counter_share(damage_poi_roles, "transit_choke"),
    }
    if spawn_runs:
        summary.update(
            {
                "spawn_fallback_per_run": avg([float(s.get("fallback_count", 0)) for s in spawn_runs]),
                "spawn_min_nearest": min(float(s.get("min_nearest_distance", 0.0)) for s in spawn_runs),
                "spawn_avg_nearest": avg([float(s.get("avg_nearest_distance", 0.0)) for s in spawn_runs]),
                "spawn_saturation": avg([float(s.get("annulus_saturation", 0.0)) for s in spawn_runs]),
            }
        )
    return summary


def print_comparison(label_a: str, summary_a: dict[str, float], label_b: str, summary_b: dict[str, float]) -> None:
    metrics = [
        ("runs", "runs"),
        ("spawned_entities", "spawned entities"),
        ("duration", "avg duration s"),
        ("first_upgrade", "avg first upgrade s"),
        ("spawn_fallback_per_run", "spawn fallback/run"),
        ("spawn_min_nearest", "spawn min nearest m"),
        ("spawn_avg_nearest", "spawn avg nearest m"),
        ("spawn_saturation", "spawn saturation"),
        ("damage_per_entity_min", "damage/entity/min"),
        ("damage_per_match_min", "damage/match min"),
        ("shots_per_entity_min", "shots/entity/min"),
        ("shots_per_match_min", "shots/match min"),
        ("plans_per_entity_min", "plans/entity/min"),
        ("plans_per_match_min", "plans/match min"),
        ("damage_per_attack_min", "damage/ATTACK min"),
        ("shots_per_attack_min", "shots/ATTACK min"),
        ("engage_samples_per_entity_min", "engage samples/entity/min"),
        ("engage_range_avg", "avg engage range m"),
        ("weapon_pickups_per_entity_min", "weapon pickups/entity/min"),
        ("non_pistol_pickups_per_entity_min", "non-pistol pickups/entity/min"),
        ("rare_pickups_per_entity_min", "rare pickups/entity/min"),
        ("heals_per_entity_min", "heals/entity/min"),
        ("shields_per_entity_min", "shields/entity/min"),
        ("disengage_per_entity_min", "disengage/entity/min"),
        ("disengage_entry_per_entity_min", "disengage entries/entity/min"),
        ("stuck_per_entity_min", "stuck/entity/min"),
        ("zone_fire_per_entity_min", "zone fire/entity/min"),
        ("survival_per_entity_min", "survival/entity/min"),
        ("ai_avg_usec", "AI avg usec"),
        ("ai_max_usec", "AI max usec"),
        ("disengage_seconds_per_entry", "DISENGAGE sec/entry"),
        ("state_zone_escape", "state ZONE_ESCAPE %"),
        ("state_disengage", "state DISENGAGE %"),
        ("state_attack", "state ATTACK %"),
        ("state_chase", "state CHASE %"),
        ("state_combat_active", "state ATTACK+CHASE %"),
        ("state_retreat_escape", "state RETREAT+ESCAPE %"),
        ("state_idle", "state IDLE %"),
        ("chase_combat", "CHASE combat %"),
        ("chase_loot", "CHASE loot %"),
        ("chase_recover_loot", "CHASE recover loot %"),
        ("chase_unknown", "CHASE unknown %"),
        ("chase_combat_self_in_poi_pct", "CHASE combat self POI %"),
        ("chase_combat_target_in_poi_pct", "CHASE combat target POI %"),
        ("chase_combat_target_on_route_pct", "CHASE combat target route %"),
        ("chase_recover_target_in_poi_pct", "CHASE recover target POI %"),
        ("chase_recover_target_on_route_pct", "CHASE recover target route %"),
        ("chase_recover_target_transit_poi_pct", "CHASE recover target transit POI %"),
        ("chase_recover_target_loot_hub_pct", "CHASE recover target loot hub %"),
        ("chase_recover_target_recovery_pocket_pct", "CHASE recover target recovery POI %"),
        ("chase_recover_target_recovery_exit_pct", "CHASE recover target recovery exit %"),
        ("chase_recover_target_loot_flow_pct", "CHASE recover target loot-flow %"),
        ("chase_recover_target_pickup_weapon_pct", "CHASE recover weapon target %"),
        ("chase_recover_target_pickup_ammo_pct", "CHASE recover ammo target %"),
        ("chase_recover_target_pickup_heal_pct", "CHASE recover heal target %"),
        ("chase_recover_target_pickup_armor_pct", "CHASE recover armor target %"),
        ("pickup_spawn_weapon_on_route_pct", "pickup spawn weapon route %"),
        ("pickup_spawn_ammo_on_route_pct", "pickup spawn ammo route %"),
        ("pickup_collect_weapon_on_route_pct", "pickup collect weapon route %"),
        ("pickup_collect_ammo_on_route_pct", "pickup collect ammo route %"),
        ("pickup_spawn_weapon_recovery_exit_pct", "pickup spawn weapon recovery exit %"),
        ("pickup_spawn_ammo_recovery_exit_pct", "pickup spawn ammo recovery exit %"),
        ("pickup_collect_weapon_recovery_exit_pct", "pickup collect weapon recovery exit %"),
        ("pickup_collect_ammo_recovery_exit_pct", "pickup collect ammo recovery exit %"),
        ("pickup_spawn_weapon_primary_choke_pct", "pickup spawn weapon primary choke %"),
        ("pickup_spawn_ammo_primary_choke_pct", "pickup spawn ammo primary choke %"),
        ("pickup_collect_weapon_primary_choke_pct", "pickup collect weapon primary choke %"),
        ("pickup_collect_ammo_primary_choke_pct", "pickup collect ammo primary choke %"),
        ("pickup_spawn_weapon_in_poi_pct", "pickup spawn weapon POI %"),
        ("pickup_spawn_ammo_in_poi_pct", "pickup spawn ammo POI %"),
        ("pickup_collect_weapon_in_poi_pct", "pickup collect weapon POI %"),
        ("pickup_collect_ammo_in_poi_pct", "pickup collect ammo POI %"),
        ("combat_hit_in_poi_pct", "combat hits in POI %"),
        ("combat_damage_in_poi_pct", "combat damage in POI %"),
        ("combat_hit_on_route_pct", "combat hits on route %"),
        ("combat_damage_on_route_pct", "combat damage on route %"),
        ("combat_kill_on_route_pct", "combat kills on route %"),
        ("damage_primary_choke_pct", "damage primary choke %"),
        ("damage_flank_pct", "damage flank %"),
        ("damage_loot_flow_pct", "damage loot flow %"),
        ("damage_recovery_exit_pct", "damage recovery exit %"),
        ("damage_transit_choke_poi_pct", "damage transit POI %"),
    ]
    label_width = max(28, max(len(label) for _, label in metrics) + 2)
    print("--- Scale Profile Comparison ---")
    print(f"{'Metric':<{label_width}} {label_a:>14} {label_b:>14} {'delta':>14}")
    for key, label in metrics:
        a = float(summary_a.get(key, 0.0))
        b = float(summary_b.get(key, 0.0))
        print(f"{label:<{label_width}} {a:>14.2f} {b:>14.2f} {b - a:>14.2f}")
    print_disengage_reason_comparison(label_a, summary_a, label_b, summary_b)
    print_tempo_decision(summary_a, summary_b)
    print_engagement_density_decision(summary_a, summary_b)
    print_chase_location_decision(summary_a, summary_b)
    print_pickup_location_decision(summary_a, summary_b)
    print_route_pressure_decision(summary_a, summary_b)
    print_pressure_decision(summary_a, summary_b)


def print_disengage_reason_comparison(
    label_a: str,
    summary_a: dict[str, float],
    label_b: str,
    summary_b: dict[str, float],
) -> None:
    rates_a = summary_a.get("disengage_reason_rates", {})
    rates_b = summary_b.get("disengage_reason_rates", {})
    reasons = sorted(
        set(rates_a) | set(rates_b),
        key=lambda reason: max(float(rates_a.get(reason, 0.0)), float(rates_b.get(reason, 0.0))),
        reverse=True,
    )
    if not reasons:
        return
    print("Disengage reasons/entity/min:")
    print(f"{'Reason':<28} {label_a:>14} {label_b:>14} {'delta':>14}")
    for reason in reasons:
        a = float(rates_a.get(reason, 0.0))
        b = float(rates_b.get(reason, 0.0))
        print(f"{reason:<28} {a:>14.2f} {b:>14.2f} {b - a:>14.2f}")


def print_pressure_decision(summary_a: dict[str, float], summary_b: dict[str, float]) -> None:
    spawn_fallback_delta = float(summary_b.get("spawn_fallback_per_run", 0.0)) - float(
        summary_a.get("spawn_fallback_per_run", 0.0)
    )
    min_nearest = float(summary_b.get("spawn_min_nearest", 0.0))
    ai_delta = float(summary_b.get("ai_avg_usec", 0.0)) - float(summary_a.get("ai_avg_usec", 0.0))
    disengage_rate_delta = float(summary_b.get("disengage_entry_per_entity_min", 0.0)) - float(
        summary_a.get("disengage_entry_per_entity_min", 0.0)
    )
    disengage_share_delta = float(summary_b.get("state_disengage", 0.0)) - float(
        summary_a.get("state_disengage", 0.0)
    )
    disengage_duration_delta = float(summary_b.get("disengage_seconds_per_entry", 0.0)) - float(
        summary_a.get("disengage_seconds_per_entry", 0.0)
    )
    zone_share_delta = float(summary_b.get("state_zone_escape", 0.0)) - float(
        summary_a.get("state_zone_escape", 0.0)
    )
    zone_fire_delta = float(summary_b.get("zone_fire_per_entity_min", 0.0)) - float(
        summary_a.get("zone_fire_per_entity_min", 0.0)
    )

    print("Pressure decision:")
    if spawn_fallback_delta > 0.0 or min_nearest < 3.4:
        print("  - Spawn/pathing remains the first blocker: fallback or nearest-spacing guard moved the wrong way.")
    else:
        print("  - Spawn/pathing is not the current blocker: fallback stayed at 0 and spacing stayed inside the gate.")
    if ai_delta > 1000.0:
        print("  - AI budget needs review before tuning behavior.")
    else:
        print("  - AI budget is not the current blocker.")
    if disengage_share_delta >= 4.0 and disengage_rate_delta <= 0.05:
        print(
            "  - DISENGAGE pressure looks duration/exit-related, not entry-frequency-related "
            "(state share rose while normalized entry rate did not)."
        )
    elif disengage_share_delta >= 4.0:
        print("  - DISENGAGE pressure looks entry-frequency-related; inspect reason deltas before behavior tuning.")
    else:
        print("  - DISENGAGE share did not move enough to justify behavior tuning by itself.")
    if disengage_duration_delta >= 1.0:
        print("  - DISENGAGE duration per trigger increased; inspect cover travel, scatter, and exit conditions.")
    if zone_share_delta >= 2.0 and zone_fire_delta <= 0.10:
        print("  - ZONE_ESCAPE share rose mildly without higher normalized zone-fire; review zone pacing after disengage exit behavior.")
    elif zone_share_delta >= 2.0:
        print("  - ZONE_ESCAPE pressure rose with zone-fire; review zone pacing and route density together.")
    else:
        print("  - ZONE_ESCAPE share is not the primary first tuning target.")


def print_tempo_decision(summary_a: dict[str, float], summary_b: dict[str, float]) -> None:
    duration_delta = float(summary_b.get("duration", 0.0)) - float(summary_a.get("duration", 0.0))
    first_upgrade_delta = float(summary_b.get("first_upgrade", 0.0)) - float(summary_a.get("first_upgrade", 0.0))
    damage_delta = float(summary_b.get("damage_per_entity_min", 0.0)) - float(
        summary_a.get("damage_per_entity_min", 0.0)
    )
    shots_delta = float(summary_b.get("shots_per_entity_min", 0.0)) - float(summary_a.get("shots_per_entity_min", 0.0))
    plans_delta = float(summary_b.get("plans_per_entity_min", 0.0)) - float(summary_a.get("plans_per_entity_min", 0.0))
    non_pistol_delta = float(summary_b.get("non_pistol_pickups_per_entity_min", 0.0)) - float(
        summary_a.get("non_pistol_pickups_per_entity_min", 0.0)
    )

    print("Tempo decision:")
    if first_upgrade_delta >= 8.0 and non_pistol_delta <= -0.03:
        print("  - Economy tempo is diluted: first upgrade is later and non-pistol pickup rate is lower.")
    elif first_upgrade_delta >= 8.0:
        print("  - First upgrade is much later; inspect pickup access and upgrade weapon distribution.")
    else:
        print("  - First upgrade timing is not the main tempo blocker.")
    if damage_delta <= -5.0 and shots_delta <= -0.5 and plans_delta <= -0.5:
        print("  - Combat tempo is diluted: damage, shots, and combat plans all fell per entity/min.")
    elif damage_delta <= -5.0 or shots_delta <= -0.5:
        print("  - Combat throughput fell; inspect engagement density before changing retreat behavior.")
    else:
        print("  - Combat throughput did not fall enough to explain scale pressure by itself.")
    if duration_delta >= 20.0:
        print("  - Match duration stretched materially; diagnose economy/combat tempo before zone or bot-threshold tuning.")


def print_engagement_density_decision(summary_a: dict[str, float], summary_b: dict[str, float]) -> None:
    entity_ratio = float(summary_b.get("spawned_entities", 0.0)) / max(1.0, float(summary_a.get("spawned_entities", 0.0)))
    damage_match_ratio = float(summary_b.get("damage_per_match_min", 0.0)) / max(
        1.0, float(summary_a.get("damage_per_match_min", 0.0))
    )
    shots_match_ratio = float(summary_b.get("shots_per_match_min", 0.0)) / max(
        1.0, float(summary_a.get("shots_per_match_min", 0.0))
    )
    plans_match_ratio = float(summary_b.get("plans_per_match_min", 0.0)) / max(
        1.0, float(summary_a.get("plans_per_match_min", 0.0))
    )
    active_delta = float(summary_b.get("state_combat_active", 0.0)) - float(summary_a.get("state_combat_active", 0.0))
    chase_combat_delta = float(summary_b.get("chase_combat", 0.0)) - float(summary_a.get("chase_combat", 0.0))
    chase_loot_total_b = float(summary_b.get("chase_loot", 0.0)) + float(summary_b.get("chase_recover_loot", 0.0))
    damage_attack_ratio = float(summary_b.get("damage_per_attack_min", 0.0)) / max(
        1.0, float(summary_a.get("damage_per_attack_min", 0.0))
    )
    engage_sample_delta = float(summary_b.get("engage_samples_per_entity_min", 0.0)) - float(
        summary_a.get("engage_samples_per_entity_min", 0.0)
    )

    print("Engagement density decision:")
    if entity_ratio > 1.2 and damage_match_ratio < entity_ratio * 0.75 and shots_match_ratio < entity_ratio * 0.75:
        print(
            "  - Combat throughput is not scaling with population: match-minute damage/shots rose far less than entity count."
        )
    else:
        print("  - Match-minute combat throughput scales close enough to population for this comparison.")
    if damage_attack_ratio >= 0.90:
        print("  - ATTACK-state damage efficiency is intact; the bottleneck is engagement density, not per-attack lethality.")
    else:
        print("  - ATTACK-state damage efficiency fell; inspect weapon mix, range, and hit conditions.")
    if active_delta <= -3.0 or engage_sample_delta <= -0.5 or plans_match_ratio < entity_ratio * 0.75:
        print("  - Active engagement coverage is thin; inspect target acquisition, chase routing, and encounter spacing.")
    else:
        print("  - Active engagement coverage did not fall enough to be the sole blocker.")
    if chase_combat_delta <= -5.0:
        print("  - CHASE time shifted away from combat targets; inspect loot/recovery interruptions and enemy acquisition.")
    elif chase_loot_total_b >= 35.0:
        print("  - A large share of CHASE time is loot/recovery movement; inspect objective interrupts and pickup spacing.")


def print_chase_location_decision(summary_a: dict[str, float], summary_b: dict[str, float]) -> None:
    recover_location_seconds_b = float(summary_b.get("chase_recover_location_seconds", 0.0))
    combat_location_seconds_b = float(summary_b.get("chase_combat_location_seconds", 0.0))
    recover_share_b = float(summary_b.get("chase_recover_loot", 0.0))
    recover_target_poi_b = float(summary_b.get("chase_recover_target_in_poi_pct", 0.0))
    recover_target_route_b = float(summary_b.get("chase_recover_target_on_route_pct", 0.0))
    recover_exit_b = float(summary_b.get("chase_recover_target_recovery_exit_pct", 0.0))
    recover_loot_flow_b = float(summary_b.get("chase_recover_target_loot_flow_pct", 0.0))
    recover_pickup_weapon_b = float(summary_b.get("chase_recover_target_pickup_weapon_pct", 0.0))
    recover_pickup_ammo_b = float(summary_b.get("chase_recover_target_pickup_ammo_pct", 0.0))
    recover_pickup_heal_b = float(summary_b.get("chase_recover_target_pickup_heal_pct", 0.0))
    recover_pickup_armor_b = float(summary_b.get("chase_recover_target_pickup_armor_pct", 0.0))
    combat_target_poi_delta = float(summary_b.get("chase_combat_target_in_poi_pct", 0.0)) - float(
        summary_a.get("chase_combat_target_in_poi_pct", 0.0)
    )
    combat_target_route_delta = float(summary_b.get("chase_combat_target_on_route_pct", 0.0)) - float(
        summary_a.get("chase_combat_target_on_route_pct", 0.0)
    )

    print("CHASE location decision:")
    if recover_location_seconds_b <= 0.0 and combat_location_seconds_b <= 0.0:
        print("  - No CHASE location telemetry was recorded; run a post-v2.0.31 simulation set.")
        return
    if recover_share_b < 20.0:
        print("  - Recovery/loot CHASE is not large enough to lead the next tuning slice by itself.")
    elif recover_target_poi_b < 45.0 and recover_target_route_b < 50.0:
        print("  - Recovery/loot CHASE targets are often outside strategic POI/routes; inspect pickup scatter first.")
    elif recover_exit_b >= 25.0:
        print("  - Recovery/loot CHASE is anchored on recovery exits; inspect exit loot, heal access, and re-entry pressure.")
    elif recover_loot_flow_b >= 30.0:
        print("  - Recovery/loot CHASE is mostly on loot-flow routes; inspect whether route loot interrupts combat rotations.")
    else:
        print("  - Recovery/loot CHASE stays inside analyzable POI/route pressure; inspect target kind before map changes.")
    if recover_pickup_weapon_b + recover_pickup_ammo_b >= 60.0:
        print("  - Recovery movement is mostly weapon/ammo access, not healing; inspect ammo economy and weapon pickup spacing.")
    elif recover_pickup_heal_b + recover_pickup_armor_b >= 60.0:
        print("  - Recovery movement is mostly sustain access; inspect heal/shield placement before aggression tuning.")
    if combat_target_poi_delta <= -5.0 or combat_target_route_delta <= -5.0:
        print("  - Combat CHASE target pressure drops at target scale; inspect target acquisition and encounter-route spacing.")


def print_pickup_location_decision(summary_a: dict[str, float], summary_b: dict[str, float]) -> None:
    spawn_weapon_count_b = float(summary_b.get("pickup_spawn_weapon_count", 0.0))
    spawn_ammo_count_b = float(summary_b.get("pickup_spawn_ammo_count", 0.0))
    collect_weapon_count_b = float(summary_b.get("pickup_collect_weapon_count", 0.0))
    collect_ammo_count_b = float(summary_b.get("pickup_collect_ammo_count", 0.0))
    spawn_weapon_exit_b = float(summary_b.get("pickup_spawn_weapon_recovery_exit_pct", 0.0))
    spawn_ammo_exit_b = float(summary_b.get("pickup_spawn_ammo_recovery_exit_pct", 0.0))
    collect_weapon_exit_b = float(summary_b.get("pickup_collect_weapon_recovery_exit_pct", 0.0))
    collect_ammo_exit_b = float(summary_b.get("pickup_collect_ammo_recovery_exit_pct", 0.0))
    recover_weapon_target_b = float(summary_b.get("chase_recover_target_pickup_weapon_pct", 0.0))
    recover_ammo_target_b = float(summary_b.get("chase_recover_target_pickup_ammo_pct", 0.0))
    recover_exit_b = float(summary_b.get("chase_recover_target_recovery_exit_pct", 0.0))
    spawn_exit_supply = (spawn_weapon_exit_b + spawn_ammo_exit_b) / 2.0
    collect_exit_supply = (collect_weapon_exit_b + collect_ammo_exit_b) / 2.0

    print("Pickup location decision:")
    if spawn_weapon_count_b + spawn_ammo_count_b <= 0.0 and collect_weapon_count_b + collect_ammo_count_b <= 0.0:
        print("  - No pickup location telemetry was recorded; run a post-v2.0.32 simulation set.")
        return
    if recover_weapon_target_b + recover_ammo_target_b < 60.0:
        print("  - Weapon/ammo pickup targets are not large enough to lead the next slice by themselves.")
    elif spawn_exit_supply >= 25.0 and collect_exit_supply >= 25.0:
        print("  - Recovery-exit weapon/ammo pressure appears placement-driven: spawn and collection both concentrate there.")
    elif collect_exit_supply >= 25.0 and spawn_exit_supply < 20.0:
        print("  - Recovery-exit weapon/ammo pressure appears selection/path-driven: collection concentrates there more than spawn.")
    elif recover_exit_b >= 25.0 and collect_exit_supply < 20.0:
        print("  - CHASE target route pressure exceeds pickup collection pressure; inspect route width/classification overlap.")
    else:
        print("  - Weapon/ammo pickup pressure is distributed enough; inspect POI target acquisition before moving loot.")
    if float(summary_b.get("pickup_collect_weapon_primary_choke_pct", 0.0)) + float(
        summary_b.get("pickup_collect_ammo_primary_choke_pct", 0.0)
    ) < 25.0:
        print("  - Primary chokes are not the main weapon/ammo collection source yet.")


def print_route_pressure_decision(summary_a: dict[str, float], summary_b: dict[str, float]) -> None:
    route_damage_b = float(summary_b.get("combat_damage_on_route_pct", 0.0))
    poi_damage_b = float(summary_b.get("combat_damage_in_poi_pct", 0.0))
    route_damage_delta = float(summary_b.get("combat_damage_on_route_pct", 0.0)) - float(
        summary_a.get("combat_damage_on_route_pct", 0.0)
    )
    poi_damage_delta = float(summary_b.get("combat_damage_in_poi_pct", 0.0)) - float(
        summary_a.get("combat_damage_in_poi_pct", 0.0)
    )
    primary_choke_b = float(summary_b.get("damage_primary_choke_pct", 0.0))
    flank_b = float(summary_b.get("damage_flank_pct", 0.0))
    transit_poi_b = float(summary_b.get("damage_transit_choke_poi_pct", 0.0))

    print("Route pressure decision:")
    if route_damage_b <= 0.0:
        print("  - No route-pressure telemetry was recorded; run a post-v2.0.28 simulation set.")
        return
    if route_damage_delta < -5.0:
        if route_damage_b >= 60.0:
            print(
                "  - Target scale keeps high route damage but below baseline; inspect whether 60 is over-concentrated before widening routes."
            )
        else:
            print("  - Target scale moved damage away from strategic routes; inspect route spacing and zone pull.")
    else:
        print("  - Target scale preserves or increases damage on strategic routes.")
    if poi_damage_delta < -5.0:
        if poi_damage_b >= 45.0:
            print(
                "  - Target scale keeps material POI damage but below baseline; inspect which POI roles lost pressure."
            )
        else:
            print("  - Target scale moved damage out of POI influence; inspect loot hubs and recovery pockets.")
    if primary_choke_b + flank_b < 25.0 and transit_poi_b < 12.0:
        print("  - Choke/flank pressure is thin; map routes may not be contesting rotations yet.")
    else:
        print("  - Choke/flank pressure is present enough to analyze before AI aggression tuning.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare two scale simulation run directories.")
    parser.add_argument("baseline_dir")
    parser.add_argument("target_dir")
    parser.add_argument("--baseline-label", default="baseline")
    parser.add_argument("--target-label", default="target")
    args = parser.parse_args()

    baseline = load_runs(Path(args.baseline_dir))
    target = load_runs(Path(args.target_dir))
    if not baseline:
        print(f"No runs found in {args.baseline_dir}.")
        return 1
    if not target:
        print(f"No runs found in {args.target_dir}.")
        return 1
    print_comparison(args.baseline_label, summarize(baseline), args.target_label, summarize(target))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
