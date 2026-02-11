#!/usr/bin/env node
/**
 * Clawpal Video Chat Bridge v2
 * 使用 OpenClaw agent 命令的最佳实践架构
 *
 * 流程：
 * 1. 接收浏览器截图 WebSocket 消息
 * 2. 保存到本地临时文件
 * 3. 调用 openclaw agent --json 处理
 * 4. 解析返回的 JSON (payloads)
 * 5. 将回复发送给浏览器
 */

const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const http = require('http');

// 配置
const CONFIG = {
    WS_PORT: 8765,
    SNAPSHOT_DIR: '/tmp/clawpal-snapshots',
    AGENT_TARGET: '#general', // OpenClaw agent 目标频道
    AGENT_TIMEOUT: 120, // agent 超时时间（秒）
};

// 确保目录存在
if (!fs.existsSync(CONFIG.SNAPSHOT_DIR)) {
    fs.mkdirSync(CONFIG.SNAPSHOT_DIR, { recursive: true });
}

// 创建 HTTP 服务器和 WebSocket 服务器
const server = http.createServer();
const wss = new WebSocket.Server({ server });

console.log(`🚀 Clawpal Video Bridge v2 启动中...`);
console.log(`📂 截图目录: ${CONFIG.SNAPSHOT_DIR}`);
console.log(`🎯 Agent 目标: ${CONFIG.AGENT_TARGET}`);

// WebSocket 连接处理
wss.on('connection', (ws) => {
    console.log('✅ 浏览器已连接');

    ws.on('message', async (data) => {
        try {
            const message = JSON.parse(data);

            if (message.type === 'snapshot') {
                await handleSnapshot(ws, message);
            } else if (message.type === 'ping') {
                ws.send(JSON.stringify({ type: 'pong' }));
            }

        } catch (err) {
            console.error('❌ 处理消息失败:', err);
            ws.send(JSON.stringify({
                type: 'error',
                message: err.message
            }));
        }
    });

    ws.on('close', () => {
        console.log('⚠️  浏览器已断开');
    });

    // 发送欢迎消息
    ws.send(JSON.stringify({
        type: 'connected',
        message: 'Clawpal Video Bridge v2 已就绪'
    }));
});

// 处理截图
async function handleSnapshot(ws, message) {
    console.log('📸 收到截图');

    // 保存 base64 图片
    const timestamp = Date.now();
    const filename = `snapshot-${timestamp}.jpg`;
    const filepath = path.join(CONFIG.SNAPSHOT_DIR, filename);

    const base64Data = message.data.replace(/^data:image\/\w+;base64,/, '');
    const buffer = Buffer.from(base64Data, 'base64');
    fs.writeFileSync(filepath, buffer);

    console.log(`💾 截图已保存: ${filepath}`);

    // 发送处理中状态
    ws.send(JSON.stringify({
        type: 'processing',
        message: 'Clawpal 正在思考...'
    }));

    try {
        // 调用 OpenClaw agent
        const agentResult = await callAgent(filepath);

        console.log('✅ Agent 处理成功');

        // 解析 payloads
        const payloads = agentResult.result?.payloads || [];

        if (payloads.length === 0) {
            throw new Error('Agent 未返回任何内容');
        }

        const payload = payloads[0];

        // 返回给浏览器
        ws.send(JSON.stringify({
            type: 'reply',
            text: payload.text || '',
            mediaUrl: payload.mediaUrl || null,
            meta: {
                duration: agentResult.result?.meta?.durationMs || 0,
                model: agentResult.result?.meta?.agentMeta?.model || 'unknown'
            }
        }));

    } catch (err) {
        console.error('❌ Agent 处理失败:', err);
        ws.send(JSON.stringify({
            type: 'error',
            message: `Agent 处理失败: ${err.message}`
        }));
    }
}

// 调用 OpenClaw agent
function callAgent(imagePath) {
    return new Promise((resolve, reject) => {
        // 构建 agent 消息
        const message = `请查看这张摄像头截图：${imagePath}\n\n根据图片内容，生成一个温暖、简短的视频回复。`;

        const cmd = `openclaw agent --to "${CONFIG.AGENT_TARGET}" --message "${message}" --json --timeout ${CONFIG.AGENT_TIMEOUT}`;

        console.log(`🤖 调用 agent...`);

        exec(cmd, { maxBuffer: 10 * 1024 * 1024 }, (error, stdout, stderr) => {
            if (error) {
                console.error('stderr:', stderr);
                reject(new Error(`Agent 执行失败: ${error.message}`));
                return;
            }

            try {
                // 解析 JSON 输出
                const result = JSON.parse(stdout.trim());

                if (result.status !== 'ok') {
                    reject(new Error(`Agent 状态异常: ${result.status}`));
                    return;
                }

                resolve(result);

            } catch (err) {
                console.error('stdout:', stdout);
                reject(new Error(`无法解析 agent 输出: ${err.message}`));
            }
        });
    });
}

// 启动服务器
server.listen(CONFIG.WS_PORT, () => {
    console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
    console.log(`✨ Clawpal Video Bridge v2 已启动`);
    console.log(`🔌 WebSocket: ws://localhost:${CONFIG.WS_PORT}`);
    console.log(`📡 等待浏览器连接...`);
    console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`);
});

// 优雅退出
process.on('SIGINT', () => {
    console.log('\n👋 关闭服务器...');
    wss.close(() => {
        console.log('✅ 服务器已关闭');
        process.exit(0);
    });
});
