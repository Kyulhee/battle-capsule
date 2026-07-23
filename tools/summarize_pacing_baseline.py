import argparse
import json
from collections import Counter
from pathlib import Path


DEFAULT_TARGET_MIN_SECONDS = 600.0
DEFAULT_TARGET_MAX_SECONDS = 900.0
FIRST_CONTACT_BAND_SECONDS = (45.0, 150.0)
FIRST_KILL_BAND_SECONDS = (60.0, 210.0)
FIRST_UPGRADE_BAND_SECONDS = (2.0, 30.0)
STAGE2_BAND_SECONDS = (240.0, 420.0)
STAGE3_BAND_SECONDS = (540.0, 720.0)


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


def sample_time(pacing: dict, key: str) -> str:
    try:
        value = float(pacing.get(key, -1.0))
    except (TypeError, ValueError):
        return "none"
    return f"{value:.1f}s" if value >= 0.0 else "none"


def sample_distance(pacing: dict, key: str) -> str:
    try:
        value = float(pacing.get(key, -1.0))
    except (TypeError, ValueError):
        return "none"
    return f"{value:.1f}m" if value >= 0.0 else "none"


def sample_ratio(pacing: dict, key: str) -> str:
    try:
        value = float(pacing.get(key, -1.0))
    except (TypeError, ValueError):
        return "none"
    return f"{value:.2f}" if value >= 0.0 else "none"


def sample_float(pacing: dict, key: str) -> float:
    try:
        return float(pacing.get(key, -1.0))
    except (TypeError, ValueError):
        return -1.0


def sample_gap(pacing: dict, start_key: str, end_key: str) -> str:
    start = sample_float(pacing, start_key)
    end = sample_float(pacing, end_key)
    if start < 0.0 or end < 0.0:
        return "none"
    return f"{end - start:.1f}s"


def hard_bump_marker(pacing: dict) -> str:
    distance = sample_float(pacing, "first_target_acquisition_distance")
    if distance < 0.0:
        return "unknown"
    return "yes" if distance <= 1.05 else "no"


def hard_bump_impact_summary(runs: list[dict]) -> str:
    acquisition_count = 0
    hard_bump_count = 0
    hard_bump_gaps: list[float] = []
    hard_bump_delayed_count = 0
    for run in runs:
        pacing = run.get("pacing", {})
        if not isinstance(pacing, dict):
            continue
        acq_time = sample_float(pacing, "first_target_acquisition_time")
        if acq_time < 0.0:
            continue
        acquisition_count += 1
        distance = sample_float(pacing, "first_target_acquisition_distance")
        if distance > 1.05:
            continue
        hard_bump_count += 1
        contact_time = sample_float(pacing, "first_contact_time")
        if contact_time >= 0.0:
            gap = contact_time - acq_time
            hard_bump_gaps.append(gap)
            if gap >= 5.0:
                hard_bump_delayed_count += 1
    if acquisition_count <= 0:
        return ""
    avg_gap = avg(hard_bump_gaps) if hard_bump_gaps else -1.0
    avg_gap_text = f"{avg_gap:.1f}s" if avg_gap >= 0.0 else "none"
    return (
        f"  hard-bump acquisition impact: {hard_bump_count}/{acquisition_count} runs, "
        f"avg-contact-gap={avg_gap_text}, delayed-5s-plus={hard_bump_delayed_count}, "
        "read=contact-gap-not-acquisition-only"
    )


def opening_sample_lines(runs: list[dict]) -> list[str]:
    lines: list[str] = []
    for index, run in enumerate(runs, start=1):
        pacing = run.get("pacing", {})
        if not isinstance(pacing, dict):
            continue
        if sample_time(pacing, "first_target_acquisition_time") == "none":
            continue
        lines.append(
            "  run {}: acq={} source={} state={} dist={} hard_bump={} target={}/{} self={}/{} zone={}/{} spawn_age={} contact={} gap={} objective_interrupt={} obj_enemy={} obj_target={}".format(
                index,
                sample_time(pacing, "first_target_acquisition_time"),
                pacing.get("first_target_acquisition_source", "none"),
                pacing.get("first_target_acquisition_state", "none"),
                sample_distance(pacing, "first_target_acquisition_distance"),
                hard_bump_marker(pacing),
                pacing.get("first_target_acquisition_poi_band", "none"),
                pacing.get("first_target_acquisition_route_band", "none"),
                pacing.get("first_target_acquisition_self_poi_band", "none"),
                pacing.get("first_target_acquisition_self_route_band", "none"),
                sample_ratio(pacing, "first_target_acquisition_zone_ratio"),
                pacing.get("first_target_acquisition_zone_status", "unknown"),
                sample_time(pacing, "first_target_acquisition_spawn_age"),
                sample_time(pacing, "first_contact_time"),
                sample_gap(pacing, "first_target_acquisition_time", "first_contact_time"),
                sample_time(pacing, "first_objective_interrupt_time"),
                sample_distance(pacing, "first_objective_interrupt_enemy_distance"),
                sample_distance(pacing, "first_objective_interrupt_objective_distance"),
            )
        )
    return lines


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


def open_damage_context_counters(runs: list[dict]) -> tuple[Counter, Counter, Counter, Counter]:
    cells = Counter()
    nearest_pois = Counter()
    edge_bands = Counter()
    contexts = Counter()
    for run in runs:
        values = run.get("combat", {}).get("open_damage_by_context", {})
        if not isinstance(values, dict):
            continue
        for raw_context, raw_value in values.items():
            parts = str(raw_context).split("|", 2)
            if len(parts) != 3:
                continue
            cell, nearest_poi, edge_band = parts
            value = float(raw_value)
            cells[cell] += value
            nearest_pois[nearest_poi] += value
            edge_bands[edge_band] += value
            contexts[f"{cell}->{nearest_poi}/{edge_band}"] += value
    return cells, nearest_pois, edge_bands, contexts


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


def band_status_line(label: str, values: list[float], floor: float, ceiling: float) -> str:
    if not values:
        return f"  {label}: none vs {floor:.0f}-{ceiling:.0f}s -> missing"
    value = avg(values)
    if value < floor:
        return (
            f"  {label}: {value:.1f}s vs {floor:.0f}-{ceiling:.0f}s "
            f"-> early by {floor - value:.1f}s"
        )
    if value > ceiling:
        return (
            f"  {label}: {value:.1f}s vs {floor:.0f}-{ceiling:.0f}s "
            f"-> late by {value - ceiling:.1f}s"
        )
    return f"  {label}: {value:.1f}s vs {floor:.0f}-{ceiling:.0f}s -> in band"


def values_in_band(values: list[float], floor: float, ceiling: float) -> bool:
    return bool(values) and floor <= avg(values) <= ceiling


def print_phase_gap_read(
    durations: list[float],
    first_contact: list[float],
    first_kill: list[float],
    first_upgrade: list[float],
    stage2: list[float],
    stage3: list[float],
    target_min: float,
    target_max: float,
) -> None:
    print("Phase gap read:")
    print(band_status_line("first contact", first_contact, *FIRST_CONTACT_BAND_SECONDS))
    print(band_status_line("first kill", first_kill, *FIRST_KILL_BAND_SECONDS))
    print(band_status_line("first non-pistol upgrade", first_upgrade, *FIRST_UPGRADE_BAND_SECONDS))
    print(band_status_line("stage 2", stage2, *STAGE2_BAND_SECONDS))
    print(band_status_line("stage 3", stage3, *STAGE3_BAND_SECONDS))
    print(band_status_line("match end", durations, target_min, target_max))

    duration_short = avg(durations) < target_min
    stage2_in_band = values_in_band(stage2, *STAGE2_BAND_SECONDS)
    stage3_missing_or_early = not stage3 or (avg(stage3) < STAGE3_BAND_SECONDS[0])
    if duration_short and stage2_in_band and stage3_missing_or_early:
        print(
            "  read: stage 2 is already in band while match end/stage 3 are short; "
            "inspect late-zone compression before moving stage 2."
        )
    if first_upgrade and avg(first_upgrade) < FIRST_UPGRADE_BAND_SECONDS[0]:
        print(
            "  read: first non-pistol access is nearly immediate; inspect spawn "
            "overlap before changing regional loot chances."
        )
    if first_contact and avg(first_contact) < FIRST_CONTACT_BAND_SECONDS[0]:
        print(
            "  read: first contact remains opening pressure; keep it separate "
            "from duration/stage tuning."
        )


def first_nonempty_counter(*counters: Counter) -> Counter:
    for counter in counters:
        if counter:
            return counter
    return Counter()


def print_first_upgrade_context(runs: list[dict]) -> None:
    weapons = first_nonempty_counter(
        string_counter(runs, "economy", "first_upgrade_weapon"),
        string_counter(runs, "pacing", "first_non_pistol_upgrade_weapon"),
    )
    sources = first_nonempty_counter(
        string_counter(runs, "economy", "first_upgrade_source"),
        string_counter(runs, "pacing", "first_non_pistol_upgrade_source"),
    )
    poi_roles = first_nonempty_counter(
        string_counter(runs, "economy", "first_upgrade_poi_role"),
        string_counter(runs, "pacing", "first_non_pistol_upgrade_poi_role"),
    )
    poi_bands = first_nonempty_counter(
        string_counter(runs, "economy", "first_upgrade_poi_band"),
        string_counter(runs, "pacing", "first_non_pistol_upgrade_poi_band"),
    )
    route_roles = first_nonempty_counter(
        string_counter(runs, "economy", "first_upgrade_route_role"),
        string_counter(runs, "pacing", "first_non_pistol_upgrade_route_role"),
    )
    route_bands = first_nonempty_counter(
        string_counter(runs, "economy", "first_upgrade_route_band"),
        string_counter(runs, "pacing", "first_non_pistol_upgrade_route_band"),
    )
    nearest_poi = first_nonempty_counter(
        string_counter(runs, "economy", "first_upgrade_nearest_poi_role"),
        string_counter(runs, "pacing", "first_non_pistol_upgrade_nearest_poi_role"),
    )
    nearest_route = first_nonempty_counter(
        string_counter(runs, "economy", "first_upgrade_nearest_route_role"),
        string_counter(runs, "pacing", "first_non_pistol_upgrade_nearest_route_role"),
    )
    if not any([weapons, sources, poi_roles, poi_bands, route_roles, route_bands, nearest_poi, nearest_route]):
        return
    print("First upgrade context:")
    print(f"  weapons=[{format_mix(weapons)}]")
    print(f"  pickup type source=[{format_mix(sources)}]")
    print(
        "  pickup source: "
        f"poi_roles=[{format_mix(poi_roles)}], poi_bands=[{format_mix(poi_bands)}], "
        f"route_roles=[{format_mix(route_roles)}], route_bands=[{format_mix(route_bands)}]"
    )
    print(
        "  nearest source: "
        f"poi=[{format_mix(nearest_poi)}], route=[{format_mix(nearest_route)}]"
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
    avg_origin = numeric_values(runs, "spawn", "avg_origin_distance")
    radial_inner_half = numeric_values(runs, "spawn", "radial_inner_half_share")
    inside_poi = numeric_values(runs, "spawn", "inside_poi_share")
    on_route = numeric_values(runs, "spawn", "on_route_share")
    origin_bands = counter_from_group(runs, "spawn", "origin_band_counts")
    poi_roles = counter_from_group(runs, "spawn", "poi_role_counts")
    route_roles = counter_from_group(runs, "spawn", "route_role_counts")
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
    if avg_origin or radial_inner_half or inside_poi or on_route:
        avg_origin_text = f"{avg(avg_origin):.1f}m" if avg_origin else "none"
        inner_half_text = f"{avg(radial_inner_half) * 100.0:.1f}%" if radial_inner_half else "none"
        inside_poi_text = f"{avg(inside_poi) * 100.0:.1f}%" if inside_poi else "none"
        on_route_text = f"{avg(on_route) * 100.0:.1f}%" if on_route else "none"
        print(
            "  spawn strategic distribution: "
            f"avg-radius={avg_origin_text}, inner-half={inner_half_text}, "
            f"inside-poi={inside_poi_text}, on-route={on_route_text}"
        )
        print(
            "  spawn strategic mix: "
            f"radial=[{format_mix(origin_bands)}], "
            f"poi=[{format_mix(poi_roles)}], route=[{format_mix(route_roles)}]"
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
        sample_lines = opening_sample_lines(runs)
        if sample_lines:
            print("  first acquisition samples:")
            for line in sample_lines:
                print(line)
        hard_bump_summary = hard_bump_impact_summary(runs)
        if hard_bump_summary:
            print(hard_bump_summary)
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
    open_damage_cells, open_damage_nearest_pois, open_damage_edge_bands, open_damage_contexts = (
        open_damage_context_counters(runs)
    )

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
    print_phase_gap_read(
        durations,
        first_contact,
        first_kill,
        first_upgrade,
        stage2,
        stage3,
        args.target_min_seconds,
        args.target_max_seconds,
    )
    print_first_upgrade_context(runs)
    print_opening_pressure(runs, first_contact)
    print("Movement pressure:")
    print(f"  CHASE context dwell: {format_mix(chase_context)}")
    print(f"  self route dwell: {format_mix(self_route)}")
    print(f"  target route dwell: {format_mix(target_route)}")
    if open_damage_cells or open_damage_nearest_pois or open_damage_edge_bands:
        print("Open combat leak:")
        print(f"  cells: {format_mix(open_damage_cells)}")
        print(f"  nearest POIs: {format_mix(open_damage_nearest_pois)}")
        print(f"  POI edge bands: {format_mix(open_damage_edge_bands)}")
        print(f"  cell contexts: {format_mix(open_damage_contexts)}")
    if stuck_cells or stuck_routes:
        print("Pathing watch:")
        print(f"  stuck route ids: {format_mix(stuck_routes)}")
        print(f"  stuck cells: {format_mix(stuck_cells)}")
    print("Next read:")
    print("  - Use the phase gap read before changing zone, loot, or combat numbers.")
    print("  - If structural gates fail, fix the structural failure first and rerun this report.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
