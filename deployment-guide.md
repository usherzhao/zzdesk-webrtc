# WebRTC远程桌面系统 - 公网部署指南

## 🌐 公网访问配置

### 1. 服务器配置

#### 1.1 防火墙设置
确保以下端口已开放：
```bash
# 信令服务器端口
8080/tcp

# COTURN服务器端口
3478/tcp
3478/udp
5349/tcp (TLS)

# TURN中继端口范围
49152-65535/udp
```

#### 1.2 云服务器安全组
如果使用阿里云、腾讯云等云服务器，需要在控制台配置安全组规则：
- 入方向规则：允许上述端口的TCP/UDP流量
- 出方向规则：允许所有流量（默认）

### 2. 域名和SSL证书配置

#### 2.1 域名解析
将您的域名解析到服务器IP地址：
```
A记录: your-domain.com -> 服务器IP
```

#### 2.2 SSL证书（推荐）
为了获得更好的浏览器兼容性，建议配置HTTPS：

**使用Let's Encrypt免费证书：**
```bash
# 安装certbot
sudo apt install certbot

# 获取证书
sudo certbot certonly --standalone -d your-domain.com

# 证书文件位置
# /etc/letsencrypt/live/your-domain.com/fullchain.pem
# /etc/letsencrypt/live/your-domain.com/privkey.pem
```

### 3. 配置文件修改

#### 3.1 更新config.json
将配置文件中的地址替换为您的实际域名：

```json
{
  "signaling": {
    "url": "wss://your-domain.com:8080",
    "description": "使用wss://协议和实际域名"
  },
  "stun": {
    "servers": [
      "stun:stun.l.google.com:19302",
      "stun:stun1.l.google.com:19302",
      "stun:your-domain.com:3478"
    ]
  },
  "turn": {
    "server": "turn:your-domain.com:3478",
    "username": "your-username",
    "password": "your-password"
  }
}
```

#### 3.2 环境变量配置
创建 `.env` 文件：
```bash
# 服务器配置
PORT=8080
HOST=0.0.0.0

# HTTPS配置（可选）
USE_HTTPS=true
CERT_PATH=/etc/letsencrypt/live/your-domain.com/fullchain.pem
KEY_PATH=/etc/letsencrypt/live/your-domain.com/privkey.pem
```

### 4. COTURN服务器配置

#### 4.1 安装COTURN
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install coturn

# CentOS/RHEL
sudo yum install epel-release
sudo yum install coturn
```

#### 4.2 配置文件 `/etc/turnserver.conf`
```bash
# 监听所有接口
listening-ip=0.0.0.0

# 外部IP（替换为您的服务器公网IP）
external-ip=YOUR_PUBLIC_IP

# 认证方式
lt-cred-mech
user=your-username:your-password
realm=your-domain.com

# 端口配置
listening-port=3478
tls-listening-port=5349

# 中继端口范围
min-port=49152
max-port=65535

# 日志
verbose
log-file=/var/log/turnserver.log

# SSL证书（可选）
cert=/etc/letsencrypt/live/your-domain.com/fullchain.pem
pkey=/etc/letsencrypt/live/your-domain.com/privkey.pem
```

#### 4.3 启动COTURN服务
```bash
# 启用服务
sudo systemctl enable coturn

# 启动服务
sudo systemctl start coturn

# 检查状态
sudo systemctl status coturn
```

### 5. 启动系统

#### 5.1 使用PM2管理进程（推荐）
```bash
# 安装PM2
npm install -g pm2

# 启动信令服务器
pm2 start signaling-server.js --name "webrtc-signaling"

# 设置开机自启
pm2 startup
pm2 save
```

#### 5.2 直接启动
```bash
# 后台运行
nohup node signaling-server.js > server.log 2>&1 &
```

### 6. 访问测试

#### 6.1 测试地址
- 系统主页：`https://your-domain.com:8080`
- 配置编辑器：`https://your-domain.com:8080/config-editor.html`
- COTURN测试：`https://your-domain.com:8080/coturn-test.html`

#### 6.2 连接测试
1. 打开配置编辑器，确认所有服务器地址正确
2. 使用COTURN测试工具验证STUN/TURN服务器
3. 在一台设备上启动屏幕共享端
4. 在另一台设备上使用观看端连接

### 7. 常见问题

#### 7.1 屏幕共享API错误
**错误**: "Cannot read properties of undefined (reading 'getDisplayMedia')"

**原因**: 屏幕共享API只能在安全上下文中使用

**解决方案**:
- 使用HTTPS协议访问：`https://your-domain.com`
- 或使用localhost访问：`http://localhost:8080`
- 或使用127.0.0.1访问：`http://127.0.0.1:8080`
- 使用安全检查工具诊断：访问 `security-check.html`

#### 7.2 WebSocket连接失败
- 检查防火墙是否开放对应端口
- 确认域名解析是否正确
- 如果使用HTTPS，确保证书配置正确

#### 7.3 视频连接失败
- 检查COTURN服务器是否正常运行
- 确认TURN服务器用户名密码正确
- 检查中继端口范围是否开放

#### 7.4 浏览器兼容性
- Chrome/Edge：完全支持
- Firefox：完全支持
- Safari：需要HTTPS环境
- 移动浏览器：需要HTTPS环境

#### 7.5 安全上下文要求
WebRTC屏幕共享API有严格的安全要求：
- **HTTPS协议**: 生产环境必须使用HTTPS
- **localhost**: 开发环境可使用localhost
- **127.0.0.1**: 本地测试可使用127.0.0.1
- **文件协议**: file:// 协议不支持

### 8. 安全建议

#### 8.1 网络安全
- 使用强密码配置TURN服务器
- 定期更新SSL证书
- 限制不必要的端口访问

#### 8.2 系统安全
- 定期更新系统和软件包
- 配置防火墙规则
- 监控系统资源使用情况

### 9. 性能优化

#### 9.1 服务器配置
- 推荐配置：2核4GB内存以上
- 带宽：上行带宽至少10Mbps
- 存储：SSD硬盘

#### 9.2 网络优化
- 使用CDN加速静态资源
- 配置Nginx反向代理
- 启用gzip压缩

## 🚀 快速部署脚本

创建 `deploy.sh` 脚本：
```bash
#!/bin/bash

# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 安装COTURN
sudo apt install -y coturn

# 安装PM2
npm install -g pm2

# 配置防火墙
sudo ufw allow 8080/tcp
sudo ufw allow 3478/tcp
sudo ufw allow 3478/udp
sudo ufw allow 5349/tcp
sudo ufw allow 49152:65535/udp

echo "✅ 基础环境配置完成！"
echo "📝 请手动配置："
echo "   1. 修改 config.json 中的域名"
echo "   2. 配置 /etc/turnserver.conf"
echo "   3. 启动服务：pm2 start signaling-server.js"
```

使用方法：
```bash
chmod +x deploy.sh
./deploy.sh
```

---

📞 **技术支持**：如果在部署过程中遇到问题，请检查日志文件或联系技术支持。