#!/bin/bash
# ==============================================================================
# 构建诊断工具（Build Diagnostics）
# 功能：
#   1. 环境诊断（Xcode/Swift/macOS版本、磁盘空间、内存）
#   2. 依赖检查（Package.resolved、Swift包缓存）
#   3. 编译警告分析（类型分布、文件分布、严重程度）
#   4. 产物分析（IPA包结构、文件大小分布、可执行文件分析）
#   5. 构建步骤耗时统计与排行
#   6. 缓存命中率分析
#   7. 错误诊断与修复建议
#   8. 构建趋势对比（与上一次构建对比）
# 使用方式：
#   source scripts/build-diagnostics.sh
#   run_pre_build_diagnostics    # 构建前诊断
#   run_post_build_diagnostics   # 构建后诊断
#   analyze_build_warnings       # 分析编译警告
#   analyze_ipa_structure        # 分析IPA包结构
# ==============================================================================

set -euo pipefail

# 加载可视化日志工具
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/visual-logger.sh" ]; then
    source "${SCRIPT_DIR}/visual-logger.sh"
fi

# ==============================================================================
# 构建前诊断：环境检查、依赖检查、缓存检查
# ==============================================================================

run_pre_build_diagnostics() {
    log_title "🔍 构建前诊断"
    
    # 1. 系统环境诊断
    log_group_start "🖥️ 系统环境诊断"
    diagnose_system_environment
    log_group_end
    
    # 2. Xcode工具链诊断
    log_group_start "🛠️ Xcode工具链诊断"
    diagnose_xcode_toolchain
    log_group_end
    
    # 3. 项目依赖诊断
    log_group_start "📦 项目依赖诊断"
    diagnose_project_dependencies
    log_group_end
    
    # 4. 缓存状态诊断
    log_group_start "💾 缓存状态诊断"
    diagnose_cache_status
    log_group_end
    
    log_success "构建前诊断完成"
}

# 系统环境诊断
diagnose_system_environment() {
    log_info "操作系统: $(uname -a)"
    log_info "macOS版本: $(sw_vers -productVersion 2>/dev/null || echo '未知')"
    log_info "主机名: $(hostname)"
    log_info "当前用户: $(whoami)"
    log_info "当前目录: $(pwd)"
    
    # 磁盘空间检查
    local disk_available=$(df -h / | tail -1 | awk '{print $4}')
    local disk_used=$(df -h / | tail -1 | awk '{print $5}')
    log_info "磁盘可用空间: ${disk_available} (已使用: ${disk_used})"
    
    # 磁盘空间预警
    local disk_available_gb=$(df -g / | tail -1 | awk '{print $4}' | tr -d 'i')
    if [ "${disk_available_gb}" -lt 10 ]; then
        log_warning "磁盘可用空间不足10GB，可能影响构建速度"
    elif [ "${disk_available_gb}" -lt 5 ]; then
        log_error "磁盘可用空间不足5GB，构建可能失败"
    fi
    
    # 内存检查
    if command -v vm_stat &> /dev/null; then
        local mem_total=$(sysctl -n hw.memsize 2>/dev/null | awk '{print $1/1024/1024/1024 "GB"}')
        log_info "总内存: ${mem_total}"
    fi
    
    # CPU信息
    local cpu_count=$(sysctl -n hw.ncpu 2>/dev/null || echo '未知')
    log_info "CPU核心数: ${cpu_count}"
}

# Xcode工具链诊断
diagnose_xcode_toolchain() {
    if command -v xcodebuild &> /dev/null; then
        local xcode_version=$(xcodebuild -version | head -1)
        log_info "Xcode版本: ${xcode_version}"
        
        local xcode_path=$(xcode-select -p)
        log_info "Xcode路径: ${xcode_path}"
        
        # 检查iOS SDK
        local ios_sdk=$(xcodebuild -showsdks 2>/dev/null | grep -i iphoneos | head -1 | awk '{print $3, $4}')
        log_info "iOS SDK: ${ios_sdk}"
        
        # 检查Swift版本
        if command -v swift &> /dev/null; then
            local swift_version=$(swift --version | head -1)
            log_info "Swift版本: ${swift_version}"
        fi
    else
        log_error "xcodebuild命令未找到，请检查Xcode安装"
    fi
    
    # 检查XcodeGen
    if command -v xcodegen &> /dev/null; then
        log_info "XcodeGen版本: $(xcodegen --version)"
    else
        log_warning "XcodeGen未安装，将在构建步骤中安装"
    fi
    
    # 检查其他构建工具
    local tools=("xcodebuild" "xcrun" "swift" "clang" "ld" "zip" "shasum")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_info "✓ ${tool} 已安装"
        else
            log_warning "✗ ${tool} 未找到"
        fi
    done
}

# 项目依赖诊断
diagnose_project_dependencies() {
    # 检查项目文件
    if [ -f "project.yml" ]; then
        log_info "✓ project.yml 存在"
        local target_count=$(grep -c "target:" project.yml 2>/dev/null || echo "0")
        log_info "  目标数量: ${target_count}"
    else
        log_error "✗ project.yml 不存在"
    fi
    
    # 检查Info.plist
    if [ -f "GitHub/Info.plist" ]; then
        log_info "✓ Info.plist 存在"
        local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" GitHub/Info.plist 2>/dev/null || echo "未知")
        local version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" GitHub/Info.plist 2>/dev/null || echo "未知")
        log_info "  Bundle ID: ${bundle_id}"
        log_info "  版本号: ${version}"
    else
        log_error "✗ Info.plist 不存在"
    fi
    
    # 检查Swift包依赖
    if [ -f "Package.resolved" ]; then
        log_info "✓ Package.resolved 存在"
        local package_count=$(grep -c "package:" Package.resolved 2>/dev/null || echo "0")
        log_info "  依赖包数量: ${package_count}"
    else
        log_warning "⚠ Package.resolved 不存在，将在构建时解析依赖"
    fi
    
    # 检查源码文件数量
    local swift_file_count=$(find GitHub -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
    log_info "Swift源文件数量: ${swift_file_count}"
    
    # 检查源码总行数
    if [ "${swift_file_count}" -gt 0 ]; then
        local total_lines=$(find GitHub -name "*.swift" -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
        log_info "Swift源码总行数: ${total_lines}"
    fi
}

# 缓存状态诊断
diagnose_cache_status() {
    # Swift包缓存
    local spm_cache=~/Library/Caches/org.swift.swiftpm
    if [ -d "$spm_cache" ]; then
        local spm_cache_size=$(du -sh "$spm_cache" 2>/dev/null | awk '{print $1}')
        log_info "✓ Swift包缓存存在，大小: ${spm_cache_size}"
    else
        log_warning "⚠ Swift包缓存不存在，首次构建将下载依赖"
    fi
    
    # 编译产物缓存
    local derived_data=~/Library/Developer/Xcode/DerivedData
    if [ -d "$derived_data" ]; then
        local derived_count=$(ls -1 "$derived_data" 2>/dev/null | wc -l | tr -d ' ')
        local derived_size=$(du -sh "$derived_data" 2>/dev/null | awk '{print $1}')
        log_info "✓ DerivedData存在，项目数: ${derived_count}，总大小: ${derived_size}"
    else
        log_warning "⚠ DerivedData不存在，将执行全量编译"
    fi
    
    # 检查当前项目的编译缓存
    if [ -d "build" ]; then
        local build_size=$(du -sh build 2>/dev/null | awk '{print $1}')
        log_info "✓ 本地build目录存在，大小: ${build_size}"
    else
        log_info "本地build目录不存在，将执行全新编译"
    fi
}

# ==============================================================================
# 构建后诊断：警告分析、产物分析、耗时统计
# ==============================================================================

run_post_build_diagnostics() {
    local build_log="${1:-build.log}"
    local ipa_path="${2:-GitHub.ipa}"
    local build_start_time="${3:-}"
    
    log_title "📊 构建后诊断"
    
    # 1. 编译警告分析
    if [ -f "$build_log" ]; then
        log_group_start "⚠️ 编译警告分析"
        analyze_build_warnings "$build_log"
        log_group_end
    fi
    
    # 2. IPA产物分析
    if [ -f "$ipa_path" ]; then
        log_group_start "📦 IPA产物分析"
        analyze_ipa_structure "$ipa_path"
        log_group_end
    fi
    
    # 3. 构建耗时统计
    if [ -n "$build_start_time" ]; then
        log_group_start "⏱️ 构建耗时统计"
        analyze_build_duration "$build_start_time"
        log_group_end
    fi
    
    log_success "构建后诊断完成"
}

# 编译警告分析
analyze_build_warnings() {
    local build_log="$1"
    
    if [ ! -f "$build_log" ]; then
        log_warning "构建日志文件不存在: ${build_log}"
        return
    fi
    
    local total_warnings=$(grep -c "warning:" "$build_log" 2>/dev/null | tr -d '[:space:]' || echo "0")
    [ -z "$total_warnings" ] && total_warnings=0
    log_info "警告总数: ${total_warnings}"
    
    if [ "${total_warnings}" -eq 0 ]; then
        log_success "零警告，代码质量优秀"
        return
    fi
    
    # 按警告类型分类统计
    log_info ""
    log_info "📋 警告类型分布:"
    
    # 弃用API警告（清理数字，确保纯整数）
    local deprecated_count=$(grep -ci "deprecated\|was deprecated" "$build_log" 2>/dev/null | tr -d '[:space:]' || echo "0")
    [ -z "$deprecated_count" ] && deprecated_count=0
    if [ "${deprecated_count}" -gt 0 ]; then
        log_warning "  弃用API警告: ${deprecated_count} 条"
    fi
    
    # 未使用变量警告
    local unused_count=$(grep -ci "unused\|never used\|never read" "$build_log" 2>/dev/null | tr -d '[:space:]' || echo "0")
    [ -z "$unused_count" ] && unused_count=0
    if [ "${unused_count}" -gt 0 ]; then
        log_warning "  未使用变量警告: ${unused_count} 条"
    fi
    
    # 类型转换警告
    local casting_count=$(grep -ci "conditional cast\|forced cast\|implicit conversion" "$build_log" 2>/dev/null | tr -d '[:space:]' || echo "0")
    [ -z "$casting_count" ] && casting_count=0
    if [ "${casting_count}" -gt 0 ]; then
        log_warning "  类型转换警告: ${casting_count} 条"
    fi
    
    # 其他警告（确保所有变量都是纯数字）
    local other_count=$((total_warnings - deprecated_count - unused_count - casting_count))
    if [ "${other_count}" -gt 0 ]; then
        log_info "  其他警告: ${other_count} 条"
    fi
    
    # 按文件分布统计（前10个警告最多的文件）
    log_info ""
    log_info "📁 警告文件分布（前10）:"
    grep "warning:" "$build_log" 2>/dev/null | \
        sed 's/.*\///' | \
        cut -d: -f1 | \
        sort | uniq -c | sort -rn | head -10 | \
        while read -r count file; do
            log_info "  ${file}: ${count} 条警告"
        done
    
    # 显示前10条警告详情
    log_info ""
    log_info "📝 警告详情（前10条）:"
    grep "warning:" "$build_log" 2>/dev/null | head -10 | while read -r line; do
        log_warning "  ${line}"
    done
    
    # 质量评估
    log_info ""
    if [ "${total_warnings}" -eq 0 ]; then
        log_success "代码质量评级: S级（零警告）"
    elif [ "${total_warnings}" -lt 5 ]; then
        log_success "代码质量评级: A级（优秀）"
    elif [ "${total_warnings}" -lt 20 ]; then
        log_info "代码质量评级: B级（良好）"
    elif [ "${total_warnings}" -lt 50 ]; then
        log_warning "代码质量评级: C级（一般，建议清理警告）"
    else
        log_error "代码质量评级: D级（较差，需要立即清理警告）"
    fi
}

# IPA产物分析
analyze_ipa_structure() {
    local ipa_path="$1"
    
    if [ ! -f "$ipa_path" ]; then
        log_error "IPA文件不存在: ${ipa_path}"
        return
    fi
    
    local ipa_size=$(ls -lh "$ipa_path" | awk '{print $5}')
    local ipa_sha256=$(shasum -a 256 "$ipa_path" | awk '{print $1}')
    
    log_info "IPA文件名: $(basename "$ipa_path")"
    log_info "文件大小: ${ipa_size}"
    log_info "SHA256: ${ipa_sha256}"
    
    # 解压IPA分析包结构
    local temp_dir=$(mktemp -d)
    unzip -q "$ipa_path" -d "$temp_dir" 2>/dev/null || true
    
    local app_path=$(find "$temp_dir" -name "*.app" -type d | head -1)
    if [ -n "$app_path" ]; then
        log_info ""
        log_info "📂 APP包结构:"
        
        # 可执行文件大小
        local app_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "${app_path}/Info.plist" 2>/dev/null || echo "GitHub")
        local executable_path="${app_path}/${app_name}"
        if [ -f "$executable_path" ]; then
            local executable_size=$(ls -lh "$executable_path" | awk '{print $5}')
            log_info "  可执行文件: ${app_name} (${executable_size})"
        fi
        
        # 文件类型分布
        log_info ""
        log_info "📊 文件类型分布:"
        
        # Swift模块
        local swift_modules=$(find "$app_path" -name "*.swiftmodule" 2>/dev/null | wc -l | tr -d ' ')
        if [ "${swift_modules}" -gt 0 ]; then
            log_info "  Swift模块: ${swift_modules} 个"
        fi
        
        # 图片资源
        local png_count=$(find "$app_path" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
        local jpg_count=$(find "$app_path" -name "*.jpg" -o -name "*.jpeg" 2>/dev/null | wc -l | tr -d ' ')
        log_info "  图片资源: PNG ${png_count} 个, JPG ${jpg_count} 个"
        
        # 故事板/XIB
        local storyboard_count=$(find "$app_path" -name "*.storyboardc" 2>/dev/null | wc -l | tr -d ' ')
        local nib_count=$(find "$app_path" -name "*.nib" 2>/dev/null | wc -l | tr -d ' ')
        log_info "  界面文件: Storyboard ${storyboard_count} 个, XIB ${nib_count} 个"
        
        # 配置文件
        local plist_count=$(find "$app_path" -name "*.plist" 2>/dev/null | wc -l | tr -d ' ')
        log_info "  配置文件: ${plist_count} 个"
        
        # Assets.car
        if [ -f "${app_path}/Assets.car" ]; then
            local assets_size=$(ls -lh "${app_path}/Assets.car" | awk '{print $5}')
            log_info "  资源包: Assets.car (${assets_size})"
        fi
        
        # 最大文件排行（前10）
        log_info ""
        log_info "🏆 最大文件排行（前10）:"
        find "$app_path" -type f -exec ls -lh {} + 2>/dev/null | \
            awk '{print $5, $9}' | \
            sort -rh | head -10 | \
            while read -r size file; do
                local filename=$(basename "$file")
                log_info "  ${filename}: ${size}"
            done
        
        # Info.plist关键信息
        log_info ""
        log_info "📋 Info.plist关键信息:"
        if [ -f "${app_path}/Info.plist" ]; then
            local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null || echo "未知")
            local version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${app_path}/Info.plist" 2>/dev/null || echo "未知")
            local build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${app_path}/Info.plist" 2>/dev/null || echo "未知")
            local min_os=$(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "${app_path}/Info.plist" 2>/dev/null || echo "未知")
            
            log_info "  Bundle ID: ${bundle_id}"
            log_info "  版本号: ${version}"
            log_info "  构建号: ${build}"
            log_info "  最低系统: iOS ${min_os}"
        fi
    fi
    
    # 清理临时目录
    rm -rf "$temp_dir"
}

# 构建耗时统计
analyze_build_duration() {
    local build_start_time="$1"
    local build_end_time=$(date +%s)
    local total_duration=$((build_end_time - build_start_time))
    
    log_info "构建总耗时: ${total_duration} 秒 ($((total_duration / 60))分$((total_duration % 60))秒)"
    
    # 耗时评估
    if [ "${total_duration}" -lt 60 ]; then
        log_success "构建速度: 极快（<1分钟）"
    elif [ "${total_duration}" -lt 180 ]; then
        log_success "构建速度: 快速（1-3分钟）"
    elif [ "${total_duration}" -lt 300 ]; then
        log_info "构建速度: 正常（3-5分钟）"
    elif [ "${total_duration}" -lt 600 ]; then
        log_warning "构建速度: 较慢（5-10分钟），建议优化缓存"
    else
        log_error "构建速度: 很慢（>10分钟），需要优化构建配置"
    fi
    
    # 性能优化建议
    log_info ""
    log_info "💡 构建性能优化建议:"
    log_info "  1. 启用增量编译（已配置缓存）"
    log_info "  2. 使用新构建系统（New Build System）"
    log_info "  3. 减少编译警告（警告会拖慢编译）"
    log_info "  4. 合理设置优化级别（Release使用-O）"
    log_info "  5. 使用模块化设计，减少跨模块依赖"
}

# ==============================================================================
# 错误诊断与修复建议
# ==============================================================================

diagnose_and_suggest() {
    local build_log="${1:-build.log}"
    local error_type="${2:-}"
    
    log_title "🔧 错误诊断与修复建议"
    
    if [ ! -f "$build_log" ]; then
        log_warning "构建日志文件不存在"
        return
    fi
    
    # 检测常见错误类型
    local errors=$(grep "error:" "$build_log" 2>/dev/null || true)
    
    if echo "$errors" | grep -qi "No such module"; then
        log_error "检测到: 模块未找到错误"
        log_info "修复建议:"
        log_info "  1. 检查Package.resolved是否存在"
        log_info "  2. 执行 swift package resolve 解析依赖"
        log_info "  3. 检查Swift包缓存是否完整"
        log_info "  4. 清理DerivedData后重新构建"
    fi
    
    if echo "$errors" | grep -qi "cannot find\|use of unresolved identifier"; then
        log_error "检测到: 标识符未找到错误"
        log_info "修复建议:"
        log_info "  1. 检查变量/函数/类名拼写"
        log_info "  2. 检查是否缺少import语句"
        log_info "  3. 检查访问级别（public/internal/private）"
        log_info "  4. 检查是否在正确的作用域内"
    fi
    
    if echo "$errors" | grep -qi "type mismatch\|cannot convert"; then
        log_error "检测到: 类型不匹配错误"
        log_info "修复建议:"
        log_info "  1. 检查变量类型声明"
        log_info "  2. 使用as?或as!进行类型转换"
        log_info "  3. 检查函数返回类型"
        log_info "  4. 使用泛型约束"
    fi
    
    if echo "$errors" | grep -qi "Undefined symbols\|ld: error"; then
        log_error "检测到: 链接错误"
        log_info "修复建议:"
        log_info "  1. 检查是否缺少源文件"
        log_info "  2. 检查框架依赖是否完整"
        log_info "  3. 检查架构设置（arm64/armv7）"
        log_info "  4. 清理DerivedData后重新构建"
    fi
    
    if echo "$errors" | grep -qi "CodeSign\|code sign"; then
        log_error "检测到: 代码签名错误"
        log_info "修复建议:"
        log_info "  1. 本项目配置为未签名构建，检查CODE_SIGNING_ALLOWED=NO"
        log_info "  2. 检查是否意外启用了签名"
        log_info "  3. 检查证书和描述文件配置"
    fi
    
    if echo "$errors" | grep -qi "disk full\|No space left"; then
        log_error "检测到: 磁盘空间不足"
        log_info "修复建议:"
        log_info "  1. 清理DerivedData: rm -rf ~/Library/Developer/Xcode/DerivedData"
        log_info "  2. 清理模拟器数据"
        log_info "  3. 清理旧的构建产物"
        log_info "  4. 增加磁盘空间"
    fi
    
    # 如果没有检测到特定错误，显示通用建议
    if [ -z "$errors" ]; then
        log_success "未检测到编译错误"
    else
        log_info ""
        log_info "通用排查步骤:"
        log_info "  1. 查看上方错误详情"
        log_info "  2. 检查最近修改的代码"
        log_info "  3. 清理DerivedData后重新构建"
        log_info "  4. 查看完整构建日志: build.log"
    fi
}

# ==============================================================================
# 导出函数
# ==============================================================================
export -f run_pre_build_diagnostics run_post_build_diagnostics
export -f diagnose_system_environment diagnose_xcode_toolchain
export -f diagnose_project_dependencies diagnose_cache_status
export -f analyze_build_warnings analyze_ipa_structure analyze_build_duration
export -f diagnose_and_suggest
