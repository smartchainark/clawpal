const WebSocket = require('ws');

console.log('🔌 连接到 OpenClaw Gateway...');
const ws = new WebSocket('ws://localhost:18789');

ws.on('open', () => {
    console.log('✅ WebSocket 已连接');
});

ws.on('message', (data) => {
    const message = JSON.parse(data.toString());
    console.log('\n📨 收到:', message.type, message.event || message.method);
    
    if (message.error) {
        console.log('❌ 错误:', message.error.message);
    }
    
    // connect.challenge
    if (message.type === 'event' && message.event === 'connect.challenge') {
        const connectRequest = {
            type: 'req',
            id: 'c1',
            method: 'connect',
            params: {
                minProtocol: 3,
                maxProtocol: 3,
                client: {
                    id: 'cli',  // 使用 'cli'
                    version: '2026.2.6-3',
                    platform: 'macos',
                    mode: 'headless'  // 添加 mode
                },
                role: 'operator',
                scopes: ['operator.read']
            }
        };
        console.log('📤 发送连接请求');
        ws.send(JSON.stringify(connectRequest));
    }
    
    // 连接成功
    if (message.id === 'c1' && message.ok) {
        console.log('✅ 连接成功！');
        console.log('完整响应:', JSON.stringify(message, null, 2));
    }
});

ws.on('error', (err) => console.error('❌', err.message));
ws.on('close', () => {
    console.log('⚠️  已关闭');
    process.exit(0);
});

setTimeout(() => ws.close(), 10000);
