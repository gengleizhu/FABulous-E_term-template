#!/usr/bin/env bash
set -euo pipefail

REPO=${1:-/home/zyzhao/FABulous}
PROJECT=${2:?generated Verilog project path is required}
RECORD=${3:?record directory is required}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

python3 "$SCRIPT_DIR/prepare_e_io_fabric.py" "$PROJECT" \
    2>&1 | tee "$RECORD/e-io-layout.log"

cd "$REPO"
if [[ -r /home/zyzhao/.nix-profile/etc/profile.d/nix.sh ]]; then
    # shellcheck disable=SC1091
    . /home/zyzhao/.nix-profile/etc/profile.d/nix.sh
fi
export NIX_SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt

nix develop --offline --no-write-lock-file --accept-flake-config .#nix-env \
    --command bash -c \
    "FABulous -p '$PROJECT' run 'load_fabric; gen_all_tile; run_fab'" \
    2>&1 | tee "$RECORD/e-io-generation.log"

require_file() {
    local path=$1
    [[ -f "$path" ]] || { printf 'FAIL: missing generated file: %s\n' "$path" >&2; return 1; }
    printf 'PASS: generated file exists: %s\n' "${path#"$PROJECT/"}"
}

require_match() {
    local pattern=$1
    local path=$2
    local label=$3
    grep -qE "$pattern" "$path" || { printf 'FAIL: %s\n' "$label" >&2; return 1; }
    printf 'PASS: %s\n' "$label"
}

require_file "$PROJECT/Tile/E_IO/E_IO.v"
require_file "$PROJECT/Tile/E_IO/E_IO_ConfigMem.csv"
require_file "$PROJECT/Tile/E_IO/E_IO_ConfigMem.v"
require_file "$PROJECT/Tile/E_IO/E_IO_switch_matrix.v"
require_file "$PROJECT/Fabric/eFPGA.v"
if [[ -f "$PROJECT/Tile/E_IO/E_IO_io_pin_order.yaml" ]]; then
    printf 'PASS: generated file exists: Tile/E_IO/E_IO_io_pin_order.yaml\n'
else
    printf 'INFO: pin-order YAML is produced by the later physical/GDS flow, not run_fab.\n'
fi

require_match '^module E_IO' "$PROJECT/Tile/E_IO/E_IO.v" \
    'E_IO module declaration exists'
require_match 'parameter[[:space:]]+NoConfigBits=114' "$PROJECT/Tile/E_IO/E_IO.v" \
    'E_IO exposes 114 configuration bits'
instance_count=$(grep -cE '^IO_1_bidirectional_frame_config_pass Inst_[AB]_' \
    "$PROJECT/Tile/E_IO/E_IO.v" || true)
[[ "$instance_count" -eq 2 ]] || {
    printf 'FAIL: expected two IO BEL instances, found %s\n' "$instance_count" >&2
    exit 1
}
printf 'PASS: E_IO contains exactly two IO BEL instances\n'
require_match 'Inst_A_IO_1_bidirectional_frame_config_pass' \
    "$PROJECT/Tile/E_IO/E_IO.v" 'A_ IO BEL instance exists'
require_match 'Inst_B_IO_1_bidirectional_frame_config_pass' \
    "$PROJECT/Tile/E_IO/E_IO.v" 'B_ IO BEL instance exists'
require_match 'E_IO' "$PROJECT/Fabric/eFPGA.v" \
    'generated fabric contains E_IO instances'

sha256sum \
    "$PROJECT/Tile/E_IO/E_IO.csv" \
    "$PROJECT/Tile/E_IO/E_IO_switch_matrix.list" \
    "$PROJECT/Tile/E_IO/E_IO.v" \
    "$PROJECT/Tile/E_IO/E_IO_ConfigMem.csv" \
    "$PROJECT/Tile/E_IO/E_IO_switch_matrix.v" \
    "$PROJECT/Fabric/eFPGA.v" \
    > "$RECORD/generated-e-io.sha256"

printf 'PASS: generated E_IO has two bidirectional IO BEL instances.\n'
