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
    disengage_events = sum(int(r.get("tactics", {}).get("disengage_triggered", 0)) for r in runs)
    state_totals = doctrine_state_totals(runs)
    state_mix = doctrine_state_mix(runs)
    summary = {
        "runs": float(len(runs)),
        "spawned_entities": avg([float(spawned_entity_count(r)) for r in runs]),
        "duration": avg(durations),
        "first_upgrade": avg(first_upgrade) if first_upgrade else -1.0,
        "damage_per_entity_min": per_spawned_entity_minute(
            runs, lambda r: r.get("combat", {}).get("total_damage_dealt", 0.0)
        ),
        "shots_per_entity_min": per_spawned_entity_minute(
            runs, lambda r: r.get("combat", {}).get("shots_fired", 0)
        ),
        "plans_per_entity_min": per_spawned_entity_minute(runs, combat_plan_total),
        "disengage_per_entity_min": per_spawned_entity_minute(
            runs, lambda r: r.get("tactics", {}).get("disengage_triggered", 0)
        ),
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
        "disengage_seconds_per_trigger": float(state_totals.get("DISENGAGE", 0.0)) / max(1, disengage_events),
        "state_zone_escape": state_mix.get("ZONE_ESCAPE", 0.0),
        "state_disengage": state_mix.get("DISENGAGE", 0.0),
        "state_attack": state_mix.get("ATTACK", 0.0),
        "state_chase": state_mix.get("CHASE", 0.0),
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
        ("shots_per_entity_min", "shots/entity/min"),
        ("plans_per_entity_min", "plans/entity/min"),
        ("disengage_per_entity_min", "disengage/entity/min"),
        ("stuck_per_entity_min", "stuck/entity/min"),
        ("zone_fire_per_entity_min", "zone fire/entity/min"),
        ("survival_per_entity_min", "survival/entity/min"),
        ("ai_avg_usec", "AI avg usec"),
        ("ai_max_usec", "AI max usec"),
        ("disengage_seconds_per_trigger", "DISENGAGE sec/trigger"),
        ("state_zone_escape", "state ZONE_ESCAPE %"),
        ("state_disengage", "state DISENGAGE %"),
        ("state_attack", "state ATTACK %"),
        ("state_chase", "state CHASE %"),
        ("state_idle", "state IDLE %"),
    ]
    print("--- Scale Profile Comparison ---")
    print(f"{'Metric':<28} {label_a:>14} {label_b:>14} {'delta':>14}")
    for key, label in metrics:
        a = float(summary_a.get(key, 0.0))
        b = float(summary_b.get(key, 0.0))
        print(f"{label:<28} {a:>14.2f} {b:>14.2f} {b - a:>14.2f}")
    print_pressure_decision(summary_a, summary_b)


def print_pressure_decision(summary_a: dict[str, float], summary_b: dict[str, float]) -> None:
    spawn_fallback_delta = float(summary_b.get("spawn_fallback_per_run", 0.0)) - float(
        summary_a.get("spawn_fallback_per_run", 0.0)
    )
    min_nearest = float(summary_b.get("spawn_min_nearest", 0.0))
    ai_delta = float(summary_b.get("ai_avg_usec", 0.0)) - float(summary_a.get("ai_avg_usec", 0.0))
    disengage_rate_delta = float(summary_b.get("disengage_per_entity_min", 0.0)) - float(
        summary_a.get("disengage_per_entity_min", 0.0)
    )
    disengage_share_delta = float(summary_b.get("state_disengage", 0.0)) - float(
        summary_a.get("state_disengage", 0.0)
    )
    disengage_duration_delta = float(summary_b.get("disengage_seconds_per_trigger", 0.0)) - float(
        summary_a.get("disengage_seconds_per_trigger", 0.0)
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
            "  - DISENGAGE pressure looks duration/exit-related, not trigger-frequency-related "
            "(state share rose while normalized trigger rate did not)."
        )
    elif disengage_share_delta >= 4.0:
        print("  - DISENGAGE pressure looks trigger-frequency-related; inspect outnumbered thresholds and scan density.")
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
