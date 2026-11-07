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

# Every dependency must carry an explicit update-type of semver-patch.
# Exception: docker digest-only bumps have no update-type and no version change
# (title "Bump alpine from `<old digest>` to `<new digest>`").
# A missing update-type anywhere else (e.g. a pip requirement range change
# like ==4.1.* -> ==5.9.*) means review — that's how PR #1 slipped through.
patches=$(printf '%s\n' "$msg" | grep -cE '^ *update-type: *version-update:semver-patch *$' || true)
types=$(printf '%s\n' "$msg" | grep -cE '^ *update-type:' || true)
title=$(printf '%s\n' "$msg" | head -1)

if [ "$types" -eq "$deps" ] && [ "$patches" -eq "$deps" ]; then
    echo safe
elif [ "$types" -eq 0 ] && [ "$deps" -eq 1 ] \
     && case "$branch" in dependabot/docker/*) true ;; *) false ;; esac \
     && printf '%s\n' "$title" | grep -qE '^(deps\([a-z]+\): )?[Bb]ump [^ ]+ from `[0-9a-f]{7,}` to `[0-9a-f]{7,}`'; then
    echo safe
else
    echo review
fi
