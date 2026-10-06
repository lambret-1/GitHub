#!/usr/bin/env bash
# ==============================================================================
# 编译自检脚本（CI Self-Check）
# 用途：验证云电脑环境具备该 iOS 项目的完整编译自检能力
# 覆盖：工具依赖、GitHub 认证、仓库访问、CI 状态、产物可下载性
# ==============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_DIR}"

PASS=0
FAIL=0
WARN=0

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

check() {
  local name="$1" cmd="$2"
  if eval "${cmd}" >/dev/null 2>&1; then
    green "  [PASS] ${name}"
    PASS=$((PASS+1))
  else
    red "  [FAIL] ${name}"
    FAIL=$((FAIL+1))
  fi
}

bold "=========================================="
bold "  iOS 项目编译自检（CI Self-Check）"
bold "=========================================="
echo ""

bold "[1/6] 基础工具依赖检查"
check "git"       "command -v git"
check "curl"      "command -v curl"
check "wget"      "command -v wget"
check "jq"        "command -v jq"
check "python3"   "command -v python3"
check "gh (GitHub CLI)" "command -v gh"
echo ""

bold "[2/6] GitHub CLI 认证状态"
if gh auth status 2>&1 | grep -q "Logged in"; then
  AUTH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
  green "  [PASS] 已认证为: ${AUTH_USER}"
  PASS=$((PASS+1))
else
  red "  [FAIL] GitHub CLI 未认证"
  FAIL=$((FAIL+1))
fi
echo ""

bold "[3/6] 仓库访问权限"
check "仓库可读 (git ls-remote)" "git ls-remote --heads origin main"
REPO_VISIBILITY=$(gh api repos/lambret-1/GitHub --jq '.visibility' 2>/dev/null || echo "unknown")
green "  [INFO] 仓库可见性: ${REPO_VISIBILITY}"
echo ""

bold "[4/6] 项目结构完整性"
check "project.yml (XcodeGen 配置)" "test -f project.yml"
check "Info.plist (主应用)"          "test -f GitHub/Info.plist"
check "GitHubApp.swift (入口)"        "test -f GitHub/GitHubApp.swift"
check "VPN 扩展 Info.plist"           "test -f VPNPacketTunnel/Info.plist"
check "CI 工作流配置"                 "test -f .github/workflows/production-build.yml"
check "版本进位脚本"                  "test -x scripts/bump-version.sh"
check "版本单元测试脚本"              "test -x scripts/test-bump-version.sh"
CURRENT_VERSION=$(grep -A1 "CFBundleShortVersionString" GitHub/Info.plist | grep string | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
green "  [INFO] 当前版本号: v${CURRENT_VERSION}"
echo ""

bold "[5/6] CI/CD 流水线状态"
LATEST_RUN=$(gh run list --limit 1 --json databaseId,conclusion,status,name,createdAt 2>/dev/null || echo "{}")
if echo "${LATEST_RUN}" | jq -e 'length > 0' >/dev/null 2>&1; then
  RUN_ID=$(echo "${LATEST_RUN}" | jq -r '.[0].databaseId')
  RUN_CONCLUSION=$(echo "${LATEST_RUN}" | jq -r '.[0].conclusion')
  RUN_STATUS=$(echo "${LATEST_RUN}" | jq -r '.[0].status')
  RUN_TITLE=$(echo "${LATEST_RUN}" | jq -r '.[0].name')
  green "  [INFO] 最近构建 ID: ${RUN_ID}"
  green "  [INFO] 最近构建标题: ${RUN_TITLE}"
  green "  [INFO] 最近构建状态: ${RUN_STATUS} / 结论: ${RUN_CONCLUSION}"
  if [ "${RUN_CONCLUSION}" = "success" ]; then
    green "  [PASS] 最近一次 CI 构建成功"
    PASS=$((PASS+1))
  else
    yellow "  [WARN] 最近一次 CI 构建未成功（结论: ${RUN_CONCLUSION}）"
    WARN=$((WARN+1))
  fi
else
  red "  [FAIL] 无法获取 CI 运行记录"
  FAIL=$((FAIL+1))
fi
echo ""

bold "[6/6] 产物可下载性验证"
LATEST_RELEASE=$(gh api "repos/lambret-1/GitHub/releases?per_page=1" 2>/dev/null || echo "[]")
if echo "${LATEST_RELEASE}" | jq -e 'length > 0' >/dev/null 2>&1; then
  RELEASE_TAG=$(echo "${LATEST_RELEASE}" | jq -r '.[0].tag_name')
  green "  [INFO] 最新 Release: ${RELEASE_TAG}"
  IPA_URL=$(gh api "repos/lambret-1/GitHub/releases/tags/${RELEASE_TAG}" --jq '.assets[] | select(.name=="GitHub.ipa") | .browser_download_url' 2>/dev/null || echo "")
  if [ -n "${IPA_URL}" ]; then
    IPA_SIZE=$(gh api "repos/lambret-1/GitHub/releases/tags/${RELEASE_TAG}" --jq '.assets[] | select(.name=="GitHub.ipa") | .size' 2>/dev/null || echo "0")
    IPA_SIZE_MB=$(awk "BEGIN {printf \"%.2f\", ${IPA_SIZE}/1024/1024}")
    green "  [INFO] IPA 大小: ${IPA_SIZE_MB} MB"
    if curl -sI -o /dev/null -w "%{http_code}" "${IPA_URL}" | grep -q "200\|302"; then
      green "  [PASS] IPA 产物可下载 (HTTP 200/302)"
      PASS=$((PASS+1))
    else
      red "  [FAIL] IPA 产物不可下载"
      FAIL=$((FAIL+1))
    fi
  else
    yellow "  [WARN] 最新 Release 未找到 GitHub.ipa 产物"
    WARN=$((WARN+1))
  fi
else
  yellow "  [WARN] 暂无 Release 记录"
  WARN=$((WARN+1))
fi
echo ""

bold "=========================================="
bold "  自检结果汇总"
bold "=========================================="
green "  通过: ${PASS}"
if [ "${WARN}" -gt 0 ]; then yellow "  警告: ${WARN}"; fi
if [ "${FAIL}" -gt 0 ]; then red "  失败: ${FAIL}"; fi
echo ""

if [ "${FAIL}" -eq 0 ]; then
  green "✅ 编译自检全部通过，云电脑已具备完整 CI/CD 操作能力"
  exit 0
else
  red "❌ 编译自检存在失败项，请检查上述 FAIL 条目"
  exit 1
fi
