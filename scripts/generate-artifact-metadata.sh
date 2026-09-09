#!/usr/bin/env bash
# ==============================================================================
# 脚本名称：generate-artifact-metadata.sh
# 脚本功能：生成IPA制品元数据JSON文件，用于离线校验、归档溯源
# 元数据内容：版本号、Git短Commit哈希、构建时间、文件SHA256、文件名、
#             文件大小、构建耗时、构建环境信息
# 退出码：0=成功 | 1=参数错误 | 2=文件操作失败 | 3=哈希计算失败
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 全局常量
# ------------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 颜色定义
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# ------------------------------------------------------------------------------
# 日志函数
# ------------------------------------------------------------------------------
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

# ------------------------------------------------------------------------------
# 入参解析
# ------------------------------------------------------------------------------
IPA_FILE_PATH=""
VERSION=""
GIT_COMMIT_SHORT=""
BUILD_START_TIME=""
OUTPUT_PATH=""

parse_arguments() {
    log_info "解析命令行参数..."

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ipa)
                IPA_FILE_PATH="$2"
                shift 2
                ;;
            --version)
                VERSION="$2"
                shift 2
                ;;
            --commit)
                GIT_COMMIT_SHORT="$2"
                shift 2
                ;;
            --build-start)
                BUILD_START_TIME="$2"
                shift 2
                ;;
            --output)
                OUTPUT_PATH="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                exit 1
                ;;
        esac
    done

    # 必选参数校验
    if [[ -z "${IPA_FILE_PATH}" ]]; then
        log_error "缺少必选参数 --ipa (IPA文件路径)"
        exit 1
    fi
    if [[ -z "${VERSION}" ]]; then
        log_error "缺少必选参数 --version (版本号)"
        exit 1
    fi
    if [[ -z "${GIT_COMMIT_SHORT}" ]]; then
        log_error "缺少必选参数 --commit (Git短哈希)"
        exit 1
    fi

    # 默认输出路径
    if [[ -z "${OUTPUT_PATH}" ]]; then
        OUTPUT_PATH="${PROJECT_ROOT}/artifact-metadata.json"
        log_info "未指定输出路径，使用默认: ${OUTPUT_PATH}"
    fi

    log_info "参数解析完成"
}

# ------------------------------------------------------------------------------
# 前置校验
# ------------------------------------------------------------------------------
check_prerequisites() {
    log_info "执行前置校验..."

    # IPA文件存在性校验
    if [[ ! -f "${IPA_FILE_PATH}" ]]; then
        log_error "IPA文件不存在: ${IPA_FILE_PATH}"
        exit 2
    fi

    # IPA文件可读性校验
    if [[ ! -r "${IPA_FILE_PATH}" ]]; then
        log_error "IPA文件无读取权限: ${IPA_FILE_PATH}"
        exit 2
    fi

    # 校验shasum工具可用性
    if ! command -v shasum &> /dev/null && ! command -v sha256sum &> /dev/null; then
        log_error "未找到SHA256哈希计算工具（shasum/sha256sum）"
        exit 3
    fi

    log_success "前置校验通过"
}

# ------------------------------------------------------------------------------
# 计算文件SHA256哈希
# ------------------------------------------------------------------------------
calculate_sha256() {
    local file_path="$1"
    local sha256=""

    log_info "计算文件SHA256哈希: ${file_path}"

    # 优先使用shasum（macOS自带），其次使用sha256sum（Linux）
    if command -v shasum &> /dev/null; then
        sha256=$(shasum -a 256 "${file_path}" | awk '{print $1}')
    elif command -v sha256sum &> /dev/null; then
        sha256=$(sha256sum "${file_path}" | awk '{print $1}')
    else
        log_error "SHA256哈希计算失败：无可用工具"
        exit 3
    fi

    # 哈希值非空校验
    if [[ -z "${sha256}" ]]; then
        log_error "SHA256哈希计算结果为空"
        exit 3
    fi

    # 哈希值格式校验（64位十六进制）
    if [[ ! "${sha256}" =~ ^[a-f0-9]{64}$ ]]; then
        log_error "SHA256哈希格式非法: ${sha256}"
        exit 3
    fi

    log_success "SHA256哈希计算完成: ${sha256:0:16}..."
    echo "${sha256}"
}

# ------------------------------------------------------------------------------
# 获取文件大小（字节）
# ------------------------------------------------------------------------------
get_file_size() {
    local file_path="$1"
    local file_size=""

    # 兼容macOS和Linux的stat命令
    if stat -f%z "${file_path}" &> /dev/null; then
        # macOS
        file_size=$(stat -f%z "${file_path}")
    else
        # Linux
        file_size=$(stat -c%s "${file_path}")
    fi

    if [[ -z "${file_size}" ]]; then
        log_error "获取文件大小失败"
        exit 2
    fi

    echo "${file_size}"
}

# ------------------------------------------------------------------------------
# 格式化文件大小（人类可读）
# ------------------------------------------------------------------------------
format_file_size() {
    local bytes="$1"

    if (( bytes < 1024 )); then
        echo "${bytes} B"
    elif (( bytes < 1024 * 1024 )); then
        echo "$(awk -v b="${bytes}" 'BEGIN {printf "%.2f", b/1024}') KB"
    elif (( bytes < 1024 * 1024 * 1024 )); then
        echo "$(awk -v b="${bytes}" 'BEGIN {printf "%.2f", b/(1024*1024)}') MB"
    else
        echo "$(awk -v b="${bytes}" 'BEGIN {printf "%.2f", b/(1024*1024*1024)}') GB"
    fi
}

# ------------------------------------------------------------------------------
# 计算构建耗时（秒）
# ------------------------------------------------------------------------------
calculate_build_duration() {
    if [[ -z "${BUILD_START_TIME}" ]]; then
        echo "0"
        return
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - BUILD_START_TIME))

    if (( duration < 0 )); then
        log_warn "构建耗时计算异常（负数），重置为0"
        duration=0
    fi

    echo "${duration}"
}

# ------------------------------------------------------------------------------
# 格式化耗时（人类可读）
# ------------------------------------------------------------------------------
format_duration() {
    local seconds="$1"
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))

    if (( minutes > 0 )); then
        echo "${minutes}分${remaining_seconds}秒"
    else
        echo "${remaining_seconds}秒"
    fi
}

# ------------------------------------------------------------------------------
# 收集构建环境信息
# ------------------------------------------------------------------------------
collect_build_env_info() {
    local env_info=""

    # 操作系统信息
    local os_name="unknown"
    if [[ "$(uname)" == "Darwin" ]]; then
        os_name="macOS $(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
    elif [[ "$(uname)" == "Linux" ]]; then
        os_name="Linux $(uname -r)"
    fi

    # Xcode版本（如果可用）
    local xcode_version="N/A"
    if command -v xcodebuild &> /dev/null; then
        xcode_version=$(xcodebuild -version 2>/dev/null | head -1 || echo "N/A")
    fi

    # 输出JSON格式的环境信息
    cat << EOF
  "build_environment": {
    "os": "${os_name}",
    "xcode_version": "${xcode_version}",
    "runner": "${RUNNER_NAME:-unknown}",
    "github_actions": "${GITHUB_ACTIONS:-false}"
  }
EOF
}

# ------------------------------------------------------------------------------
# 生成元数据JSON文件
# ------------------------------------------------------------------------------
generate_metadata_json() {
    local sha256="$1"
    local file_size="$2"
    local build_duration="$3"
    local file_name
    file_name=$(basename "${IPA_FILE_PATH}")
    local build_time
    build_time=$(date '+%Y-%m-%d %H:%M:%S %Z')
    local build_time_iso
    build_time_iso=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    log_info "生成制品元数据JSON文件..."

    # 构建完整JSON（使用here-doc确保格式正确）
    cat > "${OUTPUT_PATH}" << EOF
{
  "artifact_type": "ios-ipa",
  "version": "${VERSION}",
  "file_name": "${file_name}",
  "file_size_bytes": ${file_size},
  "file_size_human": "$(format_file_size ${file_size})",
  "sha256": "${sha256}",
  "git_commit_short": "${GIT_COMMIT_SHORT}",
  "build_time": "${build_time}",
  "build_time_iso": "${build_time_iso}",
  "build_duration_seconds": ${build_duration},
  "build_duration_human": "$(format_duration ${build_duration})",
$(collect_build_env_info)
}
EOF

    # 校验JSON文件生成成功
    if [[ ! -f "${OUTPUT_PATH}" ]]; then
        log_error "元数据JSON文件生成失败"
        exit 2
    fi

    if [[ ! -s "${OUTPUT_PATH}" ]]; then
        log_error "元数据JSON文件为空"
        exit 2
    fi

    log_success "元数据JSON文件生成完成: ${OUTPUT_PATH}"
}

# ------------------------------------------------------------------------------
# 校验JSON格式合法性
# ------------------------------------------------------------------------------
validate_json_format() {
    log_info "校验元数据JSON格式合法性..."

    # 使用python3校验JSON格式（如果可用）
    if command -v python3 &> /dev/null; then
        if ! python3 -m json.tool "${OUTPUT_PATH}" > /dev/null 2>&1; then
            log_error "JSON格式校验失败"
            echo "=========================================="
            echo "JSON文件内容（调试用）:"
            echo "=========================================="
            cat "${OUTPUT_PATH}"
            echo "=========================================="
            echo "Python3校验错误详情:"
            echo "=========================================="
            python3 -m json.tool "${OUTPUT_PATH}" 2>&1 || true
            echo "=========================================="
            exit 2
        fi
        log_success "JSON格式校验通过（python3）"
    else
        # 降级方案：简单检查括号匹配
        log_warn "python3不可用，执行降级JSON校验"
        local open_braces close_braces
        open_braces=$(grep -o '{' "${OUTPUT_PATH}" | wc -l)
        close_braces=$(grep -o '}' "${OUTPUT_PATH}" | wc -l)
        if [[ "${open_braces}" != "${close_braces}" ]]; then
            log_error "JSON括号不匹配: 开={${open_braces}, 闭=}${close_braces}"
            exit 2
        fi
        log_success "JSON降级校验通过"
    fi
}

# ------------------------------------------------------------------------------
# 输出元数据摘要
# ------------------------------------------------------------------------------
print_metadata_summary() {
    log_info "=========================================="
    log_info "制品元数据摘要"
    log_info "=========================================="
    log_info "  版本号:       ${VERSION}"
    log_info "  文件名:       $(basename "${IPA_FILE_PATH}")"
    log_info "  文件大小:     $(format_file_size "$(get_file_size "${IPA_FILE_PATH}")")"
    log_info "  SHA256:       $(calculate_sha256 "${IPA_FILE_PATH}" | cut -c1-32)..."
    log_info "  Git Commit:   ${GIT_COMMIT_SHORT}"
    log_info "  构建时间:     $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "  元数据文件:   ${OUTPUT_PATH}"
    log_info "=========================================="
}

# ------------------------------------------------------------------------------
# 主函数
# ------------------------------------------------------------------------------
main() {
    log_info "=========================================="
    log_info "制品元数据生成脚本启动"
    log_info "脚本版本: 1.0.0"
    log_info "=========================================="

    # Step 1: 解析参数
    parse_arguments "$@"

    # Step 2: 前置校验
    check_prerequisites

    # Step 3: 计算SHA256哈希
    local sha256
    sha256=$(calculate_sha256 "${IPA_FILE_PATH}")

    # Step 4: 获取文件大小
    local file_size
    file_size=$(get_file_size "${IPA_FILE_PATH}")

    # Step 5: 计算构建耗时
    local build_duration
    build_duration=$(calculate_build_duration)

    # Step 6: 生成元数据JSON
    generate_metadata_json "${sha256}" "${file_size}" "${build_duration}"

    # Step 7: 校验JSON格式
    validate_json_format

    # Step 8: 输出摘要
    print_metadata_summary

    log_success "制品元数据生成全流程完成"
    exit 0
}

# 脚本入口
main "$@"
