#!/bin/bash
# 德州扑克网站快速启动脚本
# 适用于 Ubuntu 24.04.4 服务器

echo "=========================================="
echo "  德州扑克网站 - 快速启动脚本"
echo "=========================================="

# 停止旧的 PM2 进程
echo "停止旧进程..."
pm2 delete texas-holdem 2>/dev/null

# 进入项目目录
cd /home/test1/dezhou1

# 检查环境变量文件
if [ ! -f .env ]; then
    echo "创建环境变量文件..."
    cp .env.example .env
    sed -i "s/PG_PASSWORD=.*/PG_PASSWORD=poker123/" .env
    sed -i "s/PG_DATABASE=.*/PG_DATABASE=poker/" .env
    sed -i "s/PG_USER=.*/PG_USER=poker_user/" .env
    sed -i "s/PG_HOST=.*/PG_HOST=localhost/" .env
    sed -i "s/PG_PORT=.*/PG_PORT=5432/" .env
    sed -i "s/REDIS_HOST=.*/REDIS_HOST=localhost/" .env
    sed -i "s/REDIS_PORT=.*/REDIS_PORT=6379/" .env
    sed -i "s/PORT=.*/PORT=3000/" .env
    sed -i "s|CORS_ORIGIN=.*|CORS_ORIGIN=*|" .env
fi

# 检查数据库是否创建
echo "检查数据库..."
sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw poker || {
    echo "创建数据库..."
    sudo -u postgres psql <<EOF
CREATE DATABASE poker;
CREATE USER poker_user WITH PASSWORD 'poker123';
GRANT ALL PRIVILEGES ON DATABASE poker TO poker_user;
\q
EOF
}

# 初始化数据库
echo "初始化数据库..."
node scripts/init-db.js 2>/dev/null || echo "数据库可能已初始化"

# 启动应用
echo "启动应用..."
pm2 start server.js --name texas-holdem --max-memory-restart 500M

# 等待启动
sleep 3

# 显示状态
echo ""
echo "=========================================="
echo "  启动完成！"
echo "=========================================="
pm2 status

echo ""
echo "访问地址："
echo "  本地访问: http://localhost:3000"
echo "  服务器IP: http://$(hostname -I | awk '{print $1}'):3000"
echo ""
echo "常用命令："
echo "  查看日志: pm2 logs texas-holdem"
echo "  重启应用: pm2 restart texas-holdem"
echo "  停止应用: pm2 stop texas-holdem"
echo "=========================================="
