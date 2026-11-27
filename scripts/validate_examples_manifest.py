#!/usr/bin/env python3
"""Validate docs/examples/manifest.json against the examples on disk.

Checks:
  - every example's `path` exists under docs/examples/
  - every example has a non-empty id, category and description
  - ids are unique
  - every .dryad file under docs/examples/ is referenced by the manifest
    (catches orphaned or forgotten examples)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXAMPLES_DIR = ROOT / "examples"
MANIFEST = EXAMPLES_DIR / "manifest.json"


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)


def main() -> int:
    errors = 0

    if not MANIFEST.exists():
        fail(f"manifest not found at {MANIFEST}")
        return 1

    data = json.loads(MANIFEST.read_text())
    examples = data.get("examples", [])
    if not examples:
        fail("manifest has no examples")
        return 1

    seen_ids: set[str] = set()
    referenced_paths: set[Path] = set()

    for entry in examples:
        entry_id = entry.get("id", "")
        rel_path = entry.get("path", "")
        category = entry.get("category", "")
        description = entry.get("description", "")

        if not entry_id:
            fail(f"entry missing id: {entry}")
            errors += 1
        elif entry_id in seen_ids:
            fail(f"duplicate id: {entry_id}")
            errors += 1
        else:
            seen_ids.add(entry_id)

        if not category:
            fail(f"{entry_id}: missing category")
            errors += 1

        if not description:
            fail(f"{entry_id}: missing description")
            errors += 1

        if not rel_path:
            fail(f"{entry_id}: missing path")
            errors += 1
            continue

        full_path = EXAMPLES_DIR / rel_path
        referenced_paths.add(full_path.resolve())
        if not full_path.exists():
            fail(f"{entry_id}: path does not exist: {rel_path}")
            errors += 1

    # dryadsquare/ is a self-contained mini-compiler sample driven by its own
    # README/benchmark script, not the manifest-driven playground catalog;
    # 07-tooling/ is documented as CLI commands, not individually-run files
    # (see examples/README.md). Both are intentionally excluded here.
    excluded_dirs = {
        (EXAMPLES_DIR / "dryadsquare").resolve(),
        (EXAMPLES_DIR / "07-tooling").resolve(),
    }

    def is_excluded(path: Path) -> bool:
        return any(excluded in path.parents for excluded in excluded_dirs)

    on_disk = {
        p.resolve() for p in EXAMPLES_DIR.rglob("*.dryad") if not is_excluded(p)
    }
    orphaned = on_disk - referenced_paths
    for path in sorted(orphaned):
        fail(f"orphaned example not listed in manifest.json: {path.relative_to(ROOT)}")
        errors += 1

    if errors:
        print(f"\n{errors} problem(s) found.", file=sys.stderr)
        return 1

    print(f"OK: {len(examples)} examples validated, {len(on_disk)} .dryad files accounted for.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
