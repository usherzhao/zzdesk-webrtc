@echo off
chcp 65001 >nul
echo 🚀 WebRTC远程桌面系统 - Windows部署脚本
echo ============================================
echo.

REM 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ❌ 请以管理员身份运行此脚本
    pause
    exit /b 1
)

REM 检查Node.js
echo 📦 检查Node.js安装...
node --version >nul 2>&1
if %errorLevel% neq 0 (
    echo ❌ 未检测到Node.js，请先安装Node.js
    echo 📥 下载地址: https://nodejs.org/
    pause
    exit /b 1
) else (
    for /f "tokens=*" %%i in ('node --version') do set NODE_VERSION=%%i
    echo ✅ Node.js已安装: %NODE_VERSION%
)

REM 安装PM2
echo 📦 安装PM2进程管理器...
pm2 --version >nul 2>&1
if %errorLevel% neq 0 (
    npm install -g pm2
    echo ✅ PM2安装完成
) else (
    echo ✅ PM2已安装
)

REM 获取本机IP
echo.
echo 🌐 网络配置
echo ==========
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
    set LOCAL_IP=%%a
    set LOCAL_IP=!LOCAL_IP: =!
    goto :found_ip
)
:found_ip
echo 📍 本机IP地址: %LOCAL_IP%

REM 询问配置信息
echo.
set /p WEB_PORT="🔌 请输入Web服务器端口 (默认: 8080): "
if "%WEB_PORT%"=="" set WEB_PORT=8080

set /p DOMAIN="🌍 请输入您的域名或公网IP (留空使用本机IP): "
if "%DOMAIN%"=="" set DOMAIN=%LOCAL_IP%

set /p USE_HTTPS="🔒 是否使用HTTPS/WSS? (y/n, 默认n): "
if /i "%USE_HTTPS%"=="y" (
    set PROTOCOL=wss
) else (
    set PROTOCOL=ws
)

echo.
echo 🔐 TURN服务器认证配置
echo ==================
set /p TURN_USER="👤 TURN用户名 (默认: webrtc): "
if "%TURN_USER%"=="" set TURN_USER=webrtc

set /p TURN_PASS="🔑 TURN密码 (默认: webrtc123): "
if "%TURN_PASS%"=="" set TURN_PASS=webrtc123

REM 更新配置文件
echo.
echo 📝 更新配置文件...

REM 备份原配置
if exist config.json copy config.json config.json.backup >nul

REM 生成新配置
(
echo {
echo   "signaling": {
echo     "url": "%PROTOCOL%://%DOMAIN%:%WEB_PORT%",
echo     "description": "WebSocket信令服务器地址"
echo   },
echo   "stun": {
echo     "servers": [
echo       "stun:stun.l.google.com:19302",
echo       "stun:stun1.l.google.com:19302"
echo     ],
echo     "description": "STUN服务器列表，用于NAT穿透"
echo   },
echo   "turn": {
echo     "server": "turn:%DOMAIN%:3478",
echo     "username": "%TURN_USER%",
echo     "password": "%TURN_PASS%",
echo     "description": "TURN服务器配置，用于中继连接"
echo   },
echo   "webrtc": {
echo     "iceCandidatePoolSize": 10,
echo     "iceTransportPolicy": "all",
echo     "description": "WebRTC连接配置"
echo   },
echo   "video": {
echo     "width": 1920,
echo     "height": 1080,
echo     "frameRate": 30,
echo     "description": "视频质量配置"
echo   },
echo   "ui": {
echo     "autoConnect": false,
echo     "showDebugLogs": true,
echo     "theme": "default",
echo     "description": "界面配置选项"
echo   }
echo }
) > config.json

echo ✅ 配置文件已更新

REM 启动信令服务器
echo.
echo 🚀 启动信令服务器...

REM 停止可能存在的进程
pm2 delete webrtc-signaling >nul 2>&1

REM 启动新进程，传递端口参数
pm2 start signaling-server.js --name "webrtc-signaling" -- %WEB_PORT%
pm2 save

echo ✅ 信令服务器启动成功

REM 配置Windows防火墙
echo.
echo 🔥 配置Windows防火墙...
netsh advfirewall firewall add rule name="WebRTC信令服务器" dir=in action=allow protocol=TCP localport=%WEB_PORT% >nul 2>&1
echo ✅ 防火墙规则已添加

echo.
echo 🎉 部署完成！
echo ============
echo.
echo 📋 系统信息:
echo    本机IP:     %LOCAL_IP%
echo    域名/IP:    %DOMAIN%
echo    端口:       %WEB_PORT%
echo    协议:       %PROTOCOL%
echo    信令服务器: %PROTOCOL%://%DOMAIN%:%WEB_PORT%
echo    TURN用户名: %TURN_USER%
echo    TURN密码:   %TURN_PASS%
echo.
echo 🌐 访问地址:
echo    系统主页:   http://%DOMAIN%:%WEB_PORT%
echo    配置编辑器: http://%DOMAIN%:%WEB_PORT%/config-editor.html
echo    屏幕共享端: http://%DOMAIN%:%WEB_PORT%/remote-desktop-v2.html
echo    观看端:     http://%DOMAIN%:%WEB_PORT%/final-viewer.html
echo.
echo 📝 注意事项:
echo    1. Windows环境下需要手动安装COTURN服务器
echo    2. 如需公网访问，请配置路由器端口转发
echo    3. 建议使用Chrome或Edge浏览器获得最佳体验
echo.
echo 🔧 管理命令:
echo    查看服务状态: pm2 status
echo    重启服务器:   pm2 restart webrtc-signaling
echo    查看日志:     pm2 logs webrtc-signaling
echo    停止服务器:   pm2 stop webrtc-signaling
echo.

REM 保存部署信息
(
echo WebRTC远程桌面系统 - Windows部署信息
echo 部署时间: %date% %time%
echo 本机IP: %LOCAL_IP%
echo 域名/IP: %DOMAIN%
echo 端口: %WEB_PORT%
echo 协议: %PROTOCOL%
echo 信令服务器: %PROTOCOL%://%DOMAIN%:%WEB_PORT%
echo TURN用户名: %TURN_USER%
echo TURN密码: %TURN_PASS%
echo.
echo 访问地址:
echo - 系统主页: http://%DOMAIN%:%WEB_PORT%
echo - 配置编辑器: http://%DOMAIN%:%WEB_PORT%/config-editor.html
echo - 屏幕共享端: http://%DOMAIN%:%WEB_PORT%/remote-desktop-v2.html
echo - 观看端: http://%DOMAIN%:%WEB_PORT%/final-viewer.html
) > deployment-info.txt

echo 💾 部署信息已保存到 deployment-info.txt
echo.
echo ✨ 部署完成！请访问系统主页开始使用。
echo.
pause