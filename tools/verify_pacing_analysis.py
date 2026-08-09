import contextlib
import io

from summarize_pacing_baseline import (
    kill_ammo_status,
    opening_kill_context_events,
    print_opening_kill_context,
)


def main() -> int:
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
                ]
            }
        },
        {"pacing": {}},
    ]
    events = opening_kill_context_events(runs)
    if len(events) != 2:
        raise AssertionError(f"Expected two inclusive <=60s events, got {len(events)}")
    if kill_ammo_status({"mag": 0, "reserve": 0}) != "dry":
        raise AssertionError("Dry attacker classification changed.")
    if kill_ammo_status({"mag": 0, "reserve": 4}) != "reload_available":
        raise AssertionError("Reload-available attacker classification changed.")
    if kill_ammo_status({"mag": 1, "reserve": 0}) != "rounds_available":
        raise AssertionError("Armed attacker classification changed.")
    if kill_ammo_status({"mag": -1, "reserve": -1}) != "unknown":
        raise AssertionError("Unknown attacker ammo classification changed.")

    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        print_opening_kill_context(runs)
    report = output.getvalue()
    required = [
        "Opening kill context (<= 60s): 2 events, dropped=2",
        "gun=1",
        "melee=1",
        "neutral_initiation=1",
        "recent_retaliation=1",
        "objective_interrupt=1",
        "recover_melee=1",
        "victim states=[recover=1, disengage=1]",
        "inside=1",
        "near_4_8m=1",
    ]
    for expected in required:
        if expected not in report:
            raise AssertionError(f"Missing pacing analysis contract: {expected}\n{report}")
    print("Pacing analysis smoke passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
