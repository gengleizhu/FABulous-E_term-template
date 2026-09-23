# FABulous two-BEL E_IO template migration

This package adds an east-boundary `E_IO` Tile to FABulous's common
`create-project` template. `E_IO` mirrors the generated `W_IO` routing and
contains two `IO_1_bidirectional_frame_config_pass` BELs named with the `A_`
and `B_` prefixes. Each new project receives Verilog and VHDL-specific BEL
sources as appropriate.

Run in the virtual machine:

```bash
bash /path/to/FABulous-E_term-template/e_io/scripts/install_in_vm.sh \
  /home/zyzhao/FABulous
```

If installation was committed but validation was interrupted, rerun validation
without applying the patch or creating another branch:

```bash
bash /path/to/FABulous-E_term-template/e_io/scripts/revalidate_in_vm.sh \
  /home/zyzhao/FABulous \
  /home/zyzhao/FABulous_change_records/e-io-template-YYYYMMDD-HHMMSS
```

The installer preserves unrelated dirty files, creates a timestamped feature
branch, applies and commits only the E_IO template change, creates both
Verilog and VHDL projects, replaces the default east RAM_IO column only in a
temporary validation project, and runs `gen_all_tile` plus `run_fab`.

The normal default example layout remains unchanged. To use E_IO in a real
project, place it only in applicable east-edge rows whose W1, W2, WW4, and W6
channels match the adjacent core Tile. The top and bottom cells of an E_IO-only
east column are normally `NULL` unless purpose-built corner Tiles are provided.

Generated acceptance criteria:

- `E_IO.v`, `E_IO_ConfigMem.csv`, `E_IO_ConfigMem.v`, and switch-matrix
  Verilog exist;
- `E_IO.v` contains `NoConfigBits=114`;
- exactly two IO BEL instances exist, one `A_` and one `B_`;
- the generated fabric contains E_IO instances;
- SHA-256 values are saved in the change-record directory.

`E_IO_io_pin_order.yaml` belongs to the later physical/GDS flow and is not
emitted by the `run_fab` acceptance command.
