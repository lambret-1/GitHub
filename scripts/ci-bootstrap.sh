#!/usr/bin/env bash
set -euo pipefail

EXPECTED_XCODE_VERSION="15.4"

echo "== CI toolchain =="
sw_vers
xcodebuild -version
swift --version
xcodegen --version
swiftlint version

ACTUAL_XCODE_VERSION="$(xcodebuild -version | sed -n 's/^Xcode //p')"
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

# XcodeGen 2.46 currently emits objectVersion 77 even when project.yml
# requests 60. Xcode 15.4 cannot open format 77, so normalize the generated
# project format before asking Xcode to read it.
PROJECT_FILE="GitHub.xcodeproj/project.pbxproj"
if [[ ! -f "${PROJECT_FILE}" ]]; then
  echo "::error::Generated project.pbxproj is missing"
  exit 1
fi

GENERATED_OBJECT_VERSION="$(grep -o 'objectVersion = [0-9]*;' "${PROJECT_FILE}" | head -1 | grep -o '[0-9]*')"
if [[ "${GENERATED_OBJECT_VERSION}" != "60" ]]; then
  echo "::notice::Normalizing generated objectVersion ${GENERATED_OBJECT_VERSION} to 60 for Xcode 15.4"
  sed -i '' 's/objectVersion = [0-9]*;/objectVersion = 60;/g' "${PROJECT_FILE}"
fi

FINAL_OBJECT_VERSION="$(grep -o 'objectVersion = [0-9]*;' "${PROJECT_FILE}" | head -1 | grep -o '[0-9]*')"
if [[ "${FINAL_OBJECT_VERSION}" != "60" ]]; then
  echo "::error::Expected objectVersion 60, found ${FINAL_OBJECT_VERSION}"
  exit 1
fi

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
