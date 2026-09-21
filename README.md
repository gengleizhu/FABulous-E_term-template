# FABulous E_term project-template migration

This repository adds the `E_term` east-edge termination tile to FABulous's
common `create-project` template. After installation, every newly generated
Verilog or VHDL project contains and registers:

- `Tile/E_term/E_term.csv`
- `Tile/E_term/E_term_switch_matrix.list`
- `Tile/E_term/gds_config.yaml`
- `Tile,./Tile/E_term/E_term.csv` in `fabric.csv`

The default example layout remains unchanged because its east edge uses
`RAM_IO`. A generated project can place `E_term` on applicable east-edge cells
when the neighboring routing channels match W1, W2, WW4, and W6.

## Install into a FABulous checkout

Clone or copy this repository into the virtual machine, then run:

```bash
bash scripts/install_in_vm.sh /home/zyzhao/FABulous
```

The installer:

1. refuses to overwrite changes in the affected FABulous paths;
2. preserves unrelated dirty files and generated projects;
3. records the original branch and pre-existing working-tree state;
4. creates a timestamped `codex/e-term-template-*` branch;
5. applies and commits only the E_term patch;
6. runs focused validation and records its results.

Records are written under `/home/zyzhao/FABulous_change_records` by default.
Set `RECORD_ROOT` to choose another location.

If validation is interrupted after the commit is created, switch back to the
printed feature branch and run:

```bash
bash scripts/resume_validation_in_vm.sh /home/zyzhao/FABulous
```

## Portable application

The patch can also be applied manually from the root of a compatible FABulous
checkout:

```bash
git apply --check /path/to/patches/0001-feat-include-E_term-in-new-project-templates.patch
git apply /path/to/patches/0001-feat-include-E_term-in-new-project-templates.patch
python /path/to/scripts/verify_template.py .
```

## Validation record

The migration was installed on branch
`codex/e-term-template-20260920-175834` and committed as `26403e8` in the
virtual-machine checkout. A real `create_project` call generated all three
E_term files and exactly one `fabric.csv` registration.

The normal focused pytest was blocked before test collection by the existing
VM Nix/Tkinter GLIBC mismatch (`GLIBC_2.38` unavailable). The fallback invokes
the same FABulous `create_project` implementation without importing the GUI
REPL package, and passed. This environment issue is unrelated to E_term.

## Rollback

Switch back to the original branch recorded by the installer. The original
branch receives no E_term commit, and unrelated working-tree files are left
untouched.

This repository intentionally contains no VM SSH keys, GitHub tokens, Verdi
outputs, generated user projects, or complete copy of the upstream FABulous
repository.
