#!/usr/bin/env bash
# ==============================================================================
# 脚本名称：test-bump-version.sh
# 脚本功能：版本进位计算逻辑单元测试，覆盖全量边界案例
# 测试范围：
#   1. 版本格式合法性校验（正向+反向用例）
#   2. 补丁号进位（0~8 → +1）
#   3. 补丁号满9进位到次版本（x.y.9 → x.(y+1).0）
#   4. 次版本满9进位到主版本（x.9.9 → (x+1).0.0）
#   5. 多级连续进位边界
#   6. 非法格式拒绝处理
# 退出码：0=全部测试通过 | 1=存在测试失败
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 全局常量（使用TEST_前缀，避免与被测脚本变量冲突）
# ------------------------------------------------------------------------------
readonly TEST_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_BUMP_SCRIPT="${TEST_SCRIPT_DIR}/bump-version.sh"

# 测试统计计数器
TEST_TOTAL=0
TEST_PASSED=0
TEST_FAILED=0
FAILED_CASES=()

# 颜色定义（使用TEST_前缀）
readonly TEST_COLOR_RED='\033[0;31m'
readonly TEST_COLOR_GREEN='\033[0;32m'
readonly TEST_COLOR_YELLOW='\033[1;33m'
readonly TEST_COLOR_BLUE='\033[0;34m'
readonly TEST_COLOR_CYAN='\033[0;36m'
readonly TEST_COLOR_RESET='\033[0m'

# ------------------------------------------------------------------------------
# 引入被测脚本（source方式，可直接调用内部函数）
# 注意：被测脚本的全局变量（SCRIPT_NAME、颜色等）会被引入，
#       因此测试脚本使用TEST_前缀避免命名冲突
# ------------------------------------------------------------------------------
# 临时禁用set -e，因为source脚本时可能有exit调用
set +e
source "${TEST_BUMP_SCRIPT}"
set -e

# ------------------------------------------------------------------------------
# 测试辅助函数
# ------------------------------------------------------------------------------
print_test_header() {
    echo ""
    echo -e "${TEST_COLOR_CYAN}════════════════════════════════════════════════════════════${TEST_COLOR_RESET}"
    echo -e "${TEST_COLOR_CYAN}  测试套件: $1${TEST_COLOR_RESET}"
    echo -e "${TEST_COLOR_CYAN}════════════════════════════════════════════════════════════${TEST_COLOR_RESET}"
}

assert_equals() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    TEST_TOTAL=$((TEST_TOTAL + 1))

    if [[ "${expected}" == "${actual}" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        echo -e "  ${TEST_COLOR_GREEN}✓ PASS${TEST_COLOR_RESET} | ${test_name}"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        FAILED_CASES+=("${test_name}")
        echo -e "  ${TEST_COLOR_RED}✗ FAIL${TEST_COLOR_RESET} | ${test_name}"
        echo -e "         期望值: ${TEST_COLOR_YELLOW}${expected}${TEST_COLOR_RESET}"
        echo -e "         实际值: ${TEST_COLOR_RED}${actual}${TEST_COLOR_RESET}"
    fi
}

assert_return_code() {
    local test_name="$1"
    local expected_code="$2"
    local actual_code="$3"

    TEST_TOTAL=$((TEST_TOTAL + 1))

    if [[ "${expected_code}" == "${actual_code}" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        echo -e "  ${TEST_COLOR_GREEN}✓ PASS${TEST_COLOR_RESET} | ${test_name}"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        FAILED_CASES+=("${test_name}")
        echo -e "  ${TEST_COLOR_RED}✗ FAIL${TEST_COLOR_RESET} | ${test_name}"
        echo -e "         期望退出码: ${TEST_COLOR_YELLOW}${expected_code}${TEST_COLOR_RESET}"
        echo -e "         实际退出码: ${TEST_COLOR_RED}${actual_code}${TEST_COLOR_RESET}"
    fi
}

# ------------------------------------------------------------------------------
# 测试套件1：版本格式合法性校验
# ------------------------------------------------------------------------------
test_suite_format_validation() {
    print_test_header "版本格式合法性校验"

    # 正向用例：合法格式
    local valid_versions=(
        "0.0.0"
        "1.0.0"
        "1.2.3"
        "9.9.9"
        "10.0.0"
        "99.9.9"
        "100.5.3"
    )

    for version in "${valid_versions[@]}"; do
        local exit_code=0
        (validate_version_format "${version}" >/dev/null 2>&1) || exit_code=$?
        assert_return_code "合法版本格式校验通过: ${version}" "0" "${exit_code}"
    done

    # 反向用例：非法格式
    local invalid_versions=(
        ""
        "1"
        "1.0"
        "1.0.0.0"
        "1.0.0.0.0"
        "a.b.c"
        "1.a.0"
        "1.0.a"
        "v1.0.0"
        "1.0.0-beta"
        "1.0.0.alpha"
        " 1.0.0"
        "1.0.0 "
        "1..0"
        ".0.0"
        "1.0."
        "-1.0.0"
        "1.-1.0"
        "1.0.-1"
    )

    for version in "${invalid_versions[@]}"; do
        local exit_code=0
        (validate_version_format "${version}" >/dev/null 2>&1) || exit_code=$?
        assert_return_code "非法版本格式被拒绝: '${version}'" "2" "${exit_code}"
    done
}

# ------------------------------------------------------------------------------
# 测试套件2：补丁号正常进位（0~8 → +1）
# ------------------------------------------------------------------------------
test_suite_patch_increment() {
    print_test_header "补丁号正常进位（0~8 → +1）"

    local test_cases=(
        "0.0.0:0.0.1"
        "1.0.0:1.0.1"
        "1.0.1:1.0.2"
        "1.0.2:1.0.3"
        "1.0.3:1.0.4"
        "1.0.4:1.0.5"
        "1.0.5:1.0.6"
        "1.0.6:1.0.7"
        "1.0.7:1.0.8"
        "1.0.8:1.0.9"
        "2.5.3:2.5.4"
        "10.5.5:10.5.6"
    )

    for case in "${test_cases[@]}"; do
        local input="${case%%:*}"
        local expected="${case##*:}"
        local actual
        actual=$(calculate_next_version "${input}" 2>/dev/null)
        assert_equals "补丁进位: ${input} → ${expected}" "${expected}" "${actual}"
    done
}

# ------------------------------------------------------------------------------
# 测试套件3：补丁号满9进位到次版本（x.y.9 → x.(y+1).0）
# ------------------------------------------------------------------------------
test_suite_patch_rollover_to_minor() {
    print_test_header "补丁号满9进位到次版本（x.y.9 → x.(y+1).0）"

    local test_cases=(
        "0.0.9:0.1.0"
        "1.0.9:1.1.0"
        "1.1.9:1.2.0"
        "1.2.9:1.3.0"
        "1.3.9:1.4.0"
        "1.4.9:1.5.0"
        "1.5.9:1.6.0"
        "1.6.9:1.7.0"
        "1.7.9:1.8.0"
        "1.8.9:1.9.0"
        "2.3.9:2.4.0"
        "5.7.9:5.8.0"
        "10.5.9:10.6.0"
        "99.0.9:99.1.0"
    )

    for case in "${test_cases[@]}"; do
        local input="${case%%:*}"
        local expected="${case##*:}"
        local actual
        actual=$(calculate_next_version "${input}" 2>/dev/null)
        assert_equals "补丁满9进位: ${input} → ${expected}" "${expected}" "${actual}"
    done
}

# ------------------------------------------------------------------------------
# 测试套件4：次版本满9进位到主版本（x.9.9 → (x+1).0.0）
# ------------------------------------------------------------------------------
test_suite_minor_rollover_to_major() {
    print_test_header "次版本满9进位到主版本（x.9.9 → (x+1).0.0）"

    local test_cases=(
        "0.9.9:1.0.0"
        "1.9.9:2.0.0"
        "2.9.9:3.0.0"
        "3.9.9:4.0.0"
        "4.9.9:5.0.0"
        "5.9.9:6.0.0"
        "9.9.9:10.0.0"
        "10.9.9:11.0.0"
        "99.9.9:100.0.0"
    )

    for case in "${test_cases[@]}"; do
        local input="${case%%:*}"
        local expected="${case##*:}"
        local actual
        actual=$(calculate_next_version "${input}" 2>/dev/null)
        assert_equals "次版本满9进位: ${input} → ${expected}" "${expected}" "${actual}"
    done
}

# ------------------------------------------------------------------------------
# 测试套件5：连续进位边界综合测试
# ------------------------------------------------------------------------------
test_suite_combined_rollover() {
    print_test_header "连续进位边界综合测试"

    # 模拟连续递增10次，验证版本序列连续性
    local start_version="1.0.0"
    local expected_sequence=(
        "1.0.1"
        "1.0.2"
        "1.0.3"
        "1.0.4"
        "1.0.5"
        "1.0.6"
        "1.0.7"
        "1.0.8"
        "1.0.9"
        "1.1.0"
    )

    local current="${start_version}"
    local idx=0
    for expected in "${expected_sequence[@]}"; do
        local actual
        actual=$(calculate_next_version "${current}" 2>/dev/null)
        assert_equals "连续递增第$((idx+1))次: ${current} → ${expected}" "${expected}" "${actual}"
        current="${actual}"
        idx=$((idx + 1))
    done

    # 模拟从1.9.0连续递增10次，验证跨主版本进位
    local start2="1.9.0"
    local expected2=(
        "1.9.1"
        "1.9.2"
        "1.9.3"
        "1.9.4"
        "1.9.5"
        "1.9.6"
        "1.9.7"
        "1.9.8"
        "1.9.9"
        "2.0.0"
    )

    local current2="${start2}"
    local idx2=0
    for expected in "${expected2[@]}"; do
        local actual
        actual=$(calculate_next_version "${current2}" 2>/dev/null)
        assert_equals "跨主版本递增第$((idx2+1))次: ${current2} → ${expected}" "${expected}" "${actual}"
        current2="${actual}"
        idx2=$((idx2 + 1))
    done
}

# ------------------------------------------------------------------------------
# 测试套件6：非法输入拒绝处理
# ------------------------------------------------------------------------------
test_suite_invalid_input_rejection() {
    print_test_header "非法输入拒绝处理"

    local invalid_inputs=(
        ""
        "invalid"
        "1.0"
        "v1.0.0"
        "1.0.0.0"
        "a.b.c"
    )

    for input in "${invalid_inputs[@]}"; do
        # 非法输入应该导致函数以非0退出码退出（在子shell中执行，避免exit影响主脚本）
        local exit_code=0
        (calculate_next_version "${input}" >/dev/null 2>&1) || exit_code=$?
        assert_return_code "非法输入被拒绝: '${input}'" "4" "${exit_code}"
    done
}

# ------------------------------------------------------------------------------
# 测试结果汇总输出
# ------------------------------------------------------------------------------
print_test_summary() {
    echo ""
    echo -e "${TEST_COLOR_CYAN}════════════════════════════════════════════════════════════${TEST_COLOR_RESET}"
    echo -e "${TEST_COLOR_CYAN}  单元测试结果汇总${TEST_COLOR_RESET}"
    echo -e "${TEST_COLOR_CYAN}════════════════════════════════════════════════════════════${TEST_COLOR_RESET}"
    echo -e "  测试总数:   ${TEST_TOTAL}"
    echo -e "  通过数:     ${TEST_COLOR_GREEN}${TEST_PASSED}${TEST_COLOR_RESET}"
    echo -e "  失败数:     ${TEST_COLOR_RED}${TEST_FAILED}${TEST_COLOR_RESET}"
    echo -e "  通过率:     $(( TEST_PASSED * 100 / TEST_TOTAL ))%"
    echo ""

    if [[ ${TEST_FAILED} -gt 0 ]]; then
        echo -e "${TEST_COLOR_RED}失败用例列表:${TEST_COLOR_RESET}"
        for failed in "${FAILED_CASES[@]}"; do
            echo -e "  - ${TEST_COLOR_RED}${failed}${TEST_COLOR_RESET}"
        done
        echo ""
        echo -e "${TEST_COLOR_RED}❌ 单元测试未通过，请修复后再执行构建流水线！${TEST_COLOR_RESET}"
        return 1
    else
        echo -e "${TEST_COLOR_GREEN}✅ 全部单元测试通过，版本进位逻辑验证合格！${TEST_COLOR_RESET}"
        return 0
    fi
}

# ------------------------------------------------------------------------------
# 主函数：按顺序执行所有测试套件
# ------------------------------------------------------------------------------
main() {
    echo -e "${TEST_COLOR_BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║       版本进位计算逻辑 - 单元测试套件 v1.0.0            ║"
    echo "║       被测脚本: bump-version.sh                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${TEST_COLOR_RESET}"

    # 校验被测脚本存在性
    if [[ ! -f "${TEST_BUMP_SCRIPT}" ]]; then
        echo -e "${TEST_COLOR_RED}[FATAL] 被测脚本不存在: ${TEST_BUMP_SCRIPT}${TEST_COLOR_RESET}"
        exit 1
    fi

    # 执行各测试套件（测试期间禁用set -e，因为测试本身需要验证非0退出码场景）
    set +e
    test_suite_format_validation
    test_suite_patch_increment
    test_suite_patch_rollover_to_minor
    test_suite_minor_rollover_to_major
    test_suite_combined_rollover
    test_suite_invalid_input_rejection
    set -e

    # 输出汇总并返回结果
    print_test_summary
    exit $?
}

# 执行主函数
main "$@"
