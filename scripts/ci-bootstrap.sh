#!/usr/bin/env bash
set -euo pipefail

EXPECTED_XCODE_VERSION="15.4"

echo "== CI toolchain =="
sw_vers
xcodebuild -version
swift --version
xcodegen --version
swiftlint version

ACTUAL_XCODE_VERSION="$(xcodebuild -version | awk '/Xcode / { print $2; exit }')"
if [[ "${ACTUAL_XCODE_VERSION}" != "${EXPECTED_XCODE_VERSION}" ]]; then
  echo "::error::Expected Xcode ${EXPECTED_XCODE_VERSION}, found ${ACTUAL_XCODE_VERSION}"
  exit 1
fi

echo "== Validate repository configuration =="
test -f project.yml
test -f .swiftlint.yml
test -f GitHub/Info.plist

echo "== Generate Xcode project =="
xcodegen generate
test -d GitHub.xcodeproj

echo "== Validate generated project and scheme =="
PROJECT_LIST="$(xcodebuild -list -project GitHub.xcodeproj)"
printf '%s\n' "${PROJECT_LIST}"
if ! grep -Eq '^[[:space:]]+GitHub[[:space:]]*$' <<< "${PROJECT_LIST}"; then
  echo "::error::GitHub scheme was not found in the generated project"
  exit 1
fi

echo "== Validate checkout SHA =="
CHECKED_OUT_SHA="$(git rev-parse HEAD)"
if [[ "${CHECKED_OUT_SHA}" != "${GITHUB_SHA}" ]]; then
  echo "::error::Checkout SHA mismatch: expected ${GITHUB_SHA}, got ${CHECKED_OUT_SHA}"
  exit 1
fi

echo "::notice::CI bootstrap validation passed for ${CHECKED_OUT_SHA}"
