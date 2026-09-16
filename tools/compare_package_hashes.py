"""Compare clean package bytes and verified internal entries; never rebuild or overwrite."""
import argparse
import json
from pathlib import Path
import re

from run_release_flow import digest, load_package, save


def read_inventory(text, expected_digest):
    if re.search(r"(?m)^(?:SCRIPT ERROR|ERROR|WARNING):", text):
        raise ValueError("Package verifier log contains errors/warnings")
    if not re.search(r"(?m)^Release package smoke passed:", text):
        raise ValueError("Missing exact package contract PASS")
    if re.findall(r"(?m)^PACKAGE_DIGEST ([0-9a-f]{64})$", text) != [expected_digest]:
        raise ValueError("Inventory log does not identify this PCK")
    entries = {}
    for line in text.splitlines():
        if not line.startswith("PACKAGE_HASH "):
            continue
        entry = json.loads(line.removeprefix("PACKAGE_HASH "))
        path = entry["path"]
        if (not path.startswith("res://") or path in entries or type(entry["size"]) is not int
                or entry["size"] < 0 or not re.fullmatch(r"[0-9a-f]{64}", entry["sha256"])):
            raise ValueError("Invalid/duplicate package entry")
        entries[path] = {"size": entry["size"], "sha256": entry["sha256"]}
    if not entries:
        raise ValueError("No package entry evidence")
    return entries


def compare_entries(left, right):
    common = left.keys() & right.keys()
    return {
        "only_left": sorted(left.keys() - right.keys()),
        "only_right": sorted(right.keys() - left.keys()),
        "changed": [{"path": path, "left": left[path], "right": right[path]}
                    for path in sorted(common) if left[path] != right[path]],
        "unchanged_count": sum(left[path] == right[path] for path in common),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("left_dir", "right_dir", "left_log", "right_log", "output"):
        parser.add_argument("--" + key.replace("_", "-"), type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("Refusing to overwrite comparison evidence")
    left_hashes, left_source, left_menu = load_package(args.left_dir)
    right_hashes, right_source, right_menu = load_package(args.right_dir)
    if left_source != right_source or left_menu != right_menu or left_hashes.keys() != right_hashes.keys():
        parser.error("Packages do not share source/build/artifact identity")
    artifacts = {name: {"left_sha256": left_hashes[name], "right_sha256": right_hashes[name],
                        "left_bytes": (args.left_dir / name).stat().st_size,
                        "right_bytes": (args.right_dir / name).stat().st_size}
                 for name in left_hashes}
    pck_name = next(name for name in left_hashes if name.endswith(".pck"))
    left = read_inventory(args.left_log.read_text(encoding="utf-8-sig"), left_hashes[pck_name])
    right = read_inventory(args.right_log.read_text(encoding="utf-8-sig"), right_hashes[pck_name])
    differences = compare_entries(left, right)
    result = {
        "byte_identical": left_hashes == right_hashes,
        "source_commit": left_source, "menu": left_menu,
        "left_dir": str(args.left_dir.resolve()), "right_dir": str(args.right_dir.resolve()),
        "artifacts": artifacts, "left_entry_count": len(left), "right_entry_count": len(right),
        "log_sha256": {"left": digest(args.left_log), "right": digest(args.right_log)},
        **differences,
    }
    save(args.output, result)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["byte_identical"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
