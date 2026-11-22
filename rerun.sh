#!/usr/bin/env bash
# Rerun failed or cancelled GitHub Actions jobs for a pull request.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: rerun.sh [--wait] [PR_NUMBER|PR_URL|BRANCH] [-R OWNER/REPO]

Request retries for failed, cancelled or timed-out jobs.
Several failed jobs in one completed workflow can be retried together.
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

# Older GitHub CLI versions only support JSON output through gh pr view.
checks=$(gh pr view "${pr_args[@]}" --json statusCheckRollup)
if [[ -z $checks ]]; then
    printf 'Could not read pull request checks.\n' >&2
    exit 1
fi

# Use each check's repository so PR URLs also work outside a local checkout.
# Ignore checks from external CI providers and deduplicate workflow runs.
jq_helpers='def retryable:
    (.status // "" | ascii_downcase) == "completed"
    and ((.conclusion // "" | ascii_downcase) as $conclusion
    | ["failure", "cancelled", "timed_out", "action_required", "startup_failure", "stale"]
    | index($conclusion) != null);'
runs=$(jq -r "$jq_helpers"'
    .statusCheckRollup
    | if type != "array" then error("Expected a list of PR checks") else
        [.[] | select(retryable) | .detailsUrl // empty
         | capture("^https://(?<repo>[^/]+/[^/]+/[^/]+)/actions/runs/(?<id>[0-9]+)(?:/|$)")
         | [.repo, .id]] | unique | .[] | @tsv
    end
' <<< "$checks")

if [[ -z $runs ]]; then
    printf 'No failed or cancelled GitHub Actions jobs found.\n'
    exit 0
fi

retry_blocked() {
    [[ $1 == *'(HTTP 403)'* && (
        $1 == *'already running'* ||
        $1 == *'Only jobs from the current attempt can be re-run'*
    ) ]]
}

# Select actual Actions job IDs, not the check IDs embedded in browser URLs.
error_count=0
rerun_count=0
blocked_count=0
pending=()
while IFS=$'\t' read -r repo run_id; do
    if ! run=$(gh run view "$run_id" --repo "$repo" --json jobs,status); then
        error_count=$((error_count + 1))
        continue
    fi
    if ! jobs=$(jq -c --arg repo "$repo" --arg run_id "$run_id" "$jq_helpers"'
        [.jobs | unique_by(.databaseId) | .[] | select(retryable)
        | {repo: $repo, run_id: $run_id, id: .databaseId, name: .name, conclusion}]
    ' <<< "$run"); then
        error_count=$((error_count + 1))
        continue
    fi
    # A single request covers all failures without changing attempts mid-loop.
    if jq -e '.status == "completed"' <<< "$run" >/dev/null &&
        jq -e 'length > 1 and all(.[]; .conclusion == "failure")' <<< "$jobs" >/dev/null
    then
        job_count=$(jq 'length' <<< "$jobs")
        printf 'Requesting retry of %s failed jobs together (run %s)...\n' "$job_count" "$run_id"
        if response=$(gh api --hostname "${repo%%/*}" --method POST \
            "repos/${repo#*/}/actions/runs/$run_id/rerun-failed-jobs" 2>&1); then
            rerun_count=$((rerun_count + job_count))
            continue
        fi
        printf 'GitHub rejected the retry for run %s:\n%s\n' "$run_id" "$response" >&2
        if ! retry_blocked "$response"; then
            error_count=$((error_count + 1))
            continue
        fi
        if [[ $wait_for_completion == false ]]; then
            blocked_count=$((blocked_count + job_count))
            continue
        fi
        # Refresh individual targets if another attempt started after discovery.
    fi
    while IFS= read -r target; do pending+=("$target"); done < <(jq -c '.[]' <<< "$jobs")
done <<< "$runs"

while (( ${#pending[@]} )); do
    waiting=()
    for target in "${pending[@]}"; do
        repo=$(jq -r '.repo' <<< "$target")
        run_id=$(jq -r '.run_id' <<< "$target")
        job_id=$(jq -r '.id' <<< "$target")
        name=$(jq -r '.name' <<< "$target")

        # Starting a retry can replace the other jobs' API IDs. Resolve the latest
        # job before every request, using its name only when it is unambiguous.
        if ! run=$(gh run view "$run_id" --repo "$repo" --json jobs,status); then
            error_count=$((error_count + 1))
            continue
        fi
        if ! job=$(jq -c --argjson id "$job_id" --arg name "$name" '
            [.jobs[] | select(.databaseId == $id)] as $exact
            | (if ($exact | length) == 1 then $exact
               else [.jobs[] | select(.name == $name)] end)
            | if length > 1 then error("Cannot uniquely resolve job: " + $name)
              else .[0] end
        ' <<< "$run"); then
            error_count=$((error_count + 1))
            continue
        fi
        if [[ $job == null ]]; then
            # The next attempt may briefly list only the first retried job.
            case $(jq -r '.status' <<< "$run") in
                queued|in_progress|waiting|requested|pending)
                    printf 'Retry of %s is blocked while workflow run %s is active.\n' "$name" "$run_id"
                    ;;
                *)
                    printf 'Cannot find job %s in workflow run %s.\n' "$name" "$run_id" >&2
                    error_count=$((error_count + 1))
                    continue
                    ;;
            esac
        elif ! jq -e "$jq_helpers retryable" <<< "$job" >/dev/null; then
            printf 'Skipping %s: already %s.\n' "$name" \
                "$(jq -r 'if .status == "completed" then .conclusion else .status end' <<< "$job")"
            continue
        else
            job_id=$(jq -r '.databaseId' <<< "$job")
            printf 'Requesting retry of %s (job %s, run %s)...\n' "$name" "$job_id" "$run_id"

            # Use the same endpoint as `gh run rerun --job` and retain the rejection reason.
            if response=$(gh api --hostname "${repo%%/*}" --method POST \
                "repos/${repo#*/}/actions/jobs/$job_id/rerun" 2>&1); then
                rerun_count=$((rerun_count + 1))
                continue
            fi
            printf 'GitHub rejected retry of %s:\n%s\n' "$name" "$response" >&2
            if ! retry_blocked "$response"; then
                # An ambiguous network failure may hide a successful request.
                error_count=$((error_count + 1))
                continue
            fi
        fi
        if [[ $wait_for_completion == true ]]; then
            waiting+=("$target")
        else
            blocked_count=$((blocked_count + 1))
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
