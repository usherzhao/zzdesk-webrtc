# WebRTC远程桌面系统 - 端口配置指南

## 🔌 端口自定义方法

WebRTC远程桌面系统支持多种方式自定义Web服务器端口，以适应不同的部署环境和需求。

### 方法一：命令行参数（推荐）

直接在启动时指定端口：

```bash
# 启动在3000端口
node signaling-server.js 3000

# 启动在8888端口
node signaling-server.js 8888
```

### 方法二：环境变量

设置环境变量后启动：

```bash
# Linux/macOS
export PORT=3000
node signaling-server.js

# Windows
set PORT=3000
node signaling-server.js

# 或者一行命令
PORT=3000 node signaling-server.js
```

### 方法三：使用PM2管理

```bash
# 使用命令行参数
pm2 start signaling-server.js --name "webrtc-3000" -- 3000

# 使用环境变量
pm2 start signaling-server.js --name "webrtc-3000" --env PORT=3000

# 重启到新端口
pm2 delete webrtc-signaling
pm2 start signaling-server.js --name "webrtc-signaling" -- 8888
```

### 方法四：自动部署脚本

使用提供的部署脚本时，会自动询问端口配置：

```bash
# Linux/macOS
sudo ./deploy.sh
# 脚本会询问: 🔌 请输入Web服务器端口 (默认: 8080):

# Windows
deploy.bat
# 脚本会询问: 🔌 请输入Web服务器端口 (默认: 8080):
```

## 🔧 端口优先级

系统按以下优先级选择端口：

1. **命令行参数** - 最高优先级
2. **环境变量 PORT** - 中等优先级  
3. **默认值 8080** - 最低优先级

## 🌐 常用端口建议

### 开发环境
- `3000` - 常用的开发端口
- `8080` - 默认端口
- `8888` - 备用端口

### 生产环境
- `80` - HTTP标准端口（需要root权限）
- `443` - HTTPS标准端口（需要root权限）
- `8080` - 常用的Web应用端口
- `3000-9999` - 自定义端口范围

### 云服务器推荐
- `8080` - 大多数云服务商默认开放
- `3000` - Node.js应用常用端口
- `8888` - 备用选择

## 🔥 防火墙配置

更改端口后，需要相应更新防火墙规则：

### Linux (ufw)
```bash
# 开放新端口
sudo ufw allow 3000/tcp

# 删除旧端口规则（可选）
sudo ufw delete allow 8080/tcp
```

### Windows
```cmd
# 开放新端口
netsh advfirewall firewall add rule name="WebRTC-3000" dir=in action=allow protocol=TCP localport=3000

# 删除旧端口规则（可选）
netsh advfirewall firewall delete rule name="WebRTC信令服务器"
```

### 云服务器安全组
在云服务商控制台中：
1. 添加新端口的入站规则
2. 删除旧端口规则（可选）

## 📝 配置文件更新

更改端口后，需要更新 `config.json` 中的信令服务器地址：

```json
{
  "signaling": {
    "url": "ws://your-domain.com:3000",
    "description": "更新为新的端口号"
  }
}
```

或使用配置编辑器：
- 访问 `http://your-domain.com:新端口/config-editor.html`
- 修改信令服务器地址
- 保存配置

## 🚀 快速端口切换

### 脚本方式
创建启动脚本 `start-port.sh`：
```bash
#!/bin/bash
PORT=${1:-8080}
echo "🚀 启动WebRTC服务器在端口: $PORT"
pm2 delete webrtc-signaling 2>/dev/null || true
pm2 start signaling-server.js --name "webrtc-signaling" -- $PORT
echo "✅ 服务器已启动: http://localhost:$PORT"
```

使用方法：
```bash
chmod +x start-port.sh
./start-port.sh 3000  # 启动在3000端口
./start-port.sh       # 启动在默认8080端口
```

### Docker方式（可选）
```dockerfile
# Dockerfile
FROM node:18
WORKDIR /app
COPY . .
RUN npm install
EXPOSE 8080
CMD ["node", "signaling-server.js"]
```

```bash
# 构建镜像
docker build -t webrtc-desktop .

# 运行在不同端口
docker run -p 3000:8080 webrtc-desktop  # 外部3000映射到内部8080
docker run -p 8888:8080 webrtc-desktop  # 外部8888映射到内部8080
```

## ⚠️ 注意事项

### 端口冲突
- 检查端口是否被其他应用占用
- 使用 `netstat -an | grep :端口号` 检查端口状态

### 权限问题
- 1024以下的端口需要root权限
- 建议使用1024以上的端口

### 网络访问
- 确保防火墙开放对应端口
- 云服务器需配置安全组规则
- 路由器需要端口转发（家庭网络）

### 配置同步
- 更改端口后及时更新配置文件
- 通知其他用户新的访问地址
- 更新书签和文档中的地址

## 🔍 故障排除

### 端口被占用
```bash
# 查看占用端口的进程
lsof -i :8080  # Linux/macOS
netstat -ano | findstr :8080  # Windows

# 终止占用进程
kill -9 进程ID  # Linux/macOS
taskkill /PID 进程ID /F  # Windows
```

### 无法访问
1. 检查服务器是否正常启动
2. 确认防火墙规则正确
3. 验证网络连接
4. 检查配置文件中的地址

### PM2管理问题
```bash
# 查看所有进程
pm2 list

# 重启特定进程
pm2 restart webrtc-signaling

# 查看日志
pm2 logs webrtc-signaling

# 删除进程
pm2 delete webrtc-signaling
```

---

💡 **提示**: 建议在生产环境中使用标准端口（80/443）或常用端口（8080），以获得更好的兼容性和用户体验。