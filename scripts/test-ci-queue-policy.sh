#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTROLLER="${ROOT_DIR}/scripts/ci/queue-controller.sh"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "${TEMP_DIR}/bin"
cat > "${TEMP_DIR}/bin/git" <<'MOCK_GIT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" != "ls-remote" ]]; then
  echo "Unexpected git command: $*" >&2
  exit 2
fi
printf '%s\t%s\n' "${MOCK_LATEST_SHA-}" "$3"
if [[ -n "${MOCK_REF_FILE:-}" ]]; then
  printf '%s' "$3" > "$MOCK_REF_FILE"
fi
MOCK_GIT
chmod +x "${TEMP_DIR}/bin/git"

PASS=0
FAIL=0

assert_output() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    printf '[PASS] %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '[FAIL] %s: expected "%s", got "%s"\n' "$name" "$expected" "$actual" >&2
    FAIL=$((FAIL + 1))
  fi
}

run_case() {
  local event="$1" sha="$2" latest="$3" ref="$4" event_path="$5" output_file="$6" summary_file="$7"
  : > "$output_file"
  : > "$summary_file"
  PATH="${TEMP_DIR}/bin:${PATH}" \
  MOCK_LATEST_SHA="$latest" \
  MOCK_REF_FILE="${TEMP_DIR}/requested-ref" \
  GITHUB_EVENT_NAME="$event" \
  GITHUB_SHA="$sha" \
  GITHUB_REPOSITORY="owner/repository" \
  GITHUB_SERVER_URL="https://github.com" \
  GITHUB_REF="$ref" \
  GITHUB_REF_NAME="${ref##*/}" \
  GITHUB_RUN_ID="12345" \
  GITHUB_EVENT_PATH="$event_path" \
  GITHUB_OUTPUT="$output_file" \
  GITHUB_STEP_SUMMARY="$summary_file" \
    bash "$CONTROLLER"
}

PUSH_EVENT="${TEMP_DIR}/push.json"
PR_EVENT="${TEMP_DIR}/pull_request.json"
printf '{}\n' > "$PUSH_EVENT"
printf '{"number":42}\n' > "$PR_EVENT"

run_case push abc123 abc123 refs/heads/main "$PUSH_EVENT" "${TEMP_DIR}/out" "${TEMP_DIR}/summary"
assert_output "latest push is accepted" "should_run=true" "$(grep '^should_run=' "${TEMP_DIR}/out")"
assert_output "push queue is keyed by ref" "queue_key=ref:refs/heads/main" "$(grep '^queue_key=' "${TEMP_DIR}/out")"
assert_output "accepted push is cacheable" "cacheable=true" "$(grep '^cacheable=' "${TEMP_DIR}/out")"

run_case push old111 new222 refs/heads/main "$PUSH_EVENT" "${TEMP_DIR}/out" "${TEMP_DIR}/summary"
assert_output "superseded push is skipped" "should_run=false" "$(grep '^should_run=' "${TEMP_DIR}/out")"
assert_output "stale push reports reason" "reason=superseded-before-start" "$(grep '^reason=' "${TEMP_DIR}/out")"

run_case pull_request merge42 merge42 refs/pull/42/merge "$PR_EVENT" "${TEMP_DIR}/out" "${TEMP_DIR}/summary"
assert_output "latest PR merge ref is accepted" "should_run=true" "$(grep '^should_run=' "${TEMP_DIR}/out")"
assert_output "PR queue is keyed by number" "queue_key=pr:42" "$(grep '^queue_key=' "${TEMP_DIR}/out")"
assert_output "PR freshness checks the merge ref" "refs/pull/42/merge" "$(cat "${TEMP_DIR}/requested-ref")"

run_case pull_request oldmerge newmerge refs/pull/42/merge "$PR_EVENT" "${TEMP_DIR}/out" "${TEMP_DIR}/summary"
assert_output "superseded PR merge ref is skipped" "should_run=false" "$(grep '^should_run=' "${TEMP_DIR}/out")"

run_case workflow_dispatch manualsha manualsha refs/heads/main "$PUSH_EVENT" "${TEMP_DIR}/out" "${TEMP_DIR}/summary"
assert_output "manual run shares the ref queue" "queue_key=ref:refs/heads/main" "$(grep '^queue_key=' "${TEMP_DIR}/out")"
assert_output "manual run is checked against latest ref" "should_run=true" "$(grep '^should_run=' "${TEMP_DIR}/out")"

if run_case push abc123 "" refs/heads/main "$PUSH_EVENT" "${TEMP_DIR}/out" "${TEMP_DIR}/summary"; then
  printf '[FAIL] missing remote ref must fail closed\n' >&2
  FAIL=$((FAIL + 1))
else
  printf '[PASS] missing remote ref fails closed\n'
  PASS=$((PASS + 1))
fi

printf '\nQueue policy tests: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
