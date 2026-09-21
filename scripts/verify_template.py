"""Verify the portable E_term template files without FABulous dependencies."""

from __future__ import annotations

import csv
import sys
from pathlib import Path


def main() -> None:
    """Validate the template registration and the termination mappings."""
    repo = Path(sys.argv[1] if len(sys.argv) > 1 else "FABulous_E_term").resolve()
    common = repo / "fabulous/fabric_files/FABulous_project_template_common"
    tile_dir = common / "Tile/E_term"

    required = [
        tile_dir / "E_term.csv",
        tile_dir / "E_term_switch_matrix.list",
        tile_dir / "gds_config.yaml",
    ]
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise SystemExit(f"missing template files: {missing}")

    fabric_lines = (common / "fabric.csv").read_text(encoding="utf-8").splitlines()
    registration = "Tile,./Tile/E_term/E_term.csv"
    if sum(line.startswith(registration) for line in fabric_lines) != 1:
        raise SystemExit("fabric.csv must register E_term exactly once")

    with (tile_dir / "E_term.csv").open(newline="", encoding="utf-8") as handle:
        rows = list(csv.reader(handle))
    if rows[0][:2] != ["TILE", "E_term"]:
        raise SystemExit("invalid E_term tile declaration")
    if not any(row[:2] == ["MATRIX", "./E_term_switch_matrix.list"] for row in rows):
        raise SystemExit("E_term does not reference its switch matrix")

    mappings = {
        line.strip()
        for line in (tile_dir / "E_term_switch_matrix.list")
        .read_text(encoding="utf-8")
        .splitlines()
        if line.strip() and not line.startswith("#")
    }
    expected_prefixes = {"W1BEG[", "W2BEG[", "W2BEGb[", "WW4BEG[", "W6BEG["}
    actual_prefixes = {mapping.split("0", 1)[0] for mapping in mappings}
    if len(mappings) != 5 or actual_prefixes != expected_prefixes:
        raise SystemExit(f"unexpected switch-matrix mappings: {sorted(mappings)}")

    print("PASS: new-project template contains one registered E_term tile.")


if __name__ == "__main__":
    main()
