"""Replace the default east RAM_IO column with E_IO for generation testing."""

from __future__ import annotations

import sys
from pathlib import Path


def main() -> None:
    project = Path(sys.argv[1]).resolve()
    fabric = project / "fabric.csv"
    lines = fabric.read_text(encoding="utf-8").splitlines()
    in_layout = False
    interior_rows = 0
    output: list[str] = []

    for line in lines:
        fields = line.split(",")
        if fields[0] == "FabricBegin":
            in_layout = True
        elif fields[0] == "FabricEnd":
            in_layout = False
        elif in_layout and len(fields) > 9:
            if fields[0] == "W_IO":
                if fields[9] != "RAM_IO":
                    raise SystemExit(f"unexpected east-edge tile: {fields[9]}")
                fields[9] = "E_IO"
                interior_rows += 1
                line = ",".join(fields)
            elif fields[0] == "NULL" and fields[9] in {
                "N_term_RAM_IO",
                "S_term_RAM_IO",
            }:
                fields[9] = "NULL"
                line = ",".join(fields)
        output.append(line)

    if interior_rows == 0:
        raise SystemExit("no default east RAM_IO column was replaced")
    fabric.write_text("\n".join(output) + "\n", encoding="utf-8")
    print(f"PASS: placed E_IO in {interior_rows} east-edge rows")


if __name__ == "__main__":
    main()
