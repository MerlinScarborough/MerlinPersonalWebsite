#!/bin/bash

echo "=========================================="
echo "  Merlin 网站 - Docker 部署诊断工具"
echo "=========================================="
echo ""

# 1. 检查容器状态
echo "【1】检查容器运行状态..."
docker ps -a | grep merlin
echo ""

# 2. 检查端口映射
echo "【2】检查端口映射..."
docker port merlin-website
echo ""

# 3. 检查容器日志（最近20行）
echo "【3】查看容器日志（最近20行）..."
docker logs --tail 20 merlin-website
echo ""

# 4. 测试本地访问
echo "【4】测试本地访问（从服务器内部）..."
curl -I http://localhost:80 2>&1 || echo "❌ 本地无法访问"
echo ""

# 5. 检查文件挂载
echo "【5】检查文件是否正确挂载..."
docker exec merlin-website ls -la /usr/share/nginx/html/template/Merlinsite/
echo ""

# 6. 检查 Nginx 配置
echo "【6】检查 Nginx 配置语法..."
docker exec merlin-website nginx -t
echo ""

# 7. 检查 Nginx 进程
echo "【7】检查 Nginx 进程..."
docker exec merlin-website ps aux | grep nginx
echo ""

# 8. 检查监听端口
echo "【8】检查容器内监听端口..."
docker exec merlin-website netstat -tlnp || docker exec merlin-website ss -tlnp
echo ""

# 9. 检查主机防火墙
echo "【9】检查主机防火墙规则..."
if command -v firewall-cmd &> /dev/null; then
    echo "--- firewalld (CentOS/RHEL) ---"
    sudo firewall-cmd --list-all 2>/dev/null || echo "需要 root 权限"
elif command -v ufw &> /dev/null; then
    echo "--- ufw (Ubuntu/Debian) ---"
    sudo ufw status verbose 2>/dev/null || echo "需要 root 权限"
else
    echo "未检测到常见防火墙工具"
fi
echo ""

# 10. 检查 iptables 规则
echo "【10】检查 iptables 中关于 80 端口的规则..."
sudo iptables -L -n | grep -E "(80|DOCKER)" | head -10 || echo "需要 root 权限查看完整规则"
echo ""

echo "=========================================="
echo "  诊断完成！请将输出结果发给我分析"
echo "=========================================="
