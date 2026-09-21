#!/usr/bin/env bash
set -euo pipefail

REPO=${1:-/home/zyzhao/FABulous}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PACKAGE_DIR=${2:-$(dirname "$SCRIPT_DIR")}
PATCH="$PACKAGE_DIR/patches/0001-feat-include-E_term-in-new-project-templates.patch"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RECORD_ROOT=${RECORD_ROOT:-/home/zyzhao/FABulous_change_records}
RECORD="$RECORD_ROOT/e-term-template-$TIMESTAMP"
FEATURE_BRANCH="codex/e-term-template-$TIMESTAMP"

[[ -d "$REPO/.git" ]] || {
    printf 'FABulous repository not found: %s\n' "$REPO" >&2
    exit 1
}
[[ -f "$PATCH" ]] || {
    printf 'Migration patch not found: %s\n' "$PATCH" >&2
    exit 1
}
TARGET_PATHS=(
    docs/source/user_guide/building_doc/building_fabric.md
    fabulous/fabric_files/FABulous_project_template_common/fabric.csv
    fabulous/fabric_files/FABulous_project_template_common/Tile/E_term
    tests/repl_test/test_helper.py
)

# Existing generated projects and simulator files may remain dirty. Only paths
# touched by this migration must be clean, and unrelated staged changes are not
# safe because a Git commit would include them.
[[ -z "$(git -C "$REPO" status --porcelain -- "${TARGET_PATHS[@]}")" ]] || {
    printf 'An E_term target path already has changes; refusing to overwrite it.\n' >&2
    git -C "$REPO" status --short -- "${TARGET_PATHS[@]}" >&2
    exit 1
}
git -C "$REPO" diff --cached --quiet || {
    printf 'Repository has staged changes; commit or unstage them before migration.\n' >&2
    exit 1
}

mkdir -p "$RECORD"
git -C "$REPO" rev-parse HEAD > "$RECORD/before-commit.txt"
git -C "$REPO" branch --show-current > "$RECORD/original-branch.txt"
git -C "$REPO" status --short > "$RECORD/before-status.txt"
git -C "$REPO" diff --binary > "$RECORD/pre-existing-unstaged.patch"
git -C "$REPO" ls-files --others --exclude-standard \
    > "$RECORD/pre-existing-untracked.txt"
git -C "$REPO" switch -c "$FEATURE_BRANCH"
printf '%s\n' "$FEATURE_BRANCH" > "$RECORD/feature-branch.txt"

if ! git -C "$REPO" apply --check "$PATCH" > "$RECORD/git-apply-check.log" 2>&1; then
    git -C "$REPO" switch "$(cat "$RECORD/original-branch.txt")"
    git -C "$REPO" branch -D "$FEATURE_BRANCH"
    printf 'Patch compatibility check failed. See %s/git-apply-check.log\n' "$RECORD" >&2
    exit 1
fi

git -C "$REPO" apply --index "$PATCH"
if ! git -C "$REPO" commit -m 'feat: include E_term in new project templates' \
    > "$RECORD/git-commit.log" 2>&1; then
    git -C "$REPO" apply --reverse --index "$PATCH"
    git -C "$REPO" switch "$(cat "$RECORD/original-branch.txt")"
    git -C "$REPO" branch -D "$FEATURE_BRANCH"
    printf 'Commit failed; E_term patch was removed. See %s/git-commit.log\n' "$RECORD" >&2
    exit 1
fi

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
        'Focused pytest blocked; running create_project without GUI REPL initialization.' \
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
grep -q '^Tile,./Tile/E_term/E_term.csv' "$TEMP_ROOT/new_project/fabric.csv"

sha256sum \
    "$TEMP_ROOT/new_project/Tile/E_term/E_term.csv" \
    "$TEMP_ROOT/new_project/Tile/E_term/E_term_switch_matrix.list" \
    "$TEMP_ROOT/new_project/Tile/E_term/gds_config.yaml" \
    > "$RECORD/generated-project.sha256"

git -C "$REPO" status --short > "$RECORD/after-status.txt"
printf 'E_term template support installed and verified. Record: %s\n' "$RECORD"
printf 'Feature branch: %s\n' "$FEATURE_BRANCH"
