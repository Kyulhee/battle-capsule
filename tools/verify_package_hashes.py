"""Fixtures for package comparison identity, incomplete logs and exact byte differences."""
import json
import unittest

from compare_package_hashes import compare_entries, read_inventory
from experiments.compare_scene_dumps import diagnostic_text


class PackageHashTests(unittest.TestCase):
    def setUp(self):
        self.entry = {"path": "res://src/Main.gdc", "sha256": "b" * 64, "size": 100}
        self.log = ("PACKAGE_DIGEST " + "a" * 64 + "\nPACKAGE_HASH " + json.dumps(self.entry)
                    + "\nRelease package smoke passed: contract\n")

    def test_valid_inventory(self):
        self.assertEqual(read_inventory(self.log, "a" * 64)[self.entry["path"]]["size"], 100)

    def test_missing_wrong_or_duplicate_digest_rejected(self):
        for text in [self.log.replace("PACKAGE_DIGEST", "OTHER"), self.log.replace("a" * 64, "c" * 64),
                     self.log + "PACKAGE_DIGEST " + "a" * 64 + "\n"]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                read_inventory(text, "a" * 64)

    def test_failed_incomplete_or_duplicate_entries_rejected(self):
        for text in [self.log + "ERROR: mismatch\n", self.log + "WARNING: incomplete\n",
                     self.log.replace("Release package smoke passed:", "FAILED:"),
                     self.log + "PACKAGE_HASH " + json.dumps(self.entry),
                     "PACKAGE_DIGEST " + "a" * 64 + "\nRelease package smoke passed:\n"]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                read_inventory(text, "a" * 64)

    def test_hash_and_size_differences_are_not_normalized_away(self):
        left = {"same": {"size": 1, "sha256": "a"}, "hash": {"size": 1, "sha256": "b"},
                "size": {"size": 1, "sha256": "c"}, "removed": {}}
        right = {"same": left["same"], "hash": {"size": 1, "sha256": "z"},
                 "size": {"size": 2, "sha256": "c"}, "added": {}}
        result = compare_entries(left, right)
        self.assertEqual(result["unchanged_count"], 1)
        self.assertEqual(result["only_left"], ["removed"])
        self.assertEqual(result["only_right"], ["added"])
        self.assertEqual([item["path"] for item in result["changed"]], ["hash", "size"])

    def test_scene_diagnostic_only_removes_ids_and_reference_aliases(self):
        left = '[ext_resource type="Script" path="res://a.gd" id="a"]\n[node name="A" unique_id=42]\nscript = ExtResource("a")\nhealth = 100\n'
        right = left.replace('id="a"', 'id="b"').replace('ExtResource("a")', 'ExtResource("b")').replace('unique_id=42', 'unique_id=99')
        self.assertEqual(diagnostic_text(left), diagnostic_text(right))
        for text in [right.replace('health = 100', 'health = 1'), right.replace('res://a.gd', 'res://b.gd'),
                     right.replace('name="A"', 'name="B"')]:
            self.assertNotEqual(diagnostic_text(left), diagnostic_text(text))

    def test_scene_alias_remapping_does_not_collapse_references(self):
        declarations = ('[ext_resource type="Script" path="res://a.gd" id="a"]\n'
                        '[ext_resource type="Script" path="res://b.gd" id="external_0"]\n')
        left = declarations + 'script = ExtResource("a")\n'
        right = declarations + 'script = ExtResource("external_0")\n'
        self.assertNotEqual(diagnostic_text(left), diagnostic_text(right))


if __name__ == "__main__":
    unittest.main()
