#!/usr/bin/env bash
# ==============================================================================
# 脚本名称：update-changelog.sh
# 脚本功能：在 README.md 顶部置顶插入结构化版本更新日志
# 日志内容：版本号、Git短Commit哈希、构建时间、IPA的SHA256摘要、功能描述
# 日志规则：新版本置顶插入，旧版本依次下沉，保持时间倒序
# 退出码：0=成功 | 1=参数错误 | 2=README操作失败 | 3=日志格式校验失败
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 全局常量
# ------------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly README_PATH="${PROJECT_ROOT}/README.md"
readonly CHANGELOG_MARKER="## 更新日志"
readonly CHANGELOG_START_MARKER="<!-- CHANGELOG_START -->"
readonly CHANGELOG_END_MARKER="<!-- CHANGELOG_END -->"

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
# 入参解析与校验
# ------------------------------------------------------------------------------
VERSION=""
GIT_COMMIT_SHORT=""
BUILD_TIME=""
IPA_SHA256=""
CHANGELOG_DESC=""

parse_arguments() {
    log_info "解析命令行参数..."

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                VERSION="$2"
                shift 2
                ;;
            --commit)
                GIT_COMMIT_SHORT="$2"
                shift 2
                ;;
            --build-time)
                BUILD_TIME="$2"
                shift 2
                ;;
            --sha256)
                IPA_SHA256="$2"
                shift 2
                ;;
            --desc)
                CHANGELOG_DESC="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                log_error "用法: ${SCRIPT_NAME} --version <版本号> --commit <短哈希> --build-time <构建时间> --sha256 <IPA哈希> --desc <更新描述>"
                exit 1
                ;;
        esac
    done

    # 必选参数非空校验
    if [[ -z "${VERSION}" ]]; then
        log_error "缺少必选参数 --version"
        exit 1
    fi
    if [[ -z "${GIT_COMMIT_SHORT}" ]]; then
        log_error "缺少必选参数 --commit"
        exit 1
    fi
    if [[ -z "${BUILD_TIME}" ]]; then
        log_error "缺少必选参数 --build-time"
        exit 1
    fi
    if [[ -z "${IPA_SHA256}" ]]; then
        log_error "缺少必选参数 --sha256"
        exit 1
    fi
    if [[ -z "${CHANGELOG_DESC}" ]]; then
        CHANGELOG_DESC="常规迭代更新"
        log_warn "未提供 --desc 参数，使用默认描述: ${CHANGELOG_DESC}"
    fi

    log_info "参数解析完成"
    log_info "  版本号: ${VERSION}"
    log_info "  Commit: ${GIT_COMMIT_SHORT}"
    log_info "  构建时间: ${BUILD_TIME}"
    log_info "  SHA256: ${IPA_SHA256:0:16}..."
    log_info "  更新描述: ${CHANGELOG_DESC}"
}

# ------------------------------------------------------------------------------
# 前置校验
# ------------------------------------------------------------------------------
check_prerequisites() {
    log_info "执行前置校验..."

    # README文件存在性校验
    if [[ ! -f "${README_PATH}" ]]; then
        log_error "README.md 文件不存在: ${README_PATH}"
        exit 2
    fi

    # README文件读写权限校验
    if [[ ! -r "${README_PATH}" ]]; then
        log_error "README.md 文件无读取权限"
        exit 2
    fi
    if [[ ! -w "${README_PATH}" ]]; then
        log_error "README.md 文件无写入权限"
        exit 2
    fi

    log_success "前置校验通过"
}

# ------------------------------------------------------------------------------
# 确保更新日志区域存在（首次运行时初始化）
# ------------------------------------------------------------------------------
ensure_changelog_section() {
    log_info "检查更新日志区域是否存在..."

    # 检查是否已有更新日志标记
    if grep -q "${CHANGELOG_START_MARKER}" "${README_PATH}"; then
        log_info "更新日志区域已存在"
        return 0
    fi

    log_info "首次运行，初始化更新日志区域..."

    # 检查是否有"## 更新日志"标题
    if grep -q "^## 更新日志" "${README_PATH}"; then
        # 在标题后插入标记
        sed -i "/^## 更新日志/a\\
${CHANGELOG_START_MARKER}\\
${CHANGELOG_END_MARKER}" "${README_PATH}"
    else
        # 在README末尾追加更新日志章节
        cat >> "${README_PATH}" << 'EOF'

## 更新日志

<!-- CHANGELOG_START -->
<!-- CHANGELOG_END -->
EOF
    fi

    log_success "更新日志区域初始化完成"
}

# ------------------------------------------------------------------------------
# 生成单条更新日志条目（Markdown格式）
# ------------------------------------------------------------------------------
generate_changelog_entry() {
    local entry=""

    # 构建结构化日志条目
    entry+="### v${VERSION} (${BUILD_TIME})\n\n"
    entry+="- **构建Commit**: \`${GIT_COMMIT_SHORT}\`\n"
    entry+="- **IPA SHA256**: \`${IPA_SHA256}\`\n"
    entry+="- **更新内容**: ${CHANGELOG_DESC}\n"

    echo -e "${entry}"
}

# ------------------------------------------------------------------------------
# 将新日志条目插入到日志区域顶部
# ------------------------------------------------------------------------------
insert_changelog_entry() {
    local entry="$1"
    local temp_file
    local entry_file

    log_info "插入新日志条目到README顶部..."

    # 创建临时文件
    temp_file=$(mktemp)
    entry_file=$(mktemp)

    # 将日志条目写入临时文件（避免awk多行变量传递问题）
    echo -e "${entry}" > "${entry_file}"

    # 读取README，在CHANGELOG_START标记后插入新条目
    # 使用awk读取条目文件，避免多行变量传递导致的"newline in string"错误
    awk -v start_marker="${CHANGELOG_START_MARKER}" -v entry_file="${entry_file}" '
    {
        print $0
        if ($0 == start_marker) {
            while ((getline line < entry_file) > 0) {
                print line
            }
            close(entry_file)
        }
    }
    ' "${README_PATH}" > "${temp_file}"

    # 校验临时文件非空
    if [[ ! -s "${temp_file}" ]]; then
        log_error "生成的临时文件为空，插入失败"
        rm -f "${temp_file}" "${entry_file}"
        exit 2
    fi

    # 原子替换（先备份再替换）
    local backup_path="${README_PATH}.changelog.$(date +%s).bak"
    cp "${README_PATH}" "${backup_path}"

    if ! mv "${temp_file}" "${README_PATH}"; then
        log_error "替换README文件失败，正在回滚..."
        cp "${backup_path}" "${README_PATH}"
        rm -f "${backup_path}" "${temp_file}" "${entry_file}"
        exit 2
    fi

    rm -f "${backup_path}" "${entry_file}"
    log_success "日志条目插入完成"
}

# ------------------------------------------------------------------------------
# 插入后校验（确保日志格式正确、无重复）
# ------------------------------------------------------------------------------
verify_changelog_insertion() {
    log_info "执行日志插入后校验..."

    # 校验新版本号是否出现在README中
    if ! grep -q "v${VERSION}" "${README_PATH}"; then
        log_error "校验失败：新版本号 v${VERSION} 未在README中找到"
        exit 3
    fi

    # 校验Commit哈希是否出现
    if ! grep -q "${GIT_COMMIT_SHORT}" "${README_PATH}"; then
        log_error "校验失败：Commit哈希 ${GIT_COMMIT_SHORT} 未在README中找到"
        exit 3
    fi

    # 校验SHA256是否出现
    if ! grep -q "${IPA_SHA256}" "${README_PATH}"; then
        log_error "校验失败：SHA256哈希未在README中找到"
        exit 3
    fi

    # 校验日志标记完整性
    if ! grep -q "${CHANGELOG_START_MARKER}" "${README_PATH}"; then
        log_error "校验失败：日志起始标记丢失"
        exit 3
    fi
    if ! grep -q "${CHANGELOG_END_MARKER}" "${README_PATH}"; then
        log_error "校验失败：日志结束标记丢失"
        exit 3
    fi

    log_success "日志插入校验全部通过"
}

# ------------------------------------------------------------------------------
# 主函数
# ------------------------------------------------------------------------------
main() {
    log_info "=========================================="
    log_info "README更新日志脚本启动"
    log_info "脚本版本: 1.0.0"
    log_info "README路径: ${README_PATH}"
    log_info "=========================================="

    # Step 1: 解析参数
    parse_arguments "$@"

    # Step 2: 前置校验
    check_prerequisites

    # Step 3: 确保日志区域存在
    ensure_changelog_section

    # Step 4: 生成日志条目
    local entry
    entry=$(generate_changelog_entry)
    log_info "生成的日志条目预览:"
    echo -e "${entry}" | sed 's/^/    /'

    # Step 5: 插入日志条目
    insert_changelog_entry "${entry}"

    # Step 6: 插入后校验
    verify_changelog_insertion

    log_success "README更新日志全流程完成"
    exit 0
}

# 脚本入口
main "$@"
