// 配置管理器
class ConfigManager {
    constructor() {
        this.config = null;
        this.defaultConfig = {
            signaling: {
                url: "ws://localhost:8080",
                description: "WebSocket信令服务器地址"
            },
            stun: {
                servers: [
                    "stun:stun.l.google.com:19302",
                    "stun:stun1.l.google.com:19302"
                ],
                description: "STUN服务器列表，用于NAT穿透"
            },
            turn: {
                server: "",
                username: "",
                password: "",
                description: "TURN服务器配置，用于中继连接"
            },
            webrtc: {
                iceCandidatePoolSize: 10,
                iceTransportPolicy: "all",
                description: "WebRTC连接配置"
            },
            video: {
                width: 1920,
                height: 1080,
                frameRate: 30,
                description: "视频质量配置"
            },
            ui: {
                autoConnect: false,
                showDebugLogs: true,
                theme: "default",
                description: "界面配置选项"
            }
        };
    }

    // 加载配置文件
    async loadConfig() {
        try {
            const response = await fetch('./config.json');
            if (response.ok) {
                this.config = await response.json();
                console.log('✅ 配置文件加载成功', this.config);
                return this.config;
            } else {
                console.warn('⚠️ 配置文件加载失败，使用默认配置');
                this.config = this.defaultConfig;
                return this.config;
            }
        } catch (error) {
            console.error('❌ 配置文件加载错误:', error);
            this.config = this.defaultConfig;
            return this.config;
        }
    }

    // 获取配置项
    get(path) {
        if (!this.config) {
            console.warn('⚠️ 配置未加载，返回默认值');
            return this.getFromObject(this.defaultConfig, path);
        }
        return this.getFromObject(this.config, path);
    }

    // 从对象中获取嵌套属性
    getFromObject(obj, path) {
        return path.split('.').reduce((current, key) => {
            return current && current[key] !== undefined ? current[key] : null;
        }, obj);
    }

    // 获取ICE服务器配置
    getIceServers() {
        const stunServers = this.get('stun.servers') || [];
        const turnConfig = {
            server: this.get('turn.server'),
            username: this.get('turn.username'),
            password: this.get('turn.password')
        };

        const iceServers = [];

        // 添加STUN服务器
        stunServers.forEach(server => {
            if (server) {
                iceServers.push({ urls: server });
            }
        });

        // 添加TURN服务器
        if (turnConfig.server && turnConfig.username && turnConfig.password) {
            iceServers.push({
                urls: turnConfig.server,
                username: turnConfig.username,
                credential: turnConfig.password
            });
        }

        return iceServers;
    }

    // 获取WebRTC配置
    getWebRTCConfig() {
        return {
            iceServers: this.getIceServers(),
            iceCandidatePoolSize: this.get('webrtc.iceCandidatePoolSize') || 10,
            iceTransportPolicy: this.get('webrtc.iceTransportPolicy') || 'all'
        };
    }

    // 获取视频约束
    getVideoConstraints() {
        return {
            video: {
                width: { ideal: this.get('video.width') || 1920 },
                height: { ideal: this.get('video.height') || 1080 },
                frameRate: { ideal: this.get('video.frameRate') || 30 }
            },
            audio: true
        };
    }

    // 自动填充表单
    autoFillForm() {
        const signalingUrl = this.get('signaling.url');
        const turnServer = this.get('turn.server');
        const turnUsername = this.get('turn.username');
        const turnPassword = this.get('turn.password');

        // 填充信令服务器
        const signalingInput = document.getElementById('signalingServer');
        if (signalingInput && signalingUrl) {
            signalingInput.value = signalingUrl;
        }

        // 填充STUN服务器（取第一个作为显示）
        const stunServers = this.get('stun.servers');
        const stunInput = document.getElementById('stunServer');
        if (stunInput && stunServers && stunServers.length > 0) {
            stunInput.value = stunServers[0];
        }

        // 填充TURN服务器
        const turnServerInput = document.getElementById('turnServer');
        if (turnServerInput && turnServer) {
            turnServerInput.value = turnServer;
        }

        const turnUsernameInput = document.getElementById('turnUsername');
        if (turnUsernameInput && turnUsername) {
            turnUsernameInput.value = turnUsername;
        }

        const turnPasswordInput = document.getElementById('turnPassword');
        if (turnPasswordInput && turnPassword) {
            turnPasswordInput.value = turnPassword;
        }

        console.log('✅ 表单自动填充完成');
    }

    // 显示配置信息
    showConfigInfo() {
        console.group('📋 当前配置信息');
        console.log('信令服务器:', this.get('signaling.url'));
        console.log('STUN服务器:', this.get('stun.servers'));
        console.log('TURN服务器:', this.get('turn.server'));
        console.log('TURN用户名:', this.get('turn.username'));
        console.log('视频质量:', `${this.get('video.width')}x${this.get('video.height')}@${this.get('video.frameRate')}fps`);
        console.log('调试模式:', this.get('ui.showDebugLogs'));
        console.groupEnd();
    }

    // 验证配置
    validateConfig() {
        const errors = [];
        
        if (!this.get('signaling.url')) {
            errors.push('信令服务器地址未配置');
        }

        const stunServers = this.get('stun.servers');
        if (!stunServers || stunServers.length === 0) {
            errors.push('STUN服务器未配置');
        }

        if (errors.length > 0) {
            console.warn('⚠️ 配置验证失败:', errors);
            return false;
        }

        console.log('✅ 配置验证通过');
        return true;
    }
}

// 全局配置管理器实例
window.configManager = new ConfigManager();

// 页面加载完成后自动加载配置
document.addEventListener('DOMContentLoaded', async () => {
    await window.configManager.loadConfig();
    window.configManager.validateConfig();
    window.configManager.showConfigInfo();
    
    // 延迟一下确保DOM元素已加载
    setTimeout(() => {
        window.configManager.autoFillForm();
    }, 100);
});