const WebSocket = require('ws');
const http = require('http');
const path = require('path');
const fs = require('fs');

// 创建HTTP服务器用于提供静态文件
const server = http.createServer((req, res) => {
    let filePath = '.' + req.url;
    if (filePath === './') {
        filePath = './index.html';
    }

    const extname = String(path.extname(filePath)).toLowerCase();
    const mimeTypes = {
        '.html': 'text/html',
        '.js': 'text/javascript',
        '.css': 'text/css',
        '.json': 'application/json',
        '.png': 'image/png',
        '.jpg': 'image/jpg',
        '.gif': 'image/gif',
        '.svg': 'image/svg+xml',
        '.wav': 'audio/wav',
        '.mp4': 'video/mp4',
        '.woff': 'application/font-woff',
        '.ttf': 'application/font-ttf',
        '.eot': 'application/vnd.ms-fontobject',
        '.otf': 'application/font-otf',
        '.wasm': 'application/wasm'
    };

    const contentType = mimeTypes[extname] || 'application/octet-stream';

    fs.readFile(filePath, (error, content) => {
        if (error) {
            if (error.code === 'ENOENT') {
                res.writeHead(404, { 'Content-Type': 'text/html' });
                res.end('<h1>404 - 文件未找到</h1>', 'utf-8');
            } else {
                res.writeHead(500);
                res.end(`服务器错误: ${error.code}`, 'utf-8');
            }
        } else {
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content, 'utf-8');
        }
    });
});

// 创建WebSocket服务器
const wss = new WebSocket.Server({ server });

// 存储连接的客户端
const clients = new Map();
const rooms = new Map();

console.log('🚀 WebRTC信令服务器启动中...');

wss.on('connection', (ws, req) => {
    const clientId = generateId();
    clients.set(clientId, ws);
    
    console.log(`📱 新客户端连接: ${clientId} (总连接数: ${clients.size})`);
    
    // 发送连接确认
    ws.send(JSON.stringify({
        type: 'connected',
        clientId: clientId
    }));

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            handleMessage(clientId, data);
        } catch (error) {
            console.error('❌ 消息解析错误:', error);
        }
    });

    ws.on('close', () => {
        console.log(`📱 客户端断开: ${clientId}`);
        clients.delete(clientId);
        
        // 清理房间信息
        for (const [roomId, room] of rooms.entries()) {
            if (room.host === clientId) {
                // 通知所有观看者主机已断开
                room.viewers.forEach(viewerId => {
                    const viewer = clients.get(viewerId);
                    if (viewer) {
                        viewer.send(JSON.stringify({
                            type: 'host-disconnected'
                        }));
                    }
                });
                rooms.delete(roomId);
                console.log(`🏠 房间已关闭: ${roomId}`);
            } else if (room.viewers.has(clientId)) {
                room.viewers.delete(clientId);
                console.log(`👁️ 观看者离开房间: ${roomId}`);
            }
        }
    });

    ws.on('error', (error) => {
        console.error('❌ WebSocket错误:', error);
    });
});

function handleMessage(clientId, data) {
    console.log(`📨 收到消息 [${clientId}]:`, data.type);

    switch (data.type) {
        case 'create-room':
            createRoom(clientId, data.roomId);
            break;
            
        case 'join-room':
            joinRoom(clientId, data.roomId);
            break;
            
        case 'offer':
            forwardToRoom(clientId, data, 'offer');
            break;
            
        case 'answer':
            forwardToRoom(clientId, data, 'answer');
            break;
            
        case 'ice-candidate':
            forwardToRoom(clientId, data, 'ice-candidate');
            break;
            
        case 'viewer-connected':
            notifyHost(clientId, data);
            break;
            
        default:
            console.log('❓ 未知消息类型:', data.type);
    }
}

function createRoom(hostId, roomId) {
    if (rooms.has(roomId)) {
        const host = clients.get(hostId);
        if (host) {
            host.send(JSON.stringify({
                type: 'error',
                message: '房间ID已存在'
            }));
        }
        return;
    }

    rooms.set(roomId, {
        host: hostId,
        viewers: new Set(),
        created: Date.now()
    });

    const host = clients.get(hostId);
    if (host) {
        host.send(JSON.stringify({
            type: 'room-created',
            roomId: roomId
        }));
    }

    console.log(`🏠 房间已创建: ${roomId} (主机: ${hostId})`);
}

function joinRoom(viewerId, roomId) {
    const room = rooms.get(roomId);
    if (!room) {
        const viewer = clients.get(viewerId);
        if (viewer) {
            viewer.send(JSON.stringify({
                type: 'error',
                message: '房间不存在'
            }));
        }
        return;
    }

    room.viewers.add(viewerId);
    
    const viewer = clients.get(viewerId);
    if (viewer) {
        viewer.send(JSON.stringify({
            type: 'room-joined',
            roomId: roomId,
            hostId: room.host
        }));
    }

    console.log(`👁️ 观看者加入房间: ${roomId} (观看者: ${viewerId})`);
}

function forwardToRoom(senderId, data, messageType) {
    // 查找发送者所在的房间
    let targetRoom = null;
    let isHost = false;

    for (const [roomId, room] of rooms.entries()) {
        if (room.host === senderId) {
            targetRoom = room;
            isHost = true;
            break;
        } else if (room.viewers.has(senderId)) {
            targetRoom = room;
            isHost = false;
            break;
        }
    }

    if (!targetRoom) {
        console.log('❌ 未找到发送者所在的房间');
        return;
    }

    // 转发消息
    if (isHost) {
        // 主机发送给所有观看者
        targetRoom.viewers.forEach(viewerId => {
            const viewer = clients.get(viewerId);
            if (viewer) {
                viewer.send(JSON.stringify({
                    type: messageType,
                    ...data,
                    from: senderId
                }));
            }
        });
    } else {
        // 观看者发送给主机
        const host = clients.get(targetRoom.host);
        if (host) {
            host.send(JSON.stringify({
                type: messageType,
                ...data,
                from: senderId
            }));
        }
    }
}

function notifyHost(viewerId, data) {
    // 查找观看者所在的房间
    for (const [roomId, room] of rooms.entries()) {
        if (room.viewers.has(viewerId)) {
            const host = clients.get(room.host);
            if (host) {
                host.send(JSON.stringify({
                    type: 'viewer-connected',
                    viewerId: viewerId
                }));
            }
            break;
        }
    }
}

function generateId() {
    return Math.random().toString(36).substr(2, 9).toUpperCase();
}

// 定期清理过期房间
setInterval(() => {
    const now = Date.now();
    const expireTime = 24 * 60 * 60 * 1000; // 24小时

    for (const [roomId, room] of rooms.entries()) {
        if (now - room.created > expireTime) {
            rooms.delete(roomId);
            console.log(`🧹 清理过期房间: ${roomId}`);
        }
    }
}, 60 * 60 * 1000); // 每小时检查一次

// 启动服务器 - 支持多种方式自定义端口
const PORT = process.argv[2] || process.env.PORT || 8080;
const HOST = process.env.HOST || '0.0.0.0'; // 监听所有网络接口

console.log(`🔧 端口配置: ${PORT} (来源: ${process.argv[2] ? '命令行参数' : process.env.PORT ? '环境变量' : '默认值'})`);

server.listen(PORT, HOST, () => {
    console.log(`🌐 服务器运行在 http://${HOST === '0.0.0.0' ? 'cu1.zhaotao.com.cn' : HOST}:${PORT}`);
    console.log(`📡 WebSocket信令服务器运行在 ws://${HOST === '0.0.0.0' ? 'cu1.zhaotao.com.cn' : HOST}:${PORT}`);
    console.log('');
    console.log('🔧 公网访问配置:');
    console.log('   1. 确保防火墙开放端口 8080');
    console.log('   2. 如使用云服务器，配置安全组规则');
    console.log('   3. 更新config.json中的signaling.url为您的域名或IP');
    console.log('   4. 建议使用HTTPS和WSS协议以获得更好的兼容性');
    console.log('');
    console.log('📋 访问地址:');
    console.log(`   本地访问:   http://localhost:${PORT}`);
    console.log(`   公网访问:   http://cu1.zhaotao.com.cn:${PORT}`);
    console.log(`   屏幕共享端: http://cu1.zhaotao.com.cn:${PORT}/remote-desktop-v2.html`);
    console.log(`   观看端:     http://cu1.zhaotao.com.cn:${PORT}/final-viewer.html`);
    console.log(`   配置编辑器: http://cu1.zhaotao.com.cn:${PORT}/config-editor.html`);
    console.log('');
});

// 优雅关闭
process.on('SIGINT', () => {
    console.log('\n🛑 正在关闭服务器...');
    server.close(() => {
        console.log('✅ 服务器已关闭');
        process.exit(0);
    });
});