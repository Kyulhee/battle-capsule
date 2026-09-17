"""Unit guards for the synthetic scene-ID experiment; no Godot or user-data writes."""
import copy
import unittest
from unittest.mock import patch

from experiments.run_scene_id_contract import fixtures, stable_id, validate_result


def evidence(mode="assigned"):
    checks = {f"{kind}/{action}": True for kind in ("base", "derived", "container") for action in ("pack", "save")}
    for phase in ("source", "binary"):
        for kind, names in [("base", ("position", "signal")),
                            ("derived", ("position", "signal", "inherited_parent_id_path")),
                            ("container", ("instances_distinct", "override", "second_default", "nested_parent_id_path", "base_signal", "cross_instance_signal"))]:
            checks.update({f"{kind}/{phase}/{name}": True for name in names})
    if mode in ("rename_preserved", "rename_rehashed"):
        for phase in ("source", "binary"):
            checks[f"derived/{phase}/inherited_parent_id_path"] = False
            if mode == "rename_rehashed":
                checks[f"derived/{phase}/position"] = False
                for name in ("override", "nested_parent_id_path", "cross_instance_signal"):
                    checks[f"container/{phase}/{name}"] = False
    return {"exit_code": 0, "messages": [], "report": {
        "mode": mode, "isolation": True, "checks": checks,
        "scenes": [{"scene": name, "has_base_scene": name == "derived"} for name in ("base", "derived", "container")]}}


class SceneIdContractTests(unittest.TestCase):
    def test_initial_ids_are_stable_positive_and_collision_is_rejected(self):
        self.assertEqual(stable_id("base/Target"), 1290028182)
        self.assertGreater(stable_id(""), 0)
        self.assertEqual(fixtures("assigned"), fixtures("assigned"))
        with patch("experiments.run_scene_id_contract.stable_id", return_value=1), self.assertRaises(ValueError):
            fixtures("assigned")

    def test_rename_preserves_id_but_reconciles_dependent_paths(self):
        stale, reconciled = fixtures("rename_preserved"), fixtures("rename_reconciled")
        self.assertEqual(stale["base.tscn"], reconciled["base.tscn"])
        self.assertIn('parent="Target"', stale["derived.tscn"])
        self.assertIn('parent="RenamedTarget"', reconciled["derived.tscn"])
        self.assertIn('to="Second/RenamedTarget"', reconciled["container.tscn"])
        self.assertNotEqual(stale["base.tscn"], fixtures("rename_rehashed")["base.tscn"])

    def test_positive_and_negative_contracts_are_distinct(self):
        for mode in ("assigned", "unassigned", "rename_reconciled"):
            self.assertTrue(validate_result(mode, evidence(mode)))
        for mode in ("rename_preserved", "rename_rehashed"):
            self.assertFalse(validate_result(mode, evidence(mode)))

    def test_missing_checks_or_extra_failure_is_rejected(self):
        original = evidence()
        for change in ("missing", "non_boolean", "extra_failure", "rename"):
            value = copy.deepcopy(original)
            checks = value["report"]["checks"]
            if change == "missing":
                del checks["base/pack"]
            elif change == "non_boolean":
                checks["base/pack"] = 1
            elif change == "rename":
                checks["wrong"] = checks.pop("base/pack")
            else:
                checks["base/pack"] = False
            with self.subTest(change=change), self.assertRaises(ValueError):
                validate_result("assigned", value)

    def test_negative_case_cannot_hide_unrelated_errors(self):
        for mode in ("assigned", "rename_preserved", "rename_rehashed"):
            for message in ("ERROR: unrelated", "SCRIPT ERROR: parse", "WARNING: leaked resources"):
                value = evidence(mode)
                value["messages"] = [message]
                with self.subTest(mode=mode, message=message), self.assertRaises(ValueError):
                    validate_result(mode, value)

    def test_bad_identity_exit_or_flattened_inheritance_is_rejected(self):
        for change in ("mode", "exit", "isolation", "flattened", "missing_scene"):
            value = evidence()
            if change == "mode":
                value["report"]["mode"] = "unassigned"
            elif change == "exit":
                value["exit_code"] = 1
            elif change == "isolation":
                value["report"]["isolation"] = False
            elif change == "flattened":
                value["report"]["scenes"][1]["has_base_scene"] = False
            else:
                value["report"]["scenes"].pop()
            with self.subTest(change=change), self.assertRaises(ValueError):
                validate_result("assigned", value)


if __name__ == "__main__":
    unittest.main()
