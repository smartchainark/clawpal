#!/usr/bin/env node
const WebSocket = require('ws');

console.log('🧪 端到端测试：浏览器 → Bridge → Clawpal Agent → 浏览器\n');

const ws = new WebSocket('ws://localhost:8765');
let receivedVoice = false;

ws.on('open', () => {
    console.log('✅ WebSocket 连接成功');

    // 发送测试消息
    const testMessage = '嘿 Chiffon~ 今天心情怎么样？';
    ws.send(JSON.stringify({
        type: 'voice',
        text: testMessage
    }));
    console.log(`📤 发送测试: "${testMessage}"`);
    console.log('⏳ 等待 Chiffon 回复（预计 20-40 秒）...\n');
});

ws.on('message', (data) => {
    const msg = JSON.parse(data);
    const timestamp = new Date().toLocaleTimeString();

    console.log(`[${timestamp}] 📨 ${msg.type}:`, msg.message || msg.text || msg.audioUrl || '');

    if (msg.type === 'voice') {
        receivedVoice = true;
        console.log('\n════════════════════════════════');
        console.log('✅ 端到端测试成功！');
        console.log('════════════════════════════════');
        console.log('📝 回复内容:', msg.text);
        console.log('🔊 音频 URL:', msg.audioUrl);
        console.log('════════════════════════════════\n');

        // 验证是否体现 Chiffon 角色
        const hasChiffonStyle = (
            msg.text.includes('~') ||
            msg.text.includes('omg') ||
            msg.text.includes('wait') ||
            msg.text.includes('哈') ||
            msg.text.includes('😂') ||
            msg.text.includes('haha')
        );

        if (hasChiffonStyle) {
            console.log('✅ 回复体现 Chiffon 语气特征');
        } else {
            console.log('⚠️  回复未体现 Chiffon 语气特征（可能需要改进引导词）');
        }

        process.exit(0);
    }

    if (msg.type === 'error') {
        console.error('\n❌ 错误:', msg.message);
        process.exit(1);
    }
});

ws.on('error', (err) => {
    console.error('❌ 连接错误:', err.message);
    process.exit(1);
});

// 95秒超时
setTimeout(() => {
    if (!receivedVoice) {
        console.log('\n❌ 超时：95秒内未收到语音回复');
        process.exit(1);
    }
}, 95000);
