const WebSocket = require('ws');

console.log('🔌 连接到 OpenClaw Gateway...');
const ws = new WebSocket('ws://localhost:18789');

ws.on('open', () => {
    console.log('✅ WebSocket 已连接');
});

ws.on('message', (data) => {
    const message = JSON.parse(data.toString());
    console.log('\n📨 收到消息:');
    console.log(JSON.stringify(message, null, 2));
    
    // 如果是 connect.challenge，响应连接
    if (message.type === 'event' && message.event === 'connect.challenge') {
        const connectRequest = {
            type: 'req',
            id: 'connect-1',
            method: 'connect',
            params: {
                minProtocol: 3,
                maxProtocol: 3,
                client: {
                    id: 'test-client',
                    version: '1.0.0',
                    platform: 'browser',
                    mode: 'operator'
                },
                role: 'operator',
                scopes: ['operator.read', 'operator.write']
            }
        };
        console.log('\n📤 发送连接请求...');
        ws.send(JSON.stringify(connectRequest));
    }
    
    // 如果连接成功，尝试发送消息
    if (message.type === 'res' && message.ok && message.id === 'connect-1') {
        console.log('\n✅ 连接成功！现在测试发送消息...');
        setTimeout(() => {
            const chatMessage = {
                type: 'req',
                id: 'chat-1',
                method: 'chat.send',
                params: {
                    message: '你好，这是一个测试消息'
                }
            };
            console.log('\n📤 发送聊天消息...');
            ws.send(JSON.stringify(chatMessage));
        }, 1000);
    }
});

ws.on('error', (error) => {
    console.error('\n❌ WebSocket 错误:', error.message);
});

ws.on('close', () => {
    console.log('\n⚠️  WebSocket 已关闭');
    process.exit(0);
});

// 15秒后自动关闭
setTimeout(() => {
    console.log('\n🔚 测试完成，关闭连接');
    ws.close();
}, 15000);
