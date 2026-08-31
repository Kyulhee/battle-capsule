import contextlib
import copy
import io
import math

from summarize_pacing_baseline import (
    _continuity_release_time,
    continuity_age_band,
    kill_ammo_status,
    opening_kill_context_events,
    opening_target_continuity_events,
    print_opening_kill_context,
    print_opening_survival_exposure,
    print_opening_target_continuity,
    print_survival_break_episode_linkage,
    print_survival_victim_continuity,
    _target_continuity_stable_hash,
)


EXPOSURE_AXES = (
    "poi_name",
    "poi_role",
    "poi_band",
    "route_id",
    "route_role",
    "route_band",
)


def exposure_event(
    count: int,
    state_counts: dict[str, int],
    source: str,
    reason: str,
) -> dict:
    event = {
        "count": count,
        "known_location_count": count,
        "unknown_location_count": 0,
        "by_state": state_counts,
        "by_source": {source: count} if count else {},
        "by_reason": {reason: count} if count else {},
        "by_distance_bucket": {"under_2m": count} if count else {},
        "by_threat_count_bucket": {"1": count} if count else {},
    }
    location_keys = {
        "poi_name": "survey_camp",
        "poi_role": "loot_hub",
        "poi_band": "inside",
        "route_id": "west_loop",
        "route_role": "primary_choke",
        "route_band": "on_route",
    }
    for axis, key in location_keys.items():
        event[f"by_{axis}"] = {key: count} if count else {}
    return event


def exposure_summary(
    recover_seconds: float = 30.0,
    disengage_seconds: float = 10.0,
    unknown_seconds: float = 2.0,
    tracked_actors: int = 5,
    acquisition_count: int = 4,
    entry_count: int = 3,
    death_count: int = 2,
) -> dict:
    known_keys = {
        "poi_name": "survey_camp",
        "poi_role": "loot_hub",
        "poi_band": "inside",
        "route_id": "west_loop",
        "route_role": "primary_choke",
        "route_band": "on_route",
    }
    actor_axes = {}
    unknown_recover = min(recover_seconds, unknown_seconds)
    unknown_disengage = min(
        disengage_seconds, max(0.0, unknown_seconds - unknown_recover)
    )
    for axis, known_key in known_keys.items():
        actor_axes[f"actor_seconds_by_state_and_{axis}"] = {
            "recover": {
                **(
                    {known_key: recover_seconds - unknown_recover}
                    if recover_seconds > unknown_recover
                    else {}
                ),
                **({"unknown": unknown_recover} if unknown_recover > 0.0 else {}),
            },
            "disengage": {
                **(
                    {known_key: disengage_seconds - unknown_disengage}
                    if disengage_seconds > unknown_disengage
                    else {}
                ),
                **(
                    {"unknown": unknown_disengage}
                    if unknown_disengage > 0.0
                    else {}
                ),
            },
        }
    acquisition_states = (
        {"recover": acquisition_count} if acquisition_count else {}
    )
    entry_states = {"disengage": entry_count} if entry_count else {}
    death_states = {}
    if death_count:
        recover_deaths = death_count // 2
        disengage_deaths = death_count - recover_deaths
        if recover_deaths:
            death_states["recover"] = recover_deaths
        if disengage_deaths:
            death_states["disengage"] = disengage_deaths
    return {
        "schema_version": 1,
        "exact": True,
        "complete": True,
        "population": "bots_only",
        "window_seconds": 60.0,
        "time_basis": "match_elapsed",
        "interval_seconds": 0.25,
        "attribution": "left_edge_sample_hold",
        "context_basis": "state_entry_and_periodic_static_map_classification",
        "counter_capacity": 64,
        "overflow_bucket": "other",
        "distance_buckets": [
            "under_2m",
            "2_5m",
            "5_10m",
            "10m_plus",
            "unknown",
        ],
        "threat_count_basis": "cached_additional_threats",
        "threat_count_buckets": ["0", "1", "2", "3_plus", "unknown"],
        "survival_death_source_basis": "last_damage_source",
        "survival_death_reason_basis": "last_damage_weapon",
        "map_spec_path": "res://data/maps/night_map.json",
        "scale_preset": "play_11",
        "location_taxonomy": "strategic_position_v1",
        "location_overflowed": False,
        "tracked_actors": tracked_actors,
        "initial_survival_state_counts": {
            "recover": min(tracked_actors, 1),
            "disengage": min(max(0, tracked_actors - 1), 1),
        },
        "actor_seconds_total": recover_seconds + disengage_seconds,
        "known_location_actor_seconds": (
            recover_seconds + disengage_seconds - unknown_seconds
        ),
        "unknown_location_actor_seconds": unknown_seconds,
        "actor_seconds_by_state": {
            "recover": recover_seconds,
            "disengage": disengage_seconds,
        },
        **actor_axes,
        "target_acquisitions": exposure_event(
            acquisition_count,
            acquisition_states,
            "idle_reaction",
            "target_change",
        ),
        "disengage_entries": exposure_event(
            entry_count,
            entry_states,
            "state_entry",
            "survival_break",
        ),
        "opening_bot_deaths": death_count,
        "survival_deaths": exposure_event(
            death_count,
            death_states,
            "melee",
            "unarmed",
        ),
    }


def survival_break_summary() -> dict:
    return {
        "schema_version": 2,
        "exact": True,
        "complete": True,
        "population": "opening_survival_break_disengage_episodes",
        "window_seconds": 60.0,
        "entry_censor_seconds": 59.0,
        "time_basis": "match_elapsed",
        "entry_visibility_basis": "existing_perception_revealed",
        "episodes": 2,
        "completed": 2,
        "censored": 0,
        "deaths": 1,
        "damaged_episodes": 1,
        "counteraction_episodes": 1,
        "cover_selected_episodes": 1,
        "cover_reached_episodes": 1,
        "cover_progress_observed_episodes": 1,
        "perception_lost_episodes": 1,
        "damage_after_cover_selected_episodes": 1,
        "nearest_target_missing_episodes": 1,
        "release_episodes": 1,
        "fast_reacquired_1s_episodes": 1,
        "entry_hp_ratio": {"count": 2, "sum": 0.6, "max": 0.4},
        "entry_shield_ratio": {"count": 2, "sum": 0.5, "max": 0.5},
        "entry_target_distance": {"count": 2, "sum": 7.0, "max": 4.0},
        "incoming_raw_damage": {"count": 1, "sum": 12.0, "max": 12.0},
        "damage_events": {"count": 1, "sum": 2.0, "max": 2.0},
        "cover_distance": {"count": 1, "sum": 6.0, "max": 6.0},
        "cover_min_distance": {"count": 1, "sum": 1.0, "max": 1.0},
        "cover_progress_ratio": {"count": 1, "sum": 0.833333, "max": 0.833333},
        "time_to_cover": {"count": 1, "sum": 0.5, "max": 0.5},
        "first_damage_after_cover_delay": {"count": 1, "sum": 0.2, "max": 0.2},
        "death_after_cover_selection_delay": {"count": 1, "sum": 1.0, "max": 1.0},
        "first_perception_loss_delay": {"count": 1, "sum": 0.3, "max": 0.3},
        "exit_duration": {"count": 2, "sum": 3.0, "max": 2.0},
        "entry_by_hp_bucket": {"0_25": 1, "25_50": 1},
        "entry_by_shield_bucket": {"0_25": 1, "25_50": 1},
        "entry_by_target_kind": {"bot": 2},
        "entry_by_target_distance_bucket": {"2_5m": 2},
        "entry_by_visibility": {"revealed": 1, "tracked": 1},
        "exit_by_reason": {"death": 1, "no_threat": 1},
        "exit_by_state": {"dead": 1, "idle": 1},
        "death_by_cover_outcome": {"reached": 1},
        "death_by_cover_progress": {"reached": 1},
        "death_by_first_damage_after_cover": {"under_0_25s": 1},
        "death_by_perception_loss": {"yes": 1},
        "death_by_entry_visibility": {"revealed": 1},
        "death_by_nearest_target_missing": {"no": 1},
        "death_by_counteraction": {"yes": 1},
        "death_by_fast_reacquired": {"yes": 1},
        "death_by_killer_relation": {"entry_target": 1},
        "fast_reacquire_by_source": {"retreat_counteraction": 1},
    }


def survival_break_report_for(runs: list[dict]) -> str:
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        print_survival_break_episode_linkage(runs)
    return output.getvalue()


def complete_zero_summary() -> dict:
    """Return the canonical complete schema-v2 zero aggregate fixture."""
    return {
        "schema_version": 2,
        "exact": True,
        "complete": True,
        "window_seconds": 60.0,
        "release_censor_seconds": 59.0,
        "reacquire_seconds": 1.0,
        "release_time_basis": "match_elapsed",
        "survival_episode_releases": 0,
        "survival_episode_reacquired_1s": 0,
        "release_by_target_state": {},
        "release_by_reason": {},
        "release_by_source": {},
        "reacquire_by_source": {},
        "reacquire_delay": {"count": 0, "sum": 0.0, "max": 0.0},
        "reacquire_displacement": {"count": 0, "sum": 0.0, "max": 0.0},
        "reacquire_stuck_delta_total": 0,
        "reacquire_disengage_entry_delta_total": 0,
        "disengage_exit_count": 0,
        "disengage_same_entry_target": 0,
        "disengage_reengage": 0,
        "disengage_stuck_positive": 0,
        "disengage_duration": {"count": 0, "sum": 0.0, "max": 0.0},
        "disengage_displacement": {"count": 0, "sum": 0.0, "max": 0.0},
        "disengage_stuck_delta_total": 0,
        "disengage_by_entry_reason": {},
        "disengage_by_exit_reason": {},
        "disengage_by_exit_state": {},
        "disengage_transitions": {},
    }


def one_episode_summary() -> dict:
    summary = complete_zero_summary()
    summary.update(
        {
            "survival_episode_releases": 1,
            "survival_episode_reacquired_1s": 1,
            "release_by_target_state": {"disengage": 1},
            "release_by_reason": {"memory_expired": 1},
            "release_by_source": {"attack": 1},
            "reacquire_by_source": {"idle_reaction": 1},
            "reacquire_delay": {"count": 1, "sum": 0.6, "max": 0.6},
            "reacquire_displacement": {"count": 1, "sum": 0.75, "max": 0.75},
            "reacquire_stuck_delta_total": 1,
            "reacquire_disengage_entry_delta_total": 2,
            "disengage_exit_count": 1,
            "disengage_same_entry_target": 1,
            "disengage_reengage": 1,
            "disengage_stuck_positive": 1,
            "disengage_duration": {"count": 1, "sum": 3.0, "max": 3.0},
            "disengage_displacement": {"count": 1, "sum": 2.5, "max": 2.5},
            "disengage_stuck_delta_total": 1,
            "disengage_by_entry_reason": {"survival_break": 1},
            "disengage_by_exit_reason": {"reengage": 1},
            "disengage_by_exit_state": {"chase": 1},
            "disengage_transitions": {"survival_break->reengage/chase": 1},
        }
    )
    return summary


def sample_metadata(population: int, stored: int, omitted: int) -> dict:
    return {
        "method": "deterministic_bottom_k_stable_hash",
        "capacity": 128,
        "population": population,
        "stored": stored,
        "omitted": omitted,
        "complete": omitted == 0,
    }


def one_episode_sample() -> dict:
    sample_key = "1|2|7"
    return {
        "sample_key": sample_key,
        "sample_hash": _target_continuity_stable_hash(sample_key),
        "release": {
            "time": 10.0,
            "release_time": 10.0,
            "release_time_basis": "match_elapsed",
            "actor_id": 1,
            "target_id": 2,
            "target_state_episode": 7,
            "state": "attack",
            "target_state": "disengage",
            "reason": "memory_expired",
            "source": "attack",
            "target_source": "idle_reaction",
            "distance": 6.0,
            "target_age_seconds": 2.0,
            "move_intent": "combat",
            "nav_intent": False,
            "speed": 4.0,
            "nav_target_distance": -1.0,
        },
        "reacquire_1s": {
            "time": 10.6,
            "release_time": 10.0,
            "paired_release_time": 10.0,
            "release_time_basis": "match_elapsed",
            "delay_seconds": 0.6,
            "actor_id": 1,
            "target_id": 2,
            "target_state_episode": 7,
            "state": "idle",
            "source": "idle_reaction",
            "target_state": "disengage",
            "release_reason": "memory_expired",
            "release_source": "attack",
            "paired_release_reason": "memory_expired",
            "paired_release_source": "attack",
            "distance": 5.0,
            "target_age_seconds": 0.0,
            "displacement": 0.75,
            "stuck_delta": 1,
            "disengage_entry_delta": 2,
            "spawn_delay_seconds": 0.6,
            "move_intent": "combat",
            "nav_intent": False,
            "speed": 4.0,
            "nav_target_distance": -1.0,
        },
    }


def release_only_sample(actor_id: int) -> dict:
    sample_key = f"{actor_id}|2|7"
    return {
        "sample_key": sample_key,
        "sample_hash": _target_continuity_stable_hash(sample_key),
        "release": {
            "time": 10.0,
            "release_time": 10.0,
            "release_time_basis": "match_elapsed",
            "actor_id": actor_id,
            "target_id": 2,
            "target_state_episode": 7,
            "state": "attack",
            "target_state": "disengage",
            "reason": "memory_expired",
            "source": "attack",
            "target_source": "idle_reaction",
            "distance": 6.0,
            "target_age_seconds": 2.0,
            "move_intent": "combat",
            "nav_intent": False,
            "speed": 4.0,
            "nav_target_distance": -1.0,
        },
    }


def one_exit_sample() -> dict:
    sample_key = "2|40"
    return {
        "sample_key": sample_key,
        "sample_hash": _target_continuity_stable_hash(sample_key),
        "time": 40.0,
        "actor_id": 2,
        "target_id": 1,
        "entry_target_id": 1,
        "current_target_id": 1,
        "state_episode_id": 40,
        "state": "disengage",
        "entry_reason": "survival_break",
        "reason": "reengage",
        "exit_state": "chase",
        "source": "state_exit",
        "duration_seconds": 3.0,
        "displacement": 2.5,
        "stuck_delta": 1,
        "same_entry_target": True,
        "reengage": True,
        "visible_enemies": 1,
        "additional_threats": 0,
        "targeting_player": False,
        "move_intent": "combat",
        "nav_intent": True,
        "speed": 4.0,
        "nav_target_distance": 3.0,
    }


def death_exit_summary() -> dict:
    summary = complete_zero_summary()
    summary.update(
        {
            "disengage_exit_count": 1,
            "disengage_duration": {"count": 1, "sum": 2.0, "max": 2.0},
            "disengage_displacement": {"count": 1, "sum": 1.0, "max": 1.0},
            "disengage_by_entry_reason": {"death_probe": 1},
            "disengage_by_exit_reason": {"death": 1},
            "disengage_by_exit_state": {"dead": 1},
            "disengage_transitions": {"death_probe->death/dead": 1},
        }
    )
    return summary


def death_exit_sample(actor_id: int = 9, entry_reason: str = "death_probe") -> dict:
    state_episode_id = 41
    sample_key = f"{actor_id}|{state_episode_id}"
    return {
        "sample_key": sample_key,
        "sample_hash": _target_continuity_stable_hash(sample_key),
        "time": 12.0,
        "actor_id": actor_id,
        "target_id": -1,
        "entry_target_id": -1,
        "current_target_id": -1,
        "state_episode_id": state_episode_id,
        "state": "disengage",
        "entry_reason": entry_reason,
        "reason": "death",
        "exit_state": "dead",
        "source": "none",
        "duration_seconds": 2.0,
        "displacement": 1.0,
        "stuck_delta": 0,
        "same_entry_target": False,
        "reengage": False,
        "visible_enemies": -1,
        "additional_threats": -1,
        "targeting_player": False,
        "move_intent": "stationary",
        "nav_intent": False,
        "speed": 0.0,
        "nav_target_distance": -1.0,
    }


def collapsed_other_exit_summary() -> dict:
    summary = complete_zero_summary()
    explicit_entry_reasons = {
        f"reason_{index}": 1 for index in range(31)
    }
    explicit_transitions = {
        f"reason_{index}->death/dead": 1 for index in range(31)
    }
    summary.update(
        {
            "disengage_exit_count": 32,
            "disengage_duration": {"count": 32, "sum": 64.0, "max": 2.0},
            "disengage_displacement": {
                "count": 32,
                "sum": 32.0,
                "max": 1.0,
            },
            "disengage_by_entry_reason": {
                **explicit_entry_reasons,
                "other": 1,
            },
            "disengage_by_exit_reason": {"death": 32},
            "disengage_by_exit_state": {"dead": 32},
            "disengage_transitions": {
                **explicit_transitions,
                "other": 1,
            },
        }
    )
    return summary


def v2_run(
    summary: dict | None = None,
    episode_samples: list[dict] | None = None,
    exit_samples: list[dict] | None = None,
    episode_metadata: dict | None = None,
    exit_metadata: dict | None = None,
) -> dict:
    pacing = {"target_continuity_summary": summary or complete_zero_summary()}
    if episode_samples is not None:
        pacing["target_continuity_episode_samples"] = episode_samples
        pacing["target_continuity_episode_sample_metadata"] = (
            episode_metadata
            if episode_metadata is not None
            else sample_metadata(len(episode_samples), len(episode_samples), 0)
        )
    if exit_samples is not None:
        pacing["target_continuity_disengage_exit_samples"] = exit_samples
        pacing["target_continuity_disengage_exit_sample_metadata"] = (
            exit_metadata
            if exit_metadata is not None
            else sample_metadata(len(exit_samples), len(exit_samples), 0)
        )
    return {"pacing": pacing}


def report_for(runs: list[dict]) -> str:
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        print_opening_target_continuity(runs)
    return output.getvalue()


def exposure_report_for(runs: list[dict]) -> str:
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        print_opening_survival_exposure(runs)
    return output.getvalue()


def assert_contains(report: str, *expected_fragments: str) -> None:
    for expected in expected_fragments:
        if expected not in report:
            raise AssertionError(f"Missing pacing analysis contract: {expected}\n{report}")


def verify_kill_context_and_age_bands() -> None:
    runs = [
        {
            "pacing": {
                "kill_context_dropped": 2,
                "kill_context_events": [
                    {
                        "time": 12.0,
                        "cause": "gun",
                        "victim": {
                            "state": "recover",
                            "state_age_seconds": 1.5,
                            "target_age_seconds": 0.8,
                            "disengage_entry_reason": "none",
                            "disengage_same_entry_target": False,
                            "state_displacement": 0.4,
                            "state_stuck_delta": 0,
                            "poi_role": "loot_hub",
                            "poi_band": "inside",
                            "route_role": "primary_choke",
                            "route_band": "near_0_4m",
                        },
                        "attacker": {
                            "kind": "bot",
                            "weapon": "ar",
                            "state": "attack",
                            "mag": 2,
                            "reserve": 0,
                            "attack_origin": "gun",
                            "acquisition_source": "objective_interrupt",
                            "target_match": True,
                            "opponent_recent_attacker": False,
                            "opponent_pressuring": False,
                        },
                    },
                    {
                        "time": 60.0,
                        "cause": "melee",
                        "victim": {
                            "state": "disengage",
                            "state_age_seconds": 3.0,
                            "target_age_seconds": 5.0,
                            "disengage_entry_reason": "survival_break",
                            "disengage_same_entry_target": True,
                            "state_displacement": 2.0,
                            "state_stuck_delta": 1,
                            "poi_role": "transit_choke",
                            "poi_band": "near_4_8m",
                            "route_role": "primary_choke",
                            "route_band": "on_route",
                        },
                        "attacker": {
                            "kind": "bot",
                            "weapon": "shotgun",
                            "state": "attack",
                            "mag": 0,
                            "reserve": 0,
                            "attack_origin": "recover_melee",
                            "acquisition_source": "recover_melee",
                            "target_match": True,
                            "opponent_recent_attacker": True,
                            "opponent_pressuring": True,
                        },
                    },
                    {"time": 60.01, "cause": "zone", "victim": {}, "attacker": {}},
                ],
            }
        }
    ]
    if len(opening_kill_context_events(runs)) != 2:
        raise AssertionError("Opening kill context cutoff must include exactly <=60s.")
    expected_age_bands = {
        0.0: "<2s",
        2.0: "2-4.5s",
        4.5: "4.5s+",
        -1.0: "unknown",
        None: "unknown",
    }
    for raw_age, expected in expected_age_bands.items():
        if continuity_age_band(raw_age) != expected:
            raise AssertionError(f"Unexpected continuity age band for {raw_age!r}.")
    ammo_expectations = (
        ({"mag": 0, "reserve": 0}, "dry"),
        ({"mag": 0, "reserve": 4}, "reload_available"),
        ({"mag": 1, "reserve": 0}, "rounds_available"),
        ({"mag": -1, "reserve": -1}, "unknown"),
    )
    for actor, expected in ammo_expectations:
        if kill_ammo_status(actor) != expected:
            raise AssertionError(f"Unexpected ammo state for {actor}.")

    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        print_opening_kill_context(runs)
        print_survival_victim_continuity(runs)
    assert_contains(
        output.getvalue(),
        "Opening kill context (<= 60s): 2 events, dropped=2",
        "neutral_initiation=1",
        "recent_retaliation=1",
        "victim states=[recover=1, disengage=1]",
        "Opening survival-victim continuity (<= 60s): 2 events",
        "state-age bands=[<2s=1, 2-4.5s=1, 4.5s+=0, unknown=0]",
        "target-age bands=[<2s=1, 2-4.5s=0, 4.5s+=1, unknown=0]",
    )


def verify_schema_v2_contract() -> None:
    zero_report = report_for([v2_run()])
    assert_contains(
        zero_report,
        "schema v2 exact aggregate; release<=59s",
        "unique episode releases=0",
        "aggregate diagnostic gate valid",
        "raw linked-sample coverage: unavailable",
    )

    complete_run = v2_run(
        one_episode_summary(),
        [one_episode_sample()],
        [one_exit_sample()],
    )
    complete_report = report_for([complete_run])
    assert_contains(
        complete_report,
        "unique episode releases=1, same-target reacquired<=1s=1/1 (100.0%)",
        "raw linked-sample coverage: complete",
        "episodes population=1 stored=1 omitted=0",
        "DISENGAGE exits population=1 stored=1 omitted=0",
        "release reasons=[memory_expired=1]",
        "survival_break->reengage/chase=1",
    )

    terminal_death_run = v2_run(
        death_exit_summary(),
        [],
        [death_exit_sample()],
    )
    terminal_death_report = report_for([terminal_death_run])
    assert_contains(
        terminal_death_report,
        "all DISENGAGE exits=1",
        "raw linked-sample coverage: complete",
        "exit reasons=[death=1]",
        "exit states=[dead=1]",
        "death_probe->death/dead=1",
        "reengage=0/1 (0.0%)",
    )

    # Complete raw remains authoritative enough to cross-check a bounded
    # summary counter: 31 explicit keys plus `other` represent 32 raw keys.
    collapsed_other_exits = sorted(
        (
            death_exit_sample(100 + index, f"reason_{index}")
            for index in range(32)
        ),
        key=lambda sample: (sample["sample_hash"], sample["sample_key"]),
    )
    collapsed_other_report = report_for(
        [v2_run(collapsed_other_exit_summary(), [], collapsed_other_exits)]
    )
    assert_contains(
        collapsed_other_report,
        "all DISENGAGE exits=32",
        "aggregate diagnostic gate valid",
        "raw linked-sample coverage: complete",
        "DISENGAGE exits population=32 stored=32 omitted=0",
    )

    # Bottom-k omission changes raw coverage only. The exact aggregate remains
    # the release/reacquire gate, even when no omitted row is inspectable.
    sampled_summary = complete_zero_summary()
    sampled_summary.update(
        {
            "survival_episode_releases": 129,
            "release_by_target_state": {"disengage": 129},
            "release_by_reason": {"memory_expired": 129},
            "release_by_source": {"attack": 129},
        }
    )
    sampled_episodes = sorted(
        (release_only_sample(actor_id) for actor_id in range(1, 129)),
        key=lambda sample: (sample["sample_hash"], sample["sample_key"]),
    )
    sampled_run = v2_run(
        sampled_summary,
        sampled_episodes,
        [],
        sample_metadata(129, 128, 1),
        sample_metadata(0, 0, 0),
    )
    sampled_report = report_for([sampled_run])
    assert_contains(
        sampled_report,
        "unique episode releases=129, same-target reacquired<=1s=0/129 (0.0%)",
        "aggregate diagnostic gate valid",
        "raw linked-sample coverage: sampled",
        "episodes population=129 stored=128 omitted=1",
    )

    # Missing raw arrays are explicitly unavailable, never mistaken for a zero
    # population and never allowed to invalidate a valid exact aggregate.
    raw_absent_report = report_for([v2_run(one_episode_summary())])
    assert_contains(
        raw_absent_report,
        "aggregate diagnostic gate valid",
        "raw linked-sample coverage: unavailable",
    )

    # Identical Godot instance IDs in separate runs are distinct populations.
    # Both complete raw cross-checks must survive aggregation.
    multi_run_report = report_for([copy.deepcopy(complete_run), copy.deepcopy(complete_run)])
    assert_contains(
        multi_run_report,
        "unique episode releases=2, same-target reacquired<=1s=2/2 (100.0%)",
        "all DISENGAGE exits=2",
        "episodes population=2 stored=2 omitted=0",
        "DISENGAGE exits population=2 stored=2 omitted=0",
    )


def verify_invalid_contracts() -> None:
    complete_run = v2_run(
        one_episode_summary(),
        [one_episode_sample()],
        [one_exit_sample()],
    )
    partial = {
        "pacing": {
            "target_continuity_summary": {
                "schema_version": 2,
                "exact": True,
                "complete": True,
            }
        }
    }
    assert_contains(
        report_for([partial]),
        "schema v2 exact aggregate INVALID",
        "aggregate diagnostic gate INVALID",
    )
    assert_contains(
        report_for([{"pacing": {"target_continuity_summary": None}}]),
        "schema v2 exact aggregate INVALID",
        "aggregate diagnostic gate INVALID",
    )

    malformed_cases: list[tuple[str, dict]] = []
    bool_count = one_episode_summary()
    bool_count["survival_episode_releases"] = True
    malformed_cases.append(("boolean count", bool_count))
    nonfinite = one_episode_summary()
    nonfinite["reacquire_delay"]["sum"] = math.nan
    malformed_cases.append(("non-finite measure", nonfinite))
    reacquire_overflow = one_episode_summary()
    reacquire_overflow["survival_episode_reacquired_1s"] = 2
    malformed_cases.append(("reacquire exceeds release", reacquire_overflow))
    terminal = one_episode_summary()
    terminal["release_by_reason"] = {"target_killed": 1}
    malformed_cases.append(("terminal release reason", terminal))
    incomplete_exact = one_episode_summary()
    incomplete_exact["complete"] = False
    malformed_cases.append(("incomplete advertised exact", incomplete_exact))
    oversized_counter = complete_zero_summary()
    oversized_counter.update(
        {
            "survival_episode_releases": 33,
            "release_by_target_state": {"disengage": 33},
            "release_by_reason": {f"reason_{index}": 1 for index in range(33)},
            "release_by_source": {"attack": 33},
        }
    )
    malformed_cases.append(("counter exceeds 32 keys", oversized_counter))
    for label, summary in malformed_cases:
        report = report_for([v2_run(summary)])
        if "schema v2 exact aggregate INVALID" not in report:
            raise AssertionError(f"Malformed {label} silently passed.\n{report}")

    malformed_metadata = copy.deepcopy(complete_run)
    malformed_metadata["pacing"]["target_continuity_episode_sample_metadata"][
        "population"
    ] = True
    metadata_report = report_for([malformed_metadata])
    assert_contains(
        metadata_report,
        "aggregate diagnostic gate valid",
        "raw linked-sample coverage: INVALID",
        "population must be a nonnegative integer",
    )

    population_mismatch = copy.deepcopy(complete_run)
    population_mismatch["pacing"]["target_continuity_episode_sample_metadata"].update(
        {"population": 2, "stored": 1, "omitted": 0, "complete": True}
    )
    mismatch_report = report_for([population_mismatch])
    assert_contains(
        mismatch_report,
        "aggregate diagnostic gate valid",
        "raw linked-sample coverage: INVALID",
    )

    raw_terminal = copy.deepcopy(complete_run)
    raw_terminal["pacing"]["target_continuity_episode_samples"][0]["release"][
        "reason"
    ] = "invalid_target"
    assert_contains(
        report_for([raw_terminal]),
        "aggregate diagnostic gate valid",
        "raw linked-sample coverage: INVALID",
        "release.reason is terminal",
    )

    for key, changed_value, expected in (
        ("reason", "target_switch", "complete raw release_by_reason disagrees"),
        ("source", "chase", "complete raw release_by_source disagrees"),
    ):
        raw_counter_mismatch = copy.deepcopy(complete_run)
        raw_counter_mismatch["pacing"]["target_continuity_episode_samples"][0][
            "release"
        ][key] = changed_value
        assert_contains(
            report_for([raw_counter_mismatch]),
            "aggregate diagnostic gate valid",
            "raw linked-sample coverage: INVALID",
            expected,
        )

    tampered_hash = copy.deepcopy(complete_run)
    tampered_hash["pacing"]["target_continuity_episode_samples"][0][
        "sample_hash"
    ] += 1
    assert_contains(
        report_for([tampered_hash]),
        "aggregate diagnostic gate valid",
        "raw linked-sample coverage: INVALID",
        "sample_hash does not match sample_key",
    )

    terminal_pair = copy.deepcopy(complete_run)
    terminal_reacquire = terminal_pair["pacing"][
        "target_continuity_episode_samples"
    ][0]["reacquire_1s"]
    terminal_reacquire["release_reason"] = "target_killed"
    terminal_reacquire["paired_release_reason"] = "target_killed"
    assert_contains(
        report_for([terminal_pair]),
        "aggregate diagnostic gate valid",
        "raw linked-sample coverage: INVALID",
        "paired release reason is terminal",
    )

    impossible_pair_time = copy.deepcopy(complete_run)
    early_pair = impossible_pair_time["pacing"][
        "target_continuity_episode_samples"
    ][0]["reacquire_1s"]
    early_pair["release_time"] = 9.0
    early_pair["paired_release_time"] = 9.0
    early_pair["delay_seconds"] = 1.0
    assert_contains(
        report_for([impossible_pair_time]),
        "aggregate diagnostic gate valid",
        "raw linked-sample coverage: INVALID",
        "paired release precedes first release sample",
    )

    impossible_bottom_k = copy.deepcopy(complete_run)
    impossible_bottom_k["pacing"]["target_continuity_episode_sample_metadata"].update(
        {"population": 1, "stored": 0, "omitted": 1, "complete": False}
    )
    impossible_bottom_k["pacing"]["target_continuity_episode_samples"] = []
    assert_contains(
        report_for([impossible_bottom_k]),
        "aggregate diagnostic gate valid",
        "raw linked-sample coverage: INVALID",
        "stored must equal min(population, capacity)",
    )

    target_state_mismatch = copy.deepcopy(complete_run)
    target_state_mismatch["pacing"]["target_continuity_episode_samples"][0][
        "reacquire_1s"
    ]["target_state"] = "recover"
    assert_contains(
        report_for([target_state_mismatch]),
        "aggregate diagnostic gate valid",
        "raw linked-sample coverage: INVALID",
        "target_state disagrees with release episode",
    )

    diagnostic_tamper_paths = (
        (
            "release",
            lambda run: run["pacing"]["target_continuity_episode_samples"][0][
                "release"
            ],
            "distance",
        ),
        (
            "reacquire",
            lambda run: run["pacing"]["target_continuity_episode_samples"][0][
                "reacquire_1s"
            ],
            "spawn_delay_seconds",
        ),
        (
            "exit",
            lambda run: run["pacing"][
                "target_continuity_disengage_exit_samples"
            ][0],
            "nav_target_distance",
        ),
    )
    for label, select_sample, key in diagnostic_tamper_paths:
        negative_fraction = copy.deepcopy(complete_run)
        select_sample(negative_fraction)[key] = -0.5
        assert_contains(
            report_for([negative_fraction]),
            "aggregate diagnostic gate valid",
            "raw linked-sample coverage: INVALID",
            f"{key} must be -1 or finite and nonnegative",
        )

    raw_only = {
        "pacing": {
            "target_continuity_episode_samples": [],
            "target_continuity_episode_sample_metadata": sample_metadata(0, 0, 0),
            "target_continuity_disengage_exit_samples": [],
            "target_continuity_disengage_exit_sample_metadata": sample_metadata(0, 0, 0),
        }
    }
    assert_contains(
        report_for([raw_only]),
        "linked samples are informational without a complete exact aggregate",
        "aggregate diagnostic gate INVALID",
    )

    legacy_summary = complete_zero_summary()
    legacy_summary["schema_version"] = 1
    assert_contains(
        report_for([v2_run(legacy_summary)]),
        "legacy schema v1 informational only",
        "aggregate diagnostic gate INVALID",
    )

    legacy_raw = {
        "pacing": {
            "target_continuity_dropped": 3,
            "target_continuity_events": [
                {
                    "time": 10.0,
                    "event": "release",
                    "reason": "memory_expired",
                    "state": "attack",
                    "target_state": "disengage",
                    "source": "attack",
                    "actor_id": 1,
                    "target_id": 2,
                    "target_state_episode": 7,
                }
            ],
        }
    }
    legacy_raw_report = report_for([legacy_raw])
    assert_contains(
        legacy_raw_report,
        "raw fallback",
        "raw sample truncated (dropped=3)",
        "diagnostic gate INVALID",
    )


def verify_time_axis_and_legacy_identity() -> None:
    if _target_continuity_stable_hash("1|2|7") != 1298719915:
        raise AssertionError("Stable continuity hash known vector changed.")
    # An advertised canonical basis makes the explicit release_time
    # authoritative, even when event.time-delay points somewhere else.
    canonical = {
        "time": 60.0,
        "release_time_basis": "match_elapsed",
        "release_time": 10.0,
        "delay_seconds": 0.5,
    }
    if _continuity_release_time(canonical) != 10.0:
        raise AssertionError("Canonical explicit release_time lost precedence.")
    invalid_canonical = {
        "time": 10.6,
        "release_time_basis": "match_elapsed",
        "release_time": None,
        "delay_seconds": 0.6,
    }
    if _continuity_release_time(invalid_canonical) >= 0.0:
        raise AssertionError("Malformed advertised canonical time used a fallback.")
    legacy = {"time": 60.0, "delay_seconds": 0.5}
    if _continuity_release_time(legacy) != 59.5:
        raise AssertionError("Basis-absent legacy event-time fallback changed.")

    # opening_target_continuity_events must annotate copies, not mutate source
    # rows, so identical per-process IDs remain distinct across runs.
    event = {"time": 10.0, "event": "release"}
    runs = [
        {"pacing": {"target_continuity_events": [copy.deepcopy(event)]}},
        {"pacing": {"target_continuity_events": [copy.deepcopy(event)]}},
    ]
    copied_events = opening_target_continuity_events(runs)
    if [item.get("_continuity_run_ordinal") for item in copied_events] != [0, 1]:
        raise AssertionError("Continuity raw identities lost their run ordinal.")
    if any(
        "_continuity_run_ordinal" in item
        for run in runs
        for item in run["pacing"]["target_continuity_events"]
    ):
        raise AssertionError("Continuity analyzer mutated source telemetry.")

    legacy_pair = [
        {
            "time": 10.0,
            "event": "release",
            "reason": "memory_expired",
            "state": "attack",
            "target_state": "disengage",
            "source": "attack",
            "actor_id": 1,
            "target_id": 2,
            "target_state_episode": 7,
        },
        {
            "time": 10.6,
            "event": "same_target_reacquire",
            "delay_seconds": 0.6,
            "release_reason": "memory_expired",
            "target_state": "disengage",
            "source": "idle_reaction",
            "actor_id": 1,
            "target_id": 2,
            "target_state_episode": 7,
            "displacement": 0.75,
            "stuck_delta": 0,
            "disengage_entry_delta": 0,
        },
    ]
    legacy_runs = [
        {
            "pacing": {
                "target_continuity_dropped": 0,
                "target_continuity_events": copy.deepcopy(legacy_pair),
            }
        },
        {
            "pacing": {
                "target_continuity_dropped": 0,
                "target_continuity_events": copy.deepcopy(legacy_pair),
            }
        },
    ]
    assert_contains(
        report_for(legacy_runs),
        "unique eligible episode releases=2",
        "same-target reacquired<=1s=2/2 (100.0%)",
        "diagnostic gate INVALID",
    )


def verify_opening_survival_exposure_contract() -> None:
    first = exposure_summary()
    second = exposure_summary(
        recover_seconds=20.0,
        disengage_seconds=40.0,
        unknown_seconds=3.0,
        tracked_actors=4,
        acquisition_count=2,
        entry_count=3,
        death_count=1,
    )
    multi_run = exposure_report_for(
        [
            {"pacing": {"opening_survival_exposure_summary": first}},
            {"pacing": {"opening_survival_exposure_summary": second}},
        ]
    )
    assert_contains(
        multi_run,
        "schema v1 exact, bot-only <= 60s",
        "tracked actors=9, actor-seconds=100.0",
        "deaths=3 (3.00/100 state-s)",
        "acquisitions=6",
        "disengage entries=6 (3.60/state-min)",
        "known=95.0s, unknown=5.0s (95.0%)",
        "event location coverage (known/unknown): acquisitions=6/0, entries=6/0, survival deaths=3/0",
        "recover=50.0s/deaths 1 (2.00/100s)",
        "disengage=50.0s/deaths 2 (4.00/100s)",
        "acquisition sources=[idle_reaction=6 (3.60/state-min)]",
        "entry reasons=[survival_break=6 (3.60/state-min)]",
        "death sources=[melee=3 (3.00/100s)]",
        "poi_name location coverage: known=95.0s, unknown=5.0s, overflow=0.0s",
        "survey_camp=95.0s; acq 6 (3.79/min), entry 6 (3.79/min), death 3 (3.16/100s)",
        "release->reacquire location: unavailable",
        "raw bounded samples are not promoted to totals",
    )

    mixed_identity = copy.deepcopy(second)
    mixed_identity["scale_preset"] = "play_07"
    identity_report = exposure_report_for(
        [
            {"pacing": {"opening_survival_exposure_summary": first}},
            {"pacing": {"opening_survival_exposure_summary": mixed_identity}},
        ]
    )
    assert_contains(
        identity_report,
        "survival-state deaths=3 (3.00/100 state-s)",
        "location diagnostic INVALID",
        "identities differ or are unknown; location rates held",
    )

    unknown_identity = exposure_summary()
    unknown_identity["map_spec_path"] = "unknown"
    assert_contains(
        exposure_report_for(
            [{"pacing": {"opening_survival_exposure_summary": unknown_identity}}]
        ),
        "schema v1 exact",
        "location diagnostic INVALID",
        "identities differ or are unknown; location rates held",
    )

    overflowed = exposure_summary()
    overflowed["location_overflowed"] = True
    assert_contains(
        exposure_report_for(
            [{"pacing": {"opening_survival_exposure_summary": overflowed}}]
        ),
        "schema v1 exact",
        "location diagnostic INVALID",
        "collapsed location keys into other; location rates held",
    )

    zero = exposure_summary(
        recover_seconds=0.0,
        disengage_seconds=0.0,
        unknown_seconds=0.0,
        tracked_actors=0,
        acquisition_count=0,
        entry_count=0,
        death_count=0,
    )
    assert_contains(
        exposure_report_for(
            [{"pacing": {"opening_survival_exposure_summary": zero}}]
        ),
        "actor-seconds=0.0",
        "deaths=0 (n/a/100 state-s)",
        "disengage entries=0 (n/a/state-min)",
        "known=0.0s, unknown=0.0s (n/a)",
    )

    low_coverage = exposure_summary(unknown_seconds=10.0)
    assert_contains(
        exposure_report_for(
            [{"pacing": {"opening_survival_exposure_summary": low_coverage}}]
        ),
        "location diagnostic INVALID: known location exposure is 75.0%",
        "known=30.0s, unknown=10.0s",
        "rates held; requires >= 95%",
    )

    low_death_location_coverage = exposure_summary(death_count=4)
    death_event = low_death_location_coverage["survival_deaths"]
    death_event["known_location_count"] = 3
    death_event["unknown_location_count"] = 1
    for axis in EXPOSURE_AXES:
        counter = death_event[f"by_{axis}"]
        known_key = next(iter(counter))
        counter[known_key] = 3
        counter["unknown"] = 1
    assert_contains(
        exposure_report_for(
            [
                {
                    "pacing": {
                        "opening_survival_exposure_summary": (
                            low_death_location_coverage
                        )
                    }
                }
            ]
        ),
        "event location coverage (known/unknown): acquisitions=4/0, entries=3/0, survival deaths=3/1",
        "known event location coverage below 95%",
        "survival deaths=75.0%",
        "rates held",
    )

    malformed_cases: list[tuple[str, dict, str]] = []
    bool_seconds = exposure_summary()
    bool_seconds["actor_seconds_total"] = True
    malformed_cases.append(
        ("boolean actor seconds", bool_seconds, "actor_seconds_total must be finite")
    )
    state_total = exposure_summary()
    state_total["actor_seconds_by_state"]["recover"] = 29.0
    malformed_cases.append(
        ("state total", state_total, "actor_seconds_by_state sums to")
    )
    axis_total = exposure_summary()
    axis_total["actor_seconds_by_state_and_poi_name"]["recover"][
        "survey_camp"
    ] -= 1.0
    malformed_cases.append(
        ("axis total", axis_total, "actor_seconds_by_state_and_poi_name.recover sums")
    )
    marginal_total = exposure_summary()
    marginal_total["target_acquisitions"]["by_source"]["idle_reaction"] = 3
    malformed_cases.append(
        ("event marginal", marginal_total, "target_acquisitions.by_source sums")
    )
    bool_event_count = exposure_summary()
    bool_event_count["disengage_entries"]["count"] = True
    malformed_cases.append(
        (
            "boolean event count",
            bool_event_count,
            "disengage_entries.count must be a nonnegative integer",
        )
    )
    bad_bucket = exposure_summary()
    bad_bucket["target_acquisitions"]["by_distance_bucket"] = {
        "near": bad_bucket["target_acquisitions"]["count"]
    }
    malformed_cases.append(
        (
            "noncanonical bucket",
            bad_bucket,
            "target_acquisitions.by_distance_bucket.near is not an allowed key",
        )
    )
    bad_entry_state = exposure_summary()
    bad_entry_state["disengage_entries"]["by_state"] = {
        "recover": bad_entry_state["disengage_entries"]["count"]
    }
    malformed_cases.append(
        (
            "entry state",
            bad_entry_state,
            "disengage_entries.by_state.recover is not an allowed key",
        )
    )
    location_count = exposure_summary()
    location_count["survival_deaths"]["unknown_location_count"] = 1
    malformed_cases.append(
        (
            "event coverage",
            location_count,
            "known/unknown location counts must sum to count",
        )
    )
    incomplete = exposure_summary()
    incomplete["complete"] = False
    malformed_cases.append(("incomplete", incomplete, "complete must be boolean true"))
    legacy = exposure_summary()
    legacy["schema_version"] = 0
    malformed_cases.append(("legacy", legacy, "schema_version must be integer 1"))
    location_seconds = exposure_summary()
    location_seconds["known_location_actor_seconds"] -= 1.0
    malformed_cases.append(
        (
            "location seconds",
            location_seconds,
            "known/unknown location actor seconds must sum",
        )
    )
    hidden_overflow = exposure_summary()
    hidden_overflow_axis = hidden_overflow[
        "actor_seconds_by_state_and_poi_name"
    ]["recover"]
    hidden_overflow_axis["survey_camp"] -= 1.0
    hidden_overflow_axis["other"] = 1.0
    malformed_cases.append(
        (
            "hidden overflow",
            hidden_overflow,
            "positive location other bucket requires location_overflowed=true",
        )
    )
    initial_counts = exposure_summary(tracked_actors=1)
    initial_counts["initial_survival_state_counts"] = {
        "recover": 1,
        "disengage": 1,
    }
    malformed_cases.append(
        (
            "initial states",
            initial_counts,
            "initial_survival_state_counts exceeds tracked_actors",
        )
    )
    over_window = exposure_summary(
        recover_seconds=40.0,
        disengage_seconds=30.0,
        tracked_actors=1,
        acquisition_count=0,
        entry_count=0,
        death_count=0,
    )
    malformed_cases.append(
        (
            "tracked window",
            over_window,
            "actor_seconds_total exceeds tracked_actors * window_seconds",
        )
    )
    too_many_deaths = exposure_summary(tracked_actors=1, death_count=2)
    malformed_cases.append(
        (
            "deaths exceed tracked",
            too_many_deaths,
            "survival_deaths.count exceeds tracked_actors",
        )
    )
    for label, summary, expected in malformed_cases:
        report = exposure_report_for(
            [{"pacing": {"opening_survival_exposure_summary": summary}}]
        )
        try:
            assert_contains(report, "exact aggregate INVALID", expected)
        except AssertionError as error:
            raise AssertionError(f"Exposure malformed case failed: {label}\n{error}")

    raw_only = {
        "pacing": {
            "kill_context_events": [
                {"time": 10.0, "victim": {"state": "recover"}}
            ],
            "target_continuity_events": [
                {"time": 10.0, "event": "release"}
            ],
        }
    }
    assert_contains(
        exposure_report_for([raw_only]),
        "unavailable (schema v1 exact summary missing",
        "raw kill/continuity samples are not used as a denominator",
    )

    mixed = [
        {"pacing": {"opening_survival_exposure_summary": exposure_summary()}},
        {"pacing": {}},
    ]
    assert_contains(
        exposure_report_for(mixed),
        "exact aggregate INVALID",
        "exact exposure summary missing",
    )


def verify_survival_break_episode_contract() -> None:
    summary = survival_break_summary()
    report = survival_break_report_for(
        [{"pacing": {"survival_break_episode_summary": summary}}]
    )
    assert_contains(
        report,
        "schema v2 exact, entry<=59s; episodes=2, completed=2, censored=0, deaths=1",
        "damaged=1/2, cover selected/reached=1/1",
        "nearest-target-missing=1, counteraction=1",
        "release/fast same-target reacquire<=1s=1/1",
        "cover=[reached=1]",
        "killer relation=[entry_target=1]",
        "fast reacquire sources=[retreat_counteraction=1]",
        "cover progression: observed episodes=1/2, perception lost=1, "
        "damage after selection=1; minimum distance avg=1.00m",
        "death progression: cover=[reached=1]",
    )

    legacy = copy.deepcopy(summary)
    legacy["schema_version"] = 1
    for key in (
        "perception_lost_episodes",
        "damage_after_cover_selected_episodes",
        "cover_progress_observed_episodes",
        "cover_min_distance",
        "cover_progress_ratio",
        "first_damage_after_cover_delay",
        "death_after_cover_selection_delay",
        "first_perception_loss_delay",
        "death_by_cover_progress",
        "death_by_first_damage_after_cover",
        "death_by_perception_loss",
    ):
        legacy.pop(key)
    assert_contains(
        survival_break_report_for(
            [{"pacing": {"survival_break_episode_summary": legacy}}]
        ),
        "schema v1 exact, entry<=59s",
    )

    malformed_cases: list[tuple[str, dict, str]] = []
    partial = copy.deepcopy(summary)
    partial.pop("death_by_killer_relation")
    malformed_cases.append(("partial", partial, "missing death_by_killer_relation"))
    impossible_total = copy.deepcopy(summary)
    impossible_total["censored"] = 1
    malformed_cases.append(
        ("episode total", impossible_total, "completed + censored must equal episodes")
    )
    impossible_cover = copy.deepcopy(summary)
    impossible_cover["cover_reached_episodes"] = 2
    malformed_cases.append(
        (
            "cover linkage",
            impossible_cover,
            "cover_reached_episodes exceeds cover_selected_episodes",
        )
    )
    bad_counter = copy.deepcopy(summary)
    bad_counter["death_by_fast_reacquired"] = {"yes": True}
    malformed_cases.append(
        (
            "boolean counter",
            bad_counter,
            "death_by_fast_reacquired.yes must be a nonnegative integer",
        )
    )
    bad_measure = copy.deepcopy(summary)
    bad_measure["incoming_raw_damage"]["count"] = 2
    malformed_cases.append(
        ("measure count", bad_measure, "incoming_raw_damage.count must equal 1")
    )
    bad_progress = copy.deepcopy(summary)
    bad_progress["cover_progress_ratio"] = {"count": 1, "sum": 1.1, "max": 1.1}
    malformed_cases.append(
        ("progress ratio", bad_progress, "cover_progress_ratio.max exceeds 1.0")
    )
    censored_progress = copy.deepcopy(summary)
    censored_progress["completed"] = 0
    censored_progress["censored"] = 2
    censored_progress["deaths"] = 0
    malformed_cases.append(
        (
            "censored progress",
            censored_progress,
            "cover_progress_observed_episodes exceeds completed episodes",
        )
    )
    for label, malformed, expected in malformed_cases:
        malformed_report = survival_break_report_for(
            [{"pacing": {"survival_break_episode_summary": malformed}}]
        )
        try:
            assert_contains(malformed_report, "exact aggregate INVALID", expected)
        except AssertionError as error:
            raise AssertionError(
                f"survival_break malformed case failed: {label}\n{error}"
            )

    assert_contains(
        survival_break_report_for([{"pacing": {}}]),
        "unavailable (schema v1/v2 exact summary missing)",
    )
    mixed = [
        {"pacing": {"survival_break_episode_summary": survival_break_summary()}},
        {"pacing": {}},
    ]
    assert_contains(
        survival_break_report_for(mixed),
        "exact aggregate INVALID",
        "exact survival_break summary missing",
    )


def main() -> int:
    verify_kill_context_and_age_bands()
    verify_schema_v2_contract()
    verify_invalid_contracts()
    verify_time_axis_and_legacy_identity()
    verify_opening_survival_exposure_contract()
    verify_survival_break_episode_contract()

    legacy_output = io.StringIO()
    with contextlib.redirect_stdout(legacy_output):
        print_opening_target_continuity([{"pacing": {}}])
        print_survival_victim_continuity([{"pacing": {}}])
    assert_contains(
        legacy_output.getvalue(),
        "Opening survival-target continuity: unavailable",
        "Opening survival-victim continuity: unavailable",
        "legacy run schema accepted",
    )
    print("Pacing analysis smoke passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
