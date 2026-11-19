#!/bin/bash
# Raises or clears a release problem as a GitHub issue in this repo.
#
#   release-alert.sh raise <key> <title> <body>
#   release-alert.sh clear <key>
#
# An issue rather than only a failed run: a failed run is one email that is
# easy to miss, which is how 1.0.5 sat unpublished behind an unsigned Apple
# agreement. An open issue stays in sight until the problem is gone. The key
# keeps one issue per problem, so a daily check comments instead of piling up.
#
# Needs GH_TOKEN with issues: write, and GITHUB_REPOSITORY (set on runners).

set -euo pipefail

action="$1"
key="$2"
label="release-alert"
marker="<!-- release-alert:${key} -->"

gh label create "$label" --repo "$GITHUB_REPOSITORY" --color B60205 \
    --description "A release is blocked or missing" --force >/dev/null

existing=$(gh issue list --repo "$GITHUB_REPOSITORY" --label "$label" --state open \
    --json number,body --jq ".[] | select(.body | contains(\"${marker}\")) | .number" | head -1)

case "$action" in
raise)
    title="$3"
    body="$4"
    run_url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID:-}"
    if [ -n "$existing" ]; then
        gh issue comment "$existing" --repo "$GITHUB_REPOSITORY" \
            --body "Still happening: ${run_url}"
    else
        gh issue create --repo "$GITHUB_REPOSITORY" --label "$label" --title "$title" \
            --body "$(printf '%s\n\n%s\n\nSeen in %s\n' "$marker" "$body" "$run_url")"
    fi
    ;;
clear)
    if [ -n "$existing" ]; then
        gh issue close "$existing" --repo "$GITHUB_REPOSITORY" --comment "Resolved, closing."
    fi
    ;;
esac
