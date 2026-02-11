// 快速测试 WebSocket 连接和语音消息功能
const WebSocket = require('ws');

console.log('🔌 连接到 ws://localhost:8765...');

const ws = new WebSocket('ws://localhost:8765');

ws.on('open', () => {
    console.log('✅ 连接成功！');

    // 测试发送语音消息
    console.log('📤 发送语音消息请求...');
    ws.send(JSON.stringify({
        type: 'voice',
        text: '你好，测试一下'
    }));
});

ws.on('message', (data) => {
    try {
        const message = JSON.parse(data);
        console.log('📨 收到消息:', JSON.stringify(message, null, 2));

        if (message.type === 'voice') {
            console.log('🎵 语音 URL:', message.audioUrl);
            console.log('\n✅ 测试成功！服务器正常工作。');
            process.exit(0);
        }
    } catch (err) {
        console.error('❌ 解析失败:', err.message);
    }
});

ws.on('error', (error) => {
    console.error('❌ 连接错误:', error.message);
    process.exit(1);
});

ws.on('close', () => {
    console.log('⚠️  连接已关闭');
});

// 60秒超时
setTimeout(() => {
    console.log('⏰ 超时，关闭连接');
    ws.close();
    process.exit(1);
}, 60000);
