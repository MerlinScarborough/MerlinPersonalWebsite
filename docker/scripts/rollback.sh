#!/bin/bash

# ============================================================
#  Merlin 网站 - 版本回滚工具
#  功能：查看备份列表，一键回滚到指定版本
# ============================================================

set -e

PROJECT_DIR="/root/apps/MerlinPersonalWebsite"
BACKUP_DIR="${PROJECT_DIR}/docker/backups"

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[ROLLBACK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# 列出所有可用备份
list_backups() {
    echo ""
    echo "=========================================="
    echo "  📦 可用备份列表"
    echo "=========================================="
    echo ""
    
    if [ ! -d "${BACKUP_DIR}" ] || [ -z "$(ls -A ${BACKUP_DIR}/*.tar.gz 2>/dev/null)" ]; then
        warn "⚠️ 没有找到任何备份！"
        return 1
    fi
    
    local i=1
    for backup in $(ls -1t ${BACKUP_DIR}/backup_*.tar.gz 2>/dev/null); do
        FILENAME=$(basename "$backup")
        TIMESTAMP=$(echo "${FILENAME}" | sed 's/backup_\(.*\)\.tar.gz/\1/')
        SIZE=$(du -h "$backup" | awk '{print $1}')
        DATE=$(date -d "${TIMESTAMP:0:8} ${TIMESTAMP:9:2}:${TIMESTAMP:11:2}:${TIMESTAMP:13:2}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "${TIMESTAMP}")
        
        printf "  [%2d] %s  (大小: %s, 时间: %s)\n" "$i" "${FILENAME}" "${SIZE}" "${DATE}"
        i=$((i + 1))
    done
    
    echo ""
    info "共 $(((i-1))) 个备份可用"
    echo ""
}

# 回滚到指定版本
rollback_to() {
    local BACKUP_NUM=$1
    
    # 获取备份文件列表（按时间倒序）
    mapfile -t BACKUPS < <(ls -1t ${BACKUP_DIR}/backup_*.tar.gz 2>/dev/null)
    
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        error "没有可用的备份！"
        exit 1
    fi
    
    if [ -z "${BACKUP_NUM}" ] || [ "${BACKUP_NUM}" -lt 1 ] || [ "${BACKUP_NUM}" -gt ${#BACKUPS[@]} ]; then
        error "无效的备份编号: ${BACKUP_NUM}"
        info "请使用 'list' 命令查看可用备份"
        exit 1
    fi
    
    local SELECTED_BACKUP=${BACKUPS[$((BACKUP_NUM - 1))]}
    local FILENAME=$(basename "${SELECTED_BACKUP}")
    
    warn "⚠️ 警告：此操作将覆盖当前文件！"
    warn "目标备份: ${FILENAME}"
    echo ""
    read -p "确认回滚？输入 'yes' 继续: " confirm
    
    if [ "${confirm}" != "yes" ]; then
        log "已取消回滚操作"
        return 0
    fi
    
    log "🔄 开始回滚..."
    
    # 创建当前版本的紧急备份
    EMERGENCY_BACKUP="${BACKUP_DIR}/pre_rollback_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "${EMERGENCY_BACKUP}" \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='__pycache__' \
        template/ docker/*.yml docker/*.conf 2>/dev/null || true
    
    log "✅ 已创建回滚前备份: $(basename ${EMERGENCY_BACKUP})"
    
    # 解压选定的备份
    tar -xzf "${SELECTED_BACKUP}" -C "${PROJECT_DIR}"
    
    log "✅ 回滚完成！"
    log "📝 已恢复到备份: ${FILENAME}"
    
    # 验证关键文件
    if [ -f "${PROJECT_DIR}/template/Merlinsite/index.html" ]; then
        pass "验证通过：index.html 存在"
    else
        error "验证失败：关键文件缺失！"
        error "正在恢复回滚前状态..."
        tar -xzf "${EMERGENCY_BACKUP}" -C "${PROJECT_DIR}"
        error "已恢复到回滚前的状态"
        exit 1
    fi
    
    echo ""
    log "🎉 回滚成功！刷新页面即可看到旧版本"
}

# 清理旧备份
cleanup() {
    log "🧹 清理旧备份..."
    
    DEFAULT_KEEP=5
    read -p "保留最近几个备份？(默认 ${DEFAULT_KEEP}): " KEEP_COUNT
    KEEP_COUNT=${KEEP_COUNT:-$DEFAULT_KEEP}
    
    TOTAL=$(ls -1 ${BACKUP_DIR}/backup_*.tar.gz 2>/dev/null | wc -l)
    
    if [ "${TOTAL}" -le "${KEEP_COUNT}" ]; then
        info "当前只有 ${TOTAL} 个备份，无需清理"
        return 0
    fi
    
    DELETE_COUNT=$((TOTAL - KEEP_COUNT))
    ls -1t ${BACKUP_DIR}/backup_*.tar.gz | tail -n $((KEEP_COUNT + 1)) | while read backup; do
        rm -f "$backup"
        info "已删除: $(basename $backup)"
    done
    
    log "✅ 已清理 ${DELETE_COUNT} 个旧备份，保留最新 ${KEEP_COUNT} 个"
}

pass() { echo -e "${GREEN}✅${NC} $1"; }

case "${1:-help}" in
    list|l)
        list_backups
        ;;
    rollback|r)
        if [ -n "$2" ]; then
            rollback_to "$2"
        else
            list_backups
            echo ""
            read -p "请输入要回到的备份编号: " num
            rollback_to "$num"
        fi
        ;;
    cleanup|c)
        cleanup
        ;;
    help|--help|-h)
        echo ""
        echo "⏪ Merlin 网站版本回滚工具"
        echo "==============================="
        echo ""
        echo "用法: $0 <命令> [参数]"
        echo ""
        echo "命令:"
        echo "  list|l     📋  列出所有可用备份"
        echo "  rollback|r ⏪  回滚到指定版本（需提供编号）"
        echo "  cleanup|c  🧹  清理旧备份"
        echo ""
        echo "示例:"
        echo "  $0 list              # 查看所有备份"
        echo "  $0 rollback 2        # 回滚到第 2 个备份"
        echo "  $0 r 3               # 同上（简写）"
        echo "  $0 cleanup           # 清理旧备份"
        echo ""
        ;;
    *)
        error "未知命令: $1"
        echo "使用 '$0 help' 查看帮助"
        exit 1
        ;;
esac
