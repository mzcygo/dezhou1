# 德州扑克网站 - 开发指南

## 项目概述

本项目是一个功能完整的在线德州扑克游戏平台，采用现代化的技术栈和工程化实践。

## 技术架构

### 后端技术栈
- **Node.js** (v16+): 服务器运行环境
- **Express.js**: Web 应用框架
- **Socket.io**: 实时双向通信
- **PostgreSQL**: 关系型数据库
- **Redis**: 缓存和会话管理
- **JWT**: 用户认证

### 前端技术栈
- **原生 JavaScript**: 核心逻辑
- **HTML5/CSS3**: 界面设计
- **Socket.io Client**: 实时通信

### 开发工具
- **Docker**: 容器化部署
- **Jest**: 单元测试框架
- **Nodemon**: 开发热重载
- **ESLint**: 代码检查

## 项目结构详解

```
texas-holdem-website/
├── server.js                      # 主服务器文件
├── package.json                   # 项目依赖和脚本
├── .env.example                   # 环境变量模板
│
├── database/                      # 数据库相关
│   └── schema.sql                # 数据库结构定义
│
├── public/                        # 前端静态文件
│   ├── index.html                # 主页面
│   ├── css/
│   │   └── style.css             # 样式文件
│   └── js/
│       └── app.js                # 前端应用逻辑
│
├── tests/                         # 测试文件
│   ├── api.test.js               # API 接口测试
│   ├── database.test.js          # 数据库测试
│   └── setup.js                  # 测试环境配置
│
├── scripts/                       # 工具脚本
│   └── init-db.js                # 数据库初始化脚本
│
├── docker-compose.yml             # Docker 编排文件
├── Dockerfile                     # Docker 镜像文件
├── jest.config.js                 # Jest 配置
├── start_texas_holdem.sh          # 启动脚本
├── api-test.postman_collection.json # API 测试集合
├── README.md                      # 项目说明
└── DEPLOYMENT.md                  # 部署文档
```

## 快速开始

### 1. 环境准备

确保你的系统已安装：
- Node.js (v16+)
- PostgreSQL (v14+)
- Redis (v6+)
- Docker (可选，推荐)

### 2. 安装依赖

```bash
npm install
```

### 3. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env 文件，填写实际配置
```

### 4. 初始化数据库

```bash
npm run init:db
```

或手动执行：
```bash
psql -U postgres -d poker -f database/schema.sql
```

### 5. 启动服务

**开发模式：**
```bash
npm run dev
```

**生产模式：**
```bash
npm start
```

**Docker 部署：**
```bash
npm run docker:up
```

## 开发工作流

### 代码规范

项目遵循以下代码规范：

1. **JavaScript 规范**
   - 使用 ES6+ 语法特性
   - 函数命名采用驼峰命名法
   - 常量使用大写字母和下划线
   - 类名使用帕斯卡命名法

2. **文件命名**
   - JavaScript 文件：`.js` 扩展名
   - 样式文件：`.css` 扩展名
   - 测试文件：`.test.js` 或 `.spec.js` 扩展名

3. **注释规范**
   - 文件头部添加文件说明注释
   - 函数添加 JSDoc 注释
   - 复杂逻辑添加行内注释

### 提交规范

使用语义化提交信息：

```
<type>(<scope>): <subject>

<body>

<footer>
```

类型（type）：
- `feat`: 新功能
- `fix`: 修复bug
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 重构
- `test`: 测试相关
- `chore`: 构建/工具相关

示例：
```
feat(game): 添加玩家弃牌功能

实现了玩家弃牌的逻辑处理，包括：
- 添加弃牌操作接口
- 更新游戏状态
- 通知其他玩家

Closes #123
```

### 分支策略

项目使用 Git Flow 分支模型：

- `main`: 生产环境分支
- `develop`: 开发主分支
- `feature/*`: 功能分支
- `bugfix/*`: 修复分支
- `hotfix/*`: 紧急修复分支

## API 开发

### 添加新接口

1. 在 `server.js` 中定义路由
2. 实现业务逻辑
3. 添加错误处理
4. 编写测试用例

示例：
```javascript
// GET /api/users
app.get('/api/users', async (req, res) => {
  try {
    const result = await pgPool.query('SELECT * FROM users');
    res.json(result.rows);
  } catch (error) {
    console.error('获取用户列表失败:', error);
    res.status(500).json({ error: '服务器错误' });
  }
});
```

### WebSocket 事件

添加新的 Socket.IO 事件处理：

```javascript
// 客户端发送事件
socket.on('eventName', async (data) => {
  try {
    // 处理逻辑
    const result = await processEvent(data);
    
    // 向客户端返回结果
    socket.emit('eventNameResponse', result);
    
    // 广播给所有客户端
    io.to('roomId').emit('eventNameBroadcast', result);
  } catch (error) {
    socket.emit('error', { message: error.message });
  }
});
```

## 数据库操作

### 查询操作

```javascript
// 简单查询
const result = await pgPool.query(
  'SELECT * FROM users WHERE id = $1',
  [userId]
);

// 带参数查询
const result = await pgPool.query(
  'SELECT * FROM games WHERE room_id = $1 AND status = $2',
  [roomId, 'active']
);

// 复杂查询
const result = await pgPool.query(`
  SELECT u.id, u.username, COUNT(g.id) as game_count
  FROM users u
  LEFT JOIN games g ON u.id = g.winner_id
  GROUP BY u.id, u.username
  ORDER BY game_count DESC
`);
```

### 事务操作

```javascript
const client = await pgPool.connect();

try {
  await client.query('BEGIN');
  
  // 执行多个操作
  await client.query('UPDATE users SET chips = chips - $1 WHERE id = $2', [amount, userId]);
  await client.query('INSERT INTO transactions (user_id, amount) VALUES ($1, $2)', [userId, -amount]);
  
  await client.query('COMMIT');
} catch (error) {
  await client.query('ROLLBACK');
  throw error;
} finally {
  client.release();
}
```

## 测试开发

### 编写单元测试

```javascript
const request = require('supertest');
const app = require('../server.js');

describe('API 测试', () => {
  test('获取用户信息', async () => {
    const response = await request(app)
      .get('/api/users/1')
      .set('Authorization', 'Bearer token');
    
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('username');
  });
});
```

### 运行测试

```bash
# 运行所有测试
npm test

# 运行特定测试文件
npm test -- tests/api.test.js

# 监听模式
npm run test:watch

# 生成覆盖率报告
npm run test:coverage
```

## 调试技巧

### 1. 日志调试

在代码中添加日志：
```javascript
console.log('调试信息:', data);
console.error('错误信息:', error);
```

### 2. 断点调试

使用 VSCode 调试器：

1. 创建 `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "launch",
      "name": "启动程序",
      "program": "${workspaceFolder}/server.js"
    }
  ]
}
```

2. 在代码中设置断点
3. 按 F5 启动调试

### 3. 数据库查询调试

```javascript
// 查看 SQL 查询
console.log('SQL:', query);
console.log('参数:', values);

// 查看查询结果
console.log('结果:', result.rows);
```

## 性能优化

### 1. 数据库优化

- 创建适当的索引
- 使用连接池
- 优化查询语句
- 使用 Redis 缓存

### 2. 应用优化

- 实现请求限流
- 压缩响应数据
- 使用 CDN 加速静态资源
- 启用 Gzip 压缩

### 3. Socket.io 优化

- 合理设置 pingInterval 和 pingTimeout
- 使用房间隔离不同游戏
- 避免频繁的事件触发

## 安全考虑

### 1. 输入验证

```javascript
// 验证用户输入
const { username, password } = req.body;

if (!username || username.length < 3 || username.length > 20) {
  return res.status(400).json({ error: '用户名长度必须在3-20之间' });
}

if (!password || password.length < 6) {
  return res.status(400).json({ error: '密码至少6位' });
}
```

### 2. SQL 注入防护

```javascript
// 使用参数化查询
const result = await pgPool.query(
  'SELECT * FROM users WHERE username = $1',
  [username]
);

// 避免直接拼接 SQL
// ❌ 错误示例
const result = await pgPool.query(`SELECT * FROM users WHERE username = '${username}'`);
```

### 3. XSS 防护

```javascript
// 使用 helmet 中间件
app.use(helmet());

// 对用户输入进行转义
const sanitizedInput = input.replace(/</g, '&lt;').replace(/>/g, '&gt;');
```

## 部署流程

### 1. 开发环境

```bash
npm run dev
```

### 2. 测试环境

```bash
# 运行测试
npm test

# 构建镜像
docker-compose build

# 启动服务
docker-compose up -d
```

### 3. 生产环境

```bash
# 设置生产环境变量
export NODE_ENV=production

# 构建生产镜像
docker-compose -f docker-compose.prod.yml build

# 部署到生产服务器
docker-compose -f docker-compose.prod.yml up -d
```

## 常见问题解决

### 1. 数据库连接失败

```bash
# 检查 PostgreSQL 服务状态
sudo systemctl status postgresql

# 检查连接配置
cat .env | grep PG_

# 测试数据库连接
psql -U postgres -h localhost -p 5432 -d poker
```

### 2. Redis 连接失败

```bash
# 检查 Redis 服务状态
redis-cli ping

# 检查 Redis 配置
cat .env | grep REDIS_

# 重启 Redis 服务
sudo systemctl restart redis
```

### 3. Socket.io 连接问题

- 检查 CORS 配置
- 确认防火墙设置
- 验证客户端连接 URL
- 检查 Socket.io 版本兼容性

## 扩展功能建议

### 1. 短期功能
- [ ] 添加用户头像上传
- [ ] 实现游戏回放功能
- [ ] 添加排行榜系统
- [ ] 实现好友系统

### 2. 中期功能
- [ ] 添加锦标赛模式
- [ ] 实现实时统计图表
- [ ] 添加游戏教学
- [ ] 实现多语言支持

### 3. 长期功能
- [ ] 移动端适配
- [ ] AI 对手功能
- [ ] 视频直播集成
- [ ] 社交媒体分享

## 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 项目仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'feat: 添加某个功能'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 联系方式

- 项目地址: [GitHub Repository]
- 问题反馈: [Issues]
- 邮箱: support@example.com

## 许可证

本项目采用 MIT 许可证。
