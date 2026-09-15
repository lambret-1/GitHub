#!/bin/bash
# ==============================================================================
# 可视化错误日志打印工具（Visual Logger）
# 功能：
#   1. 彩色日志输出（错误红色、警告黄色、成功绿色、信息蓝色）
#   2. 日志分组（GitHub Actions ::group:: / ::endgroup::）
#   3. 错误摘要面板（统计错误数量、类型、位置）
#   4. 构建状态可视化（步骤开始/结束、耗时统计）
#   5. 错误上下文显示（错误前后代码行）
#   6. 退出码解释（常见Xcode构建退出码含义）
# 使用方式：
#   source scripts/visual-logger.sh
#   log_error "错误信息"
#   log_warning "警告信息"
#   log_success "成功信息"
#   log_info "信息"
#   log_group_start "分组名称"
#   log_group_end
# ==============================================================================

set -euo pipefail

# ==============================================================================
# ANSI颜色码定义（GitHub Actions支持彩色输出）
# ==============================================================================
COLOR_RED='\033[0;31m'       # 红色：错误
COLOR_GREEN='\033[0;32m'     # 绿色：成功
COLOR_YELLOW='\033[1;33m'    # 黄色：警告
COLOR_BLUE='\033[0;34m'       # 蓝色：信息
COLOR_CYAN='\033[0;36m'       # 青色：标题
COLOR_MAGENTA='\033[0;35m'    # 品红：重要提示
COLOR_BOLD='\033[1m'           # 粗体
COLOR_DIM='\033[2m'            # 暗淡
COLOR_RESET='\033[0m'          # 重置颜色

# ==============================================================================
# 日志计数（用于错误摘要统计）
# ==============================================================================
LOG_ERROR_COUNT=0
LOG_WARNING_COUNT=0
LOG_SUCCESS_COUNT=0
LOG_INFO_COUNT=0

# ==============================================================================
# 日志函数：打印带颜色和图标的日志
# ==============================================================================

# 错误日志（红色 + ❌图标 + GitHub Actions ::error::）
log_error() {
    local message="$1"
    local file="${2:-}"
    local line="${3:-}"
    
    LOG_ERROR_COUNT=$((LOG_ERROR_COUNT + 1))
    
    # GitHub Actions 错误注解（支持文件和行号定位）
    if [ -n "$file" ] && [ -n "$line" ]; then
        echo "::error file=${file},line=${line}::❌ ${message}"
    else
        echo "::error::❌ ${message}"
    fi
    
    # 终端彩色输出
    echo -e "${COLOR_RED}${COLOR_BOLD}[错误] ❌ ${message}${COLOR_RESET}" >&2
}

# 警告日志（黄色 + ⚠️图标 + GitHub Actions ::warning::）
log_warning() {
    local message="$1"
    local file="${2:-}"
    local line="${3:-}"
    
    LOG_WARNING_COUNT=$((LOG_WARNING_COUNT + 1))
    
    # GitHub Actions 警告注解（支持文件和行号定位）
    if [ -n "$file" ] && [ -n "$line" ]; then
        echo "::warning file=${file},line=${line}::⚠️ ${message}"
    else
        echo "::warning::⚠️ ${message}"
    fi
    
    # 终端彩色输出
    echo -e "${COLOR_YELLOW}${COLOR_BOLD}[警告] ⚠️ ${message}${COLOR_RESET}" >&2
}

# 成功日志（绿色 + ✅图标 + GitHub Actions ::notice::）
log_success() {
    local message="$1"
    
    LOG_SUCCESS_COUNT=$((LOG_SUCCESS_COUNT + 1))
    
    # GitHub Actions 提示注解
    echo "::notice::✅ ${message}"
    
    # 终端彩色输出
    echo -e "${COLOR_GREEN}${COLOR_BOLD}[成功] ✅ ${message}${COLOR_RESET}"
}

# 信息日志（蓝色 + ℹ️图标）
log_info() {
    local message="$1"
    
    LOG_INFO_COUNT=$((LOG_INFO_COUNT + 1))
    
    # 终端彩色输出
    echo -e "${COLOR_BLUE}[信息] ℹ️ ${message}${COLOR_RESET}"
}

# 标题日志（青色 + 📌图标 + 粗体 + 分隔线）
log_title() {
    local message="$1"
    
    echo ""
    echo -e "${COLOR_CYAN}${COLOR_BOLD}════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_CYAN}${COLOR_BOLD}📌 ${message}${COLOR_RESET}"
    echo -e "${COLOR_CYAN}${COLOR_BOLD}════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
}

# 步骤开始日志（品红 + 🚀图标 + 时间戳）
log_step_start() {
    local step_name="$1"
    
    echo ""
    echo -e "${COLOR_MAGENTA}${COLOR_BOLD}🚀 开始执行: ${step_name}${COLOR_RESET}"
    echo -e "${COLOR_DIM}   开始时间: $(date '+%Y-%m-%d %H:%M:%S')${COLOR_RESET}"
    echo ""
}

# 步骤结束日志（品红 + 🏁图标 + 耗时统计）
log_step_end() {
    local step_name="$1"
    local start_time="${2:-}"
    
    echo ""
    if [ -n "$start_time" ]; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${COLOR_MAGENTA}${COLOR_BOLD}🏁 完成执行: ${step_name}${COLOR_RESET}"
        echo -e "${COLOR_DIM}   结束时间: $(date '+%Y-%m-%d %H:%M:%S') | 耗时: ${duration} 秒${COLOR_RESET}"
    else
        echo -e "${COLOR_MAGENTA}${COLOR_BOLD}🏁 完成执行: ${step_name}${COLOR_RESET}"
        echo -e "${COLOR_DIM}   结束时间: $(date '+%Y-%m-%d %H:%M:%S')${COLOR_RESET}"
    fi
    echo ""
}

# ==============================================================================
# 日志分组函数（GitHub Actions ::group:: / ::endgroup::）
# ==============================================================================

# 开始日志分组
log_group_start() {
    local group_name="$1"
    echo "::group::📂 ${group_name}"
    echo -e "${COLOR_CYAN}${COLOR_BOLD}📂 ${group_name}${COLOR_RESET}"
}

# 结束日志分组
log_group_end() {
    echo "::endgroup::"
    echo ""
}

# ==============================================================================
# 错误摘要面板（构建失败时显示）
# ==============================================================================

print_error_summary() {
    local build_log="${1:-build.log}"
    
    echo ""
    echo -e "${COLOR_RED}${COLOR_BOLD}╔══════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_RED}${COLOR_BOLD}║              🚨 构建失败错误摘要面板 🚨                     ║${COLOR_RESET}"
    echo -e "${COLOR_RED}${COLOR_BOLD}╚══════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    
    # 统计信息
    echo -e "${COLOR_BOLD}📊 统计信息:${COLOR_RESET}"
    echo -e "   错误总数: ${COLOR_RED}${LOG_ERROR_COUNT}${COLOR_RESET}"
    echo -e "   警告总数: ${COLOR_YELLOW}${LOG_WARNING_COUNT}${COLOR_RESET}"
    echo -e "   成功操作: ${COLOR_GREEN}${LOG_SUCCESS_COUNT}${COLOR_RESET}"
    echo ""
    
    # 如果有构建日志文件，分析错误类型
    if [ -f "$build_log" ]; then
        echo -e "${COLOR_BOLD}🔍 错误类型分析:${COLOR_RESET}"
        
        # 编译错误
        local compile_errors=$(grep -c "error:" "$build_log" 2>/dev/null || echo "0")
        echo -e "   编译错误: ${COLOR_RED}${compile_errors}${COLOR_RESET}"
        
        # 链接错误
        local link_errors=$(grep -ci "ld: error\|Undefined symbols\|linker error" "$build_log" 2>/dev/null || echo "0")
        echo -e "   链接错误: ${COLOR_RED}${link_errors}${COLOR_RESET}"
        
        # 签名错误
        local sign_errors=$(grep -ci "code sign\|CodeSign\|签名" "$build_log" 2>/dev/null || echo "0")
        echo -e "   签名错误: ${COLOR_RED}${sign_errors}${COLOR_RESET}"
        
        # 警告数量
        local warnings=$(grep -c "warning:" "$build_log" 2>/dev/null || echo "0")
        echo -e "   编译警告: ${COLOR_YELLOW}${warnings}${COLOR_RESET}"
        echo ""
        
        # 显示前10个错误详情
        echo -e "${COLOR_BOLD}📝 错误详情（前10条）:${COLOR_RESET}"
        grep "error:" "$build_log" 2>/dev/null | head -10 | while read -r line; do
            echo -e "   ${COLOR_RED}❌ ${line}${COLOR_RESET}"
        done
        echo ""
        
        # 显示错误上下文（第一个错误的前后5行）
        local first_error_line=$(grep -n "error:" "$build_log" 2>/dev/null | head -1 | cut -d: -f1)
        if [ -n "$first_error_line" ]; then
            echo -e "${COLOR_BOLD}🔎 第一个错误上下文（前后5行）:${COLOR_RESET}"
            local start_line=$((first_error_line - 5))
            local end_line=$((first_error_line + 5))
            [ "$start_line" -lt 1 ] && start_line=1
            sed -n "${start_line},${end_line}p" "$build_log" | while read -r line; do
                if echo "$line" | grep -q "error:"; then
                    echo -e "   ${COLOR_RED}${COLOR_BOLD}▶ ${line}${COLOR_RESET}"
                else
                    echo -e "   ${COLOR_DIM}  ${line}${COLOR_RESET}"
                fi
            done
            echo ""
        fi
    fi
    
    # 常见退出码解释
    echo -e "${COLOR_BOLD}💡 常见退出码解释:${COLOR_RESET}"
    echo -e "   ${COLOR_CYAN}0${COLOR_RESET}  - 成功"
    echo -e "   ${COLOR_RED}1${COLOR_RESET}  - 通用错误（编译失败、命令执行失败）"
    echo -e "   ${COLOR_RED}2${COLOR_RESET}  - 误用shell命令"
    echo -e "   ${COLOR_RED}126${COLOR_RESET} - 命令无法执行（权限问题）"
    echo -e "   ${COLOR_RED}127${COLOR_RESET} - 命令未找到"
    echo -e "   ${COLOR_RED}130${COLOR_RESET} - 脚本被中断（Ctrl+C）"
    echo -e "   ${COLOR_RED}137${COLOR_RESET} - 进程被强制杀死（OOM内存不足）"
    echo ""
    
    echo -e "${COLOR_RED}${COLOR_BOLD}════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
}

# ==============================================================================
# 构建成功摘要面板
# ==============================================================================

print_success_summary() {
    local ipa_path="${1:-}"
    local version="${2:-}"
    local build_duration="${3:-}"
    
    echo ""
    echo -e "${COLOR_GREEN}${COLOR_BOLD}╔══════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${COLOR_BOLD}║              ✅ 构建成功摘要面板 ✅                         ║${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${COLOR_BOLD}╚══════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    
    echo -e "${COLOR_BOLD}📦 构建产物:${COLOR_RESET}"
    if [ -n "$ipa_path" ] && [ -f "$ipa_path" ]; then
        local ipa_size=$(ls -lh "$ipa_path" | awk '{print $5}')
        local ipa_sha256=$(shasum -a 256 "$ipa_path" | awk '{print $1}')
        echo -e "   文件名: ${COLOR_CYAN}$(basename "$ipa_path")${COLOR_RESET}"
        echo -e "   文件大小: ${COLOR_CYAN}${ipa_size}${COLOR_RESET}"
        echo -e "   SHA256: ${COLOR_DIM}${ipa_sha256}${COLOR_RESET}"
    else
        echo -e "   ${COLOR_YELLOW}⚠️ 未指定IPA文件路径${COLOR_RESET}"
    fi
    echo ""
    
    echo -e "${COLOR_BOLD}📊 构建统计:${COLOR_RESET}"
    echo -e "   版本号: ${COLOR_CYAN}${version}${COLOR_RESET}"
    echo -e "   构建耗时: ${COLOR_CYAN}${build_duration} 秒${COLOR_RESET}"
    echo -e "   错误总数: ${COLOR_GREEN}${LOG_ERROR_COUNT}${COLOR_RESET}"
    echo -e "   警告总数: ${COLOR_YELLOW}${LOG_WARNING_COUNT}${COLOR_RESET}"
    echo -e "   成功操作: ${COLOR_GREEN}${LOG_SUCCESS_COUNT}${COLOR_RESET}"
    echo ""
    
    echo -e "${COLOR_GREEN}${COLOR_BOLD}════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
}

# ==============================================================================
# 环境信息打印（调试用）
# ==============================================================================

print_environment_info() {
    log_group_start "🌍 环境信息"
    
    echo -e "${COLOR_BOLD}操作系统:${COLOR_RESET} $(uname -a)"
    echo -e "${COLOR_BOLD}当前目录:${COLOR_RESET} $(pwd)"
    echo -e "${COLOR_BOLD}当前时间:${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S %Z')"
    
    if command -v xcodebuild &> /dev/null; then
        echo -e "${COLOR_BOLD}Xcode版本:${COLOR_RESET} $(xcodebuild -version | head -1)"
    fi
    
    if command -v swift &> /dev/null; then
        echo -e "${COLOR_BOLD}Swift版本:${COLOR_RESET} $(swift --version | head -1)"
    fi
    
    log_group_end
}

# ==============================================================================
# 导出函数（供其他脚本使用）
# ==============================================================================
export -f log_error log_warning log_success log_info log_title
export -f log_step_start log_step_end log_group_start log_group_end
export -f print_error_summary print_success_summary print_environment_info
