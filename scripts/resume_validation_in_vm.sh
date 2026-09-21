#!/usr/bin/env bash
set -euo pipefail

REPO=${1:-/home/zyzhao/FABulous}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
RECORD_ROOT=${RECORD_ROOT:-/home/zyzhao/FABulous_change_records}
BRANCH=$(git -C "$REPO" branch --show-current)

case "$BRANCH" in
    codex/e-term-template-*) ;;
    *)
        printf 'Current branch is not an E_term feature branch: %s\n' "$BRANCH" >&2
        printf 'Switch to the timestamped branch printed by the installer first.\n' >&2
        exit 1
        ;;
esac

TIMESTAMP=${BRANCH#codex/e-term-template-}
RECORD="$RECORD_ROOT/e-term-template-$TIMESTAMP"
mkdir -p "$RECORD"

test -f "$REPO/fabulous/fabric_files/FABulous_project_template_common/Tile/E_term/E_term.csv"
test -f "$REPO/fabulous/fabric_files/FABulous_project_template_common/Tile/E_term/E_term_switch_matrix.list"
grep -q '^Tile,./Tile/E_term/E_term.csv' \
    "$REPO/fabulous/fabric_files/FABulous_project_template_common/fabric.csv"

git -C "$REPO" rev-parse HEAD > "$RECORD/after-commit.txt"
git -C "$REPO" show --stat --oneline HEAD > "$RECORD/commit-stat.txt"

cd "$REPO"
if [[ -r /home/zyzhao/.nix-profile/etc/profile.d/nix.sh ]]; then
    # shellcheck disable=SC1091
    . /home/zyzhao/.nix-profile/etc/profile.d/nix.sh
fi

if nix develop --offline --no-write-lock-file --accept-flake-config .#nix-env \
    --command uv run pytest tests/repl_test/test_helper.py \
    -k east_termination_tile -q \
    2>&1 | tee "$RECORD/unit-test.log"; then
    printf 'Focused pytest passed.\n' > "$RECORD/test-method.txt"
else
    printf '%s\n' \
        'Focused pytest blocked by the VM Nix/Tkinter GLIBC mismatch.' \
        'Running the same create_project function without GUI REPL initialization.' \
        > "$RECORD/test-method.txt"
fi

TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT
"$REPO/.venv/bin/python" \
    "$SCRIPT_DIR/verify_create_project_vm.py" \
    "$REPO" "$TEMP_ROOT/new_project" \
    2>&1 | tee "$RECORD/create-project.log"

test -f "$TEMP_ROOT/new_project/Tile/E_term/E_term.csv"
test -f "$TEMP_ROOT/new_project/Tile/E_term/E_term_switch_matrix.list"
test -f "$TEMP_ROOT/new_project/Tile/E_term/gds_config.yaml"
grep -q '^Tile,./Tile/E_term/E_term.csv' "$TEMP_ROOT/new_project/fabric.csv"

sha256sum \
    "$TEMP_ROOT/new_project/Tile/E_term/E_term.csv" \
    "$TEMP_ROOT/new_project/Tile/E_term/E_term_switch_matrix.list" \
    "$TEMP_ROOT/new_project/Tile/E_term/gds_config.yaml" \
    > "$RECORD/generated-project.sha256"

git -C "$REPO" status --short > "$RECORD/after-status.txt"
printf 'E_term template validation passed.\n'
printf 'Feature branch: %s\n' "$BRANCH"
printf 'Record: %s\n' "$RECORD"
