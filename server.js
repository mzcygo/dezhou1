/**
 * 德州扑克网站主服务器
 * 使用 Node.js + Express + Socket.IO + PostgreSQL + Redis
 */

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const { Pool } = require('pg');
const redis = require('redis');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

// 初始化应用
const app = express();
const server = http.createServer(app);

// Socket.IO 配置
const io = socketIo(server, {
    cors: {
        origin: process.env.CORS_ORIGIN || "http://localhost:3000",
        methods: ["GET", "POST"],
        credentials: true
    },
    pingTimeout: 10000,
    pingInterval: 5000
});

// 安全中间件
app.use(helmet({
    contentSecurityPolicy: false,
    crossOriginEmbedderPolicy: false
}));
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// 限流配置
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15分钟
    max: 100, // 限制每个IP 15分钟内最多100个请求
    message: '请求过于频繁，请稍后再试'
});
app.use('/api/', limiter);

// PostgreSQL 连接池配置
const pgPool = new Pool({
    host: process.env.PG_HOST || 'localhost',
    port: process.env.PG_PORT || 5432,
    database: process.env.PG_DATABASE || 'poker',
    user: process.env.PG_USER || 'poker_user',
    password: process.env.PG_PASSWORD || 'poker_password',
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Redis 客户端配置
const redisClient = redis.createClient({
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD || undefined
});

redisClient.on('error', (err) => {
    console.error('Redis 错误:', err);
});

redisClient.connect();

// 内存中存储的游戏房间
const rooms = new Map();

// 德州扑克牌组
class Deck {
    constructor() {
        this.suits = ['♠', '♥', '♦', '♣'];
        this.ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
        this.cards = [];
        this.reset();
    }

    reset() {
        this.cards = [];
        for (let suit of this.suits) {
            for (let rank of this.ranks) {
                this.cards.push({ suit, rank });
            }
        }
        this.shuffle();
    }

    shuffle() {
        for (let i = this.cards.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [this.cards[i], this.cards[j]] = [this.cards[j], this.cards[i]];
        }
    }

    deal() {
        return this.cards.pop();
    }
}

// 游戏房间类
class GameRoom {
    constructor(id, name, maxPlayers = 9) {
        this.id = id;
        this.name = name;
        this.maxPlayers = maxPlayers;
        this.players = [];
        this.deck = new Deck();
        this.communityCards = [];
        this.pot = 0;
        this.currentBet = 0;
        this.dealerIndex = 0;
        this.currentPlayerIndex = 0;
        this.gamePhase = 'waiting'; // waiting, preflop, flop, turn, river, showdown
        this.status = 'waiting';
    }

    addPlayer(player) {
        if (this.players.length < this.maxPlayers) {
            this.players.push({
                ...player,
                hand: [],
                chips: player.chips || 100000,
                currentBet: 0,
                folded: false,
                allIn: false
            });
            return true;
        }
        return false;
    }

    removePlayer(playerId) {
        const index = this.players.findIndex(p => p.id === playerId);
        if (index !== -1) {
            this.players.splice(index, 1);
            return true;
        }
        return false;
    }

    startGame() {
        if (this.players.length < 2) {
            return false;
        }

        this.gamePhase = 'preflop';
        this.status = 'playing';
        this.deck.reset();
        this.communityCards = [];
        this.pot = 0;
        this.currentBet = 0;

        // 重置玩家状态
        this.players.forEach(player => {
            player.hand = [];
            player.currentBet = 0;
            player.folded = false;
            player.allIn = false;
        });

        // 发牌
        for (let i = 0; i < 2; i++) {
            this.players.forEach(player => {
                player.hand.push(this.deck.deal());
            });
        }

        this.currentPlayerIndex = this.dealerIndex;
        return true;
    }

    nextPhase() {
        const phases = ['preflop', 'flop', 'turn', 'river', 'showdown'];
        const currentIndex = phases.indexOf(this.gamePhase);

        if (currentIndex < phases.length - 1) {
            this.gamePhase = phases[currentIndex + 1];

            // 发公共牌
            if (this.gamePhase === 'flop') {
                this.communityCards.push(this.deck.deal());
                this.communityCards.push(this.deck.deal());
                this.communityCards.push(this.deck.deal());
            } else if (this.gamePhase === 'turn' || this.gamePhase === 'river') {
                this.communityCards.push(this.deck.deal());
            }

            this.currentPlayerIndex = this.dealerIndex;
            return true;
        }

        return false;
    }

    getCurrentPlayer() {
        return this.players[this.currentPlayerIndex];
    }

    nextPlayer() {
        do {
            this.currentPlayerIndex = (this.currentPlayerIndex + 1) % this.players.length;
        } while (this.players[this.currentPlayerIndex].folded ||
                 this.players[this.currentPlayerIndex].allIn);

        return this.players[this.currentPlayerIndex];
    }
}

// 路由定义

// 用户注册
app.post('/api/register', async (req, res) => {
    try {
        const { username, password, email } = req.body;

        // 验证输入
        if (!username || !password || !email) {
            return res.status(400).json({ error: '请填写所有必填字段' });
        }

        // 检查用户是否已存在
        const existingUser = await pgPool.query(
            'SELECT id FROM users WHERE username = $1 OR email = $2',
            [username, email]
        );

        if (existingUser.rows.length > 0) {
            return res.status(400).json({ error: '用户名或邮箱已存在' });
        }

        // 创建用户
        const result = await pgPool.query(
            'INSERT INTO users (username, password, email, chips, created_at) VALUES ($1, $2, $3, 100000, NOW()) RETURNING id, username, email, chips',
            [username, password, email]
        );

        const user = result.rows[0];

        // 缓存用户信息到 Redis
        await redisClient.setEx(`user:${user.id}`, 3600, JSON.stringify(user));

        res.json({
            message: '注册成功',
            user: {
                id: user.id,
                username: user.username,
                email: user.email,
                chips: user.chips
            }
        });

    } catch (error) {
        console.error('注册错误:', error);
        res.status(500).json({ error: '服务器错误' });
    }
});

// 用户登录
app.post('/api/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({ error: '请提供用户名和密码' });
        }

        // 从 PostgreSQL 查询用户
        const result = await pgPool.query(
            'SELECT id, username, password, email, chips FROM users WHERE username = $1 AND password = $2',
            [username, password]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({ error: '用户名或密码错误' });
        }

        const user = result.rows[0];

        // 缓存用户会话
        const token = `${user.id}:${Date.now()}`;
        await redisClient.setEx(`session:${token}`, 3600, JSON.stringify(user));

        res.json({
            message: '登录成功',
            token: token,
            user: {
                id: user.id,
                username: user.username,
                email: user.email,
                chips: user.chips
            }
        });

    } catch (error) {
        console.error('登录错误:', error);
        res.status(500).json({ error: '服务器错误' });
    }
});

// 获取房间列表
app.get('/api/rooms', async (req, res) => {
    try {
        // 从缓存获取房间列表
        const cachedRooms = await redisClient.get('rooms:list');

        if (cachedRooms) {
            return res.json(JSON.parse(cachedRooms));
        }

        // 构建房间列表
        const roomList = Array.from(rooms.values()).map(room => ({
            id: room.id,
            name: room.name,
            playerCount: room.players.length,
            maxPlayers: room.maxPlayers,
            status: room.status,
            pot: room.pot
        }));

        // 缓存房间列表 (1分钟)
        await redisClient.setEx('rooms:list', 60, JSON.stringify(roomList));

        res.json(roomList);

    } catch (error) {
        console.error('获取房间列表错误:', error);
        res.status(500).json({ error: '服务器错误' });
    }
});

// 创建房间
app.post('/api/rooms', async (req, res) => {
    try {
        const { name, maxPlayers } = req.body;
        const roomId = `room_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

        const newRoom = new GameRoom(roomId, name, maxPlayers || 9);
        rooms.set(roomId, newRoom);

        // 清除房间列表缓存
        await redisClient.del('rooms:list');

        res.json({
            message: '房间创建成功',
            room: {
                id: newRoom.id,
                name: newRoom.name,
                maxPlayers: newRoom.maxPlayers,
                status: newRoom.status
            }
        });

    } catch (error) {
        console.error('创建房间错误:', error);
        res.status(500).json({ error: '服务器错误' });
    }
});

// Socket.IO 连接处理
io.on('connection', (socket) => {
    console.log('用户连接:', socket.id);

    // 用户加入房间
    socket.on('joinRoom', async (data) => {
        try {
            const { roomId, player } = data;

            if (!rooms.has(roomId)) {
                socket.emit('error', { message: '房间不存在' });
                return;
            }

            const room = rooms.get(roomId);

            if (!room.addPlayer(player)) {
                socket.emit('error', { message: '房间已满' });
                return;
            }

            socket.join(roomId);

            // 通知房间内所有玩家
            io.to(roomId).emit('playerJoined', {
                player: player,
                players: room.players
            });

            console.log(`玩家 ${player.username} 加入房间 ${roomId}`);

        } catch (error) {
            console.error('加入房间错误:', error);
            socket.emit('error', { message: '加入房间失败' });
        }
    });

    // 开始游戏
    socket.on('startGame', async (data) => {
        try {
            const { roomId, playerId } = data;

            const room = rooms.get(roomId);
            if (!room) {
                socket.emit('error', { message: '房间不存在' });
                return;
            }

            if (!room.startGame()) {
                socket.emit('error', { message: '需要至少2名玩家才能开始游戏' });
                return;
            }

            // 发送初始手牌给每个玩家
            room.players.forEach(player => {
                const playerSocket = Array.from(io.sockets.sockets.values())
                    .find(s => s.handshake.auth.playerId === player.id);

                if (playerSocket) {
                    playerSocket.emit('gameStarted', {
                        hand: player.hand,
                        communityCards: room.communityCards,
                        pot: room.pot,
                        currentBet: room.currentBet
                    });
                }
            });

            // 广播游戏状态
            io.to(roomId).emit('gameState', {
                phase: room.gamePhase,
                communityCards: room.communityCards,
                pot: room.pot,
                currentBet: room.currentBet,
                currentPlayer: room.getCurrentPlayer().username
            });

        } catch (error) {
            console.error('开始游戏错误:', error);
            socket.emit('error', { message: '开始游戏失败' });
        }
    });

    // 玩家行动（下注、跟注、弃牌等）
    socket.on('playerAction', async (data) => {
        try {
            const { roomId, playerId, action, amount } = data;

            const room = rooms.get(roomId);
            if (!room) {
                socket.emit('error', { message: '房间不存在' });
                return;
            }

            const currentPlayer = room.getCurrentPlayer();

            // 验证是否是当前玩家的回合
            if (currentPlayer.id !== playerId) {
                socket.emit('error', { message: '不是你的回合' });
                return;
            }

            // 处理不同的玩家行动
            switch (action) {
                case 'bet':
                    if (currentPlayer.chips < amount) {
                        socket.emit('error', { message: '筹码不足' });
                        return;
                    }
                    currentPlayer.chips -= amount;
                    currentPlayer.currentBet += amount;
                    room.pot += amount;
                    room.currentBet = Math.max(room.currentBet, currentPlayer.currentBet);
                    break;

                case 'call':
                    const callAmount = room.currentBet - currentPlayer.currentBet;
                    if (currentPlayer.chips < callAmount) {
                        socket.emit('error', { message: '筹码不足' });
                        return;
                    }
                    currentPlayer.chips -= callAmount;
                    currentPlayer.currentBet = room.currentBet;
                    room.pot += callAmount;
                    break;

                case 'check':
                    if (room.currentBet > currentPlayer.currentBet) {
                        socket.emit('error', { message: '不能过牌' });
                        return;
                    }
                    break;

                case 'fold':
                    currentPlayer.folded = true;
                    break;

                case 'allIn':
                    const allInAmount = currentPlayer.chips;
                    room.pot += allInAmount;
                    currentPlayer.currentBet += allInAmount;
                    currentPlayer.chips = 0;
                    currentPlayer.allIn = true;
                    break;

                default:
                    socket.emit('error', { message: '无效的行动' });
                    return;
            }

            // 广播玩家行动
            io.to(roomId).emit('playerAction', {
                playerId: playerId,
                action: action,
                amount: amount,
                pot: room.pot,
                currentBet: room.currentBet
            });

            // 检查是否进入下一阶段
            const activePlayers = room.players.filter(p => !p.folded);
            if (activePlayers.length === 1 || room.nextPhase()) {
                // 游戏结束或进入下一阶段
                if (room.gamePhase === 'showdown') {
                    // 摊牌并决定胜负
                    const winner = determineWinner(room);
                    room.players.forEach(p => {
                        if (p.id === winner.id) {
                            p.chips += room.pot;
                        }
                    });

                    io.to(roomId).emit('gameEnded', {
                        winner: winner,
                        pot: room.pot
                    });

                    room.status = 'waiting';
                    room.pot = 0;
                    room.currentBet = 0;
                } else {
                    io.to(roomId).emit('nextPhase', {
                        phase: room.gamePhase,
                        communityCards: room.communityCards,
                        pot: room.pot
                    });
                }
            } else {
                // 下一个玩家
                room.nextPlayer();
                io.to(roomId).emit('nextTurn', {
                    currentPlayer: room.getCurrentPlayer().username
                });
            }

        } catch (error) {
            console.error('玩家行动错误:', error);
            socket.emit('error', { message: '行动处理失败' });
        }
    });

    // 玩家发送聊天消息
    socket.on('chatMessage', (data) => {
        const { roomId, message, player } = data;

        // 广播聊天消息到房间
        io.to(roomId).emit('chatMessage', {
            player: player,
            message: message,
            timestamp: new Date()
        });
    });

    // 玩家断开连接
    socket.on('disconnect', () => {
        console.log('用户断开连接:', socket.id);
    });
});

// 决定胜负的函数
function determineWinner(room) {
    const activePlayers = room.players.filter(p => !p.folded);

    // 简化版：随机选择一个活跃玩家作为赢家
    // 实际项目中需要实现完整的德州扑克牌型比较逻辑
    const winner = activePlayers[Math.floor(Math.random() * activePlayers.length)];

    return winner;
}

// 健康检查
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date(),
        uptime: process.uptime(),
        connections: io.engine.clientsCount
    });
});

// 初始化数据库表
async function initializeDatabase() {
    try {
        // 创建用户表
        await pgPool.query(`
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(50) UNIQUE NOT NULL,
                password VARCHAR(255) NOT NULL,
                email VARCHAR(100) UNIQUE NOT NULL,
                chips INTEGER DEFAULT 100000,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        // 创建游戏记录表
        await pgPool.query(`
            CREATE TABLE IF NOT EXISTS games (
                id SERIAL PRIMARY KEY,
                room_id VARCHAR(100),
                winner_id INTEGER REFERENCES users(id),
                pot INTEGER,
                start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                end_time TIMESTAMP
            )
        `);

        // 创建玩家操作记录表
        await pgPool.query(`
            CREATE TABLE IF NOT EXISTS game_actions (
                id SERIAL PRIMARY KEY,
                game_id INTEGER REFERENCES games(id),
                player_id INTEGER REFERENCES users(id),
                action_type VARCHAR(20),
                amount INTEGER,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        console.log('数据库表初始化完成');

    } catch (error) {
        console.error('数据库初始化错误:', error);
        process.exit(1);
    }
}

// 启动服务器
const PORT = process.env.PORT || 3000;

initializeDatabase().then(() => {
    server.listen(PORT, () => {
        console.log(`德州扑克服务器运行在端口 ${PORT}`);
        console.log(`访问地址: http://localhost:${PORT}`);
        console.log(`健康检查: http://localhost:${PORT}/health`);
    });
});

// 优雅关闭
process.on('SIGTERM', async () => {
    console.log('收到 SIGTERM 信号，开始关闭服务器...');

    await pgPool.end();
    await redisClient.quit();

    server.close(() => {
        console.log('服务器已关闭');
        process.exit(0);
    });
});

// 错误处理
process.on('uncaughtException', (err) => {
    console.error('未捕获的异常:', err);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('未处理的 Promise 拒绝:', reason);
    process.exit(1);
});