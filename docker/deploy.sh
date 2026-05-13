#!/bin/bash

# ============================================================
#  Merlin 网站 - 自动部署系统 v1.0
#  功能：Git 拉取 → 热更新 → 健康检查 → 失败回滚
#  作者：Merlin TA
#  日期：2026-05-13
# ============================================================

set -e  # 遇到错误立即退出

# ==================== 配置区（可自定义）====================
PROJECT_NAME="merlin-website"
PROJECT_DIR="/root/apps/MerlinPersonalWebsite"
DOCKER_DIR="${PROJECT_DIR}/docker"
LOG_DIR="${DOCKER_DIR}/logs"
BACKUP_DIR="${DOCKER_DIR}/backups"
GIT_REPO_URL=""  # 留空则使用当前仓库
GIT_BRANCH="main"
CHECK_INTERVAL=300  # 自动检查间隔（秒），5分钟
MAX_BACKUPS=5       # 最大备份数量

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==================== 函数库 ====================

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 创建必要目录
init_dirs() {
    mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"
    touch "${LOG_DIR}/deploy.log"
}

# 日志记录
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_DIR}/deploy.log"
}

# ==================== 核心功能 ====================

# 功能 1: 初始化项目（首次部署）
init_project() {
    log "🚀 开始初始化项目..."
    
    # 检查目录是否存在
    if [ ! -d "${PROJECT_DIR}" ]; then
        mkdir -p "${PROJECT_DIR}"
    fi
    
    cd "${PROJECT_DIR}"
    
    # 如果是空目录或不是 Git 仓库，需要克隆
    if [ ! -d ".git" ]; then
        if [ -z "${GIT_REPO_URL}" ]; then
            error "❌ 未配置 Git 仓库地址！"
            error "请编辑此脚本，设置 GIT_REPO_URL 变量"
            exit 1
        fi
        
        info "正在克隆仓库: ${GIT_REPO_URL}"
        git clone -b "${GIT_BRANCH}" "${GIT_REPO_URL}" "."
    else
        info "Git 仓库已存在，跳过克隆"
    fi
    
    # 初始化 Docker
    init_docker
    
    log "✅ 项目初始化完成！"
    show_status
}

# 功能 2: 启动/重启 Docker 服务
init_docker() {
    log "🐳 启动 Docker 服务..."
    
    cd "${DOCKER_DIR}"
    
    # 停止旧容器（如果存在）
    if docker ps -a | grep -q "${PROJECT_NAME}"; then
        info "发现旧容器，正在停止..."
        docker-compose down 2>/dev/null || true
    fi
    
    # 启动新容器
    docker-compose up -d
    
    # 等待服务就绪
    sleep 5
    
    # 健康检查
    if check_health; then
        log "✅ Docker 服务启动成功！"
    else
        error "❌ Docker 服务启动失败！"
        error "请查看日志: docker logs ${PROJECT_NAME}"
        exit 1
    fi
}

# 功能 3: 检查并应用更新（核心功能）
check_and_update() {
    log "🔄 开始检查更新..."
    
    cd "${PROJECT_DIR}"
    
    # 记录当前版本
    CURRENT_COMMIT=$(git rev-parse --short HEAD)
    info "当前版本: ${CURRENT_COMMIT}"
    
    # 获取远程更新
    git fetch origin "${GIT_BRANCH}"
    
    # 检查是否有更新
    LOCAL=$(git rev-parse "@")
    REMOTE=$(git rev-parse "@{u}")
    BASE=$(git merge-base @ "@{u}")
    
    if [ "$LOCAL" = "$REMOTE" ]; then
        log "✅ 已经是最新版本 (${CURRENT_COMMIT})"
        return 0
    elif [ "$LOCAL" = "$BASE" ]; then
        warn "⚠️ 发现新版本，准备更新..."
        
        # 备份当前版本
        backup_current_version
        
        # 拉取更新
        pull_updates
        
        # 验证更新
        verify_update
        
        log "✅ 更新完成！新版本: $(git rev-parse --short HEAD)"
        
        # 发送通知（可选）
        send_notification "success" "网站已更新到最新版本"
        
    elif [ "$REMOTE" = "$BASE" ]; then
        warn "⚠️ 本地有未推送的提交"
        return 2
    else
        error "❌ 分支分歧，需要手动处理"
        return 1
    fi
}

# 备份当前版本
backup_current_version() {
    log "💾 备份当前版本..."
    
    BACKUP_TIME=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="${BACKUP_DIR}/backup_${BACKUP_TIME}.tar.gz"
    
    # 只备份关键文件（不包含 .git 和 node_modules 等）
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
    
    # 清理旧备份（保留最近 N 个）
    cleanup_old_backups
}

# 清理旧备份
cleanup_old_backups() {
    BACKUP_COUNT=$(ls -1 "${BACKUP_DIR}"/backup_*.tar.gz 2>/dev/null | wc -l)
    
    if [ "${BACKUP_COUNT}" -gt "${MAX_BACKUPS}" ]; then
        info "清理旧备份，保留最近 ${MAX_BACKUPS} 个..."
        ls -1t "${BACKUP_DIR}"/backup_*.tar.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f
        log "✅ 旧备份已清理"
    fi
}

# 拉取更新
pull_updates() {
    log "📥 正在拉取更新..."
    
    git pull origin "${GIT_BRANCH}"
    
    log_to_file "成功拉取更新到 $(git rev-parse --short HEAD)"
}

# 验证更新
verify_update() {
    log "✅ 验证文件完整性..."
    
    # 检查关键文件是否存在
    CRITICAL_FILES=(
        "template/Merlinsite/index.html"
        "template/Merlinsite/style.css"
        "docker/docker-compose.yml"
        "docker/nginx.conf"
    )
    
    for file in "${CRITICAL_FILES[@]}"; do
        if [ ! -f "${PROJECT_DIR}/${file}" ]; then
            error "❌ 关键文件缺失: ${file}"
            error "正在回滚到上一个版本..."
            rollback_to_latest_backup
            exit 1
        fi
    done
    
    log "✅ 文件验证通过"
    
    # 因为使用 volume 挂载，Nginx 会自动读取新文件
    # 无需重启容器！这就是热更新的魅力 ✨
    log "🎉 热更新生效！刷新页面即可看到新版本"
}

# 功能 4: 健康检查
check_health() {
    log "🏥 执行健康检查..."
    
    # 检查容器是否运行
    if ! docker ps | grep -q "${PROJECT_NAME}"; then
        error "❌ 容器未运行"
        return 1
    fi
    
    # 测试 HTTP 访问
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80 || echo "000")
    
    if [[ "${HTTP_CODE}" =~ ^(200|301|302)$ ]]; then
        log "✅ 健康检查通过 (HTTP ${HTTP_CODE})"
        return 0
    else
        error "❌ 健康检查失败 (HTTP ${HTTP_CODE})"
        return 1
    fi
}

# 功能 5: 回滚到上一版本
rollback_to_latest_backup() {
    log "⏪ 正在回滚..."
    
    # 找到最新的备份
    LATEST_BACKUP=$(ls -1t "${BACKUP_DIR}"/backup_*.tar.gz 2>/dev/null | head -n 1)
    
    if [ -z "${LATEST_BACKUP}" ]; then
        error "❌ 没有找到可用的备份！"
        exit 1
    fi
    
    info "恢复备份: $(basename ${LATEST_BACKUP})"
    
    # 解压备份（覆盖当前文件）
    tar -xzf "${LATEST_BACKUP}" -C "${PROJECT_DIR}"
    
    log "✅ 回滚完成！"
    send_notification "warning" "网站已回滚到上一版本"
}

# 功能 6: 显示状态
show_status() {
    echo ""
    echo "=========================================="
    echo "  📊 Merlin 网站状态面板"
    echo "=========================================="
    echo ""
    
    # Git 信息
    if [ -d "${PROJECT_DIR}/.git" ]; then
        cd "${PROJECT_DIR}"
        echo "📌 Git 分支: $(git branch --show-current)"
        echo "📌 当前版本: $(git rev-parse --short HEAD)"
        echo "📌 最后提交: $(git log -1 --pretty=format:'%s (%cr)')"
        echo ""
    fi
    
    # Docker 信息
    if docker ps | grep -q "${PROJECT_NAME}"; then
        echo "🐳 容器状态: ✅ 运行中"
        CONTAINER_ID=$(docker ps -qf name=${PROJECT_NAME})
        echo "🐳 容器ID: ${CONTAINER_ID:0:12}"
        echo "🐳 运行时间: $(docker inspect --format='{{.State.StartedAt}}' ${CONTAINER_ID} | cut -d'T' -f2 | cut -d'.' -f1)"
        
        # 测试访问
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80 2>/dev/null || echo "000")
        if [[ "${HTTP_CODE}" =~ ^(200|301|302)$ ]]; then
            echo "🌐 网站访问: ✅ 正常 (HTTP ${HTTP_CODE})"
        else
            echo "🌐 网站访问: ❌ 异常 (HTTP ${HTTP_CODE})"
        fi
    else
        echo "🐳 容器状态: ❌ 未运行"
    fi
    
    echo ""
    echo "💾 备份数量: $(ls -1 ${BACKUP_DIR}/backup_*.tar.gz 2>/dev/null | wc -l || echo 0) 个"
    echo "📝 最近日志:"
    tail -n 5 "${LOG_DIR}/deploy.log" 2>/dev/null || echo "  (无日志)"
    echo ""
    echo "=========================================="
}

# 功能 7: 设置定时任务
setup_cron() {
    log "⏰ 设置自动检查定时任务..."
    
    CRON_JOB="*/5 * * * * cd ${PROJECT_DIR}/docker && bash ./deploy.sh auto >> ${LOG_DIR}/cron.log 2>&1"
    
    # 检查是否已存在
    (crontab -l 2>/dev/null | grep -F "${PROJECT_NAME}") && warn "定时任务已存在" || (
        (crontab -l 2>/dev/null; echo "${CRON_JOB}") | crontab -
        log "✅ 定时任务已设置（每 5 分钟检查一次）"
    )
    
    # 显示当前 crontab
    echo ""
    info "当前的 Crontab 任务:"
    crontab -l | grep -F "${PROJECT_NAME}" || warn "未找到相关任务"
}

# 功能 8: 移除定时任务
remove_cron() {
    log "🗑️ 移除定时任务..."
    
    crontab -l 2>/dev/null | grep -v -F "${PROJECT_NAME}" | crontab -
    log "✅ 定时任务已移除"
}

# 发送通知（可选实现）
send_notification() {
    STATUS="$1"
    MESSAGE="$2"
    
    # 这里可以接入钉钉、企业微信、邮件等通知渠道
    # 示例：钉钉机器人 Webhook
    # curl -X POST 'https://oapi.dingtalk.com/robot/send?access_token=xxx' \
    #     -H 'Content-Type: application/json' \
    #     -d "{\"msgtype\": \"text\", \"text\": {\"content\": \"Merlin网站部署通知: ${MESSAGE}\"}}"
    
    log "📢 通知: [${STATUS}] ${MESSAGE}"
}

# ==================== 主程序 ====================

main() {
    init_dirs
    
    case "${1:-help}" in
        init)
            init_project
            ;;
        start)
            init_docker
            ;;
        update|u)
            check_and_update
            ;;
        auto)
            # 自动模式（供 Cron 使用，静默运行）
            check_and_update >> "${LOG_DIR}/deploy.log" 2>&1
            ;;
        status|s)
            show_status
            ;;
        health|h)
            check_health
            exit $?
            ;;
        rollback|r)
            rollback_to_latest_backup
            ;;
        logs)
            tail -f "${LOG_DIR}/deploy.log"
            ;;
        cron-on)
            setup_cron
            ;;
        cron-off)
            remove_cron
            ;;
        restart)
            log "🔄 重启服务..."
            cd "${DOCKER_DIR}"
            docker-compose restart
            sleep 3
            check_health
            ;;
        help|--help|-h)
            echo ""
            echo "🚀 Merlin 网站部署工具 v1.0"
            echo "=========================================="
            echo ""
            echo "用法: $0 <命令>"
            echo ""
            echo "命令:"
            echo "  init      🎬  首次初始化项目（克隆代码 + 启动 Docker）"
            echo "  start     ▶️   启动/重启 Docker 服务"
            echo "  update/u  🔄  检查并应用 Git 更新（热更新）"
            echo "  auto      🤖  自动模式（供 Cron 调用，静默执行）"
            echo "  status/s  📊  显示系统状态面板"
            echo "  health/h  🏥  执行健康检查"
            echo "  rollback/r ⏪  回滚到上一版本"
            echo "  logs      📝  查看实时日志"
            echo "  cron-on   ⏰  开启定时自动检查（每5分钟）"
            echo "  cron-off  ⏸️   关闭定时任务"
            echo "  restart   🔄  重启 Docker 服务"
            echo "  help      ❓  显示帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 init              # 首次部署"
            echo "  $0 update            # 手动更新"
            echo "  $0 status            # 查看状态"
            echo "  $0 cron-on           # 开启自动更新"
            echo ""
            ;;
        *)
            error "未知命令: $1"
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
