#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_EVENT_NAME:?GITHUB_EVENT_NAME is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_SERVER_URL:?GITHUB_SERVER_URL is required}"
: "${GITHUB_REF:?GITHUB_REF is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
: "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY is required}"

write_output() {
  local should_run="$1" reason="$2" queue_key="$3" latest_sha="$4" cache_key="$5" cacheable="$6"
  {
    printf 'should_run=%s\n' "$should_run"
    printf 'reason=%s\n' "$reason"
    printf 'queue_key=%s\n' "$queue_key"
    printf 'latest_sha=%s\n' "$latest_sha"
    printf 'cache_key=%s\n' "$cache_key"
    printf 'cacheable=%s\n' "$cacheable"
  } >> "$GITHUB_OUTPUT"
  {
    echo "### Latest queue decision"
    echo
    echo "- **Queue:** ${queue_key}"
    echo "- **Decision:** ${reason}"
    echo "- **Current SHA:** ${GITHUB_SHA}"
    echo "- **Latest SHA:** ${latest_sha:-unavailable}"
    echo "- **Schedule:** ${should_run}"
  } >> "$GITHUB_STEP_SUMMARY"
}

case "$GITHUB_EVENT_NAME" in
  pull_request)
    : "${GITHUB_EVENT_PATH:?GITHUB_EVENT_PATH is required for pull_request}"
    pr_number="$(jq -er '.number' "$GITHUB_EVENT_PATH")"
    queue_key="pr:${pr_number}"
    queue_ref="refs/pull/${pr_number}/merge"
    ;;
  push|workflow_dispatch)
    # Push and manual runs on the same ref intentionally share one queue.
    queue_key="ref:${GITHUB_REF}"
    queue_ref="$GITHUB_REF"
    ;;
  *)
    write_output true "unmanaged-event" "event:${GITHUB_EVENT_NAME}" "" "" false
    exit 0
    ;;
esac

remote="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}.git"
latest_sha="$(git ls-remote "$remote" "$queue_ref" | awk 'NR == 1 { print $1 }')"

if [[ -z "$latest_sha" ]]; then
  echo "::error::Unable to resolve latest ref ${queue_ref} for queue ${queue_key}; refusing to run an unverified commit."
  exit 1
fi

if [[ "$latest_sha" != "$GITHUB_SHA" ]]; then
  write_output false "superseded-before-start" "$queue_key" "$latest_sha" "" false
  exit 0
fi

queue_hash="$(printf '%s' "$queue_key" | shasum -a 256 | awk '{ print $1 }')"
cache_key="ci-success-${queue_hash}-${GITHUB_SHA}"
write_output true "latest-sha-accepted" "$queue_key" "$latest_sha" "$cache_key" true
