#!/bin/bash
# ==============================================================================
# 可视化警告日志生成器（Bug Log Generator）
# 功能：
#   1. 从build.log中提取所有编译警告
#   2. 按警告类型分类（弃用API、未使用变量、类型转换等）
#   3. 按文件分布统计
#   4. 生成可视化的bug.log文件，包含彩色输出、统计信息、警告详情
#   5. 支持ANSI颜色码，在终端中查看时显示彩色
#   6. 生成警告严重程度评估和修复建议
# 使用方式：
#   bash scripts/generate-bug-log.sh [build.log路径] [输出文件路径]
#   默认：build.log -> bug.log
# ==============================================================================

set -euo pipefail

# 加载可视化日志工具
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/visual-logger.sh" ]; then
    source "${SCRIPT_DIR}/visual-logger.sh"
fi

# ==============================================================================
# ANSI颜色码定义
# ==============================================================================
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_MAGENTA='\033[0;35m'
COLOR_BOLD='\033[1m'
COLOR_DIM='\033[2m'
COLOR_RESET='\033[0m'
COLOR_BG_YELLOW='\033[43m'
COLOR_BG_RED='\033[41m'

# ==============================================================================
# 参数解析
# ==============================================================================
BUILD_LOG="${1:-build.log}"
OUTPUT_FILE="${2:-bug.log}"

# ==============================================================================
# 检查输入文件
# ==============================================================================
if [ ! -f "$BUILD_LOG" ]; then
    echo -e "${COLOR_RED}${COLOR_BOLD}❌ 错误：构建日志文件不存在: ${BUILD_LOG}${COLOR_RESET}" >&2
    exit 1
fi

# ==============================================================================
# 提取警告信息
# ==============================================================================
echo -e "${COLOR_CYAN}${COLOR_BOLD}正在生成可视化警告日志...${COLOR_RESET}"
echo -e "${COLOR_DIM}输入文件: ${BUILD_LOG}${COLOR_RESET}"
echo -e "${COLOR_DIM}输出文件: ${OUTPUT_FILE}${COLOR_RESET}"
echo ""

# 统计警告总数
TOTAL_WARNINGS=$(grep -c "warning:" "$BUILD_LOG" 2>/dev/null | tr -d '[:space:]' || echo "0")
[ -z "$TOTAL_WARNINGS" ] && TOTAL_WARNINGS=0

# 统计错误总数
TOTAL_ERRORS=$(grep -c "error:" "$BUILD_LOG" 2>/dev/null | tr -d '[:space:]' || echo "0")
[ -z "$TOTAL_ERRORS" ] && TOTAL_ERRORS=0

# ==============================================================================
# 按警告类型分类统计
# ==============================================================================

# 弃用API警告
DEPRECATED_COUNT=$(grep -ci "deprecated\|was deprecated" "$BUILD_LOG" 2>/dev/null | tr -d '[:space:]' || echo "0")
[ -z "$DEPRECATED_COUNT" ] && DEPRECATED_COUNT=0

# 未使用变量警告
UNUSED_COUNT=$(grep -ci "unused\|never used\|never read" "$BUILD_LOG" 2>/dev/null | tr -d '[:space:]' || echo "0")
[ -z "$UNUSED_COUNT" ] && UNUSED_COUNT=0

# 类型转换警告
CASTING_COUNT=$(grep -ci "conditional cast\|forced cast\|implicit conversion" "$BUILD_LOG" 2>/dev/null | tr -d '[:space:]' || echo "0")
[ -z "$CASTING_COUNT" ] && CASTING_COUNT=0

# 可空性警告
NULLABILITY_COUNT=$(grep -ci "nullability\|nullable\|nonnull" "$BUILD_LOG" 2>/dev/null | tr -d '[:space:]' || echo "0")
[ -z "$NULLABILITY_COUNT" ] && NULLABILITY_COUNT=0

# 其他警告
OTHER_COUNT=$((TOTAL_WARNINGS - DEPRECATED_COUNT - UNUSED_COUNT - CASTING_COUNT - NULLABILITY_COUNT))
[ "$OTHER_COUNT" -lt 0 ] && OTHER_COUNT=0

# ==============================================================================
# 按文件分布统计（前20个警告最多的文件）
# ==============================================================================
WARNING_FILES=$(grep "warning:" "$BUILD_LOG" 2>/dev/null | \
    sed 's/.*\///' | \
    cut -d: -f1 | \
    sort | uniq -c | sort -rn | head -20 || true)

# ==============================================================================
# 生成可视化bug.log文件
# ==============================================================================

cat > "$OUTPUT_FILE" << EOF
${COLOR_CYAN}${COLOR_BOLD}
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                    🐛 可视化警告日志报告 (Bug Log) 🐛                       ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════╝
${COLOR_RESET}

${COLOR_BOLD}📅 生成时间:${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S %Z')
${COLOR_BOLD}📂 源日志文件:${COLOR_RESET} ${BUILD_LOG}
${COLOR_BOLD}📊 构建状态:${COLOR_RESET} $( [ "$TOTAL_ERRORS" -gt 0 ] && echo "${COLOR_RED}${COLOR_BOLD}❌ 构建失败${COLOR_RESET}" || echo "${COLOR_GREEN}${COLOR_BOLD}✅ 构建成功${COLOR_RESET}" )

${COLOR_CYAN}${COLOR_BOLD}
┌──────────────────────────────────────────────────────────────────────────────┐
│                              📊 问题统计概览                                  │
└──────────────────────────────────────────────────────────────────────────────┘
${COLOR_RESET}

${COLOR_BOLD}  🔴 错误总数:${COLOR_RESET}  ${COLOR_RED}${COLOR_BOLD}${TOTAL_ERRORS}${COLOR_RESET} 个
${COLOR_BOLD}  🟡 警告总数:${COLOR_RESET}  ${COLOR_YELLOW}${COLOR_BOLD}${TOTAL_WARNINGS}${COLOR_RESET} 个

${COLOR_CYAN}${COLOR_BOLD}
┌──────────────────────────────────────────────────────────────────────────────┐
│                            📋 警告类型分布                                    │
└──────────────────────────────────────────────────────────────────────────────┘
${COLOR_RESET}

EOF

# 警告类型分布（带进度条）
print_warning_bar() {
    local name="$1"
    local count="$2"
    local total="$3"
    local color="$4"
    
    if [ "$total" -eq 0 ]; then
        local percentage=0
    else
        local percentage=$((count * 100 / total))
    fi
    
    # 生成进度条（20个字符宽度）
    local bar_width=20
    local filled=$((percentage * bar_width / 100))
    local empty=$((bar_width - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    
    printf "  ${color}${COLOR_BOLD}%-20s${COLOR_RESET} %5s个  [%s] %3d%%\n" "$name" "$count" "$bar" "$percentage"
}

print_warning_bar "弃用API警告" "$DEPRECATED_COUNT" "$TOTAL_WARNINGS" "$COLOR_YELLOW" >> "$OUTPUT_FILE"
print_warning_bar "未使用变量警告" "$UNUSED_COUNT" "$TOTAL_WARNINGS" "$COLOR_BLUE" >> "$OUTPUT_FILE"
print_warning_bar "类型转换警告" "$CASTING_COUNT" "$TOTAL_WARNINGS" "$COLOR_MAGENTA" >> "$OUTPUT_FILE"
print_warning_bar "可空性警告" "$NULLABILITY_COUNT" "$TOTAL_WARNINGS" "$COLOR_CYAN" >> "$OUTPUT_FILE"
print_warning_bar "其他警告" "$OTHER_COUNT" "$TOTAL_WARNINGS" "$COLOR_DIM" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << EOF

${COLOR_CYAN}${COLOR_BOLD}
┌──────────────────────────────────────────────────────────────────────────────┐
│                          📁 警告文件分布 (Top 20)                             │
└──────────────────────────────────────────────────────────────────────────────┘
${COLOR_RESET}

EOF

# 警告文件分布
if [ -n "$WARNING_FILES" ]; then
    echo "$WARNING_FILES" | while read -r count file; do
        if [ -n "$file" ]; then
            # 根据警告数量设置颜色
            if [ "$count" -ge 10 ]; then
                file_color="$COLOR_RED"
            elif [ "$count" -ge 5 ]; then
                file_color="$COLOR_YELLOW"
            else
                file_color="$COLOR_GREEN"
            fi
            printf "  ${file_color}%-40s${COLOR_RESET} %3s 个警告\n" "$file" "$count" >> "$OUTPUT_FILE"
        fi
    done
else
    echo -e "  ${COLOR_GREEN}✅ 无警告文件${COLOR_RESET}" >> "$OUTPUT_FILE"
fi

cat >> "$OUTPUT_FILE" << EOF

${COLOR_CYAN}${COLOR_BOLD}
┌──────────────────────────────────────────────────────────────────────────────┐
│                            📝 警告详情列表                                    │
└──────────────────────────────────────────────────────────────────────────────┘
${COLOR_RESET}

EOF

# 警告详情（按类型分组显示）
if [ "$TOTAL_WARNINGS" -gt 0 ]; then
    # 弃用API警告
    if [ "$DEPRECATED_COUNT" -gt 0 ]; then
        cat >> "$OUTPUT_FILE" << EOF
${COLOR_YELLOW}${COLOR_BOLD}  📌 弃用API警告 (${DEPRECATED_COUNT}个)${COLOR_RESET}
${COLOR_DIM}  ──────────────────────────────────────────────────────────────${COLOR_RESET}

EOF
        grep -i "deprecated\|was deprecated" "$BUILD_LOG" 2>/dev/null | head -20 | while read -r line; do
            echo -e "  ${COLOR_YELLOW}⚠️  ${line}${COLOR_RESET}" >> "$OUTPUT_FILE"
        done
        echo "" >> "$OUTPUT_FILE"
    fi
    
    # 未使用变量警告
    if [ "$UNUSED_COUNT" -gt 0 ]; then
        cat >> "$OUTPUT_FILE" << EOF
${COLOR_BLUE}${COLOR_BOLD}  📌 未使用变量警告 (${UNUSED_COUNT}个)${COLOR_RESET}
${COLOR_DIM}  ──────────────────────────────────────────────────────────────${COLOR_RESET}

EOF
        grep -i "unused\|never used\|never read" "$BUILD_LOG" 2>/dev/null | head -20 | while read -r line; do
            echo -e "  ${COLOR_BLUE}⚠️  ${line}${COLOR_RESET}" >> "$OUTPUT_FILE"
        done
        echo "" >> "$OUTPUT_FILE"
    fi
    
    # 类型转换警告
    if [ "$CASTING_COUNT" -gt 0 ]; then
        cat >> "$OUTPUT_FILE" << EOF
${COLOR_MAGENTA}${COLOR_BOLD}  📌 类型转换警告 (${CASTING_COUNT}个)${COLOR_RESET}
${COLOR_DIM}  ──────────────────────────────────────────────────────────────${COLOR_RESET}

EOF
        grep -i "conditional cast\|forced cast\|implicit conversion" "$BUILD_LOG" 2>/dev/null | head -20 | while read -r line; do
            echo -e "  ${COLOR_MAGENTA}⚠️  ${line}${COLOR_RESET}" >> "$OUTPUT_FILE"
        done
        echo "" >> "$OUTPUT_FILE"
    fi
    
    # 其他警告
    if [ "$OTHER_COUNT" -gt 0 ]; then
        cat >> "$OUTPUT_FILE" << EOF
${COLOR_DIM}${COLOR_BOLD}  📌 其他警告 (${OTHER_COUNT}个)${COLOR_RESET}
${COLOR_DIM}  ──────────────────────────────────────────────────────────────${COLOR_RESET}

EOF
        grep "warning:" "$BUILD_LOG" 2>/dev/null | \
            grep -vi "deprecated\|was deprecated\|unused\|never used\|never read\|conditional cast\|forced cast\|implicit conversion" | \
            head -30 | while read -r line; do
            echo -e "  ${COLOR_DIM}⚠️  ${line}${COLOR_RESET}" >> "$OUTPUT_FILE"
        done
        echo "" >> "$OUTPUT_FILE"
    fi
else
    cat >> "$OUTPUT_FILE" << EOF
${COLOR_GREEN}${COLOR_BOLD}  ✅ 恭喜！零警告，代码质量优秀！${COLOR_RESET}

EOF
fi

# ==============================================================================
# 错误详情（如果有错误）
# ==============================================================================
if [ "$TOTAL_ERRORS" -gt 0 ]; then
    cat >> "$OUTPUT_FILE" << EOF

${COLOR_RED}${COLOR_BOLD}
┌──────────────────────────────────────────────────────────────────────────────┐
│                          ❌ 错误详情列表                                      │
└──────────────────────────────────────────────────────────────────────────────┘
${COLOR_RESET}

EOF
    grep "error:" "$BUILD_LOG" 2>/dev/null | head -30 | while read -r line; do
        echo -e "  ${COLOR_RED}❌ ${line}${COLOR_RESET}" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"
fi

# ==============================================================================
# 代码质量评估和修复建议
# ==============================================================================
cat >> "$OUTPUT_FILE" << EOF

${COLOR_CYAN}${COLOR_BOLD}
┌──────────────────────────────────────────────────────────────────────────────┐
│                          🎯 代码质量评估与建议                                │
└──────────────────────────────────────────────────────────────────────────────┘
${COLOR_RESET}

EOF

# 质量评级
if [ "$TOTAL_ERRORS" -gt 0 ]; then
    QUALITY_GRADE="${COLOR_RED}${COLOR_BOLD}D级（较差，存在编译错误）${COLOR_RESET}"
elif [ "$TOTAL_WARNINGS" -eq 0 ]; then
    QUALITY_GRADE="${COLOR_GREEN}${COLOR_BOLD}S级（卓越，零警告零错误）${COLOR_RESET}"
elif [ "$TOTAL_WARNINGS" -lt 5 ]; then
    QUALITY_GRADE="${COLOR_GREEN}${COLOR_BOLD}A级（优秀）${COLOR_RESET}"
elif [ "$TOTAL_WARNINGS" -lt 20 ]; then
    QUALITY_GRADE="${COLOR_BLUE}${COLOR_BOLD}B级（良好）${COLOR_RESET}"
elif [ "$TOTAL_WARNINGS" -lt 50 ]; then
    QUALITY_GRADE="${COLOR_YELLOW}${COLOR_BOLD}C级（一般，建议清理警告）${COLOR_RESET}"
else
    QUALITY_GRADE="${COLOR_RED}${COLOR_BOLD}D级（较差，需要立即清理警告）${COLOR_RESET}"
fi

cat >> "$OUTPUT_FILE" << EOF
  ${COLOR_BOLD}📊 质量评级:${COLOR_RESET} ${QUALITY_GRADE}
  ${COLOR_BOLD}📈 警告密度:${COLOR_RESET} 每千行约 $([ "$TOTAL_WARNINGS" -gt 0 ] && echo "$((TOTAL_WARNINGS * 1000 / $(find GitHub -name '*.swift' -exec cat {} + 2>/dev/null | wc -l | tr -d ' ' || echo 1) ))" || echo "0") 个警告

${COLOR_BOLD}💡 修复建议:${COLOR_RESET}

EOF

# 具体修复建议
if [ "$DEPRECATED_COUNT" -gt 0 ]; then
    echo -e "  ${COLOR_YELLOW}1. 弃用API警告 (${DEPRECATED_COUNT}个):${COLOR_RESET}" >> "$OUTPUT_FILE"
    echo -e "     - 检查使用的API是否有替代方案" >> "$OUTPUT_FILE"
    echo -e "     - 逐步迁移到新API，避免使用已废弃接口" >> "$OUTPUT_FILE"
    echo -e "     - 参考Apple官方文档了解废弃原因和替代方案" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

if [ "$UNUSED_COUNT" -gt 0 ]; then
    echo -e "  ${COLOR_BLUE}2. 未使用变量警告 (${UNUSED_COUNT}个):${COLOR_RESET}" >> "$OUTPUT_FILE"
    echo -e "     - 删除未使用的变量和函数" >> "$OUTPUT_FILE"
    echo -e "     - 检查是否是调试代码遗留" >> "$OUTPUT_FILE"
    echo -e "     - 使用Xcode的静态分析工具辅助清理" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

if [ "$CASTING_COUNT" -gt 0 ]; then
    echo -e "  ${COLOR_MAGENTA}3. 类型转换警告 (${CASTING_COUNT}个):${COLOR_RESET}" >> "$OUTPUT_FILE"
    echo -e "     - 使用可选绑定 (if let / guard let) 替代强制转换" >> "$OUTPUT_FILE"
    echo -e "     - 检查类型转换是否安全" >> "$OUTPUT_FILE"
    echo -e "     - 考虑使用泛型和协议来减少类型转换" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

if [ "$TOTAL_WARNINGS" -gt 20 ]; then
    echo -e "  ${COLOR_RED}4. 警告数量过多:${COLOR_RESET}" >> "$OUTPUT_FILE"
    echo -e "     - 建议分批次清理警告，优先清理高风险警告" >> "$OUTPUT_FILE"
    echo -e "     - 可以在CI中设置警告阈值，超过阈值则构建失败" >> "$OUTPUT_FILE"
    echo -e "     - 建立代码审查机制，防止新警告引入" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

if [ "$TOTAL_WARNINGS" -eq 0 ] && [ "$TOTAL_ERRORS" -eq 0 ]; then
    echo -e "  ${COLOR_GREEN}✅ 代码质量优秀，继续保持！${COLOR_RESET}" >> "$OUTPUT_FILE"
    echo -e "     - 建议持续监控代码质量" >> "$OUTPUT_FILE"
    echo -e "     - 可以考虑启用更严格的编译警告选项" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

# ==============================================================================
# 页脚
# ==============================================================================
cat >> "$OUTPUT_FILE" << EOF

${COLOR_CYAN}${COLOR_BOLD}
╔══════════════════════════════════════════════════════════════════════════╗
║                     📋 报告结束 | 由CI自动生成                              ║
╚══════════════════════════════════════════════════════════════════════════╝
${COLOR_RESET}

${COLOR_DIM}提示：本文件包含ANSI颜色码，建议使用支持彩色的终端查看
      命令：cat bug.log
      去除颜色：sed 's/\x1b\[[0-9;]*m//g' bug.log > bug-plain.log${COLOR_RESET}
EOF

# ==============================================================================
# 输出完成信息
# ==============================================================================
echo ""
echo -e "${COLOR_GREEN}${COLOR_BOLD}✅ 可视化警告日志生成完成！${COLOR_RESET}"
echo -e "${COLOR_CYAN}📄 输出文件: ${OUTPUT_FILE}${COLOR_RESET}"
echo -e "${COLOR_YELLOW}⚠️  警告总数: ${TOTAL_WARNINGS} 个${COLOR_RESET}"
echo -e "${COLOR_RED}❌ 错误总数: ${TOTAL_ERRORS} 个${COLOR_RESET}"
echo ""
echo -e "${COLOR_DIM}查看命令: cat ${OUTPUT_FILE}${COLOR_RESET}"
echo -e "${COLOR_DIM}去除颜色: sed 's/\\x1b\\[[0-9;]*m//g' ${OUTPUT_FILE} > bug-plain.log${COLOR_RESET}"
