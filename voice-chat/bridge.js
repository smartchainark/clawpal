#!/usr/bin/env node
/**
 * Clawpal Video Chat Bridge
 * 连接浏览器视频聊天界面和 OpenClaw/Clawpal
 *
 * 功能：
 * 1. 接收浏览器的截图 WebSocket 消息
 * 2. 保存到临时文件
 * 3. 触发 Clawpal 处理（生成视频回复）
 * 4. 将生成的视频 URL 返回给浏览器
 */

const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const http = require('http');

// 不再需要 form-data 依赖（OpenClaw 支持本地文件）

// 配置
const CONFIG = {
    WS_PORT: 8765,
    SNAPSHOT_DIR: '/tmp/clawpal-snapshots',
    OPENCLAW_GATEWAY: 'http://localhost:18789',
    TELEGRAM_CHANNEL: process.env.CLAWPAL_CHANNEL || '#general',
    SKILL_DIR: path.join(process.env.HOME, '.openclaw/skills/clawpal'),
    AGENT_TARGET: process.env.CLAWPAL_CHANNEL || '#general', // Agent 目标频道
    AGENT_TIMEOUT: 60, // Agent 超时时间（秒）
};

// 确保目录存在
if (!fs.existsSync(CONFIG.SNAPSHOT_DIR)) {
    fs.mkdirSync(CONFIG.SNAPSHOT_DIR, { recursive: true });
}

// 创建 HTTP 服务器和 WebSocket 服务器
const server = http.createServer((req, res) => {
    // 处理 /media/ 路由，提供音频文件
    if (req.url.startsWith('/media/')) {
        const filename = path.basename(req.url);
        const filepath = path.join('/tmp', filename);

        console.log(`📥 HTTP 请求: ${req.url} → ${filepath}`);

        if (fs.existsSync(filepath)) {
            res.writeHead(200, {
                'Content-Type': 'audio/mpeg',
                'Access-Control-Allow-Origin': '*'
            });
            fs.createReadStream(filepath).pipe(res);
            console.log(`✅ 文件已发送: ${filename}`);
        } else {
            console.log(`❌ 文件不存在: ${filepath}`);
            res.writeHead(404, { 'Content-Type': 'text/plain' });
            res.end('File not found');
        }
    } else {
        // 其他请求返回 404
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not found');
    }
});

const wss = new WebSocket.Server({ server });

console.log(`🚀 Clawpal Video Bridge 启动中...`);
console.log(`📂 截图目录: ${CONFIG.SNAPSHOT_DIR}`);
console.log(`🎯 Telegram 频道: ${CONFIG.TELEGRAM_CHANNEL}`);

// WebSocket 连接处理
wss.on('connection', (ws) => {
    console.log('✅ 浏览器已连接');

    ws.on('message', async (data) => {
        try {
            const message = JSON.parse(data);

            if (message.type === 'voice') {
                await handleVoiceMessage(ws, message);
            } else if (message.type === 'snapshot') {
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
        message: 'Clawpal Video Bridge 已就绪'
    }));
});

// 处理语音消息
async function handleVoiceMessage(ws, message) {
    const userText = message.text || message.transcript;
    console.log(`💬 收到文字消息: ${userText}`);

    // 通知前端开始处理
    ws.send(JSON.stringify({
        type: 'processing',
        message: 'Clawpal 正在思考...'
    }));

    try {
        // 调用 OpenClaw agent
        const agentMessage = `send a voice message: ${userText}`;
        const cmd = `openclaw agent --to "${CONFIG.AGENT_TARGET}" --message "${agentMessage}" --json --timeout ${CONFIG.AGENT_TIMEOUT}`;

        console.log(`🤖 执行: ${cmd}`);

        exec(cmd, (error, stdout, stderr) => {
            if (error) {
                console.error('❌ Agent 调用失败:', error.message);
                console.error('stderr:', stderr);
                ws.send(JSON.stringify({
                    type: 'error',
                    message: `Agent 调用失败: ${error.message}`
                }));
                return;
            }

            try {
                const result = JSON.parse(stdout.trim());
                console.log('✅ Agent 响应:', JSON.stringify(result, null, 2));

                if (result.status === 'ok' && result.result?.payloads) {
                    const payloads = result.result.payloads;

                    for (const payload of payloads) {
                        if (payload.text) {
                            // 提取音频路径（格式：MEDIA: /tmp/xxx.mp3）
                            const mediaMatch = payload.text.match(/MEDIA:\s*(.+?)$/m);
                            if (mediaMatch) {
                                const localPath = mediaMatch[1].trim();
                                const filename = path.basename(localPath);
                                const audioUrl = `http://localhost:${CONFIG.WS_PORT}/media/${filename}`;

                                console.log(`🔊 语音文件: ${localPath} → ${audioUrl}`);

                                // 返回语音消息
                                ws.send(JSON.stringify({
                                    type: 'voice',
                                    text: payload.text.replace(/MEDIA:.+$/m, '').trim() || 'AI 语音回复',
                                    audioUrl: audioUrl
                                }));
                            } else {
                                // 纯文字回复
                                ws.send(JSON.stringify({
                                    type: 'message',
                                    text: payload.text
                                }));
                            }
                        }
                    }
                } else {
                    ws.send(JSON.stringify({
                        type: 'error',
                        message: 'Agent 未返回有效结果'
                    }));
                }

            } catch (parseErr) {
                console.error('❌ 解析 Agent 输出失败:', parseErr.message);
                console.error('stdout:', stdout);
                ws.send(JSON.stringify({
                    type: 'error',
                    message: `解析失败: ${parseErr.message}`
                }));
            }
        });

    } catch (err) {
        console.error('❌ 处理失败:', err);
        ws.send(JSON.stringify({
            type: 'error',
            message: `处理失败: ${err.message}`
        }));
    }
}

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

    // 发送给 Clawpal 处理
    ws.send(JSON.stringify({
        type: 'processing',
        message: 'Clawpal 正在思考...'
    }));

    try {
        // 直接使用本地文件路径，OpenClaw 支持本地媒体文件
        console.log(`📤 使用本地文件: ${filepath}`);

        // 调用 OpenClaw agent 发送图片消息
        const agentMessage = `看到我了吗？给我一个温暖的回应`;
        const cmd = `openclaw agent --to "${CONFIG.AGENT_TARGET}" --message "${agentMessage}" --media "${filepath}" --json --timeout ${CONFIG.AGENT_TIMEOUT}`;

        console.log(`🤖 执行: ${cmd}`);

        exec(cmd, (error, stdout, stderr) => {
            if (error) {
                console.error('❌ Agent 调用失败:', error.message);
                console.error('stderr:', stderr);
                ws.send(JSON.stringify({
                    type: 'error',
                    message: `Agent 调用失败: ${error.message}`
                }));
                return;
            }

            try {
                const result = JSON.parse(stdout.trim());
                console.log('✅ Agent 响应:', JSON.stringify(result, null, 2));

                if (result.status === 'ok' && result.result?.payloads) {
                    // 处理返回的消息
                    const payloads = result.result.payloads;

                    for (const payload of payloads) {
                        if (payload.text) {
                            // 提取音频路径
                            const mediaMatch = payload.text.match(/MEDIA:\s*(.+?)$/m);
                            if (mediaMatch) {
                                const localPath = mediaMatch[1].trim();
                                const filename = path.basename(localPath);
                                const audioUrl = `http://localhost:${CONFIG.WS_PORT}/media/${filename}`;

                                ws.send(JSON.stringify({
                                    type: 'voice',
                                    text: payload.text.replace(/MEDIA:.+$/m, '').trim() || 'AI 回复',
                                    audioUrl: audioUrl
                                }));
                            } else {
                                ws.send(JSON.stringify({
                                    type: 'message',
                                    text: payload.text
                                }));
                            }
                        }
                    }
                } else {
                    ws.send(JSON.stringify({
                        type: 'error',
                        message: 'Agent 未返回有效结果'
                    }));
                }

            } catch (parseErr) {
                console.error('❌ 解析 Agent 输出失败:', parseErr.message);
                console.error('stdout:', stdout);
                ws.send(JSON.stringify({
                    type: 'error',
                    message: `解析失败: ${parseErr.message}`
                }));
            }
        });

        // 通知浏览器截图已保存
        ws.send(JSON.stringify({
            type: 'snapshot_saved',
            filepath: filepath
        }));

    } catch (err) {
        console.error('❌ 处理失败:', err);
        ws.send(JSON.stringify({
            type: 'error',
            message: `处理失败: ${err.message}`
        }));
    }
}

// 启动服务器
server.listen(CONFIG.WS_PORT, () => {
    console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
    console.log(`✨ Clawpal Video Bridge 已启动`);
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
