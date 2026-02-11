const WebSocket = require('ws');

const ws = new WebSocket('ws://localhost:18789');
console.log('🔌 连接中...');

ws.on('open', () => console.log('✅ 已连接'));

ws.on('message', (data) => {
    const msg = JSON.parse(data.toString());
    console.log(`\n${msg.type}:`, msg.event || msg.id);
    
    if (msg.event === 'connect.challenge') {
        // 尝试作为 node 连接
        ws.send(JSON.stringify({
            type: 'req',
            id: 'c1',
            method: 'connect',
            params: {
                minProtocol: 3,
                maxProtocol: 3,
                client: {
                    id: 'node',
                    version: '1.0.0',
                    platform: 'browser'
                },
                role: 'node',
                caps: ['browser'],
                device: {
                    id: 'test-device-123',
                    name: 'Test Browser'
                }
            }
        }));
        console.log('📤 发送 node 连接请求');
    }
    
    if (msg.id === 'c1') {
        if (msg.ok) {
            console.log('✅ 成功！');
            console.log(JSON.stringify(msg, null, 2));
        } else {
            console.log('❌', msg.error?.message);
        }
        setTimeout(() => ws.close(), 2000);
    }
});

ws.on('error', (e) => console.error('❌', e.message));
ws.on('close', () => {
    console.log('⚠️  关闭');
    process.exit(0);
});

setTimeout(() => ws.close(), 10000);
