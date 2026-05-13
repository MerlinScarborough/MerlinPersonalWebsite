#!/bin/bash

# ============================================================
#  Merlin 网站 - 健康检查工具
#  功能：全面检查系统状态，生成报告
# ============================================================

CONTAINER_NAME="merlin-website"
PROJECT_DIR="/root/apps/MerlinPersonalWebsite"

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass() { echo -e "${GREEN}✅ PASS${NC}  $1"; }
fail() { echo -e "${RED}❌ FAIL${NC}  $1"; }
warn() { echo -e "${YELLOW}⚠️  WARN${NC}  $1"; }
info() { echo -e "${BLUE}ℹ️  INFO${NC}  $1"; }

SCORE=0
TOTAL=0

# 计分
add_score() {
    TOTAL=$((TOTAL + 1))
    if [ "$1" = "pass" ]; then
        SCORE=$((SCORE + 1))
    fi
}

echo ""
echo "=========================================="
echo "  🏥 Merlin 网站健康检查报告"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 1. Docker 服务状态
echo "📦 [1/7] Docker 服务"
if systemctl is-active --quiet docker; then
    pass "Docker 守护进程运行中"
    add_score "pass"
else
    fail "Docker 守护进程未运行"
    add_score "fail"
fi

# 2. 容器运行状态
echo ""
echo "🐳 [2/7] 容器状态"
if docker ps | grep -q "${CONTAINER_NAME}"; then
    pass "容器 ${CONTAINER_NAME} 运行中"
    add_score "pass"
    
    # 获取容器详细信息
    CONTAINER_ID=$(docker ps -qf name=${CONTAINER_NAME})
    info "容器ID: ${CONTAINER_ID:0:12}"
    
    UPTIME=$(docker inspect --format='{{.State.StartedAt}}' ${CONTAINER_ID} 2>/dev/null | cut -d'T' -f2 | cut -d'.' -f1)
    info "启动时间: ${UPTIME}"
    
    # 内存使用
    MEM_USAGE=$(docker stats --no-stream --format '{{.MemUsage}}' ${CONTAINER_ID} 2>/dev/null || echo "N/A")
    info "内存占用: ${MEM_USAGE}"
else
    fail "容器未运行或不存在"
    add_score "fail"
fi

# 3. 端口监听
echo ""
echo "🔌 [3/7] 网络端口"
if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
    pass "端口 80 正在监听"
    add_score "pass"
elif ss -tlnp 2>/dev/null | grep -q ":80 "; then
    pass "端口 80 正在监听"
    add_score "pass"
else
    fail "端口 80 未监听"
    add_score "fail"
fi

# 4. HTTP 响应测试
echo ""
echo "🌐 [4/7] HTTP 访问"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://localhost:80 2>/dev/null || echo "000")
RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" --connect-timeout 5 http://localhost:80 2>/dev/null || echo "0")

if [[ "${HTTP_CODE}" =~ ^(200|301|302)$ ]]; then
    pass "HTTP 状态正常 (${HTTP_CODE})"
    add_score "pass"
    info "响应时间: ${RESPONSE_TIME}s"
    
    if (( $(echo "${RESPONSE_TIME} < 1.0" | bc -l) )); then
        pass "响应速度优秀 (< 1秒)"
        add_score "pass"
    elif (( $(echo "${RESPONSE_TIME} < 3.0" | bc -l) )); then
        warn "响应速度一般 (1-3秒)"
        add_score "pass"
    else
        warn "响应较慢 (> 3秒)"
        add_score "pass"
    fi
else
    fail "HTTP 异常 (状态码: ${HTTP_CODE})"
    add_score "fail"
fi

# 5. 文件系统检查
echo ""
echo "📂 [5/7] 文件完整性"
CRITICAL_FILES=(
    "${PROJECT_DIR}/template/Merlinsite/index.html"
    "${PROJECT_DIR}/template/Merlinsite/style.css"
    "${PROJECT_DIR}/template/Merlinsite/js/main.js"
    "${PROJECT_DIR}/template/Merlinsite/js/data.js"
)

ALL_FILES_OK=true
for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        FILE_SIZE=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
        info "✓ $(basename $file) (${FILE_SIZE} bytes)"
    else
        fail "✗ 缺失: $file"
        ALL_FILES_OK=false
    fi
done

if [ "${ALL_FILES_OK}" = true ]; then
    pass "所有关键文件存在"
    add_score "pass"
else
    fail "存在缺失文件"
    add_score "fail"
fi

# 6. Git 仓库状态
echo ""
echo "📚 [6/7] Git 仓库"
if [ -d "${PROJECT_DIR}/.git" ]; then
    pass "Git 仓库正常"
    add_score "pass"
    
    cd "${PROJECT_DIR}"
    BRANCH=$(git branch --show-current)
    COMMIT=$(git rev-parse --short HEAD)
    info "分支: ${BRANCH}"
    info "版本: ${COMMIT}"
    
    if git diff --quiet; then
        pass "工作区干净（无未提交修改）"
        add_score "pass"
    else
        warn "工作区有未提交的修改"
        add_score "pass"
    fi
else
    fail "Git 仓库异常"
    add_score "fail"
fi

# 7. 磁盘空间
echo ""
echo "💾 [7/7] 系统资源"
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
MEM_TOTAL=$(free -h | awk '/^Mem:/{print $2}')
MEM_USED=$(free -h | awk '/^Mem:/{print $3}')
MEM_PERCENT=$(free | awk '/^Mem:/{printf "%.0f", $3/$2 * 100}')

info "磁盘使用: ${DISK_USAGE}%"
info "内存使用: ${MEM_USED} / ${MEM_TOTAL} (${MEM_PERCENT}%)"

if [ "${DISK_USAGE}" -lt 80 ]; then
    pass "磁盘空间充足 (< 80%)"
    add_score "pass"
elif [ "${DISK_USAGE}" -lt 90 ]; then
    warn "磁盘使用率较高 (${DISK_USAGE}%)"
    add_score "pass"
else
    fail "磁盘空间不足 (> 90%)"
    add_score "fail"
fi

if [ "${MEM_PERCENT}" -lt 80 ]; then
    pass "内存充足 (< 80%)"
    add_score "pass"
else
    warn "内存使用率较高 (${MEM_PERCENT}%)"
    add_score "pass"
fi

# 总结
echo ""
echo "=========================================="
PERCENT=$((SCORE * 100 / TOTAL))
if [ "${PERCENT}" -ge 90 ]; then
    echo -e "${GREEN}🎉 总体评分: ${SCORE}/${TOTAL} (${PERCENT}%)" 
    echo -e "   系统运行状况: 优秀${NC}"
elif [ "${PERCENT}" -ge 70 ]; then
    echo -e "${YELLOW}📊 总体评分: ${SCORE}/${TOTAL} (${PERCENT}%)"
    echo -e "   系统运行状况: 良好${NC}"
else
    echo -e "${RED}⚠️  总体评分: ${SCORE}/${TOTAL} (${PERCENT}%)"
    echo -e "   系统运行状况: 需要关注${NC}"
fi
echo "=========================================="

# 返回退出码（供其他脚本调用）
if [ "${PERCENT}" -ge 70 ]; then
    exit 0
else
    exit 1
fi
