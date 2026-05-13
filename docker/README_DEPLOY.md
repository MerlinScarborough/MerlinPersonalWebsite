# 🚀 Merlin 网站 - Git 自动部署系统 完全指南

> **版本**: v1.0  
> **更新**: 2026-05-13  
> **适用场景**: 纯静态网站 + Docker + Nginx 热更新

---

## 📚 目录

1. [技术栈与知识体系](#-技术栈与知识体系)
2. [工作原理](#-工作原理)
3. [快速开始（5分钟上手）](#-快速开始5分钟上手)
4. [日常使用命令](#-日常使用命令)
5. [自动更新机制](#-自动更新机制)
6. [热更新原理](#-热更新原理)
7. [故障排查](#-故障排查)
8. [进阶配置](#-进阶配置)

---

## 🎓 技术栈与知识体系

### 必须掌握的技能

#### 1️⃣ **Git 基础**（必须）
```bash
git clone <url>      # 克隆仓库
git pull             # 拉取最新代码
git status           # 查看状态
git log              # 查看提交历史
git add / commit     # 提交更改（本地开发时）
```

**学习资源**：
- [Git 官方文档](https://git-scm.com/doc)（30分钟入门）
- [Pro Git 书籍](https://git-scm.com/book/zh/v2)（免费中文版）

#### 2️⃣ **Shell 脚本基础**（推荐）
- Bash 基本语法
- 变量、条件判断、循环
- 文件操作命令

**学习资源**：
- [Bash Guide for Beginners](https://tldp.org/LDP/Bash-Beginners-Guide/html/)

#### 3️⃣ **Linux 定时任务 Cron**（可选，但推荐了解）

**Cron 表达式格式**：
```
┌───────────── 分钟 (0 - 59)
│ ┌───────────── 小时 (0 - 23)
│ │ ┌───────────── 日期 (1 - 31)
│ │ │ ┌───────────── 月份 (1 - 12)
│ │ │ │ ┌───────────── 星期 (0 - 6, 0=周日)
│ │ │ │ │
* * * * *
```

**常用示例**：
```bash
*/5 * * * *    # 每5分钟执行一次
0 */2 * * *    # 每2小时执行一次
0 9 * * 1-5    # 工作日上午9点执行
```

---

## ⚙️ 工作原理

### 整体流程图

```
┌──────────────────────────────────────────────────────────────┐
│                    你的开发电脑 (本地)                         │
│                                                              │
│   修改代码 → git add → git commit → git push                 │
│                    ↓                                         │
│            GitHub/GitLab/Gitea                               │
│                    ↓                                         │
└────────────────────┼─────────────────────────────────────────┘
                     │ git pull
                     ↓
┌──────────────────────────────────────────────────────────────┐
│                  云服务器                                     │
│                                                              │
│  ┌─────────────────────────────────────────────┐            │
│  │         Cron 定时任务 (每5分钟)               │            │
│  │  或手动执行: ./deploy.sh update              │            │
│  └──────────────────┬──────────────────────────┘            │
│                     ↓                                       │
│  ┌─────────────────────────────────────────────┐            │
│  │        检查 Git 是否有新版本                  │            │
│  └──────────────────┬──────────────────────────┘            │
│                     ↓ 有更新                                  │
│  ┌─────────────────────────────────────────────┐            │
│  │  1. 备份当前版本 (tar.gz)                    │            │
│  │  2. git pull 拉取新代码                      │            │
│  │  3. 验证文件完整性                           │            │
│  │  4. ✨ 热更新生效 (无需重启！)                │            │
│  └─────────────────────────────────────────────┘            │
│                     ↓                                        │
│  ┌─────────────────────────────────────────────┐            │
│  │         Nginx 容器 (持续运行)                │            │
│  │   通过 Volume 挂载读取最新文件               │            │
│  │   用户刷新页面 → 立即看到新版本              │            │
│  └─────────────────────────────────────────────┘            │
└──────────────────────────────────────────────────────────────┘
```

### 核心优势：零停机热更新

```
传统部署方式:
  停服务 → 更新文件 → 重启服务 → 用户等待 ❌

你的部署方式:
  更新文件 → Nginx 自动读取 → 刷新即生效 ✅
```

**原因**：Nginx 作为静态文件服务器，每次请求都会重新读取磁盘上的文件，所以只要文件内容改变，下一个访问的用户就会看到新版本！

---

## 🚀 快速开始（5分钟上手）

### 前提条件

1. ✅ 已有 Git 仓库（GitHub/GitLab/Gitea 都可以）
2. ✅ 代码已推送到远程仓库
3. ✅ 服务器已安装 Docker
4. ✅ 网站当前正在运行（或已完成首次部署）

### 步骤 1: 上传部署脚本到服务器

**方法 A：通过 Git 克隆（推荐）**
```bash
# 在服务器上
cd /root/apps/MerlinPersonalWebsite/docker

# 如果你的代码已经在 Git 仓库中，脚本会自动存在
ls -la deploy.sh scripts/
```

**方法 B：手动上传**
```bash
# 本地打包
tar -czvf deploy-tools.tar.gz docker/deploy.sh docker/scripts/

# 上传到服务器
scp deploy-tools.tar.gz root@你的服务器IP:/root/apps/MerlinPersonalWebsite/

# 在服务器解压
ssh root@你的服务器IP
cd /root/apps/MerlinPersonalWebsite
tar -xzvf deploy-tools.tar.gz
```

### 步骤 2: 赋予执行权限

```bash
chmod +x docker/deploy.sh
chmod +x docker/scripts/*.sh
```

### 步骤 3: 配置 Git 仓库地址（如果还没配置）

编辑 `docker/deploy.sh`，找到第 15 行：

```bash
GIT_REPO_URL="https://github.com/你的用户名/MerlinPersonalWebsite.git"
```

### 步骤 4: 首次初始化（如果是全新服务器）

```bash
cd /root/apps/MerlinPersonalWebsite/docker
./deploy.sh init
```

这会自动完成：
- ✅ 克隆 Git 仓库
- ✅ 启动 Docker 容器
- ✅ 健康检查
- ✅ 显示状态面板

### 步骤 5: 测试手动更新

```bash
./deploy.sh update
```

### 步骤 6: 开启自动更新（可选）

```bash
./deploy.sh cron-on
```

---

## 📖 日常使用命令

### 主工具：deploy.sh

```bash
cd /root/apps/MerlinPersonalWebsite/docker

# ========== 基础操作 ==========
./deploy.sh status          # 查看系统状态面板
./deploy.sh health          # 执行健康检查
./deploy.sh logs            # 查看实时日志

# ========== 更新操作 ==========
./deploy.sh update          # 手动检查并应用更新（推荐）
./deploy.sh u               # 同上（简写）

# ========== 服务管理 ==========
./deploy.sh start           # 启动/重启 Docker
./deploy.sh restart         # 重启服务
./deploy.sh init            # 首次初始化

# ========== 版本管理 ==========
./deploy.sh rollback        # 回滚到上一版本
./deploy.sh r               # 同上（简写）

# ========== 自动化 ==========
./deploy.sh cron-on         # 开启定时自动检查
./deploy.sh cron-off        # 关闭定时任务

# ========== 帮助 ==========
./deploy.sh help            # 显示帮助信息
```

### 辅助工具：scripts/

```bash
# Git 更新工具
./scripts/update.sh status  # 查看 Git 状态
./scripts/update.sh update  # 安全更新
./scripts/update.sh force   # 强制更新（丢弃本地修改）
./scripts/update.sh log     # 查看提交历史

# 健康检查（详细版）
./scripts/healthcheck.sh    # 生成完整的健康报告

# 回滚工具
./scripts/rollback.sh list  # 列出所有备份
./scripts/rollback.sh r 2   # 回滚到第2个备份
./scripts/rollback.sh cleanup  # 清理旧备份
```

---

## ⏰ 自动更新机制

### 方式 1: Cron 定时任务（推荐）

**开启自动检查**：
```bash
./deploy.sh cron-on
```

这会在系统 Crontab 中添加一个任务：
```bash
*/5 * * * * cd /root/apps/MerlinPersonalWebsite/docker && bash ./deploy.sh auto >> /root/apps/MerlinPersonalWebsite/docker/logs/cron.log 2>&1
```

**含义**：每 5 分钟自动检查一次是否有新版本，如果有就自动更新。

**查看定时任务**：
```bash
crontab -l | grep merlin
```

**查看自动更新日志**：
```bash
tail -f /root/apps/MerlinPersonalWebsite/docker/logs/cron.log
```

**关闭自动更新**：
```bash
./deploy.sh cron-off
```

### 方式 2: Systemd Timer（更现代的方式）

创建 `/etc/systemd/system/merlin-update.timer`：
```ini
[Unit]
Description=Merlin Website Auto Update Timer

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
```

创建 `/etc/systemd/system/merlin-update.service`：
```ini
[Unit]
Description=Merlin Website Auto Update

[Service]
Type=oneshot
ExecStart=/root/apps/MerlinPersonalWebsite/docker/deploy.sh auto
WorkingDirectory=/root/apps/MerlinPersonalWebsite/docker
```

启用：
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now merlin-update.timer
sudo systemctl list-timers | grep merlin
```

### 方式 3: GitHub Webhooks（推送即部署）

如果你想要**推送代码后立即自动部署**（而不是等 5 分钟），可以使用 Webhooks。

**步骤**：
1. 在 GitHub 仓库设置 Webhook
2. 服务器上运行一个简单的 HTTP 服务接收通知
3. 收到通知后触发 `./deploy.sh update`

这个功能需要额外开发，我可以帮你实现，如果你需要的话。

---

## ✨ 热更新原理详解

### 为什么不需要重启容器？

```
传统应用架构:
┌─────────────┐     ┌─────────────┐
│   用户请求   │ --> │  Node.js 进程 │
└─────────────┘     └─────────────┘
                          ↑
                    代码加载到内存
                    修改后需重启才能生效 ❌

你的网站架构:
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   用户请求   │ --> │  Nginx 容器   │ --> │  磁盘文件     │
└─────────────┘     └─────────────┘     └─────────────┘
                          ↑                    ↑
                    持续运行不重启       修改文件即可生效 ✅
```

### Volume 挂载机制

在 `docker-compose.yml` 中：
```yaml
volumes:
  - ..:/usr/share/nginx/html:ro
```

这意味着：
- `..` = 服务器上的 `/root/apps/MerlinPersonalWebsite` 目录
- `/usr/share/nginx/html` = 容器内的目录
- `:ro` = 只读挂载（安全）

**每次用户访问网页时**：
1. Nginx 收到 HTTP 请求
2. 从挂载的目录读取 HTML/CSS/JS 文件
3. 返回给用户浏览器

**当你更新文件后**：
1. 你在本地修改代码并 push 到 Git
2. 服务器执行 `git pull` 更新了磁盘上的文件
3. 下一个用户访问时，Nginx 读取的就是新文件
4. **无需重启容器！**

### 验证热更新是否生效

```bash
# 方法 1: 修改文件后立即测试
echo "<!-- test $(date) -->" >> template/Merlinsite/index.html
curl http://localhost:80 | grep "test"

# 方法 2: 查看文件时间戳
ls -la template/Merlinsite/index.html
stat template/Merlinsite/index.html

# 方法 3: 使用浏览器开发者工具
# F12 -> Network -> 勾选 "Disable cache" -> 刷新页面
```

---

## 🔧 故障排查

### 问题 1: 自动更新没有生效

**检查项**：
```bash
# 1. Cron 任务是否存在？
crontab -l | grep merlin

# 2. 日志有无错误？
tail -50 docker/logs/cron.log

# 3. 手动执行能否正常工作？
./deploy.sh update

# 4. Git 配置是否正确？
cd /root/apps/MerlinPersonalWebsite
git remote -v
git branch --show-current
```

**常见原因及解决**：
| 原因 | 解决方案 |
|------|---------|
| Cron 未启动 | `sudo systemctl start crond` |
| 脚本无执行权限 | `chmod +x deploy.sh` |
| Git 仓库地址错误 | 编辑 `deploy.sh` 的 `GIT_REPO_URL` |
| 分支名称不对 | 编辑 `deploy.sh` 的 `GIT_BRANCH` |

### 问题 2: 更新后网站显示异常

**立即回滚**：
```bash
./deploy.sh rollback
```

或使用详细回滚工具：
```bash
./scripts/rollback.sh list        # 查看备份列表
./scripts/rollback.sh r 1        # 回滚到第1个备份
```

### 问题 3: Git 冲突

**情况 A：本地有未提交的修改**
```bash
# 查看冲突
cd /root/apps/MerlinPersonalWebsite
git status

# 选择 1：丢弃本地修改（推荐）
./scripts/update.sh force

# 选择 2：保留本地修改
./scripts/update.sh update  # 会自动 stash/pop
```

**情况 B：分支分歧**
```bash
# 这种情况需要手动处理
git fetch origin
git rebase origin/main
# 或
git merge origin/main
```

### 问题 4: 容器异常退出

```bash
# 查看容器日志
docker logs merlin-website

# 重启容器
./deploy.sh restart

# 如果还是不行，尝试完全重建
cd docker
docker-compose down
docker-compose up -d --build
```

---

## ⚙️ 进阶配置

### 自定义检查间隔

编辑 `deploy.sh` 第 18 行：
```bash
CHECK_INTERVAL=300  # 默认 300 秒（5分钟）
```

改为其他值：
```bash
CHECK_INTERVAL=60    # 1 分钟
CHECK_INTERVAL=1800  # 30 分钟
CHECK_INTERVAL=3600  # 1 小时
```

然后重新设置 Cron：
```bash
./deploy.sh cron-off
./deploy.sh cron-on
```

### 接入通知系统（钉钉/企业微信/邮件）

编辑 `deploy.sh` 的 `send_notification()` 函数：

**钉钉机器人示例**：
```bash
send_notification() {
    STATUS="$1"
    MESSAGE="$2"
    
    curl -s -X POST 'https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN' \
        -H 'Content-Type: application/json' \
        -d "{
            \"msgtype\": \"text\",
            \"text\": {
                \"content\": \"🚀 Merlin网站通知\n[${STATUS}] ${MESSAGE}\n时间: $(date)\"
            }
        }" > /dev/null 2>&1
}
```

**企业微信机器人示例**：
```bash
send_notification() {
    curl -s 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY' \
        -H 'Content-Type: application/json' \
        -d "{
            \"msgtype\": \"text\",
            \"text\": {
                \"content\": \"Merlin网站: ${MESSAGE}\"
            }
        }" > /dev/null 2>&1
}
```

### 多环境管理（测试/生产）

创建不同的配置文件：
```bash
# 生产环境
cp deploy.sh deploy-prod.sh
# 编辑 GIT_BRANCH="main"

# 测试环境
cp deploy.sh deploy-staging.sh
# 编辑 GIT_BRANCH="develop"
```

### 备份策略调整

编辑 `deploy.sh` 第 19 行：
```bash
MAX_BACKUPS=10  # 默认保留 5 个，改为 10 个
```

---

## 📊 典型工作流示例

### 场景 1: 日常维护

```bash
# 每天早上检查一次状态
./deploy.sh status

# 发现新版本，手动更新
./deploy.sh update

# 查看更新后的健康状态
./scripts/healthcheck.sh
```

### 场景 2: 发布新功能

```bash
# 本地开发完成
git add .
git commit -m "feat: 新增技能树动画效果"
git push origin main

# 等待 5 分钟（自动更新）
# 或立即手动触发
ssh root@服务器IP "cd /root/apps/MerlinPersonalWebsite/docker && ./deploy.sh update"

# 验证发布成功
curl https://你的域名
```

### 场景 3: 紧急修复 Bug

```bash
# 1. 本地快速修复
# 2. 紧急推送
git commit -m "fix: 修复首页样式问题"
git push origin main

# 3. 服务器立即更新
ssh root@服务器IP "./deploy.sh update"

# 4. 验证修复
./scripts/healthcheck.sh
```

### 场景 4: 发布失败回滚

```bash
# 发现新版本有问题
./deploy.sh rollback

# 或选择特定版本
./scripts/rollback.sh list
./scripts/rollback.sh r 3  # 回滚到第3个备份

# 验证回滚成功
./deploy.sh status
```

---

## 🎯 最佳实践建议

### ✅ 推荐做法

1. **先在本地测试**：确保代码能正常运行再推送
2. **写好 Commit Message**：方便后续追踪和回滚
3. **定期检查日志**：`./deploy.sh logs`
4. **开启自动更新**：减少手动操作
5. **配置通知**：第一时间知道部署结果
6. **保持备份**：默认会自动备份，不要删除 backups 目录

### ❌ 避免的做法

1. **不要直接在服务器上修改代码**：应该通过 Git 管理
2. **不要忽略健康检查**：每次更新后都检查一下
3. **不要关闭日志记录**：出问题时日志是救命稻草
4. **不要忘记测试回滚流程**：确保备份可用

---

## 📞 获取帮助

遇到问题？

1. **查看日志**：
   ```bash
   ./deploy.sh logs
   tail -100 docker/logs/deploy.log
   ```

2. **运行诊断**：
   ```bash
   ./scripts/healthcheck.sh
   ```

3. **查看帮助**：
   ```bash
   ./deploy.sh help
   ```

---

## 📝 版本历史

- **v1.0** (2026-05-13): 初始版本
  - ✅ Git 自动拉取更新
  - ✅ 热更新（无需重启）
  - ✅ 自动备份与回滚
  - ✅ Cron 定时任务支持
  - ✅ 健康检查系统
  - ✅ 完整的日志记录

---

## 🎉 结语

恭喜你！现在你已经拥有了一个**现代化、自动化、可回滚**的部署系统！

**核心优势总结**：
- 🚀 **一键部署**：`./deploy.sh update`
- ⚡ **零停机热更新**：无需重启容器
- 🔄 **自动备份**：每次更新前自动备份
- ⏪ **一键回滚**：出问题秒级恢复
- ⏰ **自动化**：Cron 定时检查更新
- 🏥 **健康监控**：全面的系统检查

**下一步建议**：
1. 尝试一次完整的更新流程
2. 开启 Cron 自动更新
3. 配置钉钉/企业微信通知
4. （可选）接入 GitHub Webhooks 实现推送即部署

祝使用愉快！如有任何问题，随时查阅本文档或查看脚本的帮助信息。🎊
