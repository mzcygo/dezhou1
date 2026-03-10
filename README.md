# 德州扑克网站

一个功能完整的在线德州扑克游戏平台，支持多房间、实时对战、筹码管理和完整的游戏流程。

## 项目特性

- 🎴 **完整游戏逻辑**：支持德州扑克完整规则，包括翻牌前、翻牌、转牌、河牌四个阶段
- 💬 **实时通信**：基于 WebSocket 的实时游戏交互和聊天功能
- 💰 **筹码系统**：完整的筹码管理、下注、结算功能
- 👥 **多房间支持**：支持现金局和锦标赛模式
- 🔒 **安全认证**：JWT 用户认证，密码加密存储
- 📊 **数据统计**：玩家游戏统计和历史记录查询
- 🚀 **容器化部署**：支持 Docker 一键部署

## 技术栈

### 后端
- **Node.js** (v16+) - 服务器运行环境
- **Express.js** - Web 框架
- **Socket.io** - WebSocket 实时通信
- **PostgreSQL** - 关系型数据库
- **Redis** - 缓存和会话管理
- **JWT** - 用户认证
- **bcrypt** - 密码加密

### 前端
- **原生 JavaScript** - 核心逻辑
- **HTML5/CSS3** - 界面设计
- **Socket.io Client** - 实时通信客户端

## 快速开始

### 前置要求

确保你的系统已安装以下软件：

- Node.js (v16 或更高版本)
- PostgreSQL (v14 或更高版本)
- Redis (v6 或更高版本)

### 方式一：使用 Docker（推荐）

```bash
# 1. 克隆项目
git clone <repository-url>
cd texas-holdem-website

# 2. 复制环境配置文件
cp .env.example .env

# 3. 编辑 .env 文件，配置数据库密码等信息
nano .env

# 4. 启动所有服务
docker-compose up -d

# 5. 查看服务状态
docker-compose ps

# 6. 查看日志
docker-compose logs -f
```

访问 `http://localhost:3000` 即可使用应用。

### 方式二：本地开发

```bash
# 1. 安装依赖
npm install

# 2. 配置环境变量
cp .env.example .env
# 编辑 .env 文件，填写数据库连接信息

# 3. 初始化数据库
psql -U postgres -d poker -f database/schema.sql

# 4. 启动应用
node server.js
```

或者使用启动脚本：

```bash
chmod +x start_texas_holdem.sh
./start_texas_holdem.sh
```

## 环境配置

在 `.env` 文件中配置以下参数：

```env
# 服务器配置
PORT=3000
NODE_ENV=development

# PostgreSQL 配置
PG_HOST=localhost
PG_PORT=5432
PG_DATABASE=poker
PG_USER=poker_user
PG_PASSWORD=your_secure_password

# Redis 配置
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# JWT 配置
JWT_SECRET=your_jwt_secret_key
JWT_EXPIRE=24h

# CORS 配置
CORS_ORIGIN=http://localhost:3000
```

## 项目结构

```
texas-holdem-website/
├── server.js                 # 服务器主文件
├── package.json             # 项目依赖配置
├── .env.example             # 环境变量模板
├── docker-compose.yml       # Docker 编排配置
├── Dockerfile              # Docker 镜像配置
├── start_texas_holdem.sh   # 启动脚本
├── DEPLOYMENT.md           # 部署文档
├── database/
│   └── schema.sql          # 数据库结构
├── public/                 # 前端静态文件
│   ├── index.html
│   ├── css/
│   │   └── style.css
│   └── js/
│       └── app.js
└── api-test.postman_collection.json  # API 测试集合
```

## API 文档

### 用户管理

#### 注册用户
```http
POST /api/auth/register
Content-Type: application/json

{
  "username": "player1",
  "email": "player1@example.com",
  "password": "SecurePass123!"
}
```

#### 用户登录
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "player1@example.com",
  "password": "SecurePass123!"
}
```

#### 获取用户信息
```http
GET /api/user/profile
Authorization: Bearer <token>
```

### 房间管理

#### 创建房间
```http
POST /api/rooms/create
Authorization: Bearer <token>
Content-Type: application/json

{
  "roomName": "新手练习场",
  "roomType": "cash",
  "minBlind": 10,
  "maxBlind": 100,
  "maxPlayers": 6
}
```

#### 获取房间列表
```http
GET /api/rooms/list
Authorization: Bearer <token>
```

#### 加入房间
```http
POST /api/rooms/join
Authorization: Bearer <token>
Content-Type: application/json

{
  "roomId": 1
}
```

### 游戏操作

#### 开始游戏
```http
POST /api/game/start
Authorization: Bearer <token>
Content-Type: application/json

{
  "roomId": 1
}
```

#### 下注操作
```http
POST /api/game/bet
Authorization: Bearer <token>
Content-Type: application/json

{
  "roomId": 1,
  "action": "raise",
  "amount": 50
}
```

支持的 action 类型：`check`, `call`, `raise`, `fold`, `allin`

## 数据库结构

### 主要数据表

- **users** - 用户信息表
- **rooms** - 游戏房间表
- **games** - 牌局记录表
- **game_participants** - 游戏参与记录表
- **bets** - 下注记录表
- **transactions** - 交易记录表
- **chat_messages** - 聊天消息表
- **player_stats** - 玩家统计表

详细结构请参考 `database/schema.sql` 文件。

## 测试

### API 测试

使用 Postman 导入 `api-test.postman_collection.json` 进行 API 测试。

1. 安装 Postman
2. 导入测试集合文件
3. 设置环境变量 `token`（从登录接口获取）
4. 运行测试用例

### 本地测试

```bash
# 运行测试套件（如果配置了）
npm test

# 启动开发模式
npm run dev
```

## 部署

### Docker 部署

```bash
# 构建并启动所有服务
docker-compose up -d

# 停止服务
docker-compose down

# 查看日志
docker-compose logs -f app
```

### 生产环境部署

详细部署指南请参考 `DEPLOYMENT.md` 文档。

生产环境建议：
- 使用 Nginx 作为反向代理
- 配置 HTTPS 证书
- 启用 Redis 持久化
- 配置 PostgreSQL 定期备份
- 设置日志轮转

## 常见问题

### 数据库连接失败

检查 `.env` 文件中的数据库配置是否正确，确保 PostgreSQL 服务正在运行。

```bash
# 检查 PostgreSQL 状态
docker-compose ps postgres

# 查看日志
docker-compose logs postgres
```

### Redis 连接失败

确保 Redis 服务正在运行：

```bash
# 检查 Redis 状态
docker-compose ps redis

# 查看 Redis 日志
docker-compose logs redis
```

### WebSocket 连接失败

检查防火墙设置，确保 3000 端口可访问。如果使用 Nginx 反向代理，需要配置 WebSocket 支持。

## 开发指南

### 添加新功能

1. 在 `server.js` 中添加新的路由和中间件
2. 更新数据库结构（如需要）
3. 在 `public/js/app.js` 中添加前端逻辑
4. 更新 API 文档

### 代码规范

- 使用 ESLint 进行代码检查
- 遵循 JavaScript 编码规范
- 添加必要的注释和文档
- 编写单元测试

## 安全建议

- 定期更新依赖包：`npm audit fix`
- 使用强密码和密钥
- 启用 HTTPS
- 限制 API 请求频率
- 定期备份数据库
- 监控异常访问

## 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 项目
2. 创建功能分支：`git checkout -b feature/AmazingFeature`
3. 提交更改：`git commit -m 'Add some AmazingFeature'`
4. 推送到分支：`git push origin feature/AmazingFeature`
5. 提交 Pull Request

## 许可证

本项目采用 MIT 许可证。详情请参阅 LICENSE 文件。

## 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 Issue
- 发送邮件至：support@example.com
- 加入 Discord 社区

## 更新日志

### v1.0.0 (2024-03-10)
- 初始版本发布
- 实现基本游戏功能
- 支持多房间和实时通信
- 完善的用户认证和筹码系统

---

**祝您游戏愉快！** 🎴