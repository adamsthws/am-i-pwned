#!/usr/bin/env bash
# Sets up the local dev tooling inside the repo, changing nothing else on your machine:
#
#   bash tools/dev-setup.sh
#
# Creates .venv/ with pre-commit, keeps pre-commit's hook environments in
# .venv/pre-commit (not ~/.cache), and installs a git pre-commit hook that uses them.
# Undo with: rm -rf .venv .git/hooks/pre-commit
#
# Exit code: 0 = done, 1 = setup failed.

cd "$(dirname "$0")/.." || exit 1
ROOT=$(pwd)

python3 -m venv .venv || exit 1
.venv/bin/pip install --quiet --upgrade pre-commit || exit 1

HOOK=$(git rev-parse --git-path hooks)/pre-commit
cat > "$HOOK" <<HOOK_EOF
#!/usr/bin/env bash
# Installed by tools/dev-setup.sh. Runs the repo's pre-commit hooks from .venv/.
export PRE_COMMIT_HOME="$ROOT/.venv/pre-commit"
exec "$ROOT/.venv/bin/pre-commit" run --hook-stage pre-commit
HOOK_EOF
chmod +x "$HOOK"

echo "Done. Hooks now run on every commit. Run them on everything with:"
echo "  PRE_COMMIT_HOME=.venv/pre-commit .venv/bin/pre-commit run --all-files"
