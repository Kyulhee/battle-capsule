"""Shared alive-timeline analysis for simulation and manual-playtest reports.

The telemetry is an event staircase: an event's ``alive`` count is the state
immediately after that event and remains effective from ``time`` up to the next
event. When several deaths share a timestamp, list order is authoritative and
the last event at that timestamp is the checkpoint state.
"""

from __future__ import annotations

from statistics import median
from typing import Iterable


CHECKPOINT_SECONDS = (30.0, 60.0, 90.0, 120.0, 180.0, 260.0)


def _as_float(value: object, default: float = -1.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _as_int(value: object, default: int = -1) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def normalized_alive_timeline(run: dict) -> list[dict]:
    """Return valid samples in timestamp order while preserving equal-time order."""
    raw_timeline = run.get("pacing", {}).get("alive_timeline", [])
    if not isinstance(raw_timeline, list):
        return []

    samples: list[tuple[float, int, dict]] = []
    for sequence, raw_sample in enumerate(raw_timeline):
        if not isinstance(raw_sample, dict):
            continue
        time = _as_float(raw_sample.get("time"))
        alive = _as_int(raw_sample.get("alive"))
        if time < 0.0 or alive < 0:
            continue
        sample = dict(raw_sample)
        sample["time"] = time
        sample["alive"] = alive
        samples.append((time, sequence, sample))

    samples.sort(key=lambda item: (item[0], item[1]))
    return [sample for _, _, sample in samples]


def alive_at(timeline: list[dict], seconds: float) -> int | None:
    """Evaluate the right-continuous event staircase at ``seconds``."""
    value: int | None = None
    for sample in timeline:
        if float(sample["time"]) > seconds:
            break
        value = int(sample["alive"])
    return value


def _initial_alive(timeline: list[dict]) -> int | None:
    if not timeline:
        return None
    alive = int(timeline[0]["alive"])
    return alive if alive > 0 else None


def _run_duration(run: dict, timeline: list[dict]) -> float:
    duration = _as_float(run.get("core", {}).get("duration"), 0.0)
    if timeline:
        duration = max(duration, float(timeline[-1]["time"]))
    return max(0.0, duration)


def checkpoint_summaries(
    runs: Iterable[dict],
    checkpoints: Iterable[float] = CHECKPOINT_SECONDS,
) -> list[dict]:
    """Summarize the event staircase at fixed game times.

    Completed matches carry their final one-alive state forward. Player-death
    timelines ending above one are censored after their recorded duration.
    Legacy runs without ``alive_timeline`` remain valid inputs and are skipped.
    """
    run_list = list(runs)
    prepared = [
        (run, normalized_alive_timeline(run))
        for run in run_list
    ]
    timeline_runs = sum(1 for _, timeline in prepared if _initial_alive(timeline) is not None)
    summaries: list[dict] = []
    for checkpoint in checkpoints:
        seconds = float(checkpoint)
        alive_values: list[float] = []
        ratios: list[float] = []
        completed_carry = 0
        for run, timeline in prepared:
            initial = _initial_alive(timeline)
            if initial is None:
                continue
            if _run_duration(run, timeline) + 1e-6 < seconds:
                if int(timeline[-1]["alive"]) > 1:
                    continue
                alive = int(timeline[-1]["alive"])
                completed_carry += 1
            else:
                alive = alive_at(timeline, seconds)
            if alive is None:
                continue
            alive_values.append(float(alive))
            ratios.append(float(alive) / float(initial))
        summaries.append(
            {
                "seconds": seconds,
                "eligible": len(alive_values),
                "timeline_runs": timeline_runs,
                "total_runs": len(run_list),
                "avg_alive": sum(alive_values) / len(alive_values) if alive_values else None,
                "median_alive": median(alive_values) if alive_values else None,
                "avg_ratio": sum(ratios) / len(ratios) if ratios else None,
                "median_ratio": median(ratios) if ratios else None,
                "completed_carry": completed_carry,
            }
        )
    return summaries


def threshold_summary(runs: Iterable[dict], fraction: float) -> dict:
    """Return the first event time at/below a fraction of each run's start count."""
    run_list = list(runs)
    reached_times: list[float] = []
    timeline_runs = 0
    for run in run_list:
        timeline = normalized_alive_timeline(run)
        initial = _initial_alive(timeline)
        if initial is None:
            continue
        timeline_runs += 1
        threshold = float(initial) * float(fraction)
        for sample in timeline:
            if float(sample["alive"]) <= threshold:
                reached_times.append(float(sample["time"]))
                break
    return {
        "fraction": float(fraction),
        "reached": len(reached_times),
        "timeline_runs": timeline_runs,
        "total_runs": len(run_list),
        "avg_seconds": (
            sum(reached_times) / len(reached_times)
            if reached_times
            else None
        ),
        "median_seconds": median(reached_times) if reached_times else None,
    }


def alive_threshold_summary(runs: Iterable[dict], alive_threshold: int) -> dict:
    """Return the first event time at/below an absolute alive count."""
    run_list = list(runs)
    reached_times: list[float] = []
    timeline_runs = 0
    applicable_runs = 0
    threshold = max(0, int(alive_threshold))
    for run in run_list:
        timeline = normalized_alive_timeline(run)
        if _initial_alive(timeline) is None:
            continue
        timeline_runs += 1
        if int(_initial_alive(timeline)) <= threshold:
            continue
        applicable_runs += 1
        for sample in timeline:
            if int(sample["alive"]) <= threshold:
                reached_times.append(float(sample["time"]))
                break
    return {
        "alive_threshold": threshold,
        "reached": len(reached_times),
        "timeline_runs": timeline_runs,
        "applicable_runs": applicable_runs,
        "total_runs": len(run_list),
        "avg_seconds": (
            sum(reached_times) / len(reached_times)
            if reached_times
            else None
        ),
        "median_seconds": median(reached_times) if reached_times else None,
    }


def format_survival_curve_lines(runs: Iterable[dict]) -> list[str]:
    """Build a stable, legacy-compatible text report used by both analyzers."""
    run_list = list(runs)
    checkpoints = checkpoint_summaries(run_list)
    timeline_runs = checkpoints[0]["timeline_runs"] if checkpoints else 0
    if timeline_runs <= 0:
        return [
            "Survival curve: unavailable "
            "(pacing.alive_timeline missing; legacy run schema accepted)."
        ]

    lines = [
        "Survival curve (event staircase; each sample holds until the next event):"
    ]
    for summary in checkpoints:
        seconds = int(summary["seconds"])
        eligible = int(summary["eligible"])
        if eligible <= 0:
            lines.append(
                f"  {seconds}s: none "
                f"(0/{len(run_list)} runs reached checkpoint with timeline)"
            )
            continue
        lines.append(
            f"  {seconds}s: median alive={float(summary['median_alive']):.1f}, "
            f"median start ratio={100.0 * float(summary['median_ratio']):.1f}%; "
            f"avg={float(summary['avg_alive']):.1f} "
            f"({eligible}/{len(run_list)} runs, "
            f"completed carry={int(summary['completed_carry'])})"
        )

    for label, alive_threshold in (("T50 alive", 50), ("T10 alive", 10)):
        summary = alive_threshold_summary(run_list, alive_threshold)
        reached = int(summary["reached"])
        available = int(summary["applicable_runs"])
        median_seconds = summary["median_seconds"]
        if available <= 0:
            lines.append(f"  {label}: n/a (all starts <= {alive_threshold})")
            continue
        if median_seconds is None:
            lines.append(f"  {label}: not reached (0/{available} timeline runs)")
        else:
            lines.append(
                f"  {label}: median {float(median_seconds):.1f}s "
                f"(avg {float(summary['avg_seconds']):.1f}s; "
                f"{reached}/{available} timeline runs reached)"
            )

    for label, fraction in (("Half-life", 0.5), ("10% alive", 0.1)):
        summary = threshold_summary(run_list, fraction)
        reached = int(summary["reached"])
        available = int(summary["timeline_runs"])
        median_seconds = summary["median_seconds"]
        if median_seconds is None:
            lines.append(f"  {label}: not reached (0/{available} timeline runs)")
        else:
            lines.append(
                f"  {label}: median {float(median_seconds):.1f}s "
                f"(avg {float(summary['avg_seconds']):.1f}s; "
                f"{reached}/{available} timeline runs reached)"
            )
    return lines
