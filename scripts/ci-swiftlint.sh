#!/usr/bin/env bash
set -uo pipefail

CONFIG_PATH=".swiftlint.yml"
BASELINE_PATH=".swiftlint.baseline.json"
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

for required_file in "${CONFIG_PATH}" "${BASELINE_PATH}"; do
  if [[ ! -s "${required_file}" ]]; then
    echo "::error::Missing required SwiftLint file: ${required_file}"
    exit 1
  fi
done

echo "Running strict SwiftLint against the committed legacy baseline..."
set +e
swiftlint lint --config "${CONFIG_PATH}" --baseline "${BASELINE_PATH}" --strict --reporter json > "${REPORT_PATH}"
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

errors = [item for item in violations if item.get("severity", "").lower() == "error"]
warnings = [item for item in violations if item.get("severity", "").lower() == "warning"]
files = len({item.get("file") for item in violations if item.get("file")})

print(f"SwiftLint summary: {len(errors)} errors, {len(warnings)} warnings across {files} files")
for item in violations[:100]:
    level = item.get("severity", "warning").lower()
    command = "error" if level == "error" else "warning"
    print(
        f"::{command} file={item.get('file')},line={item.get('line')},"
        f"col={item.get('character')}::{item.get('rule_id')}: {item.get('reason')}"
    )
if len(violations) > 100:
    print(f"... {len(violations) - 100} additional violations are available in the JSON artifact")

summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
if summary_path:
    with open(summary_path, "a", encoding="utf-8") as summary:
        summary.write("## SwiftLint quality gate\n\n")
        summary.write("| Metric | Count |\n|---|---:|\n")
        summary.write(f"| New errors (blocking) | {len(errors)} |\n")
        summary.write(f"| New warnings | {len(warnings)} |\n")
        summary.write(f"| Files with new violations | {files} |\n")
        summary.write("\nExisting violations are suppressed only by the committed baseline; new violations are checked in strict mode.\n")

if violations or lint_status != 0:
    print("::error::SwiftLint failed. Fix new violations or explicitly review and update the baseline.")
    sys.exit(1)
PY
