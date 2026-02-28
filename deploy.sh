#!/bin/bash

# WebRTC远程桌面系统 - 快速部署脚本
# 适用于Ubuntu/Debian系统

echo "🚀 WebRTC远程桌面系统 - 公网部署脚本"
echo "============================================"

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用sudo权限运行此脚本"
    exit 1
fi

# 更新系统
echo "📦 更新系统包..."
apt update && apt upgrade -y

# 安装Node.js
echo "📦 安装Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    echo "✅ Node.js安装完成: $(node --version)"
else
    echo "✅ Node.js已安装: $(node --version)"
fi

# 安装COTURN
echo "📦 安装COTURN服务器..."
if ! command -v turnserver &> /dev/null; then
    apt install -y coturn
    echo "✅ COTURN安装完成"
else
    echo "✅ COTURN已安装"
fi

# 安装PM2
echo "📦 安装PM2进程管理器..."
if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
    echo "✅ PM2安装完成"
else
    echo "✅ PM2已安装"
fi

# 配置防火墙
echo "🔥 配置防火墙规则..."
ufw allow ${WEB_PORT}/tcp comment "WebRTC信令服务器"
ufw allow 3478/tcp comment "COTURN STUN/TURN"
ufw allow 3478/udp comment "COTURN STUN/TURN"
ufw allow 5349/tcp comment "COTURN TLS"
ufw allow 49152:65535/udp comment "COTURN中继端口"

# 如果防火墙未启用，询问是否启用
if ! ufw status | grep -q "Status: active"; then
    echo "🔥 防火墙当前未启用"
    read -p "是否启用防火墙? (y/n): " enable_firewall
    if [ "$enable_firewall" = "y" ] || [ "$enable_firewall" = "Y" ]; then
        ufw --force enable
        echo "✅ 防火墙已启用"
    fi
fi

# 获取服务器信息
echo ""
echo "🌐 服务器信息配置"
echo "=================="

# 获取公网IP
PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "未获取到")
echo "📍 检测到的公网IP: $PUBLIC_IP"

# 询问端口
read -p "🔌 请输入Web服务器端口 (默认: 8080): " WEB_PORT
WEB_PORT=${WEB_PORT:-8080}

# 询问域名
read -p "🌍 请输入您的域名 (如: example.com，留空使用IP): " DOMAIN
if [ -z "$DOMAIN" ]; then
    DOMAIN=$PUBLIC_IP
    PROTOCOL="ws"
    echo "📝 将使用IP地址: $DOMAIN"
else
    echo "📝 将使用域名: $DOMAIN"
    read -p "🔒 是否使用HTTPS/WSS? (y/n): " USE_HTTPS
    if [ "$USE_HTTPS" = "y" ] || [ "$USE_HTTPS" = "Y" ]; then
        PROTOCOL="wss"
    else
        PROTOCOL="ws"
    fi
fi

# 询问TURN服务器用户名密码
echo ""
echo "🔐 TURN服务器认证配置"
echo "===================="
read -p "👤 TURN用户名 (默认: webrtc): " TURN_USER
TURN_USER=${TURN_USER:-webrtc}

read -p "🔑 TURN密码 (默认: 随机生成): " TURN_PASS
if [ -z "$TURN_PASS" ]; then
    TURN_PASS=$(openssl rand -base64 12)
    echo "🎲 生成的随机密码: $TURN_PASS"
fi

# 更新配置文件
echo ""
echo "📝 更新配置文件..."

# 备份原配置
cp config.json config.json.backup

# 生成新配置
cat > config.json << EOF
{
  "signaling": {
    "url": "${PROTOCOL}://${DOMAIN}:${WEB_PORT}",
    "description": "WebSocket信令服务器地址"
  },
  "stun": {
    "servers": [
      "stun:stun.l.google.com:19302",
      "stun:stun1.l.google.com:19302",
      "stun:${DOMAIN}:3478"
    ],
    "description": "STUN服务器列表，用于NAT穿透"
  },
  "turn": {
    "server": "turn:${DOMAIN}:3478",
    "username": "${TURN_USER}",
    "password": "${TURN_PASS}",
    "description": "TURN服务器配置，用于中继连接"
  },
  "webrtc": {
    "iceCandidatePoolSize": 10,
    "iceTransportPolicy": "all",
    "description": "WebRTC连接配置"
  },
  "video": {
    "width": 1920,
    "height": 1080,
    "frameRate": 30,
    "description": "视频质量配置"
  },
  "ui": {
    "autoConnect": false,
    "showDebugLogs": true,
    "theme": "default",
    "description": "界面配置选项"
  }
}
EOF

echo "✅ 配置文件已更新"

# 配置COTURN
echo ""
echo "🔄 配置COTURN服务器..."

# 备份原配置
cp /etc/turnserver.conf /etc/turnserver.conf.backup 2>/dev/null || true

# 生成COTURN配置
cat > /etc/turnserver.conf << EOF
# WebRTC远程桌面系统 - COTURN配置
listening-ip=0.0.0.0
external-ip=${PUBLIC_IP}

# 认证
lt-cred-mech
user=${TURN_USER}:${TURN_PASS}
realm=${DOMAIN}

# 端口配置
listening-port=3478
tls-listening-port=5349

# 中继端口范围
min-port=49152
max-port=65535

# 日志
verbose
log-file=/var/log/turnserver.log

# 其他配置
no-multicast-peers
no-cli
no-tlsv1
no-tlsv1_1
EOF

echo "✅ COTURN配置完成"

# 启用COTURN服务
echo "🔄 启动COTURN服务..."
systemctl enable coturn
systemctl restart coturn

if systemctl is-active --quiet coturn; then
    echo "✅ COTURN服务启动成功"
else
    echo "❌ COTURN服务启动失败，请检查配置"
fi

# 启动信令服务器
echo ""
echo "🚀 启动信令服务器..."

# 停止可能存在的进程
pm2 delete webrtc-signaling 2>/dev/null || true

# 启动新进程，传递端口参数
pm2 start signaling-server.js --name "webrtc-signaling" -- ${WEB_PORT}
pm2 save

echo "✅ 信令服务器启动成功"

# 设置开机自启
pm2 startup systemd -u root --hp /root
systemctl enable pm2-root

echo ""
echo "🎉 部署完成！"
echo "============"
echo ""
echo "📋 系统信息:"
echo "   公网IP:     $PUBLIC_IP"
echo "   域名:       $DOMAIN"
echo "   端口:       $WEB_PORT"
echo "   协议:       $PROTOCOL"
echo "   信令服务器: ${PROTOCOL}://${DOMAIN}:${WEB_PORT}"
echo "   TURN服务器: turn:${DOMAIN}:3478"
echo "   TURN用户名: $TURN_USER"
echo "   TURN密码:   $TURN_PASS"
echo ""
echo "🌐 访问地址:"
echo "   系统主页:   http://${DOMAIN}:${WEB_PORT}"
echo "   配置编辑器: http://${DOMAIN}:${WEB_PORT}/config-editor.html"
echo "   屏幕共享端: http://${DOMAIN}:${WEB_PORT}/remote-desktop-v2.html"
echo "   观看端:     http://${DOMAIN}:${WEB_PORT}/final-viewer.html"
echo ""
echo "📝 后续步骤:"
echo "   1. 如使用云服务器，请在控制台配置安全组规则"
echo "   2. 如需HTTPS，请配置SSL证书"
echo "   3. 访问系统主页测试功能"
echo ""
echo "🔧 管理命令:"
echo "   查看服务状态: pm2 status"
echo "   重启信令服务器: pm2 restart webrtc-signaling"
echo "   查看日志: pm2 logs webrtc-signaling"
echo "   COTURN状态: systemctl status coturn"
echo ""

# 保存部署信息
cat > deployment-info.txt << EOF
WebRTC远程桌面系统 - 部署信息
部署时间: $(date)
公网IP: $PUBLIC_IP
域名: $DOMAIN
端口: $WEB_PORT
协议: $PROTOCOL
信令服务器: ${PROTOCOL}://${DOMAIN}:${WEB_PORT}
TURN服务器: turn:${DOMAIN}:3478
TURN用户名: $TURN_USER
TURN密码: $TURN_PASS

访问地址:
- 系统主页: http://${DOMAIN}:${WEB_PORT}
- 配置编辑器: http://${DOMAIN}:${WEB_PORT}/config-editor.html
- 屏幕共享端: http://${DOMAIN}:${WEB_PORT}/remote-desktop-v2.html
- 观看端: http://${DOMAIN}:${WEB_PORT}/final-viewer.html
EOF

echo "💾 部署信息已保存到 deployment-info.txt"
echo ""
echo "✨ 部署完成！请访问系统主页开始使用。"