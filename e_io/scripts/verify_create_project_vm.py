"""Create Verilog/VHDL projects and verify the two-BEL E_IO template."""

from __future__ import annotations

import shutil
import sys
import types
from pathlib import Path


def check_project(project: Path, suffix: str) -> None:
    tile = project / "Tile/E_IO"
    required = [
        tile / "E_IO.csv",
        tile / "E_IO_switch_matrix.list",
        tile / "gds_config.yaml",
        tile / f"IO_1_bidirectional_frame_config_pass.{suffix}",
        tile / f"Config_access.{suffix}",
    ]
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise SystemExit(f"missing E_IO template files: {missing}")

    tile_csv = (tile / "E_IO.csv").read_text(encoding="utf-8")
    bel_rows = [
        line
        for line in tile_csv.splitlines()
        if line.startswith("BEL,./IO_1_bidirectional_frame_config_pass.")
    ]
    if len(bel_rows) != 2:
        raise SystemExit(f"expected exactly two E_IO BELs, got: {bel_rows}")
    if not any(",A_," in line for line in bel_rows):
        raise SystemExit("E_IO is missing the A_ bidirectional IO BEL")
    if not any(",B_," in line for line in bel_rows):
        raise SystemExit("E_IO is missing the B_ bidirectional IO BEL")

    expected_csv = {
        "WEST,W1BEG,1,0,NULL,4",
        "WEST,W2BEG,1,0,NULL,8",
        "WEST,W2BEGb,1,0,NULL,8",
        "WEST,WW4BEG,4,0,NULL,4",
        "WEST,W6BEG,6,0,NULL,2",
        "EAST,NULL,-1,0,E1END,4",
        "EAST,NULL,-1,0,E2MID,8",
        "EAST,NULL,-1,0,E2END,8",
        "EAST,NULL,-4,0,EE4END,4",
        "EAST,NULL,-6,0,E6END,2",
    }
    for marker in expected_csv:
        if marker not in tile_csv:
            raise SystemExit(f"E_IO routing declaration missing: {marker}")

    matrix = (tile / "E_IO_switch_matrix.list").read_text(encoding="utf-8")
    expected_matrix = {
        "W1BEG[0|1|2|3],E1END[3|2|1|0]",
        "W1BEG[0|1|2|3],[A_O|A_Q|B_O|B_Q]",
        "A_[I|I|I|I|I|I|I|I],E2MID[0|1|2|3|4|5|6|7]",
        "B_[I|I|I|I|I|I|I|I],E2END[0|1|2|3|4|5|6|7]",
    }
    for marker in expected_matrix:
        if marker not in matrix:
            raise SystemExit(f"E_IO switch-matrix mapping missing: {marker}")

    fabric = (project / "fabric.csv").read_text(encoding="utf-8")
    if fabric.count("Tile,./Tile/E_IO/E_IO.csv") != 1:
        raise SystemExit("fabric.csv must register E_IO exactly once")


def main() -> None:
    repo = Path(sys.argv[1]).resolve()
    output_root = Path(sys.argv[2]).resolve()
    if output_root.exists():
        shutil.rmtree(output_root)
    output_root.mkdir(parents=True)

    sys.path.insert(0, str(repo))
    repl_package = types.ModuleType("fabulous.fabulous_repl")
    repl_package.__path__ = [str(repo / "fabulous/fabulous_repl")]
    sys.modules["fabulous.fabulous_repl"] = repl_package

    from fabulous.fabric_definition.define import HDLType
    from fabulous.fabulous_repl.helper import create_project

    for language, suffix in ((HDLType.VERILOG, "v"), (HDLType.VHDL, "vhdl")):
        destination = output_root / language.value
        create_project(destination, lang=language)
        check_project(destination, suffix)
        print(f"PASS: {language.value} create_project contains two-BEL E_IO")


if __name__ == "__main__":
    main()
