#!/bin/bash

# ============================================================
#  Merlin 网站 - Git 更新工具
#  功能：智能拉取更新，处理冲突，支持强制更新
# ============================================================

set -e

PROJECT_DIR="/root/apps/MerlinPersonalWebsite"
BRANCH="main"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[UPDATE]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

cd "${PROJECT_DIR}" || exit 1

# 显示当前状态
show_status() {
    echo ""
    log "📌 当前分支: $(git branch --show-current)"
    log "📌 当前版本: $(git rev-parse --short HEAD)"
    log "📌 最后提交: $(git log -1 --pretty=format:'%s (%cr)')"
    
    # 检查是否有未提交的更改
    if ! git diff --quiet; then
        warn "⚠️ 有未提交的本地修改"
        git status --short
    fi
    
    # 检查远程更新
    git fetch origin "${BRANCH}" 2>/dev/null
    
    LOCAL=$(git rev-parse "@")
    REMOTE=$(git rev-parse "@{u}")
    
    if [ "$LOCAL" = "$REMOTE" ]; then
        log "✅ 已是最新版本"
    else
        BEHIND=$(git rev-list --count "$LOCAL".."$REMOTE")
        warn "⚠️ 落后 ${BEHIND} 个提交"
    fi
}

# 安全更新（保留本地修改）
safe_update() {
    log "🔄 正在安全更新..."
    
    # 先暂存本地修改
    if ! git diff --quiet; then
        log "💾 暂存本地修改..."
        git stash
    fi
    
    # 拉取更新
    git pull origin "${BRANCH}"
    
    # 恢复暂存的修改
    if git stash list | grep -q "stash@{0}"; then
        log "📤 恢复本地修改..."
        git stash pop
    fi
    
    log "✅ 更新完成！"
}

# 强制更新（丢弃本地修改）
force_update() {
    warn "⚠️ 警告：这将丢弃所有本地修改！"
    read -p "确认继续？(y/n): " confirm
    
    if [ "$confirm" != "y" ]; then
        log "已取消"
        exit 0
    fi
    
    log "💥 正在强制更新..."
    git reset --hard origin/"${BRANCH}"
    git clean -fd
    
    log "✅ 强制更新完成！"
}

# 查看更新日志
show_changelog() {
    log "📋 最近 10 条更新记录:"
    echo ""
    git log --oneline -10
    echo ""
    
    # 显示差异统计
    if command -v git-diffstat &> /dev/null; then
        log "📊 变更统计:"
        git diff --stat HEAD~10..HEAD 2>/dev/null || true
    fi
}

case "${1:-status}" in
    status|s)
        show_status
        ;;
    update|u)
        safe_update
        ;;
    force|f)
        force_update
        ;;
    log|l)
        show_changelog
        ;;
    *)
        echo "用法: $0 <命令>"
        echo ""
        echo "命令:"
        echo "  status/s   📊  查看当前状态"
        echo "  update/u   🔄  安全更新（保留本地修改）"
        echo "  force/f    💥  强制更新（丢弃本地修改）"
        echo "  log/l      📋  查看更新日志"
        ;;
esac
