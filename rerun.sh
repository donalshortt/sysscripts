#!/usr/bin/env bash
# Rerun failed or cancelled GitHub Actions jobs for a pull request.
set -euo pipefail

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    cat <<'EOF'
Usage: rerun.sh [PR_NUMBER|PR_URL|BRANCH] [-R OWNER/REPO]

Rerun failed or cancelled jobs across a PR's workflows. With no argument, use the
current branch's PR. Workflows still running are skipped; try again later.

Examples:
  rerun.sh
  rerun.sh 427
  rerun.sh 427 -R donalshortt/unnamed_strat_game

Requires an authenticated GitHub CLI (gh) and jq.
EOF
    exit 0
fi

for dependency in gh jq; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$dependency" >&2
        exit 1
    fi
done

# gh pr checks returns 1 for failed checks and 8 for pending checks.
checks_status=0
checks=$(gh pr checks "$@" --json bucket,link) || checks_status=$?
if [[ $checks_status != 0 && $checks_status != 1 && $checks_status != 8 ]]; then
    exit "$checks_status"
fi
if [[ -z $checks ]]; then
    printf 'Could not read pull request checks.\n' >&2
    exit 1
fi

# Use each check's repository so PR URLs also work outside a local checkout.
# Ignore checks from external CI providers and deduplicate workflow runs.
runs=$(jq -r '
    if type != "array" then error("Expected a list of PR checks") else
        [.[] | select(.bucket == "fail" or .bucket == "cancel") | .link // empty
         | capture("^https://(?<repo>[^/]+/[^/]+/[^/]+)/actions/runs/(?<id>[0-9]+)(?:/|$)")
         | [.repo, .id]] | unique | .[] | @tsv
    end
' <<< "$checks")

if [[ -z $runs ]]; then
    printf 'No failed or cancelled GitHub Actions jobs found.\n'
    exit 0
fi

result=0
rerun_count=0
skipped_count=0
while IFS=$'\t' read -r repo run_id; do
    if ! status=$(gh run view "$run_id" --repo "$repo" --json status --jq .status); then
        result=1
        continue
    fi
    if [[ $status != completed ]]; then
        printf 'Skipping run %s (%s); try again once it finishes.\n' "$run_id" "$status"
        skipped_count=$((skipped_count + 1))
        continue
    fi
    printf 'Rerunning failed or cancelled jobs in %s, run %s...\n' "$repo" "$run_id"
    if gh run rerun "$run_id" --repo "$repo" --failed; then
        rerun_count=$((rerun_count + 1))
    else
        result=1
    fi
done <<< "$runs"

printf 'Requested reruns for %s workflow(s); skipped %s unfinished workflow(s).\n' \
    "$rerun_count" "$skipped_count"
exit "$result"
