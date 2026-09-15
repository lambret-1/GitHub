#!/bin/bash
# ==============================================================================
# 可视化警告日志生成器（Bug Log Generator）- Markdown版本
# 功能：
#   1. 从build.log中提取所有编译警告
#   2. 按警告类型分类（弃用API、未使用变量、类型转换等）
#   3. 按文件分布统计
#   4. 生成Markdown格式的bug.md文件，可直接在GitHub网页查看
#   5. 包含统计信息、警告详情、代码质量评估和修复建议
# 使用方式：
#   bash scripts/generate-bug-log.sh [build.log路径] [输出文件路径]
#   默认：build.log -> bug.md
# ==============================================================================

set -euo pipefail

# ==============================================================================
# 参数解析
# ==============================================================================
BUILD_LOG="${1:-build.log}"
OUTPUT_FILE="${2:-bug.md}"

# ==============================================================================
# 检查输入文件
# ==============================================================================
if [ ! -f "$BUILD_LOG" ]; then
    echo "❌ 错误：构建日志文件不存在: ${BUILD_LOG}" >&2
    exit 1
fi

echo "📝 正在生成可视化警告日志（Markdown格式）..."
echo "   输入文件: ${BUILD_LOG}"
echo "   输出文件: ${OUTPUT_FILE}"
echo ""

# ==============================================================================
# 提取警告信息
# ==============================================================================

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
# 计算代码总行数（用于警告密度）
# ==============================================================================
TOTAL_LINES=$(find GitHub -name '*.swift' -exec cat {} + 2>/dev/null | wc -l | tr -d ' ' || echo "0")
[ -z "$TOTAL_LINES" ] && TOTAL_LINES=0

# ==============================================================================
# 生成Markdown格式的bug.md文件
# ==============================================================================

cat > "$OUTPUT_FILE" << EOF
# 🐛 可视化警告日志报告 (Bug Log)

**生成时间**: $(date '+%Y-%m-%d %H:%M:%S %Z')
**源日志文件**: \`${BUILD_LOG}\`
**构建状态**: $( [ "$TOTAL_ERRORS" -gt 0 ] && echo "❌ 构建失败" || echo "✅ 构建成功" )

---

## 📊 问题统计概览

| 类型 | 数量 | 状态 |
|------|------|------|
| 🔴 错误 | **${TOTAL_ERRORS}** 个 | $( [ "$TOTAL_ERRORS" -gt 0 ] && echo "需要修复" || echo "无错误" ) |
| 🟡 警告 | **${TOTAL_WARNINGS}** 个 | $( [ "$TOTAL_WARNINGS" -gt 0 ] && echo "建议清理" || echo "零警告" ) |

---

## 📋 警告类型分布

| 警告类型 | 数量 | 占比 |
|----------|------|------|
| ⚠️ 弃用API警告 | ${DEPRECATED_COUNT} 个 | $([ "$TOTAL_WARNINGS" -gt 0 ] && echo "$((DEPRECATED_COUNT * 100 / TOTAL_WARNINGS))%" || echo "0%") |
| 📦 未使用变量警告 | ${UNUSED_COUNT} 个 | $([ "$TOTAL_WARNINGS" -gt 0 ] && echo "$((UNUSED_COUNT * 100 / TOTAL_WARNINGS))%" || echo "0%") |
| 🔄 类型转换警告 | ${CASTING_COUNT} 个 | $([ "$TOTAL_WARNINGS" -gt 0 ] && echo "$((CASTING_COUNT * 100 / TOTAL_WARNINGS))%" || echo "0%") |
| 🔍 可空性警告 | ${NULLABILITY_COUNT} 个 | $([ "$TOTAL_WARNINGS" -gt 0 ] && echo "$((NULLABILITY_COUNT * 100 / TOTAL_WARNINGS))%" || echo "0%") |
| 📝 其他警告 | ${OTHER_COUNT} 个 | $([ "$TOTAL_WARNINGS" -gt 0 ] && echo "$((OTHER_COUNT * 100 / TOTAL_WARNINGS))%" || echo "0%") |

---

## 📁 警告文件分布 (Top 20)

EOF

# 警告文件分布
if [ -n "$WARNING_FILES" ]; then
    echo "| 排名 | 文件名 | 警告数量 | 严重程度 |" >> "$OUTPUT_FILE"
    echo "|------|--------|----------|----------|" >> "$OUTPUT_FILE"
    RANK=1
    echo "$WARNING_FILES" | while read -r count file; do
        if [ -n "$file" ]; then
            if [ "$count" -ge 10 ]; then
                SEVERITY="🔴 高"
            elif [ "$count" -ge 5 ]; then
                SEVERITY="🟡 中"
            else
                SEVERITY="🟢 低"
            fi
            echo "| ${RANK} | \`${file}\` | ${count} 个 | ${SEVERITY} |" >> "$OUTPUT_FILE"
            RANK=$((RANK + 1))
        fi
    done
else
    echo "✅ 无警告文件" >> "$OUTPUT_FILE"
fi

cat >> "$OUTPUT_FILE" << EOF

---

## 📝 警告详情列表

EOF

# 警告详情（按类型分组显示）
if [ "$TOTAL_WARNINGS" -gt 0 ]; then
    # 弃用API警告
    if [ "$DEPRECATED_COUNT" -gt 0 ]; then
        cat >> "$OUTPUT_FILE" << EOF

### ⚠️ 弃用API警告 (${DEPRECATED_COUNT}个)

\`\`\`
EOF
        grep -i "deprecated\|was deprecated" "$BUILD_LOG" 2>/dev/null | head -20 >> "$OUTPUT_FILE"
        echo '```' >> "$OUTPUT_FILE"
    fi
    
    # 未使用变量警告
    if [ "$UNUSED_COUNT" -gt 0 ]; then
        cat >> "$OUTPUT_FILE" << EOF

### 📦 未使用变量警告 (${UNUSED_COUNT}个)

\`\`\`
EOF
        grep -i "unused\|never used\|never read" "$BUILD_LOG" 2>/dev/null | head -20 >> "$OUTPUT_FILE"
        echo '```' >> "$OUTPUT_FILE"
    fi
    
    # 类型转换警告
    if [ "$CASTING_COUNT" -gt 0 ]; then
        cat >> "$OUTPUT_FILE" << EOF

### 🔄 类型转换警告 (${CASTING_COUNT}个)

\`\`\`
EOF
        grep -i "conditional cast\|forced cast\|implicit conversion" "$BUILD_LOG" 2>/dev/null | head -20 >> "$OUTPUT_FILE"
        echo '```' >> "$OUTPUT_FILE"
    fi
    
    # 其他警告
    if [ "$OTHER_COUNT" -gt 0 ]; then
        cat >> "$OUTPUT_FILE" << EOF

### 📝 其他警告 (${OTHER_COUNT}个)

\`\`\`
EOF
        grep "warning:" "$BUILD_LOG" 2>/dev/null | \
            grep -vi "deprecated\|was deprecated\|unused\|never used\|never read\|conditional cast\|forced cast\|implicit conversion" | \
            head -30 >> "$OUTPUT_FILE"
        echo '```' >> "$OUTPUT_FILE"
    fi
else
    cat >> "$OUTPUT_FILE" << EOF

### ✅ 恭喜！零警告，代码质量优秀！

EOF
fi

# ==============================================================================
# 错误详情（如果有错误）
# ==============================================================================
if [ "$TOTAL_ERRORS" -gt 0 ]; then
    cat >> "$OUTPUT_FILE" << EOF

---

## ❌ 错误详情列表

\`\`\`
EOF
    grep "error:" "$BUILD_LOG" 2>/dev/null | head -30 >> "$OUTPUT_FILE"
    echo '```' >> "$OUTPUT_FILE"
fi

# ==============================================================================
# 代码质量评估和修复建议
# ==============================================================================
cat >> "$OUTPUT_FILE" << EOF

---

## 🎯 代码质量评估与建议

### 📊 质量评级

EOF

# 质量评级
if [ "$TOTAL_ERRORS" -gt 0 ]; then
    QUALITY_GRADE="**D级**（较差，存在编译错误）"
elif [ "$TOTAL_WARNINGS" -eq 0 ]; then
    QUALITY_GRADE="**S级**（卓越，零警告零错误）"
elif [ "$TOTAL_WARNINGS" -lt 5 ]; then
    QUALITY_GRADE="**A级**（优秀）"
elif [ "$TOTAL_WARNINGS" -lt 20 ]; then
    QUALITY_GRADE="**B级**（良好）"
elif [ "$TOTAL_WARNINGS" -lt 50 ]; then
    QUALITY_GRADE="**C级**（一般，建议清理警告）"
else
    QUALITY_GRADE="**D级**（较差，需要立即清理警告）"
fi

# 警告密度
if [ "$TOTAL_LINES" -gt 0 ] && [ "$TOTAL_WARNINGS" -gt 0 ]; then
    WARNING_DENSITY=$((TOTAL_WARNINGS * 1000 / TOTAL_LINES))
else
    WARNING_DENSITY=0
fi

cat >> "$OUTPUT_FILE" << EOF
- **质量评级**: ${QUALITY_GRADE}
- **警告密度**: 每千行约 ${WARNING_DENSITY} 个警告
- **代码总行数**: ${TOTAL_LINES} 行

### 💡 修复建议

EOF

# 具体修复建议
if [ "$DEPRECATED_COUNT" -gt 0 ]; then
    cat >> "$OUTPUT_FILE" << EOF

#### 1. 弃用API警告 (${DEPRECATED_COUNT}个)
- 检查使用的API是否有替代方案
- 逐步迁移到新API，避免使用已废弃接口
- 参考Apple官方文档了解废弃原因和替代方案

EOF
fi

if [ "$UNUSED_COUNT" -gt 0 ]; then
    cat >> "$OUTPUT_FILE" << EOF

#### 2. 未使用变量警告 (${UNUSED_COUNT}个)
- 删除未使用的变量和函数
- 检查是否是调试代码遗留
- 使用Xcode的静态分析工具辅助清理

EOF
fi

if [ "$CASTING_COUNT" -gt 0 ]; then
    cat >> "$OUTPUT_FILE" << EOF

#### 3. 类型转换警告 (${CASTING_COUNT}个)
- 使用可选绑定（if let / guard let）替代强制转换
- 检查类型转换是否安全
- 考虑使用泛型和协议来减少类型转换

EOF
fi

if [ "$TOTAL_WARNINGS" -gt 20 ]; then
    cat >> "$OUTPUT_FILE" << EOF

#### 4. 警告数量过多
- 建议分批次清理警告，优先清理高风险警告
- 可以在CI中设置警告阈值，超过阈值则构建失败
- 建立代码审查机制，防止新警告引入

EOF
fi

if [ "$TOTAL_WARNINGS" -eq 0 ] && [ "$TOTAL_ERRORS" -eq 0 ]; then
    cat >> "$OUTPUT_FILE" << EOF

#### ✅ 代码质量优秀，继续保持！
- 建议持续监控代码质量
- 可以考虑启用更严格的编译警告选项

EOF
fi

# ==============================================================================
# 页脚
# ==============================================================================
cat >> "$OUTPUT_FILE" << EOF

---

## 📋 报告说明

- 本报告由CI流水线自动生成
- 报告基于构建日志 \`${BUILD_LOG}\` 分析生成
- 报告包含警告统计、分类、文件分布、详情和修复建议
- 如需查看原始构建日志，请下载 \`build.log\` Artifact

---

*本报告由 GitHub Actions 自动生成，仅供参考*
EOF

# ==============================================================================
# 输出完成信息
# ==============================================================================
echo ""
echo "✅ 可视化警告日志生成完成！"
echo "📄 输出文件: ${OUTPUT_FILE}"
echo "⚠️  警告总数: ${TOTAL_WARNINGS} 个"
echo "❌ 错误总数: ${TOTAL_ERRORS} 个"
echo ""
echo "📊 警告类型分布:"
echo "   - 弃用API警告: ${DEPRECATED_COUNT} 个"
echo "   - 未使用变量警告: ${UNUSED_COUNT} 个"
echo "   - 类型转换警告: ${CASTING_COUNT} 个"
echo "   - 可空性警告: ${NULLABILITY_COUNT} 个"
echo "   - 其他警告: ${OTHER_COUNT} 个"
echo ""
echo "💡 提示: ${OUTPUT_FILE} 为Markdown格式，可直接在GitHub网页查看"
