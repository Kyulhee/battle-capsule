import argparse
import json
from collections import Counter
from pathlib import Path


DEFAULT_TARGET_MIN_SECONDS = 600.0
DEFAULT_TARGET_MAX_SECONDS = 900.0


def load_runs(run_dir: Path) -> list[dict]:
    summary = run_dir / "summary.json"
    if summary.exists():
        with summary.open("r", encoding="utf-8") as f:
            return json.load(f)

    runs: list[dict] = []
    for path in sorted(run_dir.glob("run_*.json")):
        with path.open("r", encoding="utf-8") as f:
            runs.append(json.load(f))
    return runs


def avg(values: list[float]) -> float:
    return sum(values) / max(1, len(values))


def positive_values(runs: list[dict], group: str, key: str) -> list[float]:
    values: list[float] = []
    for run in runs:
        raw = run.get(group, {}).get(key, -1.0)
        try:
            value = float(raw)
        except (TypeError, ValueError):
            continue
        if value >= 0.0:
            values.append(value)
    return values


def numeric_values(runs: list[dict], group: str, key: str) -> list[float]:
    values: list[float] = []
    for run in runs:
        raw = run.get(group, {}).get(key)
        try:
            values.append(float(raw))
        except (TypeError, ValueError):
            continue
    return values


def string_counter(runs: list[dict], group: str, key: str) -> Counter:
    counter = Counter()
    for run in runs:
        value = str(run.get(group, {}).get(key, "none"))
        if value and value != "none":
            counter[value] += 1
    return counter


def stage_times(runs: list[dict], stage_key: str) -> list[float]:
    values: list[float] = []
    for run in runs:
        stage_data = run.get("pacing", {}).get("stage_times", {})
        if not isinstance(stage_data, dict) or stage_key not in stage_data:
            continue
        try:
            values.append(float(stage_data[stage_key]))
        except (TypeError, ValueError):
            continue
    return values


def first_upgrade_times(runs: list[dict]) -> list[float]:
    pacing = positive_values(runs, "pacing", "first_non_pistol_upgrade_time")
    if pacing:
        return pacing
    return positive_values(runs, "economy", "first_upgrade_time")


def counter_from_group(runs: list[dict], group: str, key: str) -> Counter:
    counter = Counter()
    for run in runs:
        values = run.get(group, {}).get(key, {})
        if isinstance(values, dict):
            counter.update({name: float(value) for name, value in values.items()})
    return counter


def nested_counter(runs: list[dict], group: str, key: str) -> Counter:
    counter = Counter()
    for run in runs:
        values = run.get(group, {}).get(key, {})
        if not isinstance(values, dict):
            continue
        for nested in values.values():
            if isinstance(nested, dict):
                counter.update({name: float(value) for name, value in nested.items()})
    return counter


def format_optional_seconds(values: list[float]) -> str:
    return f"{avg(values):.1f}s" if values else "none"


def format_mix(counter: Counter, limit: int = 5) -> str:
    total = sum(float(value) for value in counter.values())
    if total <= 0.0:
        return "none"
    return ", ".join(
        f"{name}={100.0 * float(value) / total:.1f}%"
        for name, value in counter.most_common(limit)
    )


def target_phase_for_time(seconds: float, target_min: float, target_max: float) -> str:
    if seconds < 0.0:
        return "missing"
    target_mid = (target_min + target_max) * 0.5
    ratio = seconds / max(1.0, target_mid)
    if ratio < 0.13:
        return "0-2m spawn/opening"
    if ratio < 0.33:
        return "2-5m first fights/upgrades"
    if ratio < 0.60:
        return "5-9m rotations/re-entry"
    if ratio < 0.80:
        return "9-12m compression"
    return "12-15m final"


def print_milestone(label: str, values: list[float], durations: list[float], target_min: float, target_max: float) -> None:
    if not values:
        print(f"{label}: none")
        return
    value = avg(values)
    duration_ratio = 100.0 * value / max(1.0, avg(durations))
    target_ratio = 100.0 * value / max(1.0, (target_min + target_max) * 0.5)
    print(
        f"{label}: {value:.1f}s "
        f"({duration_ratio:.1f}% of current avg match, {target_ratio:.1f}% of 10-15m midpoint; "
        f"target-phase={target_phase_for_time(value, target_min, target_max)})"
    )


def print_interpretation(durations: list[float], target_min: float, target_max: float) -> None:
    current_avg = avg(durations)
    target_mid = (target_min + target_max) * 0.5
    print("Interpretation:")
    if current_avg < target_min * 0.35:
        print("  - This sample is a compressed structural smoke, not a playable 10-15 minute pacing baseline.")
    elif current_avg < target_min * 0.70:
        print("  - This sample is still shorter than the intended match, but milestone ordering can inform the next tuning plan.")
    elif current_avg < target_min:
        print("  - This sample is close to the target floor, but still shorter than the intended match.")
    elif current_avg <= target_max:
        print("  - This sample is within the target duration band; pacing milestones can be evaluated as candidate gameplay values.")
    else:
        print("  - This sample is longer than the target band; inspect late-game compression after hard safety gates pass.")

    print(f"  - Duration scale-up needed to 10m floor: {target_min / max(1.0, current_avg):.2f}x.")
    print(f"  - Duration scale-up needed to 12.5m midpoint: {target_mid / max(1.0, current_avg):.2f}x.")
    print("  - Do not lower structural scale gates based on this report.")


def print_opening_pressure(runs: list[dict], first_contact: list[float]) -> None:
    fallback = numeric_values(runs, "spawn", "fallback_count")
    min_nearest = numeric_values(runs, "spawn", "min_nearest_distance")
    avg_nearest = numeric_values(runs, "spawn", "avg_nearest_distance")
    saturation = numeric_values(runs, "spawn", "annulus_saturation")
    avg_attempts = numeric_values(runs, "spawn", "avg_attempts")
    max_attempts = numeric_values(runs, "spawn", "attempt_max")
    first_acquisition = positive_values(runs, "pacing", "first_target_acquisition_time")
    first_acquisition_distance = positive_values(runs, "pacing", "first_target_acquisition_distance")
    acquisition_sources = string_counter(runs, "pacing", "first_target_acquisition_source")
    acquisition_states = string_counter(runs, "pacing", "first_target_acquisition_state")
    acquisition_poi_bands = string_counter(runs, "pacing", "first_target_acquisition_poi_band")
    acquisition_route_bands = string_counter(runs, "pacing", "first_target_acquisition_route_band")
    first_objective_interrupt = positive_values(runs, "pacing", "first_objective_interrupt_time")
    first_objective_interrupt_enemy_distance = positive_values(runs, "pacing", "first_objective_interrupt_enemy_distance")
    first_objective_interrupt_objective_distance = positive_values(runs, "pacing", "first_objective_interrupt_objective_distance")
    objective_interrupt_sources = string_counter(runs, "pacing", "first_objective_interrupt_source")
    objective_interrupt_kinds = string_counter(runs, "pacing", "first_objective_interrupt_kind")
    objective_interrupt_needs = string_counter(runs, "pacing", "first_objective_interrupt_need")
    objective_interrupt_matches = string_counter(runs, "pacing", "first_objective_interrupt_target_match")
    if not any([fallback, min_nearest, avg_nearest, saturation, avg_attempts, max_attempts, first_acquisition, first_objective_interrupt]):
        return
    print("Opening pressure:")
    if fallback:
        print(f"  spawn fallback: {avg(fallback):.1f}/run")
    if min_nearest or avg_nearest:
        min_nearest_text = f"{min(min_nearest):.1f}m" if min_nearest else "none"
        avg_min_text = f"{avg(min_nearest):.1f}m" if min_nearest else "none"
        avg_nearest_text = f"{avg(avg_nearest):.1f}m" if avg_nearest else "none"
        print(
            "  spawn nearest: "
            f"min={min_nearest_text}, avg-min={avg_min_text}, avg-nearest={avg_nearest_text}"
        )
    if saturation or avg_attempts or max_attempts:
        saturation_text = f"{avg(saturation):.2f}" if saturation else "none"
        avg_attempts_text = f"{avg(avg_attempts):.1f}" if avg_attempts else "none"
        max_attempts_text = f"{max(max_attempts):.0f}" if max_attempts else "none"
        print(
            "  spawn packing: "
            f"saturation={saturation_text}, attempts={avg_attempts_text}/{max_attempts_text} max"
        )
    if first_acquisition:
        print(
            "  first target acquisition: "
            f"{avg(first_acquisition):.1f}s, distance={avg(first_acquisition_distance):.1f}m, "
            f"sources=[{format_mix(acquisition_sources)}], states=[{format_mix(acquisition_states)}]"
        )
        print(
            "  acquisition bands: "
            f"poi=[{format_mix(acquisition_poi_bands)}], route=[{format_mix(acquisition_route_bands)}]"
        )
        if first_contact:
            contact_gap = avg(first_contact) - avg(first_acquisition)
            print(f"  acquisition-to-contact gap: {contact_gap:.1f}s")
    if first_objective_interrupt:
        print(
            "  first objective interrupt: "
            f"{avg(first_objective_interrupt):.1f}s, enemy={avg(first_objective_interrupt_enemy_distance):.1f}m, "
            f"objective={avg(first_objective_interrupt_objective_distance):.1f}m, "
            f"sources=[{format_mix(objective_interrupt_sources)}], kinds=[{format_mix(objective_interrupt_kinds)}]"
        )
        print(
            "  objective interrupt detail: "
            f"needs=[{format_mix(objective_interrupt_needs)}], matches=[{format_mix(objective_interrupt_matches)}]"
        )
    if first_contact and min_nearest and avg(first_contact) < 5.0:
        print("  read: sub-5s first contact is still opening spawn/proximity pressure, not zone pacing.")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Summarize pacing telemetry against the 10-15 minute Night BR target."
    )
    parser.add_argument("run_dir", nargs="?", default="tools/sim_runs_current")
    parser.add_argument("--target-min-seconds", type=float, default=DEFAULT_TARGET_MIN_SECONDS)
    parser.add_argument("--target-max-seconds", type=float, default=DEFAULT_TARGET_MAX_SECONDS)
    args = parser.parse_args()

    runs = load_runs(Path(args.run_dir))
    if not runs:
        print(f"No runs found in {args.run_dir}.")
        return 1

    durations = [float(run.get("core", {}).get("duration", 0.0)) for run in runs]
    first_shot = positive_values(runs, "pacing", "first_shot_time")
    first_contact = positive_values(runs, "pacing", "first_contact_time")
    first_damage = positive_values(runs, "pacing", "first_damage_time")
    first_kill = positive_values(runs, "pacing", "first_kill_time")
    first_upgrade = first_upgrade_times(runs)
    stage2 = stage_times(runs, "2")
    stage3 = stage_times(runs, "3")

    chase_context = nested_counter(runs, "doctrine", "chase_context_time_by_archetype")
    self_route = nested_counter(runs, "doctrine", "chase_self_route_role_by_context")
    target_route = nested_counter(runs, "doctrine", "chase_target_route_role_by_context")
    stuck_cells = counter_from_group(runs, "tactics", "stuck_by_cell")
    stuck_routes = counter_from_group(runs, "tactics", "stuck_by_route_id")

    print("--- Pacing Baseline Report ---")
    print(f"Runs: {len(runs)}")
    print(f"Avg duration: {avg(durations):.1f}s")
    print(f"Min/Max duration: {min(durations):.1f}s / {max(durations):.1f}s")
    print(f"Target duration: {args.target_min_seconds:.0f}-{args.target_max_seconds:.0f}s")
    print_interpretation(durations, args.target_min_seconds, args.target_max_seconds)
    print("Milestones:")
    print_milestone("  first shot", first_shot, durations, args.target_min_seconds, args.target_max_seconds)
    print_milestone("  first contact", first_contact, durations, args.target_min_seconds, args.target_max_seconds)
    print_milestone("  first damage", first_damage, durations, args.target_min_seconds, args.target_max_seconds)
    print_milestone("  first kill", first_kill, durations, args.target_min_seconds, args.target_max_seconds)
    print_milestone("  first non-pistol upgrade", first_upgrade, durations, args.target_min_seconds, args.target_max_seconds)
    print_milestone("  stage 2", stage2, durations, args.target_min_seconds, args.target_max_seconds)
    print_milestone("  stage 3", stage3, durations, args.target_min_seconds, args.target_max_seconds)
    print_opening_pressure(runs, first_contact)
    print("Movement pressure:")
    print(f"  CHASE context dwell: {format_mix(chase_context)}")
    print(f"  self route dwell: {format_mix(self_route)}")
    print(f"  target route dwell: {format_mix(target_route)}")
    if stuck_cells or stuck_routes:
        print("Pathing watch:")
        print(f"  stuck route ids: {format_mix(stuck_routes)}")
        print(f"  stuck cells: {format_mix(stuck_cells)}")
    print("Next read:")
    print("  - Use this as a gap report before changing zone, loot, or combat numbers.")
    print("  - If structural gates fail, fix the structural failure first and rerun this report.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
