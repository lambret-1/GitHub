#!/usr/bin/env bash
set -uo pipefail

CONFIG_PATH=".swiftlint.yml"
REPORT_PATH="${SWIFTLINT_REPORT_PATH:-swiftlint-report.json}"
EXPECTED_SWIFTLINT_VERSION="0.65.1"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "::error::SwiftLint is not installed"
  exit 1
fi

ACTUAL_VERSION="$(swiftlint version | tail -1 | tr -d '[:space:]')"
echo "SwiftLint version: ${ACTUAL_VERSION}"
if [[ "${ACTUAL_VERSION}" != "${EXPECTED_SWIFTLINT_VERSION}" ]]; then
  echo "::error::Expected SwiftLint ${EXPECTED_SWIFTLINT_VERSION}, found ${ACTUAL_VERSION}"
  exit 1
fi

if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "::error::Missing ${CONFIG_PATH}"
  exit 1
fi

echo "Running SwiftLint against repository Swift sources..."
set +e
swiftlint lint --config "${CONFIG_PATH}" --reporter json > "${REPORT_PATH}"
LINT_STATUS=$?
set -e

if [[ ! -s "${REPORT_PATH}" ]]; then
  echo "::error::SwiftLint did not produce a JSON report"
  exit 1
fi

python3 - "${REPORT_PATH}" "${LINT_STATUS}" <<'PY'
import json
import os
import sys

report_path, lint_status = sys.argv[1], int(sys.argv[2])
with open(report_path, encoding="utf-8") as report_file:
    violations = json.load(report_file)

errors = [item for item in violations if item.get("severity") == "error"]
warnings = [item for item in violations if item.get("severity") == "warning"]
files = len({item.get("file") for item in violations if item.get("file")})

print(f"SwiftLint summary: {len(errors)} errors, {len(warnings)} warnings across {files} files")
for item in errors:
    print(
        f"::error file={item.get('file')},line={item.get('line')},"
        f"col={item.get('character')}::{item.get('rule_id')}: {item.get('reason')}"
    )
for item in warnings[:30]:
    print(
        f"::warning file={item.get('file')},line={item.get('line')},"
        f"col={item.get('character')}::{item.get('rule_id')}: {item.get('reason')}"
    )
if len(warnings) > 30:
    print(f"... {len(warnings) - 30} additional warnings are available in the JSON artifact")

summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
if summary_path:
    with open(summary_path, "a", encoding="utf-8") as summary:
        summary.write("## SwiftLint baseline\n\n")
        summary.write("| Metric | Count |\n|---|---:|\n")
        summary.write(f"| Errors (blocking) | {len(errors)} |\n")
        summary.write(f"| Warnings (tracked for cleanup) | {len(warnings)} |\n")
        summary.write(f"| Files with violations | {files} |\n")
        summary.write("\nWarnings are reported as the initial cleanup baseline; errors block CI.\n")

if errors or lint_status != 0:
    print("::error::SwiftLint failed. Review the violations and JSON report.")
    sys.exit(1)
PY
