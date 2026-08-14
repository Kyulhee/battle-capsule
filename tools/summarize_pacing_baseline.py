import argparse
import json
import math
from collections import Counter
from pathlib import Path

from survival_curve import format_survival_curve_lines


DEFAULT_TARGET_MIN_SECONDS = 600.0
DEFAULT_TARGET_MAX_SECONDS = 900.0
FIRST_CONTACT_BAND_SECONDS = (45.0, 150.0)
FIRST_KILL_BAND_SECONDS = (60.0, 210.0)
FIRST_UPGRADE_BAND_SECONDS = (2.0, 30.0)
STAGE2_BAND_SECONDS = (240.0, 420.0)
STAGE3_BAND_SECONDS = (540.0, 720.0)
OPENING_KILL_CONTEXT_SECONDS = 60.0
OPENING_TARGET_CONTINUITY_SECONDS = 60.0
TARGET_CONTINUITY_REACQUIRE_SECONDS = 1.0
TARGET_CONTINUITY_ELIGIBLE_RELEASE_CUTOFF = (
    OPENING_TARGET_CONTINUITY_SECONDS - TARGET_CONTINUITY_REACQUIRE_SECONDS
)
NON_REACQUIRABLE_RELEASE_REASONS = {"target_killed", "invalid_target"}
TARGET_CONTINUITY_SCHEMA_VERSION = 2
TARGET_CONTINUITY_SAMPLE_METHOD = "deterministic_bottom_k_stable_hash"
TARGET_CONTINUITY_EPISODE_SAMPLE_CAPACITY = 128
TARGET_CONTINUITY_EXIT_SAMPLE_CAPACITY = 128
TARGET_CONTINUITY_HASH_MODULUS = 2147483647
TARGET_CONTINUITY_SUMMARY_COUNTER_MAX_KEYS = 32
TARGET_CONTINUITY_EPISODE_SAMPLES_KEY = "target_continuity_episode_samples"
TARGET_CONTINUITY_EPISODE_METADATA_KEY = (
    "target_continuity_episode_sample_metadata"
)
TARGET_CONTINUITY_EXIT_SAMPLES_KEY = (
    "target_continuity_disengage_exit_samples"
)
TARGET_CONTINUITY_EXIT_METADATA_KEY = (
    "target_continuity_disengage_exit_sample_metadata"
)

TARGET_CONTINUITY_RELEASE_SAMPLE_KEYS = {
    "time",
    "release_time",
    "release_time_basis",
    "actor_id",
    "target_id",
    "target_state_episode",
    "state",
    "target_state",
    "reason",
    "source",
    "target_source",
    "distance",
    "target_age_seconds",
    "move_intent",
    "nav_intent",
    "speed",
    "nav_target_distance",
}
TARGET_CONTINUITY_REACQUIRE_SAMPLE_KEYS = {
    "time",
    "release_time",
    "paired_release_time",
    "release_time_basis",
    "actor_id",
    "target_id",
    "target_state_episode",
    "state",
    "source",
    "target_state",
    "release_reason",
    "release_source",
    "paired_release_reason",
    "paired_release_source",
    "distance",
    "target_age_seconds",
    "delay_seconds",
    "spawn_delay_seconds",
    "displacement",
    "stuck_delta",
    "disengage_entry_delta",
    "move_intent",
    "nav_intent",
    "speed",
    "nav_target_distance",
}
TARGET_CONTINUITY_EXIT_SAMPLE_KEYS = {
    "sample_key",
    "sample_hash",
    "time",
    "actor_id",
    "target_id",
    "entry_target_id",
    "current_target_id",
    "state_episode_id",
    "state",
    "exit_state",
    "reason",
    "entry_reason",
    "source",
    "duration_seconds",
    "displacement",
    "stuck_delta",
    "same_entry_target",
    "reengage",
    "visible_enemies",
    "additional_threats",
    "targeting_player",
    "move_intent",
    "nav_intent",
    "speed",
    "nav_target_distance",
}

TARGET_CONTINUITY_COUNT_KEYS = (
    "survival_episode_releases",
    "survival_episode_reacquired_1s",
    "reacquire_stuck_delta_total",
    "reacquire_disengage_entry_delta_total",
    "disengage_exit_count",
    "disengage_same_entry_target",
    "disengage_reengage",
    "disengage_stuck_positive",
    "disengage_stuck_delta_total",
)
TARGET_CONTINUITY_COUNTER_TOTALS = {
    "release_by_target_state": "survival_episode_releases",
    "release_by_reason": "survival_episode_releases",
    "release_by_source": "survival_episode_releases",
    "reacquire_by_source": "survival_episode_reacquired_1s",
    "disengage_by_entry_reason": "disengage_exit_count",
    "disengage_by_exit_reason": "disengage_exit_count",
    "disengage_by_exit_state": "disengage_exit_count",
    "disengage_transitions": "disengage_exit_count",
}
TARGET_CONTINUITY_MEASURE_TOTALS = {
    "reacquire_delay": "survival_episode_reacquired_1s",
    "reacquire_displacement": "survival_episode_reacquired_1s",
    "disengage_duration": "disengage_exit_count",
    "disengage_displacement": "disengage_exit_count",
}


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
            "  run {}: acq={} source={} kind={} state={} dist={} hard_bump={} target={}/{} self={}/{} zone={}/{} spawn_age={} contact={} gap={} objective_interrupt={} obj_enemy={} obj_target={}".format(
                index,
                sample_time(pacing, "first_target_acquisition_time"),
                pacing.get("first_target_acquisition_source", "none"),
                pacing.get("first_target_acquisition_target_kind", "none"),
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


def format_counts(counter: Counter, limit: int = 8) -> str:
    if not counter:
        return "none"
    return ", ".join(f"{name}={int(value)}" for name, value in counter.most_common(limit))


def opening_kill_context_events(
    runs: list[dict], cutoff_seconds: float = OPENING_KILL_CONTEXT_SECONDS
) -> list[dict]:
    events: list[dict] = []
    for run in runs:
        raw_events = run.get("pacing", {}).get("kill_context_events", [])
        if not isinstance(raw_events, list):
            continue
        for event in raw_events:
            if not isinstance(event, dict):
                continue
            try:
                event_time = float(event.get("time", -1.0))
            except (TypeError, ValueError):
                continue
            if 0.0 <= event_time <= cutoff_seconds:
                events.append(event)
    return events


def opening_target_continuity_events(
    runs: list[dict], cutoff_seconds: float = OPENING_TARGET_CONTINUITY_SECONDS
) -> list[dict]:
    events: list[dict] = []
    for run_ordinal, run in enumerate(runs):
        raw_events = run.get("pacing", {}).get("target_continuity_events", [])
        if not isinstance(raw_events, list):
            continue
        for event in raw_events:
            if not isinstance(event, dict):
                continue
            try:
                event_time = float(event.get("time", -1.0))
            except (TypeError, ValueError):
                continue
            if 0.0 <= event_time <= cutoff_seconds:
                event_copy = event.copy()
                event_copy["_continuity_run_ordinal"] = run_ordinal
                events.append(event_copy)
    return events


def continuity_age_band(raw_value: object) -> str:
    try:
        value = float(raw_value)
    except (TypeError, ValueError):
        return "unknown"
    if value < 0.0:
        return "unknown"
    if value < 2.0:
        return "<2s"
    if value < 4.5:
        return "2-4.5s"
    return "4.5s+"


def _target_continuity_schema_available(runs: list[dict]) -> bool:
    if not runs:
        return False
    for run in runs:
        pacing = run.get("pacing", {})
        if not isinstance(pacing, dict):
            return False
        continuity_keys = {
            "target_continuity_summary",
            "target_continuity_events",
            TARGET_CONTINUITY_EPISODE_SAMPLES_KEY,
            TARGET_CONTINUITY_EXIT_SAMPLES_KEY,
        }
        if not any(key in pacing for key in continuity_keys):
            return False
    return True


def _raw_target_continuity_available(runs: list[dict]) -> bool:
    if not runs:
        return False
    return all(
        isinstance(run.get("pacing", {}), dict)
        and isinstance(run.get("pacing", {}).get("target_continuity_events"), list)
        for run in runs
    )


def _is_strict_nonnegative_int(value: object) -> bool:
    return type(value) is int and value >= 0


def _is_finite_nonnegative_number(value: object) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
        and float(value) >= 0.0
    )


def _normalized_contract_key(value: object) -> str | None:
    if type(value) is not str:
        return None
    normalized = value.strip().lower()
    if not normalized or normalized != value:
        return None
    return normalized


def _validate_summary_measure(
    summary: dict, key: str, expected_count: int, reasons: list[str]
) -> None:
    raw_measure = summary.get(key)
    if not isinstance(raw_measure, dict):
        reasons.append(f"{key} must be an object")
        return
    required_keys = {"count", "sum", "max"}
    if set(raw_measure) != required_keys:
        reasons.append(f"{key} must contain exactly count/sum/max")
        return
    count = raw_measure.get("count")
    value_sum = raw_measure.get("sum")
    value_max = raw_measure.get("max")
    if not _is_strict_nonnegative_int(count):
        reasons.append(f"{key}.count must be a nonnegative integer")
        return
    if not _is_finite_nonnegative_number(value_sum):
        reasons.append(f"{key}.sum must be finite and nonnegative")
        return
    if not _is_finite_nonnegative_number(value_max):
        reasons.append(f"{key}.max must be finite and nonnegative")
        return
    if count != expected_count:
        reasons.append(f"{key}.count must equal {expected_count}")
    sample_sum = float(value_sum)
    sample_max = float(value_max)
    tolerance = 1.0e-6 * max(1.0, sample_sum, sample_max)
    if count == 0:
        if sample_sum != 0.0 or sample_max != 0.0:
            reasons.append(f"{key} zero-count measure must have zero sum/max")
    elif sample_max > sample_sum + tolerance \
            or sample_sum > count * sample_max + tolerance:
        reasons.append(f"{key} sum/max are inconsistent with count")


def _validate_summary_counter(
    summary: dict, key: str, expected_total: int, reasons: list[str]
) -> None:
    raw_counter = summary.get(key)
    if not isinstance(raw_counter, dict):
        reasons.append(f"{key} must be an object")
        return
    if len(raw_counter) > TARGET_CONTINUITY_SUMMARY_COUNTER_MAX_KEYS:
        reasons.append(
            f"{key} exceeds {TARGET_CONTINUITY_SUMMARY_COUNTER_MAX_KEYS} keys"
        )
    total = 0
    for raw_name, raw_value in raw_counter.items():
        if _normalized_contract_key(raw_name) is None:
            reasons.append(f"{key} has a non-canonical key")
            continue
        if not _is_strict_nonnegative_int(raw_value):
            reasons.append(f"{key}.{raw_name} must be a nonnegative integer")
            continue
        total += raw_value
    if total != expected_total:
        reasons.append(f"{key} sums to {total}, expected {expected_total}")


def _summary_counter_matches_raw(summary_counter: dict, raw_counter: Counter) -> bool:
    """Compare a complete raw population with the bounded exact counter.

    Runtime reserves `other` as the aggregate for every raw key that cannot be
    represented explicitly inside the fixed 32-key summary shape.
    """
    if "other" not in summary_counter:
        return dict(raw_counter) == summary_counter
    explicit = {key: value for key, value in summary_counter.items() if key != "other"}
    if any(raw_counter.get(key, 0) != value for key, value in explicit.items()):
        return False
    raw_other = sum(
        value for key, value in raw_counter.items() if key not in explicit
    )
    return raw_other == summary_counter["other"]


def _validate_exact_target_continuity_summary(summary: object) -> list[str]:
    if not isinstance(summary, dict):
        return ["summary must be an object"]
    required = {
        "schema_version",
        "exact",
        "complete",
        "window_seconds",
        "release_censor_seconds",
        "reacquire_seconds",
        "release_time_basis",
        *TARGET_CONTINUITY_COUNT_KEYS,
        *TARGET_CONTINUITY_COUNTER_TOTALS,
        *TARGET_CONTINUITY_MEASURE_TOTALS,
    }
    missing = sorted(required.difference(summary))
    reasons = [f"missing {key}" for key in missing]
    unexpected = sorted(set(summary).difference(required))
    reasons.extend(f"unexpected {key}" for key in unexpected)

    schema_version = summary.get("schema_version")
    if type(schema_version) is not int \
            or schema_version != TARGET_CONTINUITY_SCHEMA_VERSION:
        reasons.append(
            f"schema_version must be integer {TARGET_CONTINUITY_SCHEMA_VERSION}"
        )
    if type(summary.get("exact")) is not bool or summary.get("exact") is not True:
        reasons.append("exact must be boolean true")
    if type(summary.get("complete")) is not bool \
            or summary.get("complete") is not True:
        reasons.append("complete must be boolean true")

    expected_numbers = {
        "window_seconds": OPENING_TARGET_CONTINUITY_SECONDS,
        "release_censor_seconds": TARGET_CONTINUITY_ELIGIBLE_RELEASE_CUTOFF,
        "reacquire_seconds": TARGET_CONTINUITY_REACQUIRE_SECONDS,
    }
    for key, expected in expected_numbers.items():
        raw_value = summary.get(key)
        if not _is_finite_nonnegative_number(raw_value) \
                or not math.isclose(
                    float(raw_value), expected, rel_tol=0.0, abs_tol=1.0e-9
                ):
            reasons.append(f"{key} must equal {expected:.1f}")
    if summary.get("release_time_basis") != "match_elapsed":
        reasons.append("release_time_basis must be match_elapsed")

    counts: dict[str, int] = {}
    for key in TARGET_CONTINUITY_COUNT_KEYS:
        raw_value = summary.get(key)
        if not _is_strict_nonnegative_int(raw_value):
            reasons.append(f"{key} must be a nonnegative integer")
        else:
            counts[key] = raw_value

    releases = counts.get("survival_episode_releases", -1)
    reacquired = counts.get("survival_episode_reacquired_1s", -1)
    exits = counts.get("disengage_exit_count", -1)
    if releases >= 0 and reacquired >= 0 and reacquired > releases:
        reasons.append("survival_episode_reacquired_1s exceeds releases")
    for key in (
        "disengage_same_entry_target",
        "disengage_reengage",
        "disengage_stuck_positive",
    ):
        value = counts.get(key, -1)
        if exits >= 0 and value > exits:
            reasons.append(f"{key} exceeds disengage_exit_count")
    stuck_positive = counts.get("disengage_stuck_positive", -1)
    stuck_total = counts.get("disengage_stuck_delta_total", -1)
    if stuck_positive >= 0 and stuck_total >= 0 and stuck_total < stuck_positive:
        reasons.append(
            "disengage_stuck_delta_total is smaller than disengage_stuck_positive"
        )

    for key, count_key in TARGET_CONTINUITY_COUNTER_TOTALS.items():
        _validate_summary_counter(summary, key, counts.get(count_key, -1), reasons)
    for key, count_key in TARGET_CONTINUITY_MEASURE_TOTALS.items():
        _validate_summary_measure(summary, key, counts.get(count_key, -1), reasons)

    release_states = summary.get("release_by_target_state", {})
    if isinstance(release_states, dict):
        unexpected_states = set(release_states).difference({"recover", "disengage"})
        if unexpected_states:
            reasons.append("release_by_target_state contains a non-survival state")
    release_reasons = summary.get("release_by_reason", {})
    if isinstance(release_reasons, dict):
        terminal = {
            reason
            for reason in NON_REACQUIRABLE_RELEASE_REASONS
            if _is_strict_nonnegative_int(release_reasons.get(reason))
            and release_reasons.get(reason, 0) > 0
        }
        if terminal:
            reasons.append("release_by_reason contains terminal release reasons")
    delay = summary.get("reacquire_delay", {})
    if isinstance(delay, dict) and _is_finite_nonnegative_number(delay.get("max")) \
            and float(delay["max"]) > TARGET_CONTINUITY_REACQUIRE_SECONDS + 1.0e-9:
        reasons.append("reacquire_delay.max exceeds the one-second window")
    return reasons


def _validated_v2_target_continuity_summaries(
    runs: list[dict],
) -> tuple[list[dict], list[str], bool, bool]:
    summaries: list[dict] = []
    errors: list[str] = []
    legacy_seen = False
    summary_seen = False
    if not runs:
        return summaries, errors, legacy_seen, summary_seen
    for run_ordinal, run in enumerate(runs, start=1):
        pacing = run.get("pacing", {})
        if not isinstance(pacing, dict):
            errors.append(f"run {run_ordinal}: pacing must be an object")
            continue
        summary_advertised = "target_continuity_summary" in pacing
        summary = pacing.get("target_continuity_summary")
        if not isinstance(summary, dict):
            errors.append(f"run {run_ordinal}: exact summary missing")
            summary_seen = summary_seen or summary_advertised
            continue
        summary_seen = True
        if type(summary.get("schema_version")) is int \
                and summary.get("schema_version") == 1:
            legacy_seen = True
            errors.append(f"run {run_ordinal}: schema v1 is legacy/informational")
            continue
        run_errors = _validate_exact_target_continuity_summary(summary)
        if run_errors:
            errors.extend(f"run {run_ordinal}: {reason}" for reason in run_errors)
        else:
            summaries.append(summary)
    if len(summaries) != len(runs) and not errors:
        errors.append("not every run has a valid schema v2 exact summary")
    return summaries, errors, legacy_seen, summary_seen


def _summary_int_total(summaries: list[dict], key: str) -> int:
    total = 0
    for summary in summaries:
        try:
            total += max(0, int(summary.get(key, 0) or 0))
        except (TypeError, ValueError):
            continue
    return total


def _summary_counter(summaries: list[dict], key: str) -> Counter:
    counter = Counter()
    for summary in summaries:
        raw_counter = summary.get(key, {})
        if not isinstance(raw_counter, dict):
            continue
        for name, raw_value in raw_counter.items():
            try:
                counter[str(name)] += max(0, int(raw_value))
            except (TypeError, ValueError):
                continue
    return counter


def _summary_measure(summaries: list[dict], key: str) -> dict:
    count = 0
    value_sum = 0.0
    value_max: float | None = None
    for summary in summaries:
        raw_measure = summary.get(key, {})
        if not isinstance(raw_measure, dict):
            continue
        try:
            sample_count = max(0, int(raw_measure.get("count", 0) or 0))
            sample_sum = max(0.0, float(raw_measure.get("sum", 0.0) or 0.0))
            sample_max = max(0.0, float(raw_measure.get("max", 0.0) or 0.0))
        except (TypeError, ValueError):
            continue
        count += sample_count
        value_sum += sample_sum
        if sample_count > 0:
            value_max = sample_max if value_max is None else max(value_max, sample_max)
    return {"count": count, "sum": value_sum, "max": value_max}


def _format_summary_measure(measure: dict, unit: str) -> str:
    count = int(measure.get("count", 0))
    value_max = measure.get("max")
    if count <= 0 or value_max is None:
        return "none"
    return (
        f"avg={float(measure.get('sum', 0.0)) / count:.2f}{unit}, "
        f"max={float(value_max):.2f}{unit}"
    )


def _target_continuity_dropped(runs: list[dict]) -> int:
    dropped = 0
    for run in runs:
        try:
            dropped += max(
                0,
                int(run.get("pacing", {}).get("target_continuity_dropped", 0) or 0),
            )
        except (TypeError, ValueError):
            continue
    return dropped


def _target_continuity_drop_count_available(runs: list[dict]) -> bool:
    if not runs:
        return False
    return all(
        isinstance(run.get("pacing", {}), dict)
        and "target_continuity_dropped" in run.get("pacing", {})
        for run in runs
    )


def _event_value(event: dict, keys: tuple[str, ...], default: object) -> object:
    for key in keys:
        if key in event:
            return event.get(key)
    return default


def _event_float(event: dict, keys: tuple[str, ...], default: float = -1.0) -> float:
    try:
        return float(_event_value(event, keys, default))
    except (TypeError, ValueError):
        return default


def _event_key(event: dict, keys: tuple[str, ...], default: str = "unknown") -> str:
    value = str(_event_value(event, keys, default)).strip().lower()
    return value or default


def _continuity_episode_identity(event: dict) -> tuple[int, int, int, int] | None:
    try:
        identity = (
            int(event.get("_continuity_run_ordinal", -1)),
            int(event.get("actor_id", -1)),
            int(event.get("target_id", -1)),
            int(event.get("target_state_episode", -1)),
        )
    except (TypeError, ValueError):
        return None
    if min(identity) < 0:
        return None
    return identity


def _nonnegative_event_values(events: list[dict], *keys: str) -> list[float]:
    values: list[float] = []
    for event in events:
        try:
            value = float(_event_value(event, keys, -1.0))
        except (TypeError, ValueError):
            continue
        if value >= 0.0:
            values.append(value)
    return values


def _event_delta_total(events: list[dict], *keys: str) -> int:
    total = 0
    for event in events:
        try:
            total += max(0, int(_event_value(event, keys, 0) or 0))
        except (TypeError, ValueError):
            continue
    return total


def _format_avg_max_distance(values: list[float]) -> str:
    if not values:
        return "none"
    return f"avg={avg(values):.2f}m, max={max(values):.2f}m"


def _format_avg_seconds(values: list[float]) -> str:
    if not values:
        return "none"
    return f"{avg(values):.2f}s"


def _continuity_release_time(event: dict, releases: list[dict] | None = None) -> float:
    if "release_time_basis" in event:
        if event.get("release_time_basis") != "match_elapsed":
            return -1.0
        explicit = event.get("release_time")
        if not _is_finite_nonnegative_number(explicit):
            return -1.0
        return float(explicit)

    try:
        event_time = float(event.get("time", -1.0))
        delay = float(_event_value(event, ("delay_seconds", "delay"), -1.0))
    except (TypeError, ValueError):
        event_time = -1.0
        delay = -1.0
    if event_time >= 0.0 and delay >= 0.0 and event_time - delay >= 0.0:
        return event_time - delay

    if releases and event_time >= 0.0:
        run_ordinal = event.get("_continuity_run_ordinal", -1)
        actor_id = event.get("actor_id", -1)
        target_id = event.get("target_id", -1)
        episode_id = event.get("target_state_episode", -1)
        candidates: list[float] = []
        for release in releases:
            if release.get("_continuity_run_ordinal", -2) != run_ordinal:
                continue
            if release.get("actor_id", -2) != actor_id:
                continue
            if release.get("target_id", -2) != target_id:
                continue
            release_episode = release.get("target_state_episode", -1)
            if episode_id != -1 and release_episode != -1 and release_episode != episode_id:
                continue
            try:
                release_event_time = float(release.get("time", -1.0))
            except (TypeError, ValueError):
                continue
            if 0.0 <= release_event_time <= event_time:
                candidates.append(release_event_time)
        if candidates:
            return max(candidates)
    return -1.0


def _sample_metadata_validation(
    metadata: object,
    samples: object,
    expected_population: int | None,
    expected_capacity: int,
    label: str,
) -> tuple[dict | None, list[str]]:
    reasons: list[str] = []
    if not isinstance(samples, list):
        reasons.append(f"{label} samples must be an array")
    if not isinstance(metadata, dict):
        reasons.append(f"{label} metadata must be an object")
        return None, reasons
    required = {"method", "capacity", "population", "stored", "omitted", "complete"}
    for key in sorted(required.difference(metadata)):
        reasons.append(f"{label} metadata missing {key}")
    for key in sorted(set(metadata).difference(required)):
        reasons.append(f"{label} metadata has unexpected {key}")
    if metadata.get("method") != TARGET_CONTINUITY_SAMPLE_METHOD:
        reasons.append(f"{label} metadata method is not deterministic bottom-k")
    values: dict[str, int] = {}
    for key in ("capacity", "population", "stored", "omitted"):
        value = metadata.get(key)
        if not _is_strict_nonnegative_int(value):
            reasons.append(f"{label} metadata {key} must be a nonnegative integer")
        else:
            values[key] = value
    complete = metadata.get("complete")
    if type(complete) is not bool:
        reasons.append(f"{label} metadata complete must be boolean")
    if len(values) == 4:
        if values["capacity"] != expected_capacity:
            reasons.append(f"{label} capacity must equal {expected_capacity}")
        if values["stored"] > values["capacity"]:
            reasons.append(f"{label} stored exceeds capacity")
        if values["population"] != values["stored"] + values["omitted"]:
            reasons.append(f"{label} population must equal stored + omitted")
        expected_stored = min(values["population"], expected_capacity)
        expected_omitted = max(values["population"] - expected_capacity, 0)
        if values["stored"] != expected_stored:
            reasons.append(f"{label} stored must equal min(population, capacity)")
        if values["omitted"] != expected_omitted:
            reasons.append(f"{label} omitted must equal max(population - capacity, 0)")
        if isinstance(samples, list) and values["stored"] != len(samples):
            reasons.append(f"{label} stored does not equal array length")
        if expected_population is not None \
                and values["population"] != expected_population:
            reasons.append(f"{label} population disagrees with exact aggregate")
        if type(complete) is bool and complete != (values["omitted"] == 0):
            reasons.append(f"{label} complete disagrees with omitted")
    return metadata if not reasons else None, reasons


def _validate_sample_common(
    sample: object, label: str, reasons: list[str]
) -> tuple[str, int] | None:
    if not isinstance(sample, dict):
        reasons.append(f"{label} must be an object")
        return None
    sample_key = sample.get("sample_key")
    sample_hash = sample.get("sample_hash")
    if type(sample_key) is not str or not sample_key or sample_key.strip() != sample_key:
        reasons.append(f"{label}.sample_key must be a non-empty canonical string")
    if not _is_strict_nonnegative_int(sample_hash):
        reasons.append(f"{label}.sample_hash must be a nonnegative integer")
    if type(sample_key) is str and sample_key \
            and _is_strict_nonnegative_int(sample_hash):
        return sample_key, sample_hash
    return None


def _target_continuity_stable_hash(sample_key: str) -> int:
    value = 7
    for character in sample_key:
        value = (value * 131 + ord(character)) % TARGET_CONTINUITY_HASH_MODULUS
    return value


def _validate_raw_id(value: object, label: str, reasons: list[str]) -> int | None:
    if not _is_strict_nonnegative_int(value):
        reasons.append(f"{label} must be a nonnegative integer")
        return None
    return value


def _validate_raw_number(
    value: object, label: str, reasons: list[str]
) -> float | None:
    if not _is_finite_nonnegative_number(value):
        reasons.append(f"{label} must be finite and nonnegative")
        return None
    return float(value)


def _validate_raw_key(value: object, label: str, reasons: list[str]) -> str | None:
    normalized = _normalized_contract_key(value)
    if normalized is None:
        reasons.append(f"{label} must be a canonical lowercase string")
    return normalized


def _validate_exact_keys(
    value: dict, required: set[str], label: str, reasons: list[str]
) -> None:
    for key in sorted(required.difference(value)):
        reasons.append(f"{label} missing {key}")
    for key in sorted(set(value).difference(required)):
        reasons.append(f"{label} has unexpected {key}")


def _validate_runtime_diagnostic_number(
    value: object, label: str, reasons: list[str]
) -> None:
    # Runtime uses -1.0 only as an explicit unavailable sentinel for these
    # peripheral diagnostics; all other values must be finite and nonnegative.
    if not isinstance(value, (int, float)) or isinstance(value, bool) \
            or not math.isfinite(float(value)) \
            or (float(value) != -1.0 and float(value) < 0.0):
        reasons.append(f"{label} must be -1 or finite and nonnegative")


def _validate_runtime_diagnostic_int(
    value: object, label: str, reasons: list[str]
) -> None:
    if type(value) is not int or value < -1:
        reasons.append(f"{label} must be an integer >= -1")


def _validate_episode_sample(
    sample: object, run_ordinal: int, sample_ordinal: int
) -> tuple[dict | None, list[str]]:
    label = f"run {run_ordinal + 1} episode sample {sample_ordinal + 1}"
    reasons: list[str] = []
    common = _validate_sample_common(sample, label, reasons)
    if not isinstance(sample, dict):
        return None, reasons
    allowed_sample_keys = {"sample_key", "sample_hash", "release"}
    if "reacquire_1s" in sample:
        allowed_sample_keys.add("reacquire_1s")
    _validate_exact_keys(sample, allowed_sample_keys, label, reasons)
    release = sample.get("release")
    if not isinstance(release, dict):
        reasons.append(f"{label}.release must be an object")
        return None, reasons
    _validate_exact_keys(
        release, TARGET_CONTINUITY_RELEASE_SAMPLE_KEYS, f"{label}.release", reasons
    )
    release_time = _validate_raw_number(release.get("time"), f"{label}.release.time", reasons)
    canonical_release_time = _continuity_release_time(release)
    if release.get("release_time_basis") != "match_elapsed":
        reasons.append(f"{label}.release.release_time_basis must be match_elapsed")
    if canonical_release_time < 0.0:
        reasons.append(f"{label}.release requires finite match_elapsed release_time")
    elif release_time is not None and not math.isclose(
        release_time, canonical_release_time, rel_tol=0.0, abs_tol=1.0e-9
    ):
        reasons.append(f"{label}.release.time must equal release_time")
    actor_id = _validate_raw_id(release.get("actor_id"), f"{label}.release.actor_id", reasons)
    target_id = _validate_raw_id(release.get("target_id"), f"{label}.release.target_id", reasons)
    target_episode = _validate_raw_id(
        release.get("target_state_episode"),
        f"{label}.release.target_state_episode",
        reasons,
    )
    target_state = _validate_raw_key(
        release.get("target_state"), f"{label}.release.target_state", reasons
    )
    reason = _validate_raw_key(release.get("reason"), f"{label}.release.reason", reasons)
    _validate_raw_key(release.get("state"), f"{label}.release.state", reasons)
    _validate_raw_key(release.get("source"), f"{label}.release.source", reasons)
    _validate_raw_key(
        release.get("target_source"), f"{label}.release.target_source", reasons
    )
    _validate_raw_key(
        release.get("move_intent"), f"{label}.release.move_intent", reasons
    )
    for key in ("distance", "target_age_seconds", "speed", "nav_target_distance"):
        _validate_runtime_diagnostic_number(
            release.get(key), f"{label}.release.{key}", reasons
        )
    if type(release.get("nav_intent")) is not bool:
        reasons.append(f"{label}.release.nav_intent must be boolean")
    if release_time is not None \
            and release_time > TARGET_CONTINUITY_ELIGIBLE_RELEASE_CUTOFF + 1.0e-9:
        reasons.append(f"{label}.release.time is right-censored")
    if target_state not in {"recover", "disengage"}:
        reasons.append(f"{label}.release.target_state is not a survival state")
    if reason in NON_REACQUIRABLE_RELEASE_REASONS:
        reasons.append(f"{label}.release.reason is terminal")
    expected_sample_key = (
        f"{actor_id}|{target_id}|{target_episode}"
        if actor_id is not None and target_id is not None and target_episode is not None
        else None
    )
    if common is not None:
        sample_key, sample_hash = common
        if expected_sample_key is not None and sample_key != expected_sample_key:
            reasons.append(f"{label}.sample_key does not match release identity")
        if sample_hash >= TARGET_CONTINUITY_HASH_MODULUS:
            reasons.append(f"{label}.sample_hash exceeds signed stable-hash range")
        elif sample_hash != _target_continuity_stable_hash(sample_key):
            reasons.append(f"{label}.sample_hash does not match sample_key")

    reacquire = sample.get("reacquire_1s")
    if reacquire is not None:
        if not isinstance(reacquire, dict):
            reasons.append(f"{label}.reacquire_1s must be an object when present")
        else:
            _validate_exact_keys(
                reacquire,
                TARGET_CONTINUITY_REACQUIRE_SAMPLE_KEYS,
                f"{label}.reacquire_1s",
                reasons,
            )
            event_time = _validate_raw_number(
                reacquire.get("time"), f"{label}.reacquire_1s.time", reasons
            )
            canonical_release_time = _continuity_release_time(reacquire)
            if reacquire.get("release_time_basis") != "match_elapsed" \
                    or canonical_release_time < 0.0:
                reasons.append(
                    f"{label}.reacquire_1s requires finite match_elapsed release_time"
                )
            paired_release_time = _validate_raw_number(
                reacquire.get("paired_release_time"),
                f"{label}.reacquire_1s.paired_release_time",
                reasons,
            )
            delay = _validate_raw_number(
                reacquire.get("delay_seconds"),
                f"{label}.reacquire_1s.delay_seconds",
                reasons,
            )
            reacquire_actor = _validate_raw_id(
                reacquire.get("actor_id"), f"{label}.reacquire_1s.actor_id", reasons
            )
            reacquire_target = _validate_raw_id(
                reacquire.get("target_id"), f"{label}.reacquire_1s.target_id", reasons
            )
            reacquire_episode = _validate_raw_id(
                reacquire.get("target_state_episode"),
                f"{label}.reacquire_1s.target_state_episode",
                reasons,
            )
            _validate_raw_key(
                reacquire.get("source"), f"{label}.reacquire_1s.source", reasons
            )
            reacquire_target_state = _validate_raw_key(
                reacquire.get("target_state"),
                f"{label}.reacquire_1s.target_state",
                reasons,
            )
            reacquire_release_reason = _validate_raw_key(
                reacquire.get("release_reason"),
                f"{label}.reacquire_1s.release_reason",
                reasons,
            )
            _validate_raw_key(
                reacquire.get("release_source"),
                f"{label}.reacquire_1s.release_source",
                reasons,
            )
            paired_reason = _validate_raw_key(
                reacquire.get("paired_release_reason"),
                f"{label}.reacquire_1s.paired_release_reason",
                reasons,
            )
            paired_source = _validate_raw_key(
                reacquire.get("paired_release_source"),
                f"{label}.reacquire_1s.paired_release_source",
                reasons,
            )
            release_reason = _normalized_contract_key(reacquire.get("release_reason"))
            release_source = _normalized_contract_key(reacquire.get("release_source"))
            _validate_raw_number(
                reacquire.get("displacement"),
                f"{label}.reacquire_1s.displacement",
                reasons,
            )
            _validate_raw_id(
                reacquire.get("stuck_delta"),
                f"{label}.reacquire_1s.stuck_delta",
                reasons,
            )
            for key in (
                "distance",
                "target_age_seconds",
                "spawn_delay_seconds",
                "speed",
                "nav_target_distance",
            ):
                _validate_runtime_diagnostic_number(
                    reacquire.get(key), f"{label}.reacquire_1s.{key}", reasons
                )
            _validate_raw_key(
                reacquire.get("state"), f"{label}.reacquire_1s.state", reasons
            )
            _validate_raw_key(
                reacquire.get("move_intent"),
                f"{label}.reacquire_1s.move_intent",
                reasons,
            )
            if type(reacquire.get("nav_intent")) is not bool:
                reasons.append(f"{label}.reacquire_1s.nav_intent must be boolean")
            disengage_delta = reacquire.get(
                "disengage_entry_delta", reacquire.get("disengage_delta")
            )
            _validate_raw_id(
                disengage_delta,
                f"{label}.reacquire_1s.disengage_entry_delta",
                reasons,
            )
            if delay is not None \
                    and delay > TARGET_CONTINUITY_REACQUIRE_SECONDS + 1.0e-9:
                reasons.append(f"{label}.reacquire_1s exceeds one second")
            if event_time is not None \
                    and event_time > OPENING_TARGET_CONTINUITY_SECONDS + 1.0e-9:
                reasons.append(f"{label}.reacquire_1s.time exceeds opening window")
            if reacquire_target_state not in {"recover", "disengage"}:
                reasons.append(
                    f"{label}.reacquire_1s.target_state is not a survival state"
                )
            if target_state in {"recover", "disengage"} \
                    and reacquire_target_state != target_state:
                reasons.append(
                    f"{label}.reacquire_1s.target_state disagrees with release episode"
                )
            if reacquire_release_reason in NON_REACQUIRABLE_RELEASE_REASONS \
                    or paired_reason in NON_REACQUIRABLE_RELEASE_REASONS:
                reasons.append(f"{label}.reacquire_1s paired release reason is terminal")
            if canonical_release_time >= 0.0 \
                    and canonical_release_time \
                    > TARGET_CONTINUITY_ELIGIBLE_RELEASE_CUTOFF + 1.0e-9:
                reasons.append(f"{label}.reacquire_1s release_time is right-censored")
            if paired_release_time is not None and canonical_release_time >= 0.0 \
                    and not math.isclose(
                        paired_release_time,
                        canonical_release_time,
                        rel_tol=0.0,
                        abs_tol=1.0e-9,
                    ):
                reasons.append(
                    f"{label}.reacquire_1s paired_release_time disagrees with release_time"
                )
            if paired_release_time is not None and release_time is not None \
                    and paired_release_time + 1.0e-9 < release_time:
                reasons.append(
                    f"{label}.reacquire_1s paired release precedes first release sample"
                )
            if paired_reason is not None and release_reason is not None \
                    and paired_reason != release_reason:
                reasons.append(
                    f"{label}.reacquire_1s paired_release_reason disagrees"
                )
            if paired_source is not None and release_source is not None \
                    and paired_source != release_source:
                reasons.append(
                    f"{label}.reacquire_1s paired_release_source disagrees"
                )
            if event_time is not None and canonical_release_time >= 0.0:
                if event_time + 1.0e-9 < canonical_release_time:
                    reasons.append(f"{label}.reacquire_1s precedes release")
                elif delay is not None and not math.isclose(
                    event_time - canonical_release_time,
                    delay,
                    rel_tol=0.0,
                    abs_tol=1.0e-6,
                ):
                    reasons.append(f"{label}.reacquire_1s delay disagrees with timestamps")
            if (actor_id, target_id, target_episode) != (
                reacquire_actor,
                reacquire_target,
                reacquire_episode,
            ):
                reasons.append(f"{label}.reacquire_1s identity does not match release")

    if common is None or reasons:
        return None, reasons
    sample_copy = sample.copy()
    sample_copy["_continuity_run_ordinal"] = run_ordinal
    return sample_copy, reasons


def _validate_exit_sample(
    sample: object, run_ordinal: int, sample_ordinal: int
) -> tuple[dict | None, list[str]]:
    label = f"run {run_ordinal + 1} exit sample {sample_ordinal + 1}"
    reasons: list[str] = []
    common = _validate_sample_common(sample, label, reasons)
    if not isinstance(sample, dict):
        return None, reasons
    _validate_exact_keys(
        sample, TARGET_CONTINUITY_EXIT_SAMPLE_KEYS, label, reasons
    )
    event_time = _validate_raw_number(sample.get("time"), f"{label}.time", reasons)
    actor_id = _validate_raw_id(sample.get("actor_id"), f"{label}.actor_id", reasons)
    state_episode_id = _validate_raw_id(
        sample.get("state_episode_id"), f"{label}.state_episode_id", reasons
    )
    _validate_raw_key(sample.get("entry_reason"), f"{label}.entry_reason", reasons)
    _validate_raw_key(
        sample.get("exit_reason", sample.get("reason")), f"{label}.exit_reason", reasons
    )
    _validate_raw_key(sample.get("exit_state"), f"{label}.exit_state", reasons)
    for key in ("state", "source", "move_intent"):
        _validate_raw_key(sample.get(key), f"{label}.{key}", reasons)
    _validate_raw_number(
        sample.get("duration_seconds", sample.get("duration")),
        f"{label}.duration_seconds",
        reasons,
    )
    _validate_raw_number(sample.get("displacement"), f"{label}.displacement", reasons)
    _validate_raw_id(sample.get("stuck_delta"), f"{label}.stuck_delta", reasons)
    for key in ("same_entry_target", "reengage"):
        if type(sample.get(key)) is not bool:
            reasons.append(f"{label}.{key} must be boolean")
    if type(sample.get("targeting_player")) is not bool \
            or type(sample.get("nav_intent")) is not bool:
        reasons.append(f"{label} targeting_player/nav_intent must be boolean")
    for key in ("target_id", "entry_target_id", "current_target_id", "visible_enemies", "additional_threats"):
        _validate_runtime_diagnostic_int(sample.get(key), f"{label}.{key}", reasons)
    for key in ("speed", "nav_target_distance"):
        _validate_runtime_diagnostic_number(sample.get(key), f"{label}.{key}", reasons)
    if event_time is not None \
            and event_time > OPENING_TARGET_CONTINUITY_SECONDS + 1.0e-9:
        reasons.append(f"{label}.time exceeds opening window")
    if common is not None:
        sample_key, sample_hash = common
        if actor_id is not None and state_episode_id is not None \
                and sample_key != f"{actor_id}|{state_episode_id}":
            reasons.append(f"{label}.sample_key does not match exit identity")
        if sample_hash >= TARGET_CONTINUITY_HASH_MODULUS:
            reasons.append(f"{label}.sample_hash exceeds signed stable-hash range")
        elif sample_hash != _target_continuity_stable_hash(sample_key):
            reasons.append(f"{label}.sample_hash does not match sample_key")
    if common is None or reasons:
        return None, reasons
    sample_copy = sample.copy()
    sample_copy["_continuity_run_ordinal"] = run_ordinal
    return sample_copy, reasons


def _float_totals_match(raw_value: float, exact_value: object, count: int) -> bool:
    if not _is_finite_nonnegative_number(exact_value):
        return False
    return math.isclose(
        raw_value,
        float(exact_value),
        rel_tol=0.0,
        abs_tol=1.0e-6 * max(1, count),
    )


def _crosscheck_complete_raw_samples(
    summary: dict,
    episode_samples: list[dict],
    exit_samples: list[dict],
    check_episodes: bool,
    check_exits: bool,
) -> list[str]:
    reasons: list[str] = []
    releases = [sample["release"] for sample in episode_samples]
    reacquires = [
        sample["reacquire_1s"]
        for sample in episode_samples
        if isinstance(sample.get("reacquire_1s"), dict)
    ]
    if check_episodes:
        if len(releases) != summary["survival_episode_releases"]:
            reasons.append("complete episode sample count disagrees with releases")
        if len(reacquires) != summary["survival_episode_reacquired_1s"]:
            reasons.append("complete nested reacquire count disagrees with aggregate")
        if not _summary_counter_matches_raw(
            summary["release_by_target_state"],
            Counter(item["target_state"] for item in releases),
        ):
            reasons.append("complete raw release_by_target_state disagrees with aggregate")
        if not _summary_counter_matches_raw(
            summary["release_by_reason"],
            Counter(item["reason"] for item in releases),
        ):
            reasons.append("complete raw release_by_reason disagrees with aggregate")
        if not _summary_counter_matches_raw(
            summary["release_by_source"],
            Counter(item["source"] for item in releases),
        ):
            reasons.append("complete raw release_by_source disagrees with aggregate")
        if not _summary_counter_matches_raw(
            summary["reacquire_by_source"],
            Counter(item["source"] for item in reacquires),
        ):
            reasons.append("complete raw reacquire_by_source disagrees with aggregate")

        measure_specs = (
            ("reacquire_delay", reacquires, lambda item: float(item["delay_seconds"])),
            ("reacquire_displacement", reacquires, lambda item: float(item["displacement"])),
        )
        for key, samples, getter in measure_specs:
            values = [getter(item) for item in samples]
            raw_sum = sum(values)
            raw_max = max(values, default=0.0)
            exact = summary[key]
            if not _float_totals_match(raw_sum, exact["sum"], len(values)) \
                    or not _float_totals_match(raw_max, exact["max"], 1):
                reasons.append(f"complete raw {key} disagrees with aggregate")

        raw_stuck = sum(int(item["stuck_delta"]) for item in reacquires)
        raw_disengage = sum(
            int(item.get("disengage_entry_delta", item.get("disengage_delta", 0)))
            for item in reacquires
        )
        if raw_stuck != summary["reacquire_stuck_delta_total"]:
            reasons.append("complete raw reacquire stuck total disagrees with aggregate")
        if raw_disengage != summary["reacquire_disengage_entry_delta_total"]:
            reasons.append("complete raw reacquire disengage total disagrees with aggregate")

    if not check_exits:
        return reasons
    if len(exit_samples) != summary["disengage_exit_count"]:
        reasons.append("complete exit sample count disagrees with aggregate")
    exit_reason = lambda item: item.get("exit_reason", item.get("reason"))
    exit_counters = {
        "disengage_by_entry_reason": Counter(item["entry_reason"] for item in exit_samples),
        "disengage_by_exit_reason": Counter(exit_reason(item) for item in exit_samples),
        "disengage_by_exit_state": Counter(item["exit_state"] for item in exit_samples),
        "disengage_transitions": Counter(
            f"{item['entry_reason']}->{exit_reason(item)}/{item['exit_state']}"
            for item in exit_samples
        ),
    }
    for key, counter in exit_counters.items():
        if not _summary_counter_matches_raw(summary[key], counter):
            reasons.append(f"complete raw {key} disagrees with aggregate")
    exit_subcounts = {
        "disengage_same_entry_target": sum(
            item["same_entry_target"] for item in exit_samples
        ),
        "disengage_reengage": sum(item["reengage"] for item in exit_samples),
        "disengage_stuck_positive": sum(
            int(item["stuck_delta"]) > 0 for item in exit_samples
        ),
        "disengage_stuck_delta_total": sum(
            int(item["stuck_delta"]) for item in exit_samples
        ),
    }
    for key, raw_total in exit_subcounts.items():
        if raw_total != summary[key]:
            reasons.append(f"complete raw {key} disagrees with aggregate")
    exit_measures = (
        (
            "disengage_duration",
            [float(item.get("duration_seconds", item.get("duration"))) for item in exit_samples],
        ),
        ("disengage_displacement", [float(item["displacement"]) for item in exit_samples]),
    )
    for key, values in exit_measures:
        exact = summary[key]
        if not _float_totals_match(sum(values), exact["sum"], len(values)) \
                or not _float_totals_match(max(values, default=0.0), exact["max"], 1):
            reasons.append(f"complete raw {key} disagrees with aggregate")
    return reasons


def _validate_v2_raw_coverage(
    runs: list[dict], summaries: list[dict]
) -> dict:
    result = {
        "status": "unavailable",
        "errors": [],
        "episode_population": 0,
        "episode_stored": 0,
        "episode_omitted": 0,
        "exit_population": 0,
        "exit_stored": 0,
        "exit_omitted": 0,
    }
    if not runs:
        return result
    raw_keys = {
        TARGET_CONTINUITY_EPISODE_SAMPLES_KEY,
        TARGET_CONTINUITY_EPISODE_METADATA_KEY,
        TARGET_CONTINUITY_EXIT_SAMPLES_KEY,
        TARGET_CONTINUITY_EXIT_METADATA_KEY,
    }
    presence: list[bool] = []
    for run in runs:
        pacing = run.get("pacing", {})
        presence.append(isinstance(pacing, dict) and any(key in pacing for key in raw_keys))
    if not any(presence):
        return result
    if not all(presence):
        result["status"] = "invalid"
        result["errors"] = ["raw v2 coverage is missing for one or more runs"]
        return result

    errors: list[str] = []
    any_omitted = False
    for run_ordinal, run in enumerate(runs):
        pacing = run.get("pacing", {})
        if not isinstance(pacing, dict):
            errors.append(f"run {run_ordinal + 1}: pacing must be an object")
            continue
        episode_samples = pacing.get(TARGET_CONTINUITY_EPISODE_SAMPLES_KEY)
        exit_samples = pacing.get(TARGET_CONTINUITY_EXIT_SAMPLES_KEY)
        summary = summaries[run_ordinal] if len(summaries) == len(runs) else None
        expected_episode_population = (
            summary["survival_episode_releases"] if summary is not None else None
        )
        expected_exit_population = (
            summary["disengage_exit_count"] if summary is not None else None
        )
        episode_meta, episode_meta_errors = _sample_metadata_validation(
            pacing.get(TARGET_CONTINUITY_EPISODE_METADATA_KEY),
            episode_samples,
            expected_episode_population,
            TARGET_CONTINUITY_EPISODE_SAMPLE_CAPACITY,
            f"run {run_ordinal + 1} episode",
        )
        exit_meta, exit_meta_errors = _sample_metadata_validation(
            pacing.get(TARGET_CONTINUITY_EXIT_METADATA_KEY),
            exit_samples,
            expected_exit_population,
            TARGET_CONTINUITY_EXIT_SAMPLE_CAPACITY,
            f"run {run_ordinal + 1} exit",
        )
        errors.extend(episode_meta_errors)
        errors.extend(exit_meta_errors)

        valid_episode_samples: list[dict] = []
        valid_exit_samples: list[dict] = []
        episode_order: list[tuple[int, str]] = []
        exit_order: list[tuple[int, str]] = []
        episode_keys: set[str] = set()
        exit_keys: set[str] = set()
        episode_ids: set[tuple[int, int, int, int]] = set()
        exit_ids: set[tuple[int, int, int]] = set()
        if isinstance(episode_samples, list):
            for sample_ordinal, sample in enumerate(episode_samples):
                valid, sample_errors = _validate_episode_sample(
                    sample, run_ordinal, sample_ordinal
                )
                errors.extend(sample_errors)
                if valid is None:
                    continue
                valid_episode_samples.append(valid)
                sample_key = valid["sample_key"]
                episode_order.append((valid["sample_hash"], sample_key))
                if sample_key in episode_keys:
                    errors.append(f"run {run_ordinal + 1}: duplicate episode sample_key")
                episode_keys.add(sample_key)
                release = valid["release"]
                identity = (
                    run_ordinal,
                    release["actor_id"],
                    release["target_id"],
                    release["target_state_episode"],
                )
                if identity in episode_ids:
                    errors.append(f"run {run_ordinal + 1}: duplicate episode identity")
                episode_ids.add(identity)
        if isinstance(exit_samples, list):
            for sample_ordinal, sample in enumerate(exit_samples):
                valid, sample_errors = _validate_exit_sample(
                    sample, run_ordinal, sample_ordinal
                )
                errors.extend(sample_errors)
                if valid is None:
                    continue
                valid_exit_samples.append(valid)
                sample_key = valid["sample_key"]
                exit_order.append((valid["sample_hash"], sample_key))
                if sample_key in exit_keys:
                    errors.append(f"run {run_ordinal + 1}: duplicate exit sample_key")
                exit_keys.add(sample_key)
                identity = (
                    run_ordinal,
                    valid["actor_id"],
                    valid["state_episode_id"],
                )
                if identity in exit_ids:
                    errors.append(f"run {run_ordinal + 1}: duplicate exit identity")
                exit_ids.add(identity)
        if episode_order != sorted(episode_order):
            errors.append(f"run {run_ordinal + 1}: episode samples are not bottom-k sorted")
        if exit_order != sorted(exit_order):
            errors.append(f"run {run_ordinal + 1}: exit samples are not bottom-k sorted")

        if episode_meta is not None:
            result["episode_population"] += episode_meta["population"]
            result["episode_stored"] += episode_meta["stored"]
            result["episode_omitted"] += episode_meta["omitted"]
            any_omitted = any_omitted or episode_meta["omitted"] > 0
        if exit_meta is not None:
            result["exit_population"] += exit_meta["population"]
            result["exit_stored"] += exit_meta["stored"]
            result["exit_omitted"] += exit_meta["omitted"]
            any_omitted = any_omitted or exit_meta["omitted"] > 0
        episode_complete = bool(
            summary is not None
            and episode_meta is not None
            and episode_meta["complete"]
            and isinstance(episode_samples, list)
            and len(valid_episode_samples) == len(episode_samples)
        )
        exit_complete = bool(
            summary is not None
            and exit_meta is not None
            and exit_meta["complete"]
            and isinstance(exit_samples, list)
            and len(valid_exit_samples) == len(exit_samples)
        )
        if summary is not None and (episode_complete or exit_complete):
            errors.extend(
                f"run {run_ordinal + 1}: {reason}"
                for reason in _crosscheck_complete_raw_samples(
                    summary,
                    valid_episode_samples,
                    valid_exit_samples,
                    episode_complete,
                    exit_complete,
                )
            )

    result["errors"] = errors
    result["status"] = "invalid" if errors else ("sampled" if any_omitted else "complete")
    return result


def _print_v2_raw_coverage(raw: dict) -> None:
    status = raw["status"]
    if status == "unavailable":
        print("  raw linked-sample coverage: unavailable; aggregate remains authoritative")
        return
    details = (
        f"episodes population={raw['episode_population']} stored={raw['episode_stored']} "
        f"omitted={raw['episode_omitted']}; DISENGAGE exits "
        f"population={raw['exit_population']} stored={raw['exit_stored']} "
        f"omitted={raw['exit_omitted']}"
    )
    if status == "invalid":
        errors = raw.get("errors", [])
        reason = errors[0] if errors else "malformed metadata or linked samples"
        extra = len(errors) - 1
        suffix = f" (+{extra} more)" if extra > 0 else ""
        print(
            f"  raw linked-sample coverage: INVALID ({reason}{suffix}); {details}; "
            "aggregate remains authoritative"
        )
        return
    print(
        f"  raw linked-sample coverage: {status}; {details}; "
        "aggregate remains authoritative"
    )


def kill_ammo_status(actor: dict) -> str:
    try:
        mag = int(actor.get("mag", -1))
        reserve = int(actor.get("reserve", -1))
    except (TypeError, ValueError):
        return "unknown"
    if mag < 0 or reserve < 0:
        return "unknown"
    if mag <= 0 and reserve <= 0:
        return "dry"
    if mag <= 0:
        return "reload_available"
    return "rounds_available"


def print_opening_kill_context(runs: list[dict]) -> None:
    events = opening_kill_context_events(runs)
    if not events:
        return
    dropped = sum(
        max(0, int(run.get("pacing", {}).get("kill_context_dropped", 0) or 0))
        for run in runs
    )
    causes = Counter()
    weapons = Counter()
    states = Counter()
    origins = Counter()
    acquisitions = Counter()
    ammo_states = Counter()
    intent = Counter()
    victim_states = Counter()
    victim_pois = Counter()
    victim_poi_bands = Counter()
    victim_routes = Counter()
    victim_route_bands = Counter()
    for event in events:
        attacker = event.get("attacker", {})
        victim = event.get("victim", {})
        if not isinstance(attacker, dict):
            attacker = {}
        if not isinstance(victim, dict):
            victim = {}
        causes[str(event.get("cause", "unknown"))] += 1
        has_attacker = str(attacker.get("kind", "none")) != "none"
        if has_attacker:
            weapons[str(attacker.get("weapon", "none"))] += 1
            states[str(attacker.get("state", "none"))] += 1
            origins[str(attacker.get("attack_origin", "none"))] += 1
            acquisitions[str(attacker.get("acquisition_source", "none"))] += 1
            ammo_states[kill_ammo_status(attacker)] += 1
            intent["target_match" if bool(attacker.get("target_match", False)) else "off_target"] += 1
            # Only the attacker's history answers whether this kill was retaliation.
            # The victim's history already contains the fatal hit by snapshot time.
            recent = bool(attacker.get("opponent_recent_attacker", False))
            pressuring = bool(attacker.get("opponent_pressuring", False))
            if recent:
                intent["recent_retaliation"] += 1
            if pressuring:
                intent["opponent_pressuring"] += 1
            if not recent and not pressuring:
                intent["neutral_initiation"] += 1
        else:
            intent["unattributed"] += 1
        victim_states[str(victim.get("state", "unknown"))] += 1
        victim_pois[str(victim.get("poi_role", "open"))] += 1
        victim_poi_bands[str(victim.get("poi_band", "unknown"))] += 1
        victim_routes[str(victim.get("route_role", "off_route"))] += 1
        victim_route_bands[str(victim.get("route_band", "unknown"))] += 1
    print(
        f"Opening kill context (<= {OPENING_KILL_CONTEXT_SECONDS:.0f}s): "
        f"{len(events)} events, dropped={dropped}"
    )
    print(f"  causes=[{format_counts(causes)}], attacker weapons=[{format_counts(weapons)}]")
    print(f"  attacker states=[{format_counts(states)}], ammo=[{format_counts(ammo_states)}]")
    print(f"  attack origins=[{format_counts(origins)}]")
    print(f"  acquisition sources=[{format_counts(acquisitions)}]")
    print(f"  intent=[{format_counts(intent)}]")
    print(f"  victim states=[{format_counts(victim_states)}]")
    print(
        "  victim location: "
        f"poi=[{format_counts(victim_pois)}], poi-band=[{format_counts(victim_poi_bands)}], "
        f"route=[{format_counts(victim_routes)}], route-band=[{format_counts(victim_route_bands)}]"
    )


def _print_exact_target_continuity(
    summaries: list[dict], raw_coverage: dict
) -> None:
    releases = _summary_int_total(summaries, "survival_episode_releases")
    reacquired = _summary_int_total(
        summaries, "survival_episode_reacquired_1s"
    )
    exits = _summary_int_total(summaries, "disengage_exit_count")
    rate = 100.0 * reacquired / releases if releases else None
    rate_text = f"{rate:.1f}%" if rate is not None else "n/a"
    print(
        "Opening survival-target continuity "
        f"(schema v2 exact aggregate; release<={TARGET_CONTINUITY_ELIGIBLE_RELEASE_CUTOFF:.0f}s): "
        f"unique episode releases={releases}, same-target reacquired<=1s="
        f"{reacquired}/{releases} ({rate_text}), all DISENGAGE exits={exits}; "
        "aggregate diagnostic gate valid"
    )

    _print_v2_raw_coverage(raw_coverage)

    print(
        "  release target states="
        f"[{format_counts(_summary_counter(summaries, 'release_by_target_state'))}]"
    )
    print(
        f"  release reasons=[{format_counts(_summary_counter(summaries, 'release_by_reason'))}]"
    )
    print(
        f"  release sources=[{format_counts(_summary_counter(summaries, 'release_by_source'))}]"
    )
    print(
        "  reacquired<=1s sources="
        f"[{format_counts(_summary_counter(summaries, 'reacquire_by_source'))}]"
    )

    delay = _summary_measure(summaries, "reacquire_delay")
    reacquire_displacement = _summary_measure(
        summaries, "reacquire_displacement"
    )
    print(
        "  reacquired<=1s metrics: "
        f"delay {_format_summary_measure(delay, 's')}, "
        f"displacement {_format_summary_measure(reacquire_displacement, 'm')}, "
        f"stuck_delta={_summary_int_total(summaries, 'reacquire_stuck_delta_total')}, "
        "disengage_delta="
        f"{_summary_int_total(summaries, 'reacquire_disengage_entry_delta_total')}"
    )

    print(
        "  disengage entry->exit="
        f"[{format_counts(_summary_counter(summaries, 'disengage_transitions'))}]"
    )
    print(
        "  disengage entry reasons="
        f"[{format_counts(_summary_counter(summaries, 'disengage_by_entry_reason'))}], "
        "exit reasons="
        f"[{format_counts(_summary_counter(summaries, 'disengage_by_exit_reason'))}], "
        "exit states="
        f"[{format_counts(_summary_counter(summaries, 'disengage_by_exit_state'))}]"
    )
    same_entry_target = _summary_int_total(
        summaries, "disengage_same_entry_target"
    )
    reengage = _summary_int_total(summaries, "disengage_reengage")
    stuck_positive = _summary_int_total(summaries, "disengage_stuck_positive")
    same_rate = 100.0 * same_entry_target / exits if exits else None
    reengage_rate = 100.0 * reengage / exits if exits else None
    stuck_rate = 100.0 * stuck_positive / exits if exits else None
    same_text = f"{same_rate:.1f}%" if same_rate is not None else "n/a"
    reengage_text = f"{reengage_rate:.1f}%" if reengage_rate is not None else "n/a"
    stuck_text = f"{stuck_rate:.1f}%" if stuck_rate is not None else "n/a"
    duration = _summary_measure(summaries, "disengage_duration")
    exit_displacement = _summary_measure(summaries, "disengage_displacement")
    print(
        "  disengage exits: "
        f"same-entry-target={same_entry_target}/{exits} ({same_text}), "
        f"reengage={reengage}/{exits} ({reengage_text}), "
        f"duration {_format_summary_measure(duration, 's')}, "
        f"displacement {_format_summary_measure(exit_displacement, 'm')}, "
        f"stuck_delta={_summary_int_total(summaries, 'disengage_stuck_delta_total')}, "
        f"stuck-positive={stuck_positive}/{exits} ({stuck_text})"
    )


def print_opening_target_continuity(runs: list[dict]) -> None:
    if not runs:
        print("Opening survival-target continuity: unavailable (no runs).")
        return
    summaries, exact_errors, legacy_seen, summary_seen = (
        _validated_v2_target_continuity_summaries(runs)
    )
    if len(summaries) == len(runs) and not exact_errors:
        raw_coverage = _validate_v2_raw_coverage(runs, summaries)
        _print_exact_target_continuity(summaries, raw_coverage)
        return
    if summary_seen:
        if legacy_seen and all(
            isinstance(run.get("pacing", {}), dict)
            and isinstance(
                run.get("pacing", {}).get("target_continuity_summary"), dict
            )
            and run.get("pacing", {})
            .get("target_continuity_summary", {})
            .get("schema_version") == 1
            for run in runs
        ):
            print(
                "Opening survival-target continuity: legacy schema v1 "
                "informational only; schema v2 exact aggregate missing; "
                "aggregate diagnostic gate INVALID."
            )
            return
        reason = exact_errors[0] if exact_errors else "invalid advertised exact summary"
        extra = len(exact_errors) - 1
        suffix = f" (+{extra} more)" if extra > 0 else ""
        print(
            "Opening survival-target continuity: schema v2 exact aggregate "
            f"INVALID ({reason}{suffix}); aggregate diagnostic gate INVALID."
        )
        return
    v2_raw_advertised = any(
        isinstance(run.get("pacing", {}), dict)
        and any(
            key in run.get("pacing", {})
            for key in (
                TARGET_CONTINUITY_EPISODE_SAMPLES_KEY,
                TARGET_CONTINUITY_EPISODE_METADATA_KEY,
                TARGET_CONTINUITY_EXIT_SAMPLES_KEY,
                TARGET_CONTINUITY_EXIT_METADATA_KEY,
            )
        )
        for run in runs
    )
    if v2_raw_advertised:
        print(
            "Opening survival-target continuity: schema v2 linked samples are "
            "informational without a complete exact aggregate; aggregate "
            "diagnostic gate INVALID."
        )
        return
    if not _target_continuity_schema_available(runs) \
            or not _raw_target_continuity_available(runs):
        print(
            "Opening survival-target continuity: unavailable "
            "(exact aggregate/raw continuity coverage missing; legacy run schema accepted)."
        )
        return

    dropped = _target_continuity_dropped(runs)
    events = opening_target_continuity_events(runs)
    release_samples = [
        event for event in events if _event_key(event, ("event",), "") == "release"
    ]
    eligible_releases: list[dict] = []
    eligible_release_ids: set[tuple[int, int, int, int]] = set()
    raw_identity_complete = True
    for event in release_samples:
        release_time = _event_float(event, ("time",))
        target_state = _event_key(event, ("target_state",), "none")
        reason = _event_key(event, ("reason",), "unknown")
        if not 0.0 <= release_time <= TARGET_CONTINUITY_ELIGIBLE_RELEASE_CUTOFF:
            continue
        if target_state not in {"recover", "disengage"}:
            continue
        if reason in NON_REACQUIRABLE_RELEASE_REASONS:
            continue
        identity = _continuity_episode_identity(event)
        if identity is None:
            raw_identity_complete = False
            eligible_releases.append(event)
            continue
        if identity in eligible_release_ids:
            continue
        eligible_release_ids.add(identity)
        eligible_releases.append(event)

    reacquires = [
        event
        for event in events
        if _event_key(event, ("event",), "") == "same_target_reacquire"
    ]
    exit_samples = [
        event
        for event in events
        if _event_key(event, ("event",), "") == "disengage_exit"
    ]
    eligible_fast_reacquires: list[dict] = []
    reacquired_episode_ids: set[tuple[int, int, int, int]] = set()
    for event in reacquires:
        delay = _event_float(event, ("delay_seconds", "delay"))
        if not 0.0 <= delay <= TARGET_CONTINUITY_REACQUIRE_SECONDS:
            continue
        # release_time on Bot events is spawn-age based. event.time and
        # delay_seconds are both Telemetry elapsed time, so they are the
        # canonical raw-fallback censor axis.
        release_time = _continuity_release_time(event, release_samples)
        if not 0.0 <= release_time <= TARGET_CONTINUITY_ELIGIBLE_RELEASE_CUTOFF:
            continue
        if _event_key(event, ("release_reason",), "unknown") \
                in NON_REACQUIRABLE_RELEASE_REASONS:
            continue
        if _event_key(event, ("target_state",), "none") \
                not in {"recover", "disengage"}:
            continue
        identity = _continuity_episode_identity(event)
        if identity is None:
            raw_identity_complete = False
        else:
            if identity not in eligible_release_ids or identity in reacquired_episode_ids:
                continue
            reacquired_episode_ids.add(identity)
        eligible_fast_reacquires.append(event)

    exits: list[dict] = []
    exit_episode_ids: set[tuple[int, int, int]] = set()
    for event in exit_samples:
        try:
            identity = (
                int(event.get("_continuity_run_ordinal", -1)),
                int(event.get("actor_id", -1)),
                int(event.get("state_episode_id", -1)),
            )
        except (TypeError, ValueError):
            identity = (-1, -1)
        if min(identity) < 0:
            raw_identity_complete = False
            exits.append(event)
            continue
        if identity in exit_episode_ids:
            continue
        exit_episode_ids.add(identity)
        exits.append(event)

    rate = (
        100.0 * len(eligible_fast_reacquires) / len(eligible_releases)
        if eligible_releases
        else None
    )
    rate_text = f"{rate:.1f}%" if rate is not None else "n/a"
    if dropped > 0:
        sample_status = f"raw sample truncated (dropped={dropped})"
    elif not raw_identity_complete:
        sample_status = "raw sample identity incomplete (dropped=0)"
    else:
        sample_status = "raw sample complete (dropped=0)"
    print(
        "Opening survival-target continuity "
        f"(raw fallback; release<={TARGET_CONTINUITY_ELIGIBLE_RELEASE_CUTOFF:.0f}s): "
        f"sample release events={len(release_samples)}, "
        f"unique eligible episode releases={len(eligible_releases)}, "
        f"same-target reacquired<=1s={len(eligible_fast_reacquires)}/"
        f"{len(eligible_releases)} ({rate_text}), all DISENGAGE exits={len(exits)}; "
        f"{sample_status}; complete exact aggregate coverage missing; "
        "diagnostic gate INVALID"
    )

    release_target_states = Counter(
        _event_key(event, ("target_state",), "unknown")
        for event in eligible_releases
    )
    release_reasons = Counter(
        _event_key(event, ("reason",), "unknown") for event in eligible_releases
    )
    release_sources = Counter(
        _event_key(event, ("source",), "unknown") for event in eligible_releases
    )
    reacquire_sources = Counter(
        _event_key(event, ("source",), "unknown")
        for event in eligible_fast_reacquires
    )
    print(f"  release target states=[{format_counts(release_target_states)}]")
    print(f"  release reasons=[{format_counts(release_reasons)}]")
    print(f"  release sources=[{format_counts(release_sources)}]")
    print(f"  reacquired<=1s sources=[{format_counts(reacquire_sources)}]")

    reacquire_delays = _nonnegative_event_values(
        eligible_fast_reacquires, "delay_seconds", "delay"
    )
    reacquire_displacement = _nonnegative_event_values(
        eligible_fast_reacquires, "displacement"
    )
    print(
        "  reacquired<=1s metrics: "
        f"delay avg={_format_avg_seconds(reacquire_delays)}, "
        f"displacement {_format_avg_max_distance(reacquire_displacement)}, "
        f"stuck_delta={_event_delta_total(eligible_fast_reacquires, 'stuck_delta')}, "
        f"disengage_delta={_event_delta_total(eligible_fast_reacquires, 'disengage_delta', 'disengage_entry_delta')}"
    )

    exit_transitions = Counter()
    for event in exits:
        entry_reason = _event_key(event, ("entry_reason",), "unknown")
        exit_reason = _event_key(event, ("exit_reason", "reason"), "unknown")
        exit_state = _event_key(event, ("exit_state",), "unknown")
        exit_transitions[f"{entry_reason}->{exit_reason}/{exit_state}"] += 1
    same_entry_target = sum(bool(event.get("same_entry_target", False)) for event in exits)
    reengage = sum(
        bool(event.get("reengage", False))
        or _event_key(event, ("exit_state",), "unknown") in {"chase", "attack"}
        for event in exits
    )
    same_target_rate = 100.0 * same_entry_target / len(exits) if exits else None
    reengage_rate = 100.0 * reengage / len(exits) if exits else None
    same_target_text = f"{same_target_rate:.1f}%" if same_target_rate is not None else "n/a"
    reengage_text = f"{reengage_rate:.1f}%" if reengage_rate is not None else "n/a"
    exit_durations = _nonnegative_event_values(exits, "duration", "duration_seconds")
    exit_displacement = _nonnegative_event_values(exits, "displacement")
    exit_stuck_delta = _event_delta_total(exits, "stuck_delta")
    stuck_positive = sum(
        _event_float(event, ("stuck_delta",), 0.0) > 0.0 for event in exits
    )
    stuck_rate = 100.0 * stuck_positive / len(exits) if exits else None
    stuck_text = f"{stuck_rate:.1f}%" if stuck_rate is not None else "n/a"
    entry_reasons = Counter(
        _event_key(event, ("entry_reason",), "unknown") for event in exits
    )
    exit_reasons = Counter(
        _event_key(event, ("exit_reason", "reason"), "unknown") for event in exits
    )
    exit_states = Counter(
        _event_key(event, ("exit_state",), "unknown") for event in exits
    )
    print(f"  disengage entry->exit=[{format_counts(exit_transitions)}]")
    print(
        f"  disengage entry reasons=[{format_counts(entry_reasons)}], "
        f"exit reasons=[{format_counts(exit_reasons)}], "
        f"exit states=[{format_counts(exit_states)}]"
    )
    print(
        "  disengage exits: "
        f"same-entry-target={same_entry_target}/{len(exits)} ({same_target_text}), "
        f"reengage={reengage}/{len(exits)} ({reengage_text}), "
        f"duration avg={_format_avg_seconds(exit_durations)}, "
        f"displacement {_format_avg_max_distance(exit_displacement)}, "
        f"stuck_delta={exit_stuck_delta}, "
        f"stuck-positive={stuck_positive}/{len(exits)} ({stuck_text})"
    )


def print_survival_victim_continuity(runs: list[dict]) -> None:
    survival_events: list[dict] = []
    continuity_keys = {
        "state_age_seconds",
        "target_age_seconds",
        "disengage_entry_reason",
        "disengage_same_entry_target",
        "state_displacement",
        "state_stuck_delta",
    }
    for event in opening_kill_context_events(runs):
        victim = event.get("victim", {})
        if not isinstance(victim, dict):
            continue
        if str(victim.get("state", "")).strip().lower() not in {"recover", "disengage"}:
            continue
        survival_events.append(victim)

    has_continuity_fields = any(
        any(key in victim for key in continuity_keys)
        for victim in survival_events
    )
    if not has_continuity_fields:
        if _target_continuity_schema_available(runs) and not survival_events:
            print(
                f"Opening survival-victim continuity "
                f"(<= {OPENING_KILL_CONTEXT_SECONDS:.0f}s): 0 events"
            )
            return
        print(
            "Opening survival-victim continuity: unavailable "
            "(kill actor continuity fields missing; legacy run schema accepted)."
        )
        return

    state_age_bands = Counter(
        continuity_age_band(victim.get("state_age_seconds"))
        for victim in survival_events
    )
    target_age_bands = Counter(
        continuity_age_band(victim.get("target_age_seconds"))
        for victim in survival_events
    )
    entry_reasons = Counter(
        str(victim.get("disengage_entry_reason", "unknown")).strip().lower() or "unknown"
        for victim in survival_events
    )
    ordered_bands = ["<2s", "2-4.5s", "4.5s+", "unknown"]
    state_band_text = ", ".join(
        f"{band}={int(state_age_bands.get(band, 0))}" for band in ordered_bands
    )
    target_band_text = ", ".join(
        f"{band}={int(target_age_bands.get(band, 0))}" for band in ordered_bands
    )
    print(
        f"Opening survival-victim continuity "
        f"(<= {OPENING_KILL_CONTEXT_SECONDS:.0f}s): {len(survival_events)} events"
    )
    print(f"  state-age bands=[{state_band_text}]")
    print(f"  disengage entry reasons=[{format_counts(entry_reasons)}]")
    print(f"  target-age bands=[{target_band_text}]")

    movement_events = [
        victim
        for victim in survival_events
        if "state_displacement" in victim or "state_stuck_delta" in victim
    ]
    same_target_events = [
        victim
        for victim in survival_events
        if "disengage_same_entry_target" in victim
    ]
    if movement_events or same_target_events:
        displacement = _nonnegative_event_values(movement_events, "state_displacement")
        same_target = sum(
            bool(victim.get("disengage_same_entry_target", False))
            for victim in same_target_events
        )
        same_target_rate = (
            100.0 * same_target / len(same_target_events)
            if same_target_events
            else None
        )
        same_target_text = f"{same_target_rate:.1f}%" if same_target_rate is not None else "n/a"
        print(
            "  survival-state movement: "
            f"displacement {_format_avg_max_distance(displacement)}, "
            f"stuck_delta={_event_delta_total(movement_events, 'state_stuck_delta')}, "
            f"same-entry-target={same_target}/{len(same_target_events)} ({same_target_text})"
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
    acquisition_target_kinds = string_counter(runs, "pacing", "first_target_acquisition_target_kind")
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
            f"sources=[{format_mix(acquisition_sources)}], "
            f"targets=[{format_mix(acquisition_target_kinds)}], "
            f"states=[{format_mix(acquisition_states)}]"
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
    for line in format_survival_curve_lines(runs):
        print(line)
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
    print_opening_kill_context(runs)
    print_opening_target_continuity(runs)
    print_survival_victim_continuity(runs)
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
