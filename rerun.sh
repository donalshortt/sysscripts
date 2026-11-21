#!/usr/bin/env bash
# Rerun failed or cancelled GitHub Actions jobs for a pull request.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: rerun.sh [--wait] [PR_NUMBER|PR_URL|BRANCH] [-R OWNER/REPO]

Immediately request individual retries for failed, cancelled or timed-out jobs.
With no argument, use the current branch's PR. GitHub may also retry dependent jobs.
Use --wait to retry requests GitHub blocks because of an active or changed attempt.
Each job is retried at most once successfully; running jobs are never cancelled.
Exit status 2 means GitHub temporarily blocked retries; 1 means another error.

Examples:
  rerun.sh
  rerun.sh 427
  rerun.sh --wait
  rerun.sh 427 -R owner/repo

Requires an authenticated GitHub CLI (gh) and jq.
EOF
}

wait_for_completion=false
pr_args=()
for argument in "$@"; do
    case "$argument" in
        --wait) wait_for_completion=true ;;
        -h|--help) usage; exit 0 ;;
        *) pr_args+=("$argument") ;;
    esac
done

for dependency in gh jq; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$dependency" >&2
        exit 1
    fi
done

# gh pr checks returns 1 for failed checks and 8 for pending checks.
checks_status=0
checks=$(gh pr checks "${pr_args[@]}" --json bucket,link) || checks_status=$?
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

# Select actual Actions job IDs, not the check IDs embedded in browser URLs.
jq_helpers='def retryable:
    .status == "completed" and (.conclusion as $conclusion
    | ["failure", "cancelled", "timed_out", "action_required", "startup_failure", "stale"]
    | index($conclusion) != null);'
error_count=0
pending=()
while IFS=$'\t' read -r repo run_id; do
    if ! run=$(gh run view "$run_id" --repo "$repo" --json jobs); then
        error_count=$((error_count + 1))
        continue
    fi
    if ! jobs=$(jq -c --arg repo "$repo" --arg run_id "$run_id" "$jq_helpers"'
        .jobs | unique_by(.databaseId) | .[] | select(retryable)
        | {repo: $repo, run_id: $run_id, id: .databaseId, name: .name}
    ' <<< "$run"); then
        error_count=$((error_count + 1))
        continue
    fi
    if [[ -n $jobs ]]; then
        while IFS= read -r target; do pending+=("$target"); done <<< "$jobs"
    fi
done <<< "$runs"

rerun_count=0
blocked_count=0
while (( ${#pending[@]} )); do
    waiting=()
    for target in "${pending[@]}"; do
        repo=$(jq -r '.repo' <<< "$target")
        run_id=$(jq -r '.run_id' <<< "$target")
        job_id=$(jq -r '.id' <<< "$target")
        name=$(jq -r '.name' <<< "$target")

        # Starting a retry can replace the other jobs' API IDs. Resolve the latest
        # job before every request, using its name only when it is unambiguous.
        if ! run=$(gh run view "$run_id" --repo "$repo" --json jobs); then
            error_count=$((error_count + 1))
            continue
        fi
        if ! job=$(jq -ce --argjson id "$job_id" --arg name "$name" '
            [.jobs[] | select(.databaseId == $id)] as $exact
            | (if ($exact | length) == 1 then $exact
               else [.jobs[] | select(.name == $name)] end)
            | if length == 1 then .[0]
              else error("Cannot uniquely resolve job: " + $name) end
        ' <<< "$run"); then
            error_count=$((error_count + 1))
            continue
        fi
        if ! jq -e "$jq_helpers retryable" <<< "$job" >/dev/null; then
            printf 'Skipping %s: already %s.\n' "$name" \
                "$(jq -r 'if .status == "completed" then .conclusion else .status end' <<< "$job")"
            continue
        fi
        job_id=$(jq -r '.databaseId' <<< "$job")
        printf 'Requesting retry of %s (job %s, run %s)...\n' "$name" "$job_id" "$run_id"

        # This is the same job endpoint as `gh run rerun --job`, but `gh api`
        # preserves GitHub's rejection reason instead of hiding HTTP 403 details.
        if response=$(gh api --hostname "${repo%%/*}" --method POST \
            "repos/${repo#*/}/actions/jobs/$job_id/rerun" 2>&1); then
            rerun_count=$((rerun_count + 1))
            continue
        fi
        printf 'GitHub rejected retry of %s:\n%s\n' "$name" "$response" >&2
        if [[ $response == *'(HTTP 403)'* && (
            $response == *'already running'* ||
            $response == *'Only jobs from the current attempt can be re-run'*
        ) ]]; then
            if [[ $wait_for_completion == true ]]; then
                waiting+=("$target")
            else
                blocked_count=$((blocked_count + 1))
            fi
        else
            # Permission errors and ambiguous network failures need attention,
            # not another POST which might repeat a request GitHub accepted.
            error_count=$((error_count + 1))
        fi
    done
    pending=("${waiting[@]}")
    if (( ${#pending[@]} )); then
        printf 'Waiting 20 seconds before refreshing %s blocked job(s)...\n' "${#pending[@]}"
        sleep 20
    fi
done

printf 'Requested retries for %s job(s); %s blocked; %s error(s).\n' \
    "$rerun_count" "$blocked_count" "$error_count"
if (( error_count )); then exit 1; fi
if (( blocked_count )); then
    printf 'Use --wait to keep retrying requests GitHub temporarily blocks.\n'
    exit 2
fi
