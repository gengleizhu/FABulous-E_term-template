#!/usr/bin/env bash
set -euo pipefail

REPO=${1:-/home/zyzhao/FABulous}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PATCH="$SCRIPT_DIR/../patches/0001-feat-add-two-BEL-east-IO-project-template.patch"
RECORD_ROOT=${RECORD_ROOT:-/home/zyzhao/FABulous_change_records}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RECORD="$RECORD_ROOT/e-io-template-$TIMESTAMP"
BRANCH="codex/e-io-template-$TIMESTAMP"

[[ -d "$REPO/.git" ]] || { echo "FABulous repository not found: $REPO" >&2; exit 1; }
[[ -f "$PATCH" ]] || { echo "Migration patch not found: $PATCH" >&2; exit 1; }

TARGETS=(
    docs/source/user_guide/building_doc/building_fabric.md
    fabulous/fabric_files/FABulous_project_template_common/fabric.csv
    fabulous/fabric_files/FABulous_project_template_common/Tile/E_IO
    fabulous/fabric_files/FABulous_project_template_verilog/Tile/E_IO
    fabulous/fabric_files/FABulous_project_template_vhdl/Tile/E_IO
    tests/repl_test/test_helper.py
)

[[ -z "$(git -C "$REPO" status --porcelain -- "${TARGETS[@]}")" ]] || {
    echo 'An E_IO target path already has changes; refusing to overwrite it.' >&2
    git -C "$REPO" status --short -- "${TARGETS[@]}" >&2
    exit 1
}
git -C "$REPO" diff --cached --quiet || {
    echo 'Repository has unrelated staged changes; unstage or commit them first.' >&2
    exit 1
}

mkdir -p "$RECORD"
git -C "$REPO" branch --show-current > "$RECORD/original-branch.txt"
git -C "$REPO" rev-parse HEAD > "$RECORD/before-commit.txt"
git -C "$REPO" status --short > "$RECORD/before-status.txt"
git -C "$REPO" diff --binary > "$RECORD/pre-existing-unstaged.patch"
git -C "$REPO" ls-files --others --exclude-standard \
    > "$RECORD/pre-existing-untracked.txt"

git -C "$REPO" switch -c "$BRANCH"
printf '%s\n' "$BRANCH" > "$RECORD/feature-branch.txt"

if ! git -C "$REPO" apply --check "$PATCH" > "$RECORD/apply-check.log" 2>&1; then
    git -C "$REPO" switch "$(cat "$RECORD/original-branch.txt")"
    git -C "$REPO" branch -D "$BRANCH"
    echo "Patch compatibility check failed: $RECORD/apply-check.log" >&2
    exit 1
fi

git -C "$REPO" apply --index "$PATCH"
git -C "$REPO" commit -m 'feat: add two-BEL east IO project template' \
    > "$RECORD/commit.log" 2>&1
git -C "$REPO" rev-parse HEAD > "$RECORD/after-commit.txt"
git -C "$REPO" show --stat --oneline HEAD > "$RECORD/commit-stat.txt"

TEMP_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEMP_ROOT"' EXIT

"$REPO/.venv/bin/python" "$SCRIPT_DIR/verify_create_project_vm.py" \
    "$REPO" "$TEMP_ROOT/projects" \
    2>&1 | tee "$RECORD/create-project-validation.log"

bash "$SCRIPT_DIR/validate_generated_e_io.sh" \
    "$REPO" "$TEMP_ROOT/projects/verilog" "$RECORD"

git -C "$REPO" status --short > "$RECORD/after-status.txt"
printf 'E_IO template installed and verified.\n'
printf 'Branch: %s\n' "$BRANCH"
printf 'Record: %s\n' "$RECORD"
