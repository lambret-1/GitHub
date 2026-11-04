#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_EVENT_NAME:?GITHUB_EVENT_NAME is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"

write_output() {
  local should_run="$1" reason="$2" queue_key="$3" latest_sha="$4"
  {
    printf 'should_run=%s\n' "$should_run"
    printf 'reason=%s\n' "$reason"
    printf 'queue_key=%s\n' "$queue_key"
    printf 'latest_sha=%s\n' "$latest_sha"
  } >> "$GITHUB_OUTPUT"
  {
    echo "### Latest queue decision"
    echo
    echo "- **Queue:** ${queue_key}"
    echo "- **Decision:** ${reason}"
    echo "- **Current SHA:** ${GITHUB_SHA}"
    echo "- **Latest SHA:** ${latest_sha:-not-applicable}"
    echo "- **Schedule:** ${should_run}"
  } >> "$GITHUB_STEP_SUMMARY"
}

# Manual jobs have a dedicated concurrency group and are deliberately retained.
if [[ "$GITHUB_EVENT_NAME" == "workflow_dispatch" ]]; then
  write_output true "manual-run-preserved" "manual-${GITHUB_RUN_ID}" ""
  exit 0
fi

if [[ "${SUCCESS_CACHE_HIT:-false}" == "true" ]]; then
  write_output false "duplicate-sha-already-passed" "${CI_QUEUE_KEY:-unknown}" "$GITHUB_SHA"
  exit 0
fi

if [[ "$GITHUB_EVENT_NAME" == "push" ]]; then
  branch="$GITHUB_REF_NAME"
  queue_key="push:$branch"
  remote="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}.git"
  latest_sha="$(git ls-remote "$remote" "refs/heads/$branch" | awk 'NR == 1 { print $1 }')"
elif [[ "$GITHUB_EVENT_NAME" == "pull_request" ]]; then
  pr_number="$(jq -er '.number' "$GITHUB_EVENT_PATH")"
  head_repo="$(jq -er '.pull_request.head.repo.clone_url' "$GITHUB_EVENT_PATH")"
  head_ref="$(jq -er '.pull_request.head.ref' "$GITHUB_EVENT_PATH")"
  queue_key="pr:$pr_number"
  latest_sha="$(git ls-remote "$head_repo" "refs/heads/$head_ref" | awk 'NR == 1 { print $1 }')"
else
  write_output true "unmanaged-event" "event:$GITHUB_EVENT_NAME" ""
  exit 0
fi

if [[ -z "$latest_sha" ]]; then
  echo "::error::Unable to resolve latest commit for queue $queue_key."
  exit 1
fi

if [[ "$latest_sha" != "$GITHUB_SHA" ]]; then
  write_output false "superseded-before-start" "$queue_key" "$latest_sha"
  exit 0
fi

write_output true "latest-sha-accepted" "$queue_key" "$latest_sha"
