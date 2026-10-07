#!/bin/bash
# ==============================================================================
# 下载裁剪版 Xray.xcframework 脚本
# 用途：在 CI 构建或本地开发前下载 Xray 核心框架
# 来源：https://github.com/lambret-1/XrayCore-iOS Releases
# 说明：裁剪版仅保留 VLESS/VMess 协议，最小化内存占用
# ==============================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FRAMEWORK_DIR="$PROJECT_DIR/VPNPacketTunnel/Xray.xcframework"

# 裁剪版 Xray 框架版本（对应 XrayCore-iOS Release tag）
XRAY_VERSION="2026.10.07"
DOWNLOAD_URL="https://github.com/lambret-1/XrayCore-iOS/releases/download/v${XRAY_VERSION}/Xray.xcframework.zip"

echo -e "${GREEN}=== 开始下载裁剪版 Xray.xcframework ===${NC}"
echo "版本: v$XRAY_VERSION"
echo "来源: XrayCore-iOS (仅保留 VLESS/VMess)"
echo "下载地址: $DOWNLOAD_URL"
echo "目标目录: $FRAMEWORK_DIR"

# 检查是否已存在
if [ -d "$FRAMEWORK_DIR" ] && [ -f "$FRAMEWORK_DIR/ios-arm64/libxray.a" ]; then
    echo -e "${YELLOW}Xray.xcframework 已存在，跳过下载${NC}"
    exit 0
fi

# 创建临时目录
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "下载 Xray.xcframework.zip..."
cd "$TEMP_DIR"
curl -L -o Xray.xcframework.zip "$DOWNLOAD_URL" --silent --show-error

# 验证下载
if [ ! -f "Xray.xcframework.zip" ] || [ ! -s "Xray.xcframework.zip" ]; then
    echo -e "${RED}错误：下载失败或文件为空${NC}"
    exit 1
fi

echo "下载完成: $(du -sh Xray.xcframework.zip | cut -f1)"

# 解压
echo "解压..."
unzip -q Xray.xcframework.zip

# 检查框架是否存在
if [ ! -d "Xray.xcframework" ]; then
    echo -e "${RED}错误：未找到 Xray.xcframework${NC}"
    exit 1
fi

# 复制到项目目录
echo "复制框架到项目目录..."
mkdir -p "$(dirname "$FRAMEWORK_DIR")"
cp -R "Xray.xcframework" "$FRAMEWORK_DIR"

# 验证
DEVICE_DIR="$FRAMEWORK_DIR/ios-arm64"
SIM_DIR=$(find "$FRAMEWORK_DIR" -maxdepth 1 -type d -name "*simulator*" | head -1)

if [ -z "$SIM_DIR" ]; then
    SIM_DIR="$FRAMEWORK_DIR/ios-arm64_x86_64-simulator"
fi

if [ -f "$DEVICE_DIR/libxray.a" ] && [ -f "$SIM_DIR/libxray.a" ]; then
    echo -e "${GREEN}=== 裁剪版 Xray.xcframework 下载成功 ===${NC}"
    echo "真机版本: $(du -sh "$DEVICE_DIR/libxray.a" | cut -f1)"
    echo "模拟器版本: $(du -sh "$SIM_DIR/libxray.a" | cut -f1)"
    echo "头文件: $(ls "$DEVICE_DIR/Headers/")"
else
    echo -e "${RED}错误：框架文件不完整${NC}"
    echo "目录结构:"
    ls -la "$FRAMEWORK_DIR/"
    echo "真机目录内容:"
    ls -la "$DEVICE_DIR/" 2>/dev/null || echo "真机目录不存在"
    echo "模拟器目录内容:"
    ls -la "$SIM_DIR/" 2>/dev/null || echo "模拟器目录不存在"
    exit 1
fi
