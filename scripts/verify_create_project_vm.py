"""Exercise FABulous create_project without importing the GUI REPL package."""

from __future__ import annotations

import shutil
import sys
import types
from pathlib import Path


def main() -> None:
    """Create a real project and validate its E_term template integration."""
    repo = Path(sys.argv[1]).resolve()
    destination = Path(sys.argv[2]).resolve()

    sys.path.insert(0, str(repo))

    # Importing fabulous.fabulous_repl normally imports tkinter before helper.py.
    # The VM's Nix Tcl requires a newer glibc than the host. A namespace package
    # lets this focused test import helper.py without changing production code.
    repl_package = types.ModuleType("fabulous.fabulous_repl")
    repl_package.__path__ = [str(repo / "fabulous/fabulous_repl")]
    sys.modules["fabulous.fabulous_repl"] = repl_package

    from fabulous.fabric_definition.define import HDLType
    from fabulous.fabulous_repl.helper import create_project

    if destination.exists():
        shutil.rmtree(destination)
    create_project(destination, lang=HDLType.VERILOG)

    tile_dir = destination / "Tile/E_term"
    required = [
        tile_dir / "E_term.csv",
        tile_dir / "E_term_switch_matrix.list",
        tile_dir / "gds_config.yaml",
    ]
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise SystemExit(f"missing E_term files in created project: {missing}")

    fabric_text = (destination / "fabric.csv").read_text(encoding="utf-8")
    registration = "Tile,./Tile/E_term/E_term.csv"
    if sum(line.startswith(registration) for line in fabric_text.splitlines()) != 1:
        raise SystemExit("created fabric.csv does not register E_term exactly once")

    print(f"PASS: create_project generated registered E_term at {destination}")


if __name__ == "__main__":
    main()
