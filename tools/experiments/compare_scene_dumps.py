"""Diagnostic text comparison only; never changes the package byte gate."""
import argparse
import json
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from run_release_flow import digest, save


def diagnostic_text(text):
    # ResourceSaver invents external reference aliases while exporting text.
    # Keep declaration order/type/path and remap only those aliases/references.
    aliases = re.findall(r'^\[ext_resource .* id="([^"\n]+)"\]$', text, re.MULTILINE)
    if len(aliases) != len(set(aliases)):
        raise ValueError("Duplicate external resource aliases")
    mapping = {alias: f"external_{index}" for index, alias in enumerate(aliases)}
    text = re.sub(r'^(\[ext_resource .* id=")([^"\n]+)("\])$',
                  lambda m: m[1] + mapping[m[2]] + m[3], text, flags=re.MULTILINE)
    # Replace references once so a source alias cannot collide with a new alias.
    text = re.sub(r'ExtResource\("([^"\n]+)"\)',
                  lambda m: f'ExtResource("{mapping[m[1]]}")' if m[1] in mapping else m[0], text)
    return re.sub(r'^(\[node [^\n]*)$',
                  lambda m: re.sub(r" unique_id=\d+(?= |\])", "", m[0]), text, flags=re.MULTILINE)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--comparison", required=True, type=Path)
    parser.add_argument("--left", required=True, type=Path)
    parser.add_argument("--right", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("Refusing to overwrite evidence")
    comparison = json.loads(args.comparison.read_text(encoding="utf-8"))
    left = json.loads((args.left / "scenes.json").read_text(encoding="utf-8"))
    right = json.loads((args.right / "scenes.json").read_text(encoding="utf-8"))
    changed = {row["path"]: row for row in comparison["changed"]}
    if len(left) != len(changed) or len(right) != len(changed):
        raise ValueError("Incomplete scene dump coverage")
    right_map = {row["path"]: row for row in right}
    if {row["path"] for row in left} != changed.keys() or right_map.keys() != changed.keys():
        raise ValueError("Wrong/duplicate scene dump paths")
    rows = []
    for a in left:
        path = a["path"]
        b = right_map[path]
        if a["packed_sha256"] != changed[path]["left"]["sha256"] or b["packed_sha256"] != changed[path]["right"]["sha256"]:
            raise ValueError("Scene dump not bound to compared package bytes")
        for directory, row in [(args.left, a), (args.right, b)]:
            if Path(row["dump"]).name != row["dump"] or digest(directory / row["dump"]) != row["dump_sha256"]:
                raise ValueError("Dump path/hash mismatch")
        equal = diagnostic_text((args.left / a["dump"]).read_text(encoding="utf-8")) == diagnostic_text((args.right / b["dump"]).read_text(encoding="utf-8"))
        rows.append({"path": path, "node_count_left": a["node_count"], "node_count_right": b["node_count"],
                     "node_ids_equal": a["node_ids"] == b["node_ids"], "text_equal_without_ids_and_aliases": equal})
    result = {"scope": "Diagnostic text only; no byte gate override or full semantic equivalence claim",
              "comparison_sha256": digest(args.comparison), "scenes": rows}
    save(args.output, result)
    print(f"{sum(row['text_equal_without_ids_and_aliases'] for row in rows)}/{len(rows)} scene dumps match except node IDs/text aliases; original byte gate unchanged")


if __name__ == "__main__":
    main()
