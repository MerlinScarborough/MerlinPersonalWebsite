@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ============================================
:: Merlin Website - Windows 启动脚本
:: ============================================
::
:: 功能：自动配置 Windows 环境并启动容器
:: 使用方法：双击运行或在命令行执行 start.bat
::

echo =====================================
echo   Merlin Personal Website
echo   Windows 环境自动配置工具
echo =====================================
echo.

cd /d "%~dp0"

:: 检查 .env.windows 是否存在
if not exist ".env.windows" (
    echo [错误] 未找到 .env.windows 配置文件
    pause
    exit /b 1
)

:: 复制配置文件
copy /y ".env.windows" ".env" >nul
echo [成功] 已使用 Windows 配置

echo.
echo =====================================
echo 正在启动 Docker 容器...
echo.

:: 尝试使用 docker compose（新版）
docker compose up -d
if %errorlevel% neq 0 (
    :: 如果失败，尝试 docker-compose（旧版）
    docker-compose up -d
    if %errorlevel% neq 0 (
        echo [错误] Docker 启动失败
        pause
        exit /b 1
    )
)

echo.
echo =====================================
echo [成功] 启动完成！
echo.
echo 访问地址:
echo   本地: http://localhost
echo.
echo 常用命令:
echo   查看状态: docker ps ^| findstr merlin
echo   查看日志: docker logs merlin-website --tail 20
echo   停止容器: docker compose down
echo =====================================

pause
