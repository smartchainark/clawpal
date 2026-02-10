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

// 检查依赖
try {
    require('form-data');
} catch (err) {
    console.error('❌ 缺少依赖: form-data');
    console.log('📦 请运行: npm install -g form-data');
    process.exit(1);
}

// 配置
const CONFIG = {
    WS_PORT: 8765,
    SNAPSHOT_DIR: '/tmp/clawpal-snapshots',
    OPENCLAW_GATEWAY: 'http://localhost:18789',
    TELEGRAM_CHANNEL: process.env.CLAWPAL_CHANNEL || '#general', // 从环境变量读取
    SKILL_DIR: path.join(process.env.HOME, '.openclaw/skills/clawpal'),
};

// 确保目录存在
if (!fs.existsSync(CONFIG.SNAPSHOT_DIR)) {
    fs.mkdirSync(CONFIG.SNAPSHOT_DIR, { recursive: true });
}

// 创建 HTTP 服务器和 WebSocket 服务器
const server = http.createServer();
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
        message: 'Clawpal Video Bridge 已就绪'
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

    // 发送给 Clawpal 处理
    ws.send(JSON.stringify({
        type: 'processing',
        message: 'Clawpal 正在思考...'
    }));

    try {
        // 上传截图到公共 URL（Replicate API 需要 URL，不支持本地文件）
        const imageUrl = await uploadImage(filepath);
        console.log(`📤 图片已上传: ${imageUrl}`);

        // 调用 Clawpal 的 video.sh 生成视频
        const prompt = "waving hello with a warm smile at the camera";
        const videoResult = await generateClawpalVideo(prompt, imageUrl);

        console.log('✅ 视频生成成功:', videoResult.video_url);

        // 返回视频 URL
        ws.send(JSON.stringify({
            type: 'video',
            url: videoResult.video_url,
            character: videoResult.character,
            duration: videoResult.duration
        }));

    } catch (err) {
        console.error('❌ Clawpal 处理失败:', err);
        ws.send(JSON.stringify({
            type: 'error',
            message: `Clawpal 处理失败: ${err.message}`
        }));
    }
}

// 上传图片到公共 URL（多图床 fallback）
async function uploadImage(filepath) {
    const uploaders = [
        { name: 'transfer.sh', fn: uploadToTransferSh },
        { name: 'tmpfiles.org', fn: uploadToTmpFiles },
        { name: '0x0.st', fn: uploadTo0x0 }
    ];

    for (const uploader of uploaders) {
        try {
            console.log(`📤 尝试上传到 ${uploader.name}...`);
            const url = await uploader.fn(filepath);
            console.log(`✅ 上传成功: ${uploader.name}`);
            return url;
        } catch (err) {
            console.warn(`⚠️  ${uploader.name} 失败: ${err.message}`);
        }
    }

    throw new Error('所有图床上传均失败');
}

// transfer.sh 上传
function uploadToTransferSh(filepath) {
    return new Promise((resolve, reject) => {
        const FormData = require('form-data');
        const form = new FormData();
        const filename = path.basename(filepath);
        form.append('file', fs.createReadStream(filepath), filename);

        form.submit('https://transfer.sh', (err, res) => {
            if (err) {
                reject(new Error(`上传失败: ${err.message}`));
                return;
            }

            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                const url = data.trim();
                if (url.startsWith('http')) {
                    resolve(url);
                } else {
                    reject(new Error(`返回无效 URL: ${data}`));
                }
            });
            res.on('error', reject);
        });
    });
}

// tmpfiles.org 上传
function uploadToTmpFiles(filepath) {
    return new Promise((resolve, reject) => {
        const FormData = require('form-data');
        const form = new FormData();
        form.append('file', fs.createReadStream(filepath));

        form.submit('https://tmpfiles.org/api/v1/upload', (err, res) => {
            if (err) {
                reject(new Error(`上传失败: ${err.message}`));
                return;
            }

            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    const json = JSON.parse(data);
                    if (json.status === 'success' && json.data?.url) {
                        // tmpfiles.org 返回的 URL 需要替换域名
                        const url = json.data.url.replace('tmpfiles.org/', 'tmpfiles.org/dl/');
                        resolve(url);
                    } else {
                        reject(new Error(`返回无效响应: ${data}`));
                    }
                } catch (e) {
                    reject(new Error(`解析响应失败: ${data}`));
                }
            });
            res.on('error', reject);
        });
    });
}

// 0x0.st 上传（备选）
function uploadTo0x0(filepath) {
    return new Promise((resolve, reject) => {
        const FormData = require('form-data');
        const form = new FormData();
        form.append('file', fs.createReadStream(filepath));

        form.submit('https://0x0.st', (err, res) => {
            if (err) {
                reject(new Error(`上传失败: ${err.message}`));
                return;
            }

            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                const url = data.trim();
                if (url.startsWith('http')) {
                    resolve(url);
                } else {
                    reject(new Error(`返回无效 URL: ${data}`));
                }
            });
            res.on('error', reject);
        });
    });
}

// 调用 Clawpal video.sh 生成视频
function generateClawpalVideo(prompt, sourceImage) {
    return new Promise((resolve, reject) => {
        const videoScript = path.join(CONFIG.SKILL_DIR, 'scripts/video.sh');

        // 调用: video.sh "<prompt>" ["<source_image>"] ["<duration>"]
        const cmd = `bash "${videoScript}" "${prompt}" "${sourceImage}" 5`;

        console.log(`🎬 执行: ${cmd}`);

        exec(cmd, (error, stdout, stderr) => {
            if (error) {
                console.error('stderr:', stderr);
                reject(new Error(`video.sh 执行失败: ${error.message}`));
                return;
            }

            try {
                // 解析 JSON 输出
                const result = JSON.parse(stdout.trim());

                if (!result.success || !result.video_url) {
                    reject(new Error('视频生成失败或没有返回 URL'));
                    return;
                }

                resolve(result);

            } catch (err) {
                console.error('stdout:', stdout);
                reject(new Error(`无法解析 video.sh 输出: ${err.message}`));
            }
        });
    });
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
