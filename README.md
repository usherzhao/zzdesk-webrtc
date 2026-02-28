# WebRTC远程桌面系统

基于WebRTC技术的高性能远程桌面解决方案，支持屏幕共享和远程观看。

## ✨ 主要特性

- 🖥️ **高质量屏幕共享** - 支持1080p@30fps高清传输
- 🔒 **端到端加密** - WebRTC原生加密，保障数据安全
- 🌐 **NAT穿透** - 集成STUN/TURN服务器支持
- ⚡ **低延迟** - P2P直连，毫秒级延迟
- 📱 **跨平台** - 支持Windows、macOS、Linux
- 🎯 **易于部署** - 一键部署脚本，快速上手

## 🚀 快速开始

### 方法一：自动部署（推荐）

**Linux/macOS:**
```bash
sudo ./deploy.sh
```

**Windows:**
```cmd
# 以管理员身份运行
deploy.bat
```

### 方法二：手动部署

1. **安装依赖**
```bash
npm install
```

2. **启动信令服务器**
```bash
# 默认端口8080
node signaling-server.js

# 自定义端口
node signaling-server.js 3000

# 使用环境变量
PORT=3000 node signaling-server.js
```

3. **访问系统**
- 打开浏览器访问 `http://localhost:8080`（或您自定义的端口）

## 📁 文件结构

```
├── index.html              # 系统主页
├── config.json             # 配置文件
├── config-manager.js       # 配置管理器
├── config-editor.html      # 配置编辑器
├── signaling-server.js     # WebSocket信令服务器
├── remote-desktop-v2.html  # 屏幕共享端
├── final-viewer.html       # 远程观看端
├── coturn-test.html        # COTURN测试工具
├── deploy.sh              # Linux部署脚本
├── deploy.bat             # Windows部署脚本
└── deployment-guide.md    # 详细部署指南
```

## 🎯 使用方法

### 1. 配置系统
- 访问 `config-editor.html` 编辑配置
- 设置信令服务器、STUN/TURN服务器地址
- 配置视频质量和网络参数

### 2. 开始屏幕共享
- 打开 `remote-desktop-v2.html`
- 点击"开始屏幕共享"
- 复制生成的连接ID

### 3. 远程观看
- 打开 `final-viewer.html`
- 输入连接ID
- 点击"连接远程桌面"

## ⚙️ 配置说明

### 端口自定义
系统支持多种方式自定义Web服务器端口：

```bash
# 方法1: 命令行参数（推荐）
node signaling-server.js 3000

# 方法2: 环境变量
PORT=3000 node signaling-server.js

# 方法3: PM2管理
pm2 start signaling-server.js --name "webrtc-3000" -- 3000

# 方法4: 自动部署脚本会询问端口配置
```

详细端口配置说明请参考：[端口配置指南](port-configuration.md)

### 基本配置 (config.json)
```json
{
  "signaling": {
    "url": "ws://localhost:8080"
  },
  "stun": {
    "servers": [
      "stun:stun.l.google.com:19302"
    ]
  },
  "turn": {
    "server": "turn:your-server:3478",
    "username": "your-username",
    "password": "your-password"
  }
}
```

### 公网访问配置
1. 将 `localhost` 替换为您的域名或IP
2. 使用 `wss://` 协议（推荐）
3. 配置COTURN服务器
4. 开放必要端口：8080, 3478, 49152-65535

## 🔧 COTURN服务器配置

### 安装COTURN
```bash
# Ubuntu/Debian
sudo apt install coturn

# CentOS/RHEL
sudo yum install coturn
```

### 配置文件 (/etc/turnserver.conf)
```
listening-ip=0.0.0.0
external-ip=YOUR_PUBLIC_IP
lt-cred-mech
user=username:password
realm=yourdomain.com
listening-port=3478
min-port=49152
max-port=65535
```

### 启动服务
```bash
sudo systemctl enable coturn
sudo systemctl start coturn
```

## 🌐 公网部署

### 防火墙配置
```bash
# 信令服务器
sudo ufw allow 8080/tcp

# COTURN服务器
sudo ufw allow 3478/tcp
sudo ufw allow 3478/udp
sudo ufw allow 5349/tcp
sudo ufw allow 49152:65535/udp
```

### 使用PM2管理进程
```bash
# 安装PM2
npm install -g pm2

# 启动服务
pm2 start signaling-server.js --name "webrtc-signaling"

# 设置开机自启
pm2 startup
pm2 save
```

## 🔍 故障排除

### 常见问题

1. **屏幕共享失败 - "Cannot read properties of undefined (reading 'getDisplayMedia')"**
   - **原因**: 不在安全上下文中，浏览器禁用了屏幕共享API
   - **解决方案**:
     - 使用 `https://` 协议访问
     - 或使用 `localhost` 或 `127.0.0.1` 访问
     - 使用安全检查工具诊断: `security-check.html`

2. **WebSocket连接失败**
   - 检查防火墙设置
   - 确认服务器地址正确
   - 检查证书配置（HTTPS环境）

3. **视频连接失败**
   - 检查COTURN服务器状态
   - 验证TURN服务器认证信息
   - 确认中继端口开放

4. **浏览器兼容性**
   - Chrome/Edge: 完全支持
   - Firefox: 完全支持
   - Safari: 需要HTTPS环境

### 调试工具
- 使用 `coturn-test.html` 测试COTURN服务器
- 查看浏览器控制台日志
- 检查PM2进程状态：`pm2 status`

## 📊 系统要求

### 服务器要求
- CPU: 2核心以上
- 内存: 4GB以上
- 带宽: 上行10Mbps以上
- 系统: Linux/Windows/macOS

### 客户端要求
- 现代浏览器（Chrome 60+, Firefox 60+, Safari 12+）
- 支持WebRTC的设备
- 稳定的网络连接

## 🔐 安全建议

1. **网络安全**
   - 使用HTTPS/WSS协议
   - 配置强密码
   - 限制不必要的端口访问

2. **系统安全**
   - 定期更新系统和软件
   - 配置防火墙规则
   - 监控系统资源

## 📞 技术支持

如果在使用过程中遇到问题：

1. 查看 `deployment-guide.md` 详细部署指南
2. 检查系统日志和浏览器控制台
3. 使用测试工具验证服务器配置
4. 参考故障排除章节

## 📄 许可证

本项目基于MIT许可证开源。

---

🎉 **开始使用WebRTC远程桌面系统，享受高质量的远程桌面体验！**