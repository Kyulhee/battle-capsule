"""Search capture integrity: exact aggregates, bounded examples and invalid-input rejection."""
import copy
import unittest
from analyze_loot_search import FILTERS, SENSING, MAP, analyze


def fixture(sensing=False):
    counts = dict.fromkeys(FILTERS, 0)
    counts.update(out_of_radius=3, not_sensed=2)
    event = dict(actor_id=1, state="RECOVER", recovery_substate="patrol", position=[0, 0], radius=20,
        prefer_immediate=True, loaded=0, reserve=0, search_timer=-0.1, counts={"pool": 5, **counts},
        mode="scan", selected_id=None, selected_kind="none", match_time=10, scope="RECOVER/patrol", outcome="not_sensed")
    scope = dict(calls=3, outcomes={"not_sensed":3}, filters={k:v*3 for k,v in counts.items()}, pool_candidates=15)
    events = [copy.deepcopy(event), copy.deepcopy(event)]
    events[1]["match_time"] = 11
    flow = dict(schema_version=3, complete=True, initial_only=False, loot_search_enabled=True,
        search_audit_created=True, search_audit_loaded=True, search_until=260, map=MAP, preset="night_br_m1_60",
        seed=41000, time_scale=1, search_window_only=True, loot_progress_candidate=False, checkpoints_not_reached=[],
        end_time=260.01, snapshots=[dict(requested_time=t, observed_time=t, alive=60,
            actors=[dict(id=i+1) for i in range(60)]) for t in (0,120,260)],
        loot_search=dict(schema_version=1, valid=True, calls=3, scans=3, pool_candidates=15, outcomes={"not_sensed":3},
            filters=copy.deepcopy(scope["filters"]), by_scope={"RECOVER/patrol":scope}, events=events, omitted=1, capacity=64, per_bucket=2))
    if sensing:
        audit = flow["loot_search"]
        audit.update(schema_version=2, sensing={**dict.fromkeys(SENSING, 0), "far_range":3, "fov":3})
        scope["sensing"] = copy.deepcopy(audit["sensing"])
        for event in events:
            event["sensing"] = {**dict.fromkeys(SENSING, 0), "far_range":1, "fov":1}
    return flow


class SearchAnalysisTests(unittest.TestCase):
    def test_sensing_exact_and_immutable(self):
        flow = fixture(sensing=True)
        before = copy.deepcopy(flow)
        result = analyze(flow)
        self.assertEqual(flow, before)
        self.assertEqual(result["sensing_candidate_visits"]["fov"], 3)
        self.assertIsNone(analyze(fixture())["sensing_candidate_visits"])

    def test_sensing_rejects_mutations(self):
        mutations = {
            "missing": lambda a: a.pop("sensing"),
            "unknown": lambda a: a["sensing"].update(unknown=0),
            "negative": lambda a: a["sensing"].update(los=-1),
            "fraction": lambda a: a["sensing"].update(los=0.0),
            "attempts": lambda a: a["sensing"].update(los=1),
            "rejections": lambda a: a["sensing"].update(fov=2, passed=1),
            "scope": lambda a: a["by_scope"]["RECOVER/patrol"]["sensing"].update(fov=2, los=1),
            "event_missing": lambda a: a["events"][0]["sensing"].pop("los"),
            "event_sum": lambda a: a["events"][0]["sensing"].update(los=1),
            "event_population": lambda a: a["events"][0]["sensing"].update(fov=0, los=1),
        }
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                flow = fixture(sensing=True)
                mutate(flow["loot_search"])
                with self.assertRaises((ValueError, KeyError)):
                    analyze(flow)

    def test_sensing_quiet_and_cached(self):
        flow = fixture(sensing=True)
        a = flow["loot_search"]
        a.update(scans=0, pool_candidates=0, outcomes={"cached_none":3}, filters={}, sensing={})
        a["by_scope"]["RECOVER/patrol"].update(pool_candidates=0, outcomes={"cached_none":3}, filters={}, sensing={})
        for event in a["events"]:
            event.update(mode="cached_none", outcome="cached_none", counts=dict.fromkeys(("pool", *FILTERS),0),
                         sensing=dict.fromkeys(SENSING,0))
        self.assertEqual(analyze(flow)["fresh_scans"], 0)
        a.update(calls=0, scans=0, pool_candidates=0, outcomes={}, filters={}, sensing={}, by_scope={}, events=[], omitted=0)
        self.assertEqual(analyze(flow)["calls"], 0)

    def test_exact_and_immutable(self):
        flow = fixture()
        before = copy.deepcopy(flow)
        result = analyze(flow)
        self.assertEqual(flow, before)
        self.assertEqual((result["calls"], result["fresh_scans"], result["stored_examples"]), (3,3,2))

    def test_quiet_capture(self):
        flow = fixture()
        flow["loot_search"].update(calls=0, scans=0, pool_candidates=0, outcomes={}, filters={}, by_scope={}, events=[], omitted=0)
        self.assertEqual(analyze(flow)["calls"], 0)

    def test_cached_none_has_no_scan_population(self):
        flow = fixture()
        a = flow["loot_search"]
        a.update(scans=0, pool_candidates=0, outcomes={"cached_none":3}, filters={})
        a["by_scope"]["RECOVER/patrol"].update(pool_candidates=0, outcomes={"cached_none":3}, filters={})
        for event in a["events"]:
            event.update(mode="cached_none", outcome="cached_none", counts=dict.fromkeys(("pool", *FILTERS),0))
        self.assertEqual(analyze(flow)["fresh_scans"], 0)

    def test_rejects_mutations(self):
        mutations = {
            "incomplete": lambda f: f.update(complete=False),
            "mixed": lambda f: f.update(ai_phase_trace_enabled=True),
            "unloaded": lambda f: f.update(search_audit_loaded=False),
            "scale": lambda f: f.update(time_scale=5),
            "missing_checkpoint": lambda f: f.update(checkpoints_not_reached=[260]),
            "late_checkpoint": lambda f: f["snapshots"][-1].update(observed_time=261),
            "capture_invalid": lambda f: f["loot_search"].update(valid=False),
            "calls": lambda f: f["loot_search"].update(calls=4),
            "scans": lambda f: f["loot_search"].update(scans=2),
            "scope": lambda f: f["loot_search"]["by_scope"]["RECOVER/patrol"].update(calls=4),
            "pool": lambda f: f["loot_search"].update(pool_candidates=99),
            "fraction": lambda f: f["loot_search"].update(calls=3.0),
            "omitted": lambda f: f["loot_search"].update(omitted=0),
            "retention": lambda f: f["loot_search"].update(per_bucket=3),
            "missing_example": lambda f: f["loot_search"]["events"].pop(),
            "nan": lambda f: f["loot_search"]["events"][0].update(match_time=float("nan")),
            "event_time": lambda f: f["loot_search"]["events"][0].update(match_time=270),
            "armed": lambda f: f["loot_search"]["events"][0].update(loaded=1),
            "state": lambda f: f["loot_search"]["events"][0].update(state="ATTACK"),
            "classification": lambda f: f["loot_search"]["events"][0].update(outcome="out_of_radius"),
            "event_sum": lambda f: f["loot_search"]["events"][0]["counts"].update(pool=6),
            "selection": lambda f: f["loot_search"]["events"][0].update(selected_id=7),
            "scope_label": lambda f: f["loot_search"]["events"][0].update(scope="IDLE"),
            "cache_scan": lambda f: f["loot_search"]["events"][0].update(mode="cached_none"),
        }
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                flow = fixture()
                mutate(flow)
                with self.assertRaises(ValueError):
                    analyze(flow)


if __name__ == "__main__":
    unittest.main()
