const http = require('http');
const fs = require('fs');
const path = require('path');

const server = http.createServer((req, res) => {
    if (req.url === '/') {
        // 测试页面
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(`
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>音频测试</title>
</head>
<body>
    <h1>🎙️ 音频播放测试</h1>
    <button onclick="playAudio()">播放音频</button>
    <p id="status"></p>
    <audio id="audio" controls></audio>
    
    <script>
        function playAudio() {
            const audio = document.getElementById('audio');
            const status = document.getElementById('status');
            
            audio.src = '/audio/hello-voice.mp3';
            
            audio.onloadeddata = () => {
                status.textContent = '✅ 音频加载成功！';
                audio.play();
            };
            
            audio.onerror = (e) => {
                status.textContent = '❌ 音频加载失败: ' + e.message;
            };
        }
    </script>
</body>
</html>
        `);
    } else if (req.url.startsWith('/audio/')) {
        // 提供音频文件
        const filename = path.basename(req.url);
        const filepath = path.join('/tmp', filename);
        
        if (fs.existsSync(filepath)) {
            res.writeHead(200, { 
                'Content-Type': 'audio/mpeg',
                'Access-Control-Allow-Origin': '*'
            });
            fs.createReadStream(filepath).pipe(res);
        } else {
            res.writeHead(404);
            res.end('File not found');
        }
    } else {
        res.writeHead(404);
        res.end('Not found');
    }
});

server.listen(8766, () => {
    console.log('✅ 测试服务器启动: http://localhost:8766');
    console.log('📂 音频目录: /tmp/');
});
