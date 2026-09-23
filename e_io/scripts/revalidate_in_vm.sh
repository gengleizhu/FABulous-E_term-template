#!/usr/bin/env bash
set -euo pipefail

REPO=${1:-/home/zyzhao/FABulous}
RECORD=${2:?record directory is required}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

[[ -d "$REPO/.git" ]] || { echo "FABulous repository not found: $REPO" >&2; exit 1; }
mkdir -p "$RECORD"

TEMP_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEMP_ROOT"' EXIT

"$REPO/.venv/bin/python" "$SCRIPT_DIR/verify_create_project_vm.py" \
    "$REPO" "$TEMP_ROOT/projects" \
    2>&1 | tee "$RECORD/create-project-revalidation.log"

bash "$SCRIPT_DIR/validate_generated_e_io.sh" \
    "$REPO" "$TEMP_ROOT/projects/verilog" "$RECORD" \
    2>&1 | tee "$RECORD/generated-e-io-validation.log"

git -C "$REPO" status --short > "$RECORD/after-status.txt"
printf 'PASS: E_IO template revalidation completed.\n'
