#!/bin/bash

# ============================================
# Merlin Website - 智能环境检测启动脚本
# ============================================
#
# 功能：自动检测操作系统并生成正确的 .env 文件
# 使用方法：
#   Windows (Git Bash):  ./start.sh
#   Linux:               chmod +x start.sh && ./start.sh
#

set -e

echo "====================================="
echo "  Merlin Personal Website"
echo "  环境检测与自动配置工具"
echo "====================================="
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            echo "windows"
            ;;
        Linux*)
            echo "linux"
            ;;
        Darwin*)
            echo "macos"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

OS_TYPE=$(detect_os)
echo "✓ 检测到操作系统: $OS_TYPE"

# 根据操作系统生成 .env 文件
case "$OS_TYPE" in
    windows)
        if [ -f ".env.windows" ]; then
            cp .env.windows .env
            echo "✓ 已使用 Windows 配置 (.env.windows -> .env)"
        else
            echo "✗ 错误: 未找到 .env.windows 配置文件"
            exit 1
        fi
        ;;
    linux|macos)
        if [ -f ".env.linux" ]; then
            # Linux/MacOS: 尝试自动检测项目路径
            CURRENT_DIR="$(pwd)/.."
            CURRENT_DIR="$(cd "$CURRENT_DIR" && pwd)"
            
            echo "ℹ 检测到当前目录: $CURRENT_DIR"
            
            # 询问用户是否使用自动检测的路径
            if [ -f "$CURRENT_DIR/template/Merlinsite/index.html" ]; then
                echo "✓ 验证成功: 找到网站文件"
                sed "s|^PROJECT_PATH=.*$|PROJECT_PATH=$CURRENT_DIR|" .env.linux > .env
                echo "✓ 已自动配置项目路径"
            else
                cp .env.linux .env
                echo "⚠ 使用默认配置，请手动编辑 .env 文件设置 PROJECT_PATH"
            fi
        else
            echo "✗ 错误: 未找到 .env.linux 配置文件"
            exit 1
        fi
        ;;
    *)
        echo "✗ 错误: 不支持的操作系统: $OS_TYPE"
        exit 1
        ;;
esac

echo ""
echo "====================================="

# 启动 Docker 容器
echo "🚀 正在启动 Docker 容器..."
echo ""

if command -v docker-compose &> /dev/null; then
    docker-compose up -d
elif command -v docker &> /dev/null; then
    docker compose up -d
else
    echo "✗ 错误: 未找到 Docker 或 Docker Compose"
    exit 1
fi

echo ""
echo "====================================="
echo "✓ 启动完成！"
echo ""
echo "访问地址:"
echo "  本地: http://localhost"
echo ""
echo "常用命令:"
echo "  查看状态: docker ps | grep merlin"
echo "  查看日志: docker logs merlin-website --tail 20"
echo "  停止容器: docker compose down"
echo "====================================="
