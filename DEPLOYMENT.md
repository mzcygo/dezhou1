# 德州扑克网站部署文档

## 环境要求

### 硬件要求
- **CPU**: 4核以上
- **内存**: 8GB 以上（推荐 16GB）
- **硬盘**: 100GB 以上 SSD
- **网络**: 100Mbps 带宽

### 软件要求
- **操作系统**: Ubuntu 20.04+ / CentOS 7+ / macOS / Windows 10+
- **Node.js**: v16.0.0 或更高版本
- **PostgreSQL**: v13.0 或更高版本
- **Redis**: v6.0 或更高版本
- **Nginx**: v1.18 或更高版本（推荐用于生产环境）

## 快速开始

### 1. 安装依赖

#### Ubuntu/Debian
```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装 Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# 安装 PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# 安装 Redis
sudo apt install -y redis-server

# 安装 Nginx
sudo apt install -y nginx
```

#### macOS
```bash
# 使用 Homebrew 安装
brew install node
brew install postgresql
brew install redis
brew install nginx
```

#### Windows
- Node.js: https://nodejs.org/
- PostgreSQL: https://www.postgresql.org/download/windows/
- Redis: https://github.com/microsoftarchive/redis/releases
- Nginx: http://nginx.org/en/download.html

### 2. 克隆项目（如适用）
```bash
git clone <your-repo-url>
cd texas-holdem-website
```

### 3. 安装 Node.js 依赖
```bash
npm install
```

### 4. 配置环境变量

创建 `.env` 文件：
```bash
cp .env.example .env
```

编辑 `.env` 文件：
```env
# 服务器配置
PORT=3000
NODE_ENV=development

# 数据库配置
PG_HOST=localhost
PG_PORT=5432
PG_DATABASE=poker
PG_USER=poker_user
PG_PASSWORD=your_secure_password

# Redis 配置
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# CORS 配置
CORS_ORIGIN=http://localhost:3000

# JWT 配置
JWT_SECRET=your_jwt_secret_key_here
JWT_EXPIRE=24h
```

### 5. 初始化数据库

#### PostgreSQL 设置
```bash
# 启动 PostgreSQL 服务
sudo systemctl start postgresql
sudo systemctl enable postgresql

# 创建数据库和用户
sudo -u postgres psql << EOF
CREATE DATABASE poker;
CREATE USER poker_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE poker TO poker_user;
EOF
```

#### 启动 Redis 服务
```bash
# 启动 Redis
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

### 6. 启动应用

#### 开发模式
```bash
npm run dev
```

#### 生产模式
```bash
npm start
```

### 7. 访问应用

打开浏览器访问：
```
http://localhost:3000
```

## 使用启动脚本

项目提供了便捷的启动脚本：

```bash
# 赋予执行权限
chmod +x start_texas_holdem.sh

# 运行脚本
./start_texas_holdem.sh
```

启动脚本会自动完成以下操作：
1. 检查 Node.js、Redis、PostgreSQL 是否已安装
2. 启动 Redis 和 PostgreSQL 服务
3. 创建数据库和用户
4. 安装 Node.js 依赖
5. 启动应用服务器

## 生产环境部署

### 1. 使用 PM2 进程管理器

```bash
# 安装 PM2
npm install -g pm2

# 启动应用
pm2 start server.js --name "poker-server"

# 查看状态
pm2 status

# 查看日志
pm2 logs poker-server

# 设置开机自启
pm2 startup
pm2 save
```

### 2. 配置 Nginx 反向代理

创建 Nginx 配置文件 `/etc/nginx/sites-available/poker`：

```nginx
upstream poker_backend {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    server_name your-domain.com;

    # 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL 证书配置
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # 日志配置
    access_log /var/log/nginx/poker_access.log;
    error_log /var/log/nginx/poker_error.log;

    # 静态文件
    location / {
        proxy_pass http://poker_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }

    # 静态资源缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://poker_backend;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # WebSocket 支持
    location /socket.io/ {
        proxy_pass http://poker_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }
}
```

启用配置：
```bash
# 创建软链接
sudo ln -s /etc/nginx/sites-available/poker /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx
```

### 3. 配置 SSL 证书（Let's Encrypt）

```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d your-domain.com

# 自动续期
sudo certbot renew --dry-run
```

### 4. 数据库优化

#### PostgreSQL 配置优化

编辑 `/etc/postgresql/13/main/postgresql.conf`：
```ini
# 内存配置
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 2621kB
min_wal_size = 1GB
max_wal_size = 4GB

# 连接配置
max_connections = 200

# 日志配置
log_min_duration_statement = 1000
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
```

重启 PostgreSQL：
```bash
sudo systemctl restart postgresql
```

#### Redis 配置优化

编辑 `/etc/redis/redis.conf`：
```ini
# 内存配置
maxmemory 2gb
maxmemory-policy allkeys-lru

# 持久化配置
save 900 1
save 300 10
save 60 10000

# 网络配置
tcp-keepalive 300
tcp-backlog 511
timeout 300

# 日志配置
loglevel notice
```

重启 Redis：
```bash
sudo systemctl restart redis-server
```

## 监控与日志

### 1. PM2 监控

```bash
# 实时监控
pm2 monit

# 查看详细信息
pm2 show poker-server

# 重启应用
pm2 restart poker-server

# 停止应用
pm2 stop poker-server
```

### 2. 日志管理

```bash
# 查看应用日志
pm2 logs poker-server --lines 100

# 查看错误日志
pm2 logs poker-server --err

# 清空日志
pm2 flush
```

### 3. 系统监控

使用监控工具（如 Prometheus + Grafana）监控系统性能：
- CPU 使用率
- 内存使用率
- 磁盘 I/O
- 网络流量
- PostgreSQL 连接数
- Redis 内存使用

## 安全加固

### 1. 防火墙配置

```bash
# 安装 UFW
sudo apt install ufw

# 默认策略
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 允许 SSH
sudo ufw allow 22/tcp

# 允许 HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 启用防火墙
sudo ufw enable
```

### 2. 数据库安全

```bash
# 修改 PostgreSQL 默认密码
sudo -u postgres psql
\password postgres

# 限制远程访问
# 编辑 /etc/postgresql/13/main/pg_hba.conf
# 仅允许本地连接
```

### 3. Redis 安全

```bash
# 设置 Redis 密码
# 编辑 /etc/redis/redis.conf
requirepass your_redis_password

# 禁用危险命令
# 编辑 /etc/redis/redis.conf
rename-command CONFIG ""
rename-command FLUSHDB ""
rename-command FLUSHALL ""
```

### 4. 应用安全

- 使用强密码
- 定期更新依赖包：`npm audit fix`
- 启用 HTTPS
- 设置 CSP 头
- 实施 CORS 策略
- 使用 Helmet 中间件

## 备份策略

### 1. PostgreSQL 备份

```bash
# 手动备份
sudo -u postgres pg_dump poker > backup_$(date +%Y%m%d_%H%M%S).sql

# 自动备份脚本
#!/bin/bash
BACKUP_DIR="/path/to/backups"
DATE=$(date +%Y%m%d_%H%M%S)
sudo -u postgres pg_dump poker > $BACKUP_DIR/backup_$DATE.sql

# 保留最近 7 天的备份
find $BACKUP_DIR -name "backup_*.sql" -mtime +7 -delete
```

### 2. Redis 备份

```bash
# 触发 RDB 快照
redis-cli BGSAVE

# 复制 RDB 文件
cp /var/lib/redis/dump.rdb /path/to/backups/dump_$(date +%Y%m%d_%H%M%S).rdb
```

### 3. 应用数据备份

```bash
# 备份上传文件
tar -czf uploads_backup_$(date +%Y%m%d_%H%M%S).tar.gz public/uploads
```

## 故障排除

### 常见问题

#### 1. 端口被占用
```bash
# 查看端口占用
sudo lsof -i :3000
sudo lsof -i :5432
sudo lsof -i :6379

# 终止进程
sudo kill -9 <PID>
```

#### 2. 数据库连接失败
```bash
# 检查 PostgreSQL 状态
sudo systemctl status postgresql

# 查看日志
sudo tail -f /var/log/postgresql/postgresql-13-main.log
```

#### 3. Redis 连接失败
```bash
# 检查 Redis 状态
sudo systemctl status redis-server

# 测试连接
redis-cli ping
```

#### 4. WebSocket 连接失败
- 检查 Nginx 配置是否正确支持 WebSocket
- 检查防火墙是否允许 WebSocket 连接
- 查看浏览器控制台错误信息

## 性能调优

### 1. Node.js 性能

```bash
# 使用 Cluster 模式
pm2 start server.js -i max --name "poker-server"
```

### 2. 数据库连接池

在 `server.js` 中调整连接池配置：
```javascript
const pgPool = new Pool({
    max: 50,              // 增加最大连接数
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});
```

### 3. Redis 连接池

使用 Redis 连接池：
```javascript
const redis = require('redis');
const { createCluster } = redis;

const cluster = createCluster({
    rootNodes: [{
        url: 'redis://localhost:6379'
    }]
});
```

## 扩展部署

### 1. 水平扩展

使用负载均衡器（如 HAProxy、AWS ELB）分发请求到多个应用实例。

### 2. 数据库读写分离

- 主库处理写操作
- 从库处理读操作
- 使用 PostgreSQL 流复制

### 3. Redis 集群

使用 Redis Cluster 实现高可用和水平扩展：
```bash
redis-cli --cluster create 127.0.0.1:7000 127.0.0.1:7001 \
127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 \
--cluster-replicas 1
```

## 维护建议

1. **定期更新**: 定期更新系统和依赖包
2. **监控告警**: 设置监控告警，及时发现问题
3. **日志分析**: 定期分析日志，优化性能
4. **备份验证**: 定期验证备份文件的可恢复性
5. **安全审计**: 定期进行安全审计和渗透测试
6. **容量规划**: 根据业务增长规划系统容量

## 支持

如有问题，请联系技术支持或查看项目文档：
- 项目文档: [项目 Wiki]
- 问题反馈: [Issue Tracker]
- 社区支持: [Discord/Slack]