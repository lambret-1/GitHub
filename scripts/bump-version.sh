#!/usr/bin/env bash
# ==============================================================================
# 脚本名称：bump-version.sh
# 脚本功能：三段式语义化版本号自动解析、合法性校验、进位计算、安全写入
# 版本规则：主版本.次版本.补丁号（补丁位 0~9，满9自动进位）
#   - 补丁号 < 9：补丁号 +1
#   - 补丁号 == 9：补丁置0，次版本 +1
#   - 次版本 == 9 且补丁 == 9：补丁置0、次版本置0、主版本 +1
# 示例：1.0.9 → 1.1.0 | 1.9.9 → 2.0.0 | 2.3.9 → 2.4.0
# 退出码：0=成功 | 1=参数错误 | 2=版本格式非法 | 3=Plist读写失败 | 4=进位计算异常
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 全局常量定义（消除硬编码魔术变量）
# ------------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly INFO_PLIST_PATH="${PROJECT_ROOT}/GitHub/Info.plist"
readonly VERSION_KEY="CFBundleShortVersionString"
readonly BUILD_KEY="CFBundleVersion"
readonly VERSION_PATTERN="^[0-9]+\.[0-9]+\.[0-9]+$"
readonly MAX_PATCH=9
readonly MAX_MINOR=9

# 颜色输出定义（仅用于终端可读性，不影响逻辑）
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# ------------------------------------------------------------------------------
# 日志输出函数（结构化日志，便于CI日志检索）
# ------------------------------------------------------------------------------
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

# ------------------------------------------------------------------------------
# 前置校验函数
# ------------------------------------------------------------------------------
check_prerequisites() {
    log_info "执行前置环境校验..."

    # 校验Plist文件存在性
    if [[ ! -f "${INFO_PLIST_PATH}" ]]; then
        log_error "Info.plist 文件不存在: ${INFO_PLIST_PATH}"
        exit 3
    fi

    # 校验Plist文件可读性
    if [[ ! -r "${INFO_PLIST_PATH}" ]]; then
        log_error "Info.plist 文件无读取权限: ${INFO_PLIST_PATH}"
        exit 3
    fi

    # 校验Plist文件可写性
    if [[ ! -w "${INFO_PLIST_PATH}" ]]; then
        log_error "Info.plist 文件无写入权限: ${INFO_PLIST_PATH}"
        exit 3
    fi

    # 校验PlistBuddy工具可用性（macOS系统自带）
    if ! command -v /usr/libexec/PlistBuddy &> /dev/null; then
        log_error "PlistBuddy 工具不可用，请确认运行环境为 macOS"
        exit 3
    fi

    log_success "前置环境校验通过"
}

# ------------------------------------------------------------------------------
# 版本格式合法性校验函数
# 入参：$1=待校验版本号字符串
# 返回：0=合法 | 2=非法
# ------------------------------------------------------------------------------
validate_version_format() {
    local version="$1"

    # 空值校验
    if [[ -z "${version}" ]]; then
        log_error "版本号为空，无法进行校验"
        return 2
    fi

    # 三段式纯数字格式正则校验（使用grep -E，避免bash =~对特殊字符的解析问题）
    if ! echo "${version}" | grep -qE "${VERSION_PATTERN}"; then
        log_error "版本号格式非法: '${version}'，要求三段式纯数字格式（如 1.0.0）"
        return 2
    fi

    # 逐段数值范围校验（防御性校验，正则已保证数字但确保无异常值）
    local major minor patch
    IFS='.' read -r major minor patch <<< "${version}"

    if (( major < 0 )); then
        log_error "主版本号不能为负数: ${major}"
        return 2
    fi
    if (( minor < 0 || minor > MAX_MINOR )); then
        log_error "次版本号超出范围 [0, ${MAX_MINOR}]: ${minor}"
        return 2
    fi
    if (( patch < 0 || patch > MAX_PATCH )); then
        log_error "补丁号超出范围 [0, ${MAX_PATCH}]: ${patch}"
        return 2
    fi

    return 0
}

# ------------------------------------------------------------------------------
# 版本进位计算核心函数（纯函数，无副作用，便于单元测试）
# 入参：$1=当前版本号（三段式）
# 输出：stdout 打印计算后的新版本号
# 返回：0=计算成功 | 4=计算异常
# ------------------------------------------------------------------------------
calculate_next_version() {
    local current_version="$1"

    # 入参格式校验
    if ! validate_version_format "${current_version}"; then
        log_error "进位计算入参版本格式校验失败"
        exit 4
    fi

    # 解析三段版本号
    local major minor patch
    IFS='.' read -r major minor patch <<< "${current_version}"

    log_info "当前版本解析结果: 主版本=${major}, 次版本=${minor}, 补丁号=${patch}"

    # 进位逻辑核心计算
    if (( patch < MAX_PATCH )); then
        # 场景1：补丁号未达上限，补丁号 +1
        patch=$((patch + 1))
        log_info "进位路径: 补丁号 +1（${patch}）"
    elif (( minor < MAX_MINOR )); then
        # 场景2：补丁号达上限，次版本未达上限 → 补丁置0，次版本+1
        patch=0
        minor=$((minor + 1))
        log_info "进位路径: 补丁置0，次版本 +1（${minor}）"
    else
        # 场景3：补丁和次版本均达上限 → 补丁置0、次版本置0、主版本+1
        patch=0
        minor=0
        major=$((major + 1))
        log_info "进位路径: 补丁置0、次版本置0，主版本 +1（${major}）"
    fi

    # 组装新版本号
    local new_version="${major}.${minor}.${patch}"

    # 计算结果二次校验（防御性编程，确保输出合法）
    if ! validate_version_format "${new_version}"; then
        log_error "进位计算结果格式校验失败: ${new_version}"
        exit 4
    fi

    log_info "进位计算完成: ${current_version} → ${new_version}"
    echo "${new_version}"
}

# ------------------------------------------------------------------------------
# 从Plist读取当前版本号
# 输出：stdout 打印当前版本号
# ------------------------------------------------------------------------------
read_current_version() {
    log_info "从 Info.plist 读取当前版本号..."

    local current_version
    if ! current_version=$(/usr/libexec/PlistBuddy -c "Print :${VERSION_KEY}" "${INFO_PLIST_PATH}" 2>/dev/null); then
        log_error "读取 ${VERSION_KEY} 失败，请确认Plist结构正确"
        exit 3
    fi

    # 读取结果非空校验
    if [[ -z "${current_version}" ]]; then
        log_error "${VERSION_KEY} 值为空"
        exit 3
    fi

    # 读取结果格式校验
    if ! validate_version_format "${current_version}"; then
        log_error "Plist中存储的版本号格式非法，终止流水线以防止版本污染"
        exit 2
    fi

    log_success "读取到当前版本号: ${current_version}"
    echo "${current_version}"
}

# ------------------------------------------------------------------------------
# 安全写入版本号到Plist（先备份、再写入、后校验，三段式原子操作）
# 入参：$1=新版本号
# ------------------------------------------------------------------------------
write_version_to_plist() {
    local new_version="$1"

    log_info "开始安全写入版本号到 Info.plist: ${new_version}"

    # 入参格式校验
    if ! validate_version_format "${new_version}"; then
        log_error "待写入版本号格式校验失败，拒绝写入"
        exit 2
    fi

    # Step 1: 创建Plist备份（故障回滚用）
    local backup_path="${INFO_PLIST_PATH}.bump.$(date +%s).bak"
    if ! cp "${INFO_PLIST_PATH}" "${backup_path}"; then
        log_error "Plist备份失败，终止写入操作"
        exit 3
    fi
    log_info "已创建Plist备份: ${backup_path}"

    # Step 2: 写入版本号
    if ! /usr/libexec/PlistBuddy -c "Set :${VERSION_KEY} ${new_version}" "${INFO_PLIST_PATH}" 2>/dev/null; then
        log_error "写入 ${VERSION_KEY} 失败，正在回滚..."
        cp "${backup_path}" "${INFO_PLIST_PATH}"
        rm -f "${backup_path}"
        log_error "已回滚Plist到原状态"
        exit 3
    fi

    # Step 3: 读取校验（写入后立即回读确认）
    local verified_version
    verified_version=$(/usr/libexec/PlistBuddy -c "Print :${VERSION_KEY}" "${INFO_PLIST_PATH}" 2>/dev/null)
    if [[ "${verified_version}" != "${new_version}" ]]; then
        log_error "写入后校验失败，期望值=${new_version}，实际值=${verified_version}，正在回滚..."
        cp "${backup_path}" "${INFO_PLIST_PATH}"
        rm -f "${backup_path}"
        log_error "已回滚Plist到原状态"
        exit 3
    fi

    # Step 4: 同步更新构建号（CFBundleVersion）为时间戳，确保每次构建唯一
    local build_number
    build_number=$(date +%s)
    /usr/libexec/PlistBuddy -c "Set :${BUILD_KEY} ${build_number}" "${INFO_PLIST_PATH}" 2>/dev/null || true
    log_info "同步更新构建号(CFBundleVersion): ${build_number}"

    # Step 5: 清理备份文件（写入成功后删除备份）
    rm -f "${backup_path}"

    log_success "版本号安全写入并校验通过: ${new_version}"
}

# ------------------------------------------------------------------------------
# 输出结构化结果（供CI流水线后续步骤解析使用）
# 入参：$1=旧版本 | $2=新版本
# ------------------------------------------------------------------------------
emit_structured_output() {
    local old_version="$1"
    local new_version="$2"

    log_info "输出结构化版本变更信息..."

    # 输出到stdout，供CI环境变量捕获
    echo "VERSION_OLD=${old_version}"
    echo "VERSION_NEW=${new_version}"
    echo "VERSION_BUMPED=true"

    # 同时写入到GITHUB_OUTPUT（如果在GitHub Actions环境中）
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        {
            echo "version_old=${old_version}"
            echo "version_new=${new_version}"
            echo "version_bumped=true"
        } >> "${GITHUB_OUTPUT}"
        log_info "已写入版本信息到 GITHUB_OUTPUT"
    fi

    log_success "版本递增全流程完成: ${old_version} → ${new_version}"
}

# ------------------------------------------------------------------------------
# 主函数（流程编排）
# ------------------------------------------------------------------------------
main() {
    log_info "=========================================="
    log_info "版本号自动递增脚本启动"
    log_info "脚本版本: 1.0.0"
    log_info "项目根目录: ${PROJECT_ROOT}"
    log_info "Plist路径: ${INFO_PLIST_PATH}"
    log_info "=========================================="

    # Step 1: 前置环境校验
    check_prerequisites

    # Step 2: 读取当前版本号
    local current_version
    current_version=$(read_current_version)

    # Step 3: 执行进位计算
    local new_version
    new_version=$(calculate_next_version "${current_version}")

    # Step 4: 安全写入Plist
    write_version_to_plist "${new_version}"

    # Step 5: 输出结构化结果
    emit_structured_output "${current_version}" "${new_version}"

    exit 0
}

# ------------------------------------------------------------------------------
# 脚本入口（支持被source引入进行单元测试，直接执行则运行main）
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
