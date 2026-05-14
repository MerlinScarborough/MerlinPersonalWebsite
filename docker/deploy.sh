#!/bin/bash

# ============================================================
#  Merlin 网站 - 手动部署工具 v2.0
#  功能：SFTP上传 → 备份 → 验证 → 热更新
#  作者：Merlin TA
#  日期：2026-05-14
# ============================================================

set -e

# ==================== 配置区 ====================
PROJECT_NAME="merlin-website"
PROJECT_DIR="/root/apps/MerlinPersonalWebsite"
DOCKER_DIR="${PROJECT_DIR}/docker"
LOG_DIR="${DOCKER_DIR}/logs"
BACKUP_DIR="${DOCKER_DIR}/backups"
MAX_BACKUPS=5

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

init_dirs() {
    mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"
    touch "${LOG_DIR}/deploy.log"
}

log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_DIR}/deploy.log"
}

# ==================== 核心功能 ====================

# 功能 1: 启动/重启 Docker 服务
start_docker() {
    log "🐳 启动 Docker 服务..."
    
    cd "${DOCKER_DIR}"
    
    if docker ps -a | grep -q "${PROJECT_NAME}"; then
        info "发现旧容器，正在停止..."
        docker-compose down 2>/dev/null || true
    fi
    
    docker-compose up -d
    sleep 5
    
    if check_health; then
        log "✅ Docker 服务启动成功！"
        log_to_file "Docker 服务启动成功"
    else
        error "❌ Docker 服务启动失败！"
        error "请查看日志: docker logs ${PROJECT_NAME}"
        exit 1
    fi
}

# 功能 2: 部署新版本（SFTP上传后执行此命令）
deploy_new_version() {
    log "🚀 开始部署新版本..."
    log "📝 请确保你已经通过 SFTP 上传了新的文件！"
    echo ""
    
    # 步骤 1: 备份当前版本
    backup_current_version
    
    # 步骤 2: 验证文件完整性
    verify_files
    
    # 步骤 3: 热更新生效（无需重启容器）
    log "🎉 部署完成！热更新已生效！"
    log "🌐 刷新浏览器即可看到新版本"
    
    log_to_file "成功部署新版本"
    
    # 发送通知
    send_notification "success" "网站已更新到新版本"
}

# 备份当前版本
backup_current_version() {
    log "💾 备份当前版本..."
    
    BACKUP_TIME=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="${BACKUP_DIR}/backup_${BACKUP_TIME}.tar.gz"
    
    tar -czf "${BACKUP_FILE}" \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='__pycache__' \
        --exclude='.venv' \
        --exclude='*.log' \
        --exclude='docker/logs' \
        --exclude='docker/backups' \
        template/ docker/*.yml docker/*.conf 2>/dev/null || true
    
    log "✅ 已备份到: ${BACKUP_FILE}"
    
    cleanup_old_backups
}

cleanup_old_backups() {
    BACKUP_COUNT=$(ls -1 "${BACKUP_DIR}"/backup_*.tar.gz 2>/dev/null | wc -l)
    
    if [ "${BACKUP_COUNT}" -gt "${MAX_BACKUPS}" ]; then
        info "清理旧备份，保留最近 ${MAX_BACKUPS} 个..."
        ls -1t "${BACKUP_DIR}"/backup_*.tar.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f
        log "✅ 旧备份已清理"
    fi
}

# 验证文件完整性
verify_files() {
    log "✅ 验证文件完整性..."
    
    CRITICAL_FILES=(
        "template/Merlinsite/index.html"
        "template/Merlinsite/style.css"
        "docker/docker-compose.yml"
        "docker/nginx.conf"
    )
    
    for file in "${CRITICAL_FILES[@]}"; do
        if [ ! -f "${PROJECT_DIR}/${file}" ]; then
            error "❌ 关键文件缺失: ${file}"
            error "⚠️ 请检查 SFTP 是否上传完整！"
            exit 1
        else
            info "✓ $(basename $file) 存在"
        fi
    done
    
    log "✅ 所有文件验证通过"
}

# 功能 3: 健康检查
check_health() {
    log "🏥 执行健康检查..."
    
    if ! docker ps | grep -q "${PROJECT_NAME}"; then
        error "❌ 容器未运行"
        return 1
    fi
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80 || echo "000")
    
    if [[ "${HTTP_CODE}" =~ ^(200|301|302)$ ]]; then
        log "✅ 健康检查通过 (HTTP ${HTTP_CODE})"
        return 0
    else
        error "❌ 健康检查失败 (HTTP ${HTTP_CODE})"
        return 1
    fi
}

# 功能 4: 回滚到上一版本
rollback_to_latest_backup() {
    log "⏪ 正在回滚..."
    
    LATEST_BACKUP=$(ls -1t "${BACKUP_DIR}"/backup_*.tar.gz 2>/dev/null | head -n 1)
    
    if [ -z "${LATEST_BACKUP}" ]; then
        error "❌ 没有找到可用的备份！"
        exit 1
    fi
    
    warn "⚠️ 警告：将恢复到上一个版本！"
    read -p "确认回滚？(y/n): " confirm
    
    if [ "$confirm" != "y" ]; then
        log "已取消"
        return 0
    fi
    
    info "恢复备份: $(basename ${LATEST_BACKUP})"
    
    tar -xzf "${LATEST_BACKUP}" -C "${PROJECT_DIR}"
    
    log "✅ 回滚完成！刷新页面即可看到旧版本"
    send_notification "warning" "网站已回滚到上一版本"
}

# 功能 5: 显示状态
show_status() {
    echo ""
    echo "=========================================="
    echo "  📊 Merlin 网站状态面板"
    echo "=========================================="
    echo ""
    
    if docker ps | grep -q "${PROJECT_NAME}"; then
        echo "🐳 容器状态: ✅ 运行中"
        CONTAINER_ID=$(docker ps -qf name=${PROJECT_NAME})
        echo "🐳 容器ID: ${CONTAINER_ID:0:12}"
        
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80 2>/dev/null || echo "000")
        if [[ "${HTTP_CODE}" =~ ^(200|301|302)$ ]]; then
            echo "🌐 网站访问: ✅ 正常 (HTTP ${HTTP_CODE})"
        else
            echo "🌐 网站访问: ❌ 异常 (HTTP ${HTTP_CODE})"
        fi
        
        MEM_USAGE=$(docker stats --no-stream --format '{{.MemUsage}}' ${CONTAINER_ID} 2>/dev/null || echo "N/A")
        echo "💾 内存占用: ${MEM_USAGE}"
    else
        echo "🐳 容器状态: ❌ 未运行"
    fi
    
    echo ""
    echo "📂 文件目录: ${PROJECT_DIR}"
    echo "📦 备份数量: $(ls -1 ${BACKUP_DIR}/backup_*.tar.gz 2>/dev/null | wc -l || echo 0) 个"
    
    if [ -f "${PROJECT_DIR}/template/Merlinsite/index.html" ]; then
        INDEX_SIZE=$(stat -c%s "${PROJECT_DIR}/template/Merlinsite/index.html" 2>/dev/null || stat -f%z "${PROJECT_DIR}/template/Merlinsite/index.html")
        MOD_TIME=$(stat -c%y "${PROJECT_DIR}/template/Merlinsite/index.html" 2>/dev/null | cut -d'.' -f1)
        echo "📄 index.html: ${INDEX_SIZE} bytes (${MOD_TIME})"
    fi
    
    echo ""
    echo "📝 最近日志:"
    tail -n 3 "${LOG_DIR}/deploy.log" 2>/dev/null || echo "  (无日志)"
    echo ""
    echo "=========================================="
}

# 发送通知（可选实现）
send_notification() {
    STATUS="$1"
    MESSAGE="$2"
    
    log "📢 通知: [${STATUS}] ${MESSAGE}"
}

# ==================== 主程序 ====================

main() {
    init_dirs
    
    case "${1:-help}" in
        start|s)
            start_docker
            ;;
        deploy|d)
            deploy_new_version
            ;;
        status|st)
            show_status
            ;;
        health|h)
            check_health
            exit $?
            ;;
        rollback|r)
            rollback_to_latest_backup
            ;;
        logs|l)
            tail -f "${LOG_DIR}/deploy.log"
            ;;
        restart)
            log "🔄 重启服务..."
            cd "${DOCKER_DIR}"
            docker-compose restart
            sleep 3
            check_health
            ;;
        backup|b)
            backup_current_version
            log "✅ 手动备份完成"
            ;;
        help|--help|-h)
            echo ""
            echo "🚀 Merlin 网站手动部署工具 v2.0"
            echo "=========================================="
            echo ""
            echo "用法: $0 <命令>"
            echo ""
            echo "📋 部署流程:"
            echo "  1️⃣  通过 SFTP 上传新文件到服务器"
            echo "      目录: ${PROJECT_DIR}"
            echo "  2️⃣  运行: ./deploy.sh deploy"
            echo "  3️⃣  刷新浏览器查看效果 ✨"
            echo ""
            echo "🎯 命令列表:"
            echo "  deploy/d  🚀  部署新版本（备份+验证+热更新）"
            echo "  start/s   ▶️   启动 Docker 服务"
            echo "  status/st 📊  显示系统状态面板"
            echo "  health/h  🏥  执行健康检查"
            echo "  rollback/r ⏪  回滚到上一版本"
            echo "  backup/b  💾  手动创建备份"
            echo "  logs/l    📝  查看实时日志"
            echo "  restart   🔄  重启 Docker 服务"
            echo "  help      ❓  显示帮助信息"
            echo ""
            echo "📝 示例:"
            echo "  $0 deploy           # SFTP上传后执行部署"
            echo "  $0 status           # 查看当前状态"
            echo "  $0 rollback         # 出问题时回滚"
            echo "  $0 backup           # 大改动前先备份"
            echo ""
            ;;
        *)
            error "未知命令: $1"
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"
