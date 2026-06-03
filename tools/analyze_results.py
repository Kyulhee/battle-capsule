import json
import sys
from collections import Counter
from pathlib import Path


RUN_DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("tools") / "sim_runs_current"


def load_runs(run_dir: Path) -> list[dict]:
    if (run_dir / "summary.json").exists():
        with (run_dir / "summary.json").open("r", encoding="utf-8") as f:
            return json.load(f)

    runs = []
    for path in sorted(run_dir.glob("run_*.json")):
        with path.open("r", encoding="utf-8") as f:
            runs.append(json.load(f))
    return runs


def avg(values: list[float]) -> float:
    return sum(values) / max(1, len(values))


def run_numbers(runs: list[dict], predicate) -> list[int]:
    return [idx + 1 for idx, run in enumerate(runs) if predicate(run)]


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


def per_spawned_entity_minute(results: list[dict], value_fn) -> float:
    total_value = 0.0
    total_entity_minutes = 0.0
    for run in results:
        duration_min = float(run.get("core", {}).get("duration", 0.0)) / 60.0
        entity_count = max(1, spawned_entity_count(run))
        total_value += float(value_fn(run))
        total_entity_minutes += duration_min * float(entity_count)
    return total_value / max(1.0, total_entity_minutes)


def per_match_minute(results: list[dict], value_fn) -> float:
    total_value = 0.0
    total_minutes = 0.0
    for run in results:
        total_value += float(value_fn(run))
        total_minutes += float(run.get("core", {}).get("duration", 0.0)) / 60.0
    return total_value / max(1.0, total_minutes)


def doctrine_engage_sample_count(run: dict) -> int:
    return sum(int(bucket.get("count", 0)) for bucket in run.get("doctrine", {}).get("engage_range_by_archetype", {}).values())


def combat_location_counter(results: list[dict], key: str) -> Counter:
    counter = Counter()
    for run in results:
        values = run.get("combat", {}).get(key, {})
        counter.update({name: float(value) for name, value in values.items()})
    return counter


def doctrine_context_counter(results: list[dict], key: str, context: str) -> Counter:
    counter = Counter()
    for run in results:
        values = run.get("doctrine", {}).get(key, {})
        context_values = values.get(context, {}) if isinstance(values, dict) else {}
        if isinstance(context_values, dict):
            counter.update({name: float(value) for name, value in context_values.items()})
    return counter


def economy_kind_counter(results: list[dict], key: str, kind: str) -> Counter:
    counter = Counter()
    for run in results:
        values = run.get("economy", {}).get(key, {})
        kind_values = values.get(kind, {}) if isinstance(values, dict) else {}
        if isinstance(kind_values, dict):
            counter.update({name: float(value) for name, value in kind_values.items()})
    return counter


def format_context_mix(results: list[dict], key: str, contexts: list[str], limit: int = 4) -> str:
    parts = []
    for context in contexts:
        counter = doctrine_context_counter(results, key, context)
        if counter:
            parts.append(f"{context}=[{format_counter_mix(counter, limit)}]")
    return "; ".join(parts) if parts else "none"


def format_economy_kind_mix(results: list[dict], key: str, kinds: list[str], limit: int = 4) -> str:
    parts = []
    for kind in kinds:
        counter = economy_kind_counter(results, key, kind)
        if counter:
            parts.append(f"{kind}=[{format_counter_mix(counter, limit)}]")
    return "; ".join(parts) if parts else "none"


def format_counter_mix(counter: Counter, limit: int = 5) -> str:
    total = sum(float(value) for value in counter.values())
    if total <= 0.0:
        return "none"
    parts = []
    for name, value in counter.most_common(limit):
        parts.append(f"{name}={100.0 * float(value) / total:.1f}%")
    return ", ".join(parts)


if __name__ == "__main__":
    results = load_runs(RUN_DIR)
    if not results:
        print(f"No results found in {RUN_DIR}.")
        raise SystemExit(1)

    durations = [r.get("core", {}).get("duration", 0.0) for r in results]
    stages = [r.get("core", {}).get("zone_stage_reached", 0) for r in results]
    attack_bouts = [r.get("combat", {}).get("attack_max_continuous", 0.0) for r in results]
    recover = [r.get("tactics", {}).get("recover_bouts", 0) for r in results]
    recover_success = [r.get("tactics", {}).get("recover_success", 0) for r in results]
    died_in_recover = [r.get("tactics", {}).get("died_in_recover", 0) for r in results]
    disengage = [r.get("tactics", {}).get("disengage_triggered", 0) for r in results]
    disengage_entries = [disengage_entry_count(r) for r in results]
    stuck = [r.get("tactics", {}).get("stuck_triggered", 0) for r in results]
    cover_peek = [r.get("tactics", {}).get("cover_peek", 0) for r in results]
    reposition = [r.get("tactics", {}).get("combat_reposition", 0) for r in results]
    kite = [r.get("tactics", {}).get("combat_kite", 0) for r in results]
    survival_break = [r.get("tactics", {}).get("survival_break", 0) for r in results]
    zone_escape_fire = [r.get("tactics", {}).get("zone_escape_fire", 0) for r in results]
    retreat_counterfire = [r.get("tactics", {}).get("retreat_counterfire", 0) for r in results]
    retreat_melee_counter = [r.get("tactics", {}).get("retreat_melee_counter", 0) for r in results]
    stuck_while_threatened = [r.get("tactics", {}).get("stuck_while_threatened", 0) for r in results]
    zone_assisted_death = [r.get("tactics", {}).get("zone_assisted_death", 0) for r in results]
    zone_deaths = [r.get("zone", {}).get("zone_deaths", 0) for r in results]
    max_outside_time = [r.get("zone", {}).get("max_outside_time", 0.0) for r in results]
    spawn_runs = [
        r.get("spawn", {})
        for r in results
        if int(r.get("spawn", {}).get("placed_count", 0)) > 0
    ]
    first_upgrade = [
        r.get("economy", {}).get("first_upgrade_time", -1.0)
        for r in results
        if r.get("economy", {}).get("first_upgrade_time", -1.0) >= 0
    ]

    total_recover = sum(recover)
    total_recover_success = sum(recover_success)
    total_recover_deaths = sum(died_in_recover)
    weapon_pickups = Counter()
    first_upgrade_weapons = Counter()
    for r in results:
        economy = r.get("economy", {})
        weapon_pickups.update(economy.get("weapon_pickups", {}))
        first_weapon = economy.get("first_upgrade_weapon", "none")
        if first_weapon != "none":
            first_upgrade_weapons[first_weapon] += 1
    pressure = [r.get("pressure", {}) for r in results]
    pressure_triggered = sum(p.get("pressure_triggered", 0) for p in pressure)
    pressure_resolved = sum(p.get("pressure_cleared", 0) + p.get("pressure_failed", 0) for p in pressure)
    disengage_reasons = Counter()
    disengage_reasons_by_archetype: dict[str, Counter] = {}
    doctrine_profiles = Counter()
    doctrine_plans = Counter()
    doctrine_supply = Counter()
    doctrine_plan_by_archetype: dict[str, Counter] = {}
    doctrine_state_time_by_archetype: dict[str, Counter] = {}
    doctrine_chase_context_by_archetype: dict[str, Counter] = {}
    doctrine_range_by_archetype: dict[str, dict[str, float]] = {}
    ai_samples = 0
    ai_total_usec = 0
    ai_max_usec = 0
    ai_state_buckets: dict[str, dict[str, float]] = {}
    for r in results:
        tactics = r.get("tactics", {})
        disengage_reasons.update(tactics.get("disengage_reasons", {}))
        for archetype, reasons in tactics.get("disengage_reasons_by_archetype", {}).items():
            disengage_reasons_by_archetype.setdefault(archetype, Counter()).update(reasons)
        doctrine = r.get("doctrine", {})
        doctrine_profiles.update(doctrine.get("profile_counts", {}))
        doctrine_plans.update(doctrine.get("combat_plan_counts", {}))
        doctrine_supply.update(doctrine.get("supply_decisions", {}))
        for archetype, plans in doctrine.get("plan_by_archetype", {}).items():
            doctrine_plan_by_archetype.setdefault(archetype, Counter()).update(plans)
        for archetype, states in doctrine.get("state_time_by_archetype", {}).items():
            doctrine_state_time_by_archetype.setdefault(archetype, Counter()).update(
                {state: float(seconds) for state, seconds in states.items()}
            )
        for archetype, contexts in doctrine.get("chase_context_time_by_archetype", {}).items():
            doctrine_chase_context_by_archetype.setdefault(archetype, Counter()).update(
                {context: float(seconds) for context, seconds in contexts.items()}
            )
        for archetype, bucket in doctrine.get("engage_range_by_archetype", {}).items():
            count = int(bucket.get("count", 0))
            if count <= 0:
                continue
            dst = doctrine_range_by_archetype.setdefault(
                archetype,
                {"count": 0.0, "total": 0.0, "min": float("inf"), "max": 0.0},
            )
            dst["count"] += count
            dst["total"] += float(bucket.get("total", 0.0))
            dst["min"] = min(dst["min"], float(bucket.get("min", dst["min"])))
            dst["max"] = max(dst["max"], float(bucket.get("max", dst["max"])))
        ai = r.get("ai", {})
        ai_samples += int(ai.get("update_samples", 0))
        ai_total_usec += int(ai.get("update_total_usec", 0))
        ai_max_usec = max(ai_max_usec, int(ai.get("update_max_usec", 0)))
        for state, bucket in ai.get("update_by_state", {}).items():
            count = int(bucket.get("samples", 0))
            if count <= 0:
                continue
            dst = ai_state_buckets.setdefault(state, {"samples": 0.0, "total_usec": 0.0, "max_usec": 0.0})
            dst["samples"] += count
            dst["total_usec"] += float(bucket.get("total_usec", 0.0))
            dst["max_usec"] = max(dst["max_usec"], float(bucket.get("max_usec", 0.0)))

    print("--- Simulation Analysis ---")
    print(f"Runs: {len(results)}")
    print(f"Avg duration: {avg(durations):.1f}s")
    print(f"Min/Max duration: {min(durations):.1f}s / {max(durations):.1f}s")
    print(f"Avg zone stage: {avg(stages):.2f}")
    print(f"Runs under 60s: {sum(1 for d in durations if d < 60.0)}")
    print(f"Avg/Max longest attack bout: {avg(attack_bouts):.1f}s / {max(attack_bouts):.1f}s")
    print(f"Recover success: {total_recover_success}/{total_recover} ({100.0 * total_recover_success / max(1, total_recover):.1f}%)")
    print(
        f"Died in RECOVER: {total_recover_deaths} "
        f"({avg(died_in_recover):.1f}/run, {100.0 * total_recover_deaths / max(1, total_recover):.1f}% of bouts)"
    )
    print(f"Avg disengage triggers: {avg(disengage):.1f}")
    print(f"Avg disengage entries: {avg(disengage_entries):.1f}")
    if disengage_reasons:
        reason_parts = []
        for reason, count in sorted(disengage_reasons.items(), key=lambda item: item[1], reverse=True):
            rate = per_spawned_entity_minute(
                results,
                lambda r, key=reason: r.get("tactics", {}).get("disengage_reasons", {}).get(key, 0),
            )
            reason_parts.append(f"{reason}={count} ({rate:.2f}/entity/min)")
        print(f"Disengage reasons: {', '.join(reason_parts)}")
    if disengage_reasons_by_archetype:
        print("Disengage reasons by archetype:")
        for archetype, reasons in sorted(disengage_reasons_by_archetype.items()):
            parts = [f"{reason}={count}" for reason, count in sorted(reasons.items(), key=lambda item: item[1], reverse=True)]
            print(f"  {archetype}: {', '.join(parts) if parts else 'none'}")
    print(f"Avg stuck triggers: {avg(stuck):.1f}")
    print(
        "Avg combat plans: cover={:.1f}, reposition={:.1f}, kite={:.1f}, survival={:.1f}".format(
            avg(cover_peek),
            avg(reposition),
            avg(kite),
            avg(survival_break),
        )
    )
    print(
        "Avg retreat combat: zone_fire={:.1f}, counterfire={:.1f}, melee={:.1f}, stuck_threat={:.1f}, zone_assist={:.1f}".format(
            avg(zone_escape_fire),
            avg(retreat_counterfire),
            avg(retreat_melee_counter),
            avg(stuck_while_threatened),
            avg(zone_assisted_death),
        )
    )
    print(
        "Scale-normalized per spawned entity/min: damage={:.1f}, shots={:.2f}, plans={:.2f}, disengage={:.2f}, entries={:.2f}, stuck={:.2f}, zone_fire={:.2f}, survival={:.2f}".format(
            per_spawned_entity_minute(results, lambda r: r.get("combat", {}).get("total_damage_dealt", 0.0)),
            per_spawned_entity_minute(results, lambda r: r.get("combat", {}).get("shots_fired", 0)),
            per_spawned_entity_minute(results, combat_plan_total),
            per_spawned_entity_minute(results, lambda r: r.get("tactics", {}).get("disengage_triggered", 0)),
            per_spawned_entity_minute(results, disengage_entry_count),
            per_spawned_entity_minute(results, lambda r: r.get("tactics", {}).get("stuck_triggered", 0)),
            per_spawned_entity_minute(results, lambda r: r.get("tactics", {}).get("zone_escape_fire", 0)),
            per_spawned_entity_minute(results, lambda r: r.get("tactics", {}).get("survival_break", 0)),
        )
    )
    print(
        "Match-normalized throughput/min: damage={:.1f}, shots={:.1f}, plans={:.1f}".format(
            per_match_minute(results, lambda r: r.get("combat", {}).get("total_damage_dealt", 0.0)),
            per_match_minute(results, lambda r: r.get("combat", {}).get("shots_fired", 0)),
            per_match_minute(results, combat_plan_total),
        )
    )
    hit_poi_roles = combat_location_counter(results, "hit_location_by_poi_role")
    damage_poi_roles = combat_location_counter(results, "damage_location_by_poi_role")
    kill_poi_roles = combat_location_counter(results, "kill_location_by_poi_role")
    hit_route_roles = combat_location_counter(results, "hit_location_by_route_role")
    damage_route_roles = combat_location_counter(results, "damage_location_by_route_role")
    kill_route_roles = combat_location_counter(results, "kill_location_by_route_role")
    damage_route_ids = combat_location_counter(results, "damage_location_by_route_id")
    if hit_poi_roles or damage_poi_roles or kill_poi_roles:
        print(
            "Combat location by POI role: hits=[{}], damage=[{}], kills=[{}]".format(
                format_counter_mix(hit_poi_roles),
                format_counter_mix(damage_poi_roles),
                format_counter_mix(kill_poi_roles),
            )
        )
    if hit_route_roles or damage_route_roles or kill_route_roles:
        print(
            "Combat route pressure: hits=[{}], damage=[{}], kills=[{}], damage route ids=[{}]".format(
                format_counter_mix(hit_route_roles),
                format_counter_mix(damage_route_roles),
                format_counter_mix(kill_route_roles),
                format_counter_mix(damage_route_ids),
            )
        )
    print(
        "Economy-normalized per spawned entity/min: weapons={:.2f}, non_pistol={:.2f}, rare={:.2f}, heals={:.2f}, shields={:.2f}".format(
            per_spawned_entity_minute(results, weapon_pickup_total),
            per_spawned_entity_minute(results, non_pistol_pickup_total),
            per_spawned_entity_minute(results, lambda r: r.get("economy", {}).get("rare_pickups", 0)),
            per_spawned_entity_minute(results, lambda r: r.get("economy", {}).get("heals_used", 0)),
            per_spawned_entity_minute(results, lambda r: r.get("economy", {}).get("shields_picked", 0)),
        )
    )
    pickup_kinds = ["weapon", "ammo", "heal", "armor"]
    spawn_route_mix = format_economy_kind_mix(results, "pickup_spawn_route_role_by_kind", pickup_kinds)
    collect_route_mix = format_economy_kind_mix(results, "pickup_collect_route_role_by_kind", pickup_kinds)
    spawn_poi_mix = format_economy_kind_mix(results, "pickup_spawn_poi_role_by_kind", pickup_kinds)
    collect_poi_mix = format_economy_kind_mix(results, "pickup_collect_poi_role_by_kind", pickup_kinds)
    spawn_poi_band_mix = format_economy_kind_mix(results, "pickup_spawn_poi_band_by_kind", pickup_kinds)
    collect_poi_band_mix = format_economy_kind_mix(results, "pickup_collect_poi_band_by_kind", pickup_kinds)
    if spawn_route_mix != "none" or collect_route_mix != "none":
        print(f"Pickup spawn route by kind: {spawn_route_mix}")
        print(f"Pickup collect route by kind: {collect_route_mix}")
        print(f"Pickup spawn POI by kind: {spawn_poi_mix}")
        print(f"Pickup collect POI by kind: {collect_poi_mix}")
        print(f"Pickup spawn POI band by kind: {spawn_poi_band_mix}")
        print(f"Pickup collect POI band by kind: {collect_poi_band_mix}")
    print(f"Zone deaths: {sum(zone_deaths)} ({avg(zone_deaths):.1f}/run), max outside time: {max(max_outside_time):.1f}s")
    if spawn_runs:
        placed = [int(s.get("placed_count", 0)) for s in spawn_runs]
        requested = [int(s.get("requested_count", 0)) for s in spawn_runs]
        fallback = [int(s.get("fallback_count", 0)) for s in spawn_runs]
        min_nearest = [float(s.get("min_nearest_distance", 0.0)) for s in spawn_runs]
        avg_nearest = [float(s.get("avg_nearest_distance", 0.0)) for s in spawn_runs]
        avg_attempts = [float(s.get("avg_attempts", 0.0)) for s in spawn_runs]
        max_attempts = [int(s.get("attempt_max", 0)) for s in spawn_runs]
        saturation = [float(s.get("annulus_saturation", 0.0)) for s in spawn_runs]
        print(
            "Spawn distribution: placed={:.1f}/{:.1f}, fallback={:.1f}/run, min_nearest avg/min={:.1f}/{:.1f}m, avg_nearest={:.1f}m".format(
                avg(placed),
                avg(requested),
                avg(fallback),
                avg(min_nearest),
                min(min_nearest),
                avg(avg_nearest),
            )
        )
        print(
            "Spawn attempts: avg={:.1f}, max={}, saturation={:.2f}".format(
                avg(avg_attempts),
                max(max_attempts),
                avg(saturation),
            )
        )
    if first_upgrade:
        print(f"Avg first upgrade: {avg(first_upgrade):.1f}s")
    if first_upgrade_weapons:
        first_parts = [f"{weapon}={count}" for weapon, count in sorted(first_upgrade_weapons.items())]
        print(f"First upgrade weapons: {', '.join(first_parts)}")
    if weapon_pickups:
        pickup_parts = [f"{weapon}={count}" for weapon, count in sorted(weapon_pickups.items())]
        print(f"Weapon pickups: {', '.join(pickup_parts)}")
    if doctrine_profiles:
        profile_parts = [f"{name}={count}" for name, count in sorted(doctrine_profiles.items())]
        print(f"Doctrine profiles: {', '.join(profile_parts)}")
    if doctrine_plans:
        plan_parts = [f"{plan}={count}" for plan, count in sorted(doctrine_plans.items()) if count]
        print(f"Doctrine plans: {', '.join(plan_parts) if plan_parts else 'none'}")
    if doctrine_plan_by_archetype:
        print("Doctrine plans by archetype:")
        for archetype, plans in sorted(doctrine_plan_by_archetype.items()):
            parts = [f"{plan}={count}" for plan, count in sorted(plans.items()) if count]
            print(f"  {archetype}: {', '.join(parts) if parts else 'none'}")
    if doctrine_state_time_by_archetype:
        print("Doctrine state time by archetype:")
        for archetype, states in sorted(doctrine_state_time_by_archetype.items()):
            parts = [
                f"{state}={seconds:.1f}s"
                for state, seconds in sorted(states.items(), key=lambda item: item[1], reverse=True)
                if seconds > 0.0
            ]
            print(f"  {archetype}: {', '.join(parts) if parts else 'none'}")
        state_totals = Counter()
        for states in doctrine_state_time_by_archetype.values():
            state_totals.update(states)
        total_state_time = sum(float(seconds) for seconds in state_totals.values())
        if total_state_time > 0.0:
            parts = [
                f"{state}={100.0 * float(seconds) / total_state_time:.1f}%"
                for state, seconds in sorted(state_totals.items(), key=lambda item: item[1], reverse=True)
                if float(seconds) > 0.0
            ]
            print(f"Doctrine state mix: {', '.join(parts)}")
            active_share = 100.0 * (
                float(state_totals.get("ATTACK", 0.0)) + float(state_totals.get("CHASE", 0.0))
            ) / total_state_time
            retreat_share = 100.0 * (
                float(state_totals.get("DISENGAGE", 0.0)) + float(state_totals.get("ZONE_ESCAPE", 0.0))
            ) / total_state_time
            attack_minutes = float(state_totals.get("ATTACK", 0.0)) / 60.0
            damage_per_attack_min = (
                sum(float(r.get("combat", {}).get("total_damage_dealt", 0.0)) for r in results)
                / max(1.0, attack_minutes)
            )
            shots_per_attack_min = (
                sum(float(r.get("combat", {}).get("shots_fired", 0)) for r in results) / max(1.0, attack_minutes)
            )
            print(
                "Engagement density: active_state={:.1f}%, retreat_escape={:.1f}%, damage/ATTACK_min={:.1f}, shots/ATTACK_min={:.1f}, engage_samples/entity/min={:.2f}".format(
                    active_share,
                    retreat_share,
                    damage_per_attack_min,
                    shots_per_attack_min,
                    per_spawned_entity_minute(results, doctrine_engage_sample_count),
                )
            )
    if doctrine_chase_context_by_archetype:
        print("Doctrine CHASE context by archetype:")
        chase_totals = Counter()
        for archetype, contexts in sorted(doctrine_chase_context_by_archetype.items()):
            chase_totals.update(contexts)
            parts = [
                f"{context}={seconds:.1f}s"
                for context, seconds in sorted(contexts.items(), key=lambda item: item[1], reverse=True)
                if float(seconds) > 0.0
            ]
            print(f"  {archetype}: {', '.join(parts) if parts else 'none'}")
        total_chase_context = sum(float(seconds) for seconds in chase_totals.values())
        if total_chase_context > 0.0:
            parts = [
                f"{context}={100.0 * float(seconds) / total_chase_context:.1f}%"
                for context, seconds in sorted(chase_totals.items(), key=lambda item: item[1], reverse=True)
                if float(seconds) > 0.0
            ]
            print(f"CHASE context mix: {', '.join(parts)}")
        chase_contexts = ["combat", "loot", "recover_loot"]
        self_poi_mix = format_context_mix(results, "chase_self_poi_role_by_context", chase_contexts)
        target_poi_mix = format_context_mix(results, "chase_target_poi_role_by_context", chase_contexts)
        target_route_mix = format_context_mix(results, "chase_target_route_role_by_context", chase_contexts)
        target_kind_mix = format_context_mix(results, "chase_target_kind_by_context", chase_contexts)
        self_poi_band_mix = format_context_mix(results, "chase_self_poi_band_by_context", chase_contexts)
        target_poi_band_mix = format_context_mix(results, "chase_target_poi_band_by_context", chase_contexts)
        target_route_band_mix = format_context_mix(results, "chase_target_route_band_by_context", chase_contexts)
        if self_poi_mix != "none" or target_poi_mix != "none" or target_kind_mix != "none":
            print(f"CHASE self POI by context: {self_poi_mix}")
            print(f"CHASE target POI by context: {target_poi_mix}")
            print(f"CHASE target route by context: {target_route_mix}")
            print(f"CHASE self POI band by context: {self_poi_band_mix}")
            print(f"CHASE target POI band by context: {target_poi_band_mix}")
            print(f"CHASE target route band by context: {target_route_band_mix}")
            print(f"CHASE target kind by context: {target_kind_mix}")
    if doctrine_range_by_archetype:
        print("Doctrine engage range by archetype:")
        for archetype, bucket in sorted(doctrine_range_by_archetype.items()):
            count = max(1.0, bucket["count"])
            print(
                f"  {archetype}: avg={bucket['total'] / count:.1f}m "
                f"min={bucket['min']:.1f}m max={bucket['max']:.1f}m n={int(bucket['count'])}"
            )
    if doctrine_supply:
        supply_parts = [f"{decision}={count}" for decision, count in sorted(doctrine_supply.items())]
        print(f"Doctrine supply: {', '.join(supply_parts)}")
    if ai_samples > 0:
        print(f"AI update budget: samples={ai_samples}, avg={ai_total_usec / ai_samples:.1f}us, max={ai_max_usec}us")
        top_states = sorted(
            ai_state_buckets.items(),
            key=lambda item: item[1]["total_usec"] / max(1.0, item[1]["samples"]),
            reverse=True,
        )[:4]
        if top_states:
            print("AI update by state:")
            for state, bucket in top_states:
                samples = max(1.0, bucket["samples"])
                print(
                    f"  {state}: avg={bucket['total_usec'] / samples:.1f}us "
                    f"max={bucket['max_usec']:.0f}us n={int(bucket['samples'])}"
                )
    if pressure_triggered:
        print(f"Pressure resolved: {pressure_resolved}/{pressure_triggered}")

    zero_damage_runs = run_numbers(
        results,
        lambda r: float(r.get("combat", {}).get("total_damage_dealt", 0.0)) <= 0.0,
    )
    zero_weapon_damage_runs = run_numbers(
        results,
        lambda r: sum(float(v) for v in r.get("combat", {}).get("damage_by_weapon", {}).values()) <= 0.0,
    )
    zero_shot_runs = run_numbers(
        results,
        lambda r: int(r.get("combat", {}).get("shots_fired", 0)) <= 0,
    )
    zero_plan_runs = run_numbers(results, lambda r: combat_plan_total(r) <= 0)

    print("Regression sentinels:")
    print(f"  zero total damage runs: {zero_damage_runs or 'none'}")
    print(f"  zero weapon damage runs: {zero_weapon_damage_runs or 'none'}")
    print(f"  zero shot runs: {zero_shot_runs or 'none'}")
    print(f"  zero combat plan runs: {zero_plan_runs or 'none'}")
    if zero_damage_runs or zero_weapon_damage_runs or zero_shot_runs or zero_plan_runs:
        print("  WARNING: investigate combat/perception/damage before tuning duration targets.")
