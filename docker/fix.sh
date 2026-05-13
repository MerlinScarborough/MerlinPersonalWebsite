#!/bin/bash

echo "=========================================="
echo "  Merlin 网站 - 一键修复脚本"
echo "=========================================="
echo ""

# 停止现有容器
echo "[1/6] 停止现有容器..."
docker-compose down 2>/dev/null || docker stop merlin-website 2>/dev/null || true

# 清理旧容器（可选，谨慎使用）
# echo "[2/6] 清理旧容器..."
# docker rm merlin-website 2>/dev/null || true

# 检查并开放系统防火墙
echo "[2/6] 检查系统防火墙..."

if command -v firewall-cmd &> /dev/null; then
    echo "检测到 firewalld，正在开放 80 端口..."
    sudo firewall-cmd --permanent --add-port=80/tcp
    sudo firewall-cmd --reload
    echo "✅ firewalld 已开放 80 端口"
elif command -v ufw &> /dev/null; then
    echo "检测到 ufw，正在开放 80 端口..."
    sudo ufw allow 80/tcp
    echo "✅ ufw 已开放 80 端口"
else
    echo "⚠️ 未检测到常见防火墙工具，可能需要手动配置 iptables"
fi

# 检查 SELinux (CentOS/RHEL)
if [ -f /etc/selinux/config ]; then
    echo "[3/6] 检查 SELinux..."
    if [ "$(getenforce)" = "Enforcing" ]; then
        echo "⚠️ SELinux 正在运行，这可能阻止 Docker 访问"
        echo "建议：临时关闭测试: sudo setenforce 0"
        read -p "是否临时关闭 SELinux？(y/n): " close_selinux
        if [ "$close_selinux" = "y" ]; then
            sudo setenforce 0
            echo "✅ SELinux 已临时设置为 Permissive"
        fi
    else
        echo "✅ SELinux 未启用或已是 Permissive 模式"
    fi
else
    echo "[3/6] 未检测到 SELinux (非 RHEL 系统)"
fi

# 验证文件存在
echo "[4/6] 验证网站文件..."
if [ -f "../template/Merlinsite/index.html" ]; then
    echo "✅ 找到 index.html"
else
    echo "❌ 未找到 index.html！请确认文件路径正确"
    echo "当前目录结构:"
    ls -la ../template/Merlinsite/ 2>/dev/null || echo "目录不存在"
    exit 1
fi

# 重新启动容器
echo "[5/6] 启动 Docker 容器..."
docker-compose up -d

# 等待容器启动
echo "[6/6] 等待服务就绪..."
sleep 3

# 验证
echo ""
echo "=========================================="
echo "  验证结果"
echo "=========================================="

# 检查容器状态
if docker ps | grep -q merlin-website; then
    echo "✅ 容器正在运行"
else
    echo "❌ 容器未运行，查看日志："
    docker logs merlin-website
    exit 1
fi

# 测试本地访问
if curl -s -o /dev/null -w "%{http_code}" http://localhost:80 | grep -q "200\|301\|302"; then
    echo "✅ 本地访问正常 (HTTP 状态码正常)"
else
    echo "⚠️ 本地访问异常，查看日志："
    docker logs --tail 20 merlin-website
fi

echo ""
echo "=========================================="
echo "  请尝试从浏览器访问："
echo "  http://$(curl -s ifconfig.me)"
echo "=========================================="
