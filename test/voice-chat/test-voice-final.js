#!/usr/bin/env node
const WebSocket = require('ws');

const ws = new WebSocket('ws://localhost:8765');

ws.on('open', () => {
    console.log('✅ 连接成功');

    // 测试语音消息
    ws.send(JSON.stringify({
        type: 'voice',
        text: '测试一下'
    }));
    console.log('💬 发送语音请求: 测试一下');
});

ws.on('message', (data) => {
    const msg = JSON.parse(data);
    console.log(`📨 ${msg.type}:`, msg.message || msg.text || msg.audioUrl || '');

    if (msg.type === 'voice') {
        console.log('🎉 成功！收到语音回复');
        console.log('   文字:', msg.text);
        console.log('   音频:', msg.audioUrl);
        process.exit(0);
    }

    if (msg.type === 'error') {
        console.error('❌ 错误:', msg.message);
        process.exit(1);
    }
});

ws.on('error', (err) => {
    console.error('❌ 连接错误:', err.message);
    process.exit(1);
});

// 60秒超时
setTimeout(() => {
    console.log('⏰ 60秒超时');
    process.exit(1);
}, 60000);
