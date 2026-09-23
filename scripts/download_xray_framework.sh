#!/bin/bash
# ==============================================================================
# 下载 Xray.xcframework 脚本
# 用途：在 CI 构建或本地开发前下载 Xray 核心框架
# 来源：react-native-nitro-xray-core npm 包（包含预编译的 Xray 静态库）
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

# Xray 框架版本（对应 npm 包版本）
XRAY_VERSION="1.3.0"
NPM_PACKAGE="react-native-nitro-xray-core@$XRAY_VERSION"

echo -e "${GREEN}=== 开始下载 Xray.xcframework ===${NC}"
echo "版本: $XRAY_VERSION"
echo "目标目录: $FRAMEWORK_DIR"

# 检查是否已存在
if [ -d "$FRAMEWORK_DIR" ] && [ -f "$FRAMEWORK_DIR/ios-arm64/libxray.a" ]; then
    echo -e "${YELLOW}Xray.xcframework 已存在，跳过下载${NC}"
    exit 0
fi

# 创建临时目录
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "下载 npm 包: $NPM_PACKAGE..."
cd "$TEMP_DIR"

# 使用 npm pack 下载包（不安装，只下载 tarball）
npm pack "$NPM_PACKAGE" --silent

# 解压
TARBALL=$(ls *.tgz | head -1)
echo "解压: $TARBALL"
tar -xzf "$TARBALL"

# 检查框架是否存在
if [ ! -d "package/ios/Xray.xcframework" ]; then
    echo -e "${RED}错误：未找到 Xray.xcframework${NC}"
    exit 1
fi

# 复制到项目目录
echo "复制框架到项目目录..."
mkdir -p "$(dirname "$FRAMEWORK_DIR")"
cp -R "package/ios/Xray.xcframework" "$FRAMEWORK_DIR"

# 验证
if [ -f "$FRAMEWORK_DIR/ios-arm64/libxray.a" ] && [ -f "$FRAMEWORK_DIR/ios-arm64-simulator/libxray.a" ]; then
    echo -e "${GREEN}=== Xray.xcframework 下载成功 ===${NC}"
    echo "真机版本: $(du -sh $FRAMEWORK_DIR/ios-arm64/libxray.a | cut -f1)"
    echo "模拟器版本: $(du -sh $FRAMEWORK_DIR/ios-arm64-simulator/libxray.a | cut -f1)"
else
    echo -e "${RED}错误：框架文件不完整${NC}"
    exit 1
fi
