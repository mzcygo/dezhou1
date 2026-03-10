#!/bin/bash

# 德州扑克网站启动脚本

echo "=== 德州扑克网站启动脚本 ==="
echo "启动时间: $(date)"
echo "----------------------------"

# 检查 Node.js 是否已安装
if ! command -v node &> /dev/null; then
    echo "错误: Node.js 未安装，请先安装 Node.js"
    exit 1
fi

echo "Node.js 版本: $(node --version)"

# 检查 Redis 是否已安装
if ! command -v redis-server &> /dev/null; then
    echo "错误: Redis 未安装，请先安装 Redis"
    exit 1
fi

echo "Redis 版本: $(redis-server --version | grep -oP 'v\d+\.\d+\.\d+')"

# 检查 PostgreSQL 是否已安装
if ! command -v psql &> /dev/null; then
    echo "错误: PostgreSQL 未安装，请先安装 PostgreSQL"
    exit 1
fi

echo "PostgreSQL 版本: $(psql --version | grep -oP '\d+\.\d+')"

echo "----------------------------"
echo "所有依赖检查通过，准备启动服务..."
echo "----------------------------"

# 启动 Redis 服务
echo "启动 Redis 服务..."
redis-server --daemonize yes

# 启动 PostgreSQL 服务
echo "启动 PostgreSQL 服务..."
sudo systemctl start postgresql

echo "----------------------------"
echo "数据库服务启动完成"
echo "----------------------------"

# 创建数据库和用户
echo "创建德州扑克数据库和用户..."
psql -U postgres << EOF
CREATE DATABASE poker;
CREATE USER poker_user WITH PASSWORD 'poker_password';
GRANT ALL PRIVILEGES ON DATABASE poker TO poker_user;
EOF

echo "----------------------------"
echo "数据库创建完成"
echo "----------------------------"

# 安装 Node.js 依赖
echo "安装 Node.js 依赖..."
pm install
echo "----------------------------"

echo "德州扑克网站启动成功！"
echo "请访问 http://localhost:3000 进入游戏"
echo "----------------------------"