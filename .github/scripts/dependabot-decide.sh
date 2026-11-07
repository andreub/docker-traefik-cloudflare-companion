#!/usr/bin/env bash
# Decide whether a Dependabot PR is safe to auto-merge.
#   dependabot-decide.sh <head-branch> < <head-commit-message>
# Prints "safe" or "review".
# Safe = docker or pip update where every dependency is a semver-patch bump,
# or has no update-type (digest-only bump). Everything else needs review.
set -euo pipefail
branch=${1:?head branch}
msg=$(cat)

case "$branch" in
    dependabot/docker/* | dependabot/pip/*) ;;
    *) echo review; exit 0 ;;
esac

# Dependabot appends a YAML block: "updated-dependencies:\n- dependency-name: …\n  update-type: …"
deps=$(printf '%s\n' "$msg" | grep -cE '^- dependency-name:' || true)
[ "$deps" -gt 0 ] || { echo review; exit 0; }

types=$(printf '%s\n' "$msg" | sed -nE 's/^ *update-type: *//p')
if printf '%s\n' "$types" | grep -vE '^(version-update:semver-patch)?$' | grep -q .; then
    echo review
else
    echo safe
fi
