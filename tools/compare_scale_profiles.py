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
    ]
    print("--- Scale Profile Comparison ---")
    print(f"{'Metric':<28} {label_a:>14} {label_b:>14} {'delta':>14}")
    for key, label in metrics:
        a = float(summary_a.get(key, 0.0))
        b = float(summary_b.get(key, 0.0))
        print(f"{label:<28} {a:>14.2f} {b:>14.2f} {b - a:>14.2f}")
    print_disengage_reason_comparison(label_a, summary_a, label_b, summary_b)
    print_tempo_decision(summary_a, summary_b)
    print_engagement_density_decision(summary_a, summary_b)
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
