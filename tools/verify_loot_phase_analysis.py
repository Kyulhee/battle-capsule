"""Matched-phase stock comparison contract and mutation rejection fixtures."""
import copy
import unittest
from analyze_loot_phase import MAP, compare


def fixture(candidate=False):
    snapshot = dict(requested_time=0, observed_time=0, alive=60, zone_stage=1, zone_shrinking=False,
        actors=[dict(id=i+1, loaded=0, reserve=0, state_name="RECOVER", recovery_substate="patrol") for i in range(60)],
        needs=dict(no_ammo=60), records=[dict(kind="ammo", source="stage_wave")],
        totals=dict(items=1, ammo_packs=1, weapons=0))
    snapshots = []
    for t in (0, 120, 260):
        s = copy.deepcopy(snapshot)
        s.update(requested_time=t, observed_time=t)
        snapshots.append(s)
    phase = copy.deepcopy(snapshot)
    phase.update(requested_time=261.05, observed_time=261.06, zone_stage=2, phase_key="stage2_post_wave_1s",
                 phase_anchor_time=260.05, phase_offset_seconds=1.0)
    return dict(schema_version=3, complete=True, initial_only=False, loot_phase_enabled=True,
        map=MAP, preset="night_br_m1_60", time_scale=1, checkpoints_not_reached=[], snapshots=snapshots,
        phase_snapshots=[phase], phase_stage_times={"2":260.05}, end_time=261.06, seed=41000,
        phase_window_only=True, loot_progress_candidate=candidate)


class PhaseTests(unittest.TestCase):
    def test_matching_phase_and_immutability(self):
        left, right = fixture(), fixture(True)
        before = copy.deepcopy((left, right))
        result = compare(left, right)
        self.assertEqual((left, right), before)
        self.assertEqual(result["candidate"]["empty_recovery_substates"], {"patrol": 60})
        self.assertEqual(result["control"]["stage_wave_items"], 1)

    def test_different_absolute_transition_times_are_valid(self):
        left, right = fixture(), fixture(True)
        phase = right["phase_snapshots"][0]
        phase.update(phase_anchor_time=260.15, requested_time=261.15, observed_time=261.16)
        right.update(phase_stage_times={"2":260.15}, end_time=261.16)
        self.assertEqual(compare(left, right)["integrity"], "PASS")

    def test_invalid_reports(self):
        mutations = {
            "incomplete": lambda r: r.update(complete=False),
            "disabled": lambda r: r.update(loot_phase_enabled=False),
            "missing": lambda r: r.update(phase_snapshots=[]),
            "duplicate": lambda r: r["phase_snapshots"].append(copy.deepcopy(r["phase_snapshots"][0])),
            "legacy_only": lambda r: r.update(phase_snapshots=[r["snapshots"][-1]]),
            "wrong_stage": lambda r: r["phase_snapshots"][0].update(zone_stage=1),
            "shrinking": lambda r: r["phase_snapshots"][0].update(zone_shrinking=True),
            "early": lambda r: r["phase_snapshots"][0].update(observed_time=261),
            "late": lambda r: r["phase_snapshots"][0].update(observed_time=261.5),
            "nan": lambda r: r["phase_snapshots"][0].update(observed_time=float("nan")),
            "anchor": lambda r: r.update(phase_stage_times={"2":260.0}),
            "offset": lambda r: r["phase_snapshots"][0].update(phase_offset_seconds=2),
            "actor_ids": lambda r: r["snapshots"][0]["actors"][0].update(id=999),
            "duplicate_actor": lambda r: r["phase_snapshots"][0]["actors"][0].update(id=2),
            "stock": lambda r: r["phase_snapshots"][0]["totals"].update(items=3),
            "empty": lambda r: r["phase_snapshots"][0]["needs"].update(no_ammo=0),
            "seed": lambda r: r.update(seed=41001),
            "mixed": lambda r: r.update(candidate=True),
            "instrumented": lambda r: r.update(ai_phase_audit_loaded=True),
            "window": lambda r: r.update(phase_window_only=False),
            "accelerated_window": lambda r: r.update(time_scale=5),
        }
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                right = fixture(True)
                mutate(right)
                with self.assertRaises((ValueError, KeyError)):
                    compare(fixture(), right)


if __name__ == "__main__":
    unittest.main()
