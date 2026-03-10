#!/bin/bash

################################################################################
# 德州扑克网站 - Ubuntu 24.04.4 一键配置环境脚本
# 自动安装 Node.js、PostgreSQL、Redis、Docker 等所有依赖
################################################################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_step() {
    echo ""
    print_message "${BLUE}" "========================================"
    print_message "${BLUE}" "$1"
    print_message "${BLUE}" "========================================"
    echo ""
}

print_success() {
    print_message "${GREEN}" "✓ $1"
}

print_error() {
    print_message "${RED}" "✗ $1"
}

print_warning() {
    print_message "${YELLOW}" "⚠ $1"
}

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "请使用 sudo 运行此脚本"
        echo "用法: sudo bash setup_ubuntu.sh"
        exit 1
    fi
}

# 更新系统
update_system() {
    print_step "更新系统包"
    
    print_message "${YELLOW}" "正在更新软件包列表..."
    apt-get update -y
    
    print_message "${YELLOW}" "正在升级已安装的软件包..."
    apt-get upgrade -y
    
    print_message "${YELLOW}" "正在安装必要的工具..."
    apt-get install -y \
        curl \
        wget \
        git \
        vim \
        unzip \
        build-essential \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release
    
    print_success "系统更新完成"
}

# 安装 Node.js 18 LTS
install_nodejs() {
    print_step "安装 Node.js 18 LTS"
    
    # 检查是否已安装 Node.js
    if command -v node &> /dev/null; then
        local current_version=$(node -v)
        print_success "Node.js 已安装，当前版本: $current_version"
        
        # 检查版本是否满足要求
        local major_version=$(echo $current_version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$major_version" -ge 16 ]; then
            print_success "Node.js 版本满足要求 (>= 16)"
            return
        else
            print_warning "Node.js 版本过低，需要升级"
        fi
    fi
    
    # 使用 NodeSource 仓库安装 Node.js 18 LTS
    print_message "${YELLOW}" "添加 NodeSource 仓库..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    
    print_message "${YELLOW}" "正在安装 Node.js..."
    apt-get install -y nodejs
    
    # 验证安装
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        local node_version=$(node -v)
        local npm_version=$(npm -v)
        print_success "Node.js 安装成功，版本: $node_version"
        print_success "npm 安装成功，版本: $npm_version"
    else
        print_error "Node.js 安装失败"
        exit 1
    fi
    
    # 设置 npm 镜像源（可选，使用淘宝镜像加速）
    print_message "${YELLOW}" "设置 npm 镜像源为淘宝镜像..."
    npm config set registry https://registry.npmmirror.com
    print_success "npm 镜像源设置完成"
}

# 安装 PostgreSQL 14
install_postgresql() {
    print_step "安装 PostgreSQL 14"
    
    # 检查是否已安装 PostgreSQL
    if command -v psql &> /dev/null; then
        local pg_version=$(psql --version | grep -oP '\d+\.\d+' | head -1)
        print_success "PostgreSQL 已安装，版本: $pg_version"
        return
    fi
    
    # 添加 PostgreSQL 官方仓库
    print_message "${YELLOW}" "添加 PostgreSQL 官方仓库..."
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    apt-get update -y
    
    # 安装 PostgreSQL 14
    print_message "${YELLOW}" "正在安装 PostgreSQL 14..."
    apt-get install -y postgresql-14 postgresql-contrib-14
    
    # 启动 PostgreSQL 服务
    print_message "${YELLOW}" "启动 PostgreSQL 服务..."
    systemctl start postgresql
    systemctl enable postgresql
    
    # 验证安装
    if systemctl is-active --quiet postgresql; then
        print_success "PostgreSQL 服务运行正常"
        local pg_version=$(psql --version)
        print_success "PostgreSQL 版本: $pg_version"
    else
        print_error "PostgreSQL 服务启动失败"
        exit 1
    fi
}

# 配置 PostgreSQL
configure_postgresql() {
    print_step "配置 PostgreSQL 数据库"
    
    print_message "${YELLOW}" "创建数据库用户和数据库..."
    
    # 设置 postgres 用户密码（使用环境变量或默认值）
    local db_password=${DB_PASSWORD:-poker123}
    
    # 执行 SQL 配置
    sudo -u postgres psql <<EOF
-- 创建数据库用户
CREATE USER poker_user WITH PASSWORD '$db_password';

-- 创建数据库
CREATE DATABASE poker OWNER poker_user;

-- 授予权限
GRANT ALL PRIVILEGES ON DATABASE poker TO poker_user;

-- 退出
\q
EOF
    
    print_success "PostgreSQL 数据库配置完成"
    print_message "${YELLOW}" "数据库名称: poker"
    print_message "${YELLOW}" "用户名: poker_user"
    print_message "${YELLOW}" "密码: $db_password"
}

# 安装 Redis 7
install_redis() {
    print_step "安装 Redis 7"
    
    # 检查是否已安装 Redis
    if command -v redis-server &> /dev/null; then
        local redis_version=$(redis-server --version | grep -oP '\d+\.\d+\.\d+')
        print_success "Redis 已安装，版本: $redis_version"
        
        # 启动 Redis 服务（如果未运行）
        if ! systemctl is-active --quiet redis-server; then
            systemctl start redis-server
            print_success "Redis 服务已启动"
        fi
        
        return
    fi
    
    # 添加 Redis 官方仓库
    print_message "${YELLOW}" "添加 Redis 官方仓库..."
    add-apt-repository ppa:redislabs/redis -y
    apt-get update -y
    
    # 安装 Redis
    print_message "${YELLOW}" "正在安装 Redis..."
    apt-get install -y redis-server
    
    # 启动 Redis 服务
    print_message "${YELLOW}" "启动 Redis 服务..."
    systemctl start redis-server
    systemctl enable redis-server
    
    # 验证安装
    if systemctl is-active --quiet redis-server; then
        print_success "Redis 服务运行正常"
        local redis_version=$(redis-server --version)
        print_success "Redis 版本: $redis_version"
    else
        print_error "Redis 服务启动失败"
        exit 1
    fi
}

# 安装 Docker 和 Docker Compose
install_docker() {
    print_step "安装 Docker 和 Docker Compose"
    
    # 检查是否已安装 Docker
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | grep -oP '\d+\.\d+\.\d+')
        print_success "Docker 已安装，版本: $docker_version"
        
        # 检查 Docker Compose
        if command -v docker-compose &> /dev/null; then
            local compose_version=$(docker-compose --version | grep -oP '\d+\.\d+\.\d+')
            print_success "Docker Compose 已安装，版本: $compose_version"
            return
        fi
    fi
    
    # 添加 Docker 官方 GPG 密钥
    print_message "${YELLOW}" "添加 Docker 官方 GPG 密钥..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # 添加 Docker 仓库
    print_message "${YELLOW}" "添加 Docker 仓库..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update -y
    
    # 安装 Docker
    print_message "${YELLOW}" "正在安装 Docker..."
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # 启动 Docker 服务
    print_message "${YELLOW}" "启动 Docker 服务..."
    systemctl start docker
    systemctl enable docker
    
    # 将当前用户添加到 docker 组（避免每次使用 sudo）
    print_message "${YELLOW}" "配置 Docker 用户权限..."
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
        print_success "用户 $SUDO_USER 已添加到 docker 组"
        print_warning "请注销后重新登录，或运行 'newgrp docker' 使配置生效"
    fi
    
    # 验证安装
    if systemctl is-active --quiet docker; then
        print_success "Docker 服务运行正常"
        local docker_version=$(docker --version)
        print_success "Docker 版本: $docker_version"
        
        # 测试 Docker
        if docker run --rm hello-world &> /dev/null; then
            print_success "Docker 运行测试通过"
        else
            print_warning "Docker 运行测试失败，可能需要用户重新登录"
        fi
    else
        print_error "Docker 服务启动失败"
        exit 1
    fi
}

# 安装 Nginx（可选，用于生产环境）
install_nginx() {
    print_step "安装 Nginx（可选）"
    
    read -p "是否安装 Nginx 用于反向代理？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_message "${YELLOW}" "正在安装 Nginx..."
        apt-get install -y nginx
        
        systemctl start nginx
        systemctl enable nginx
        
        if systemctl is-active --quiet nginx; then
            print_success "Nginx 服务运行正常"
            local nginx_version=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')
            print_success "Nginx 版本: $nginx_version"
            print_message "${YELLOW}" "Nginx 默认配置文件: /etc/nginx/nginx.conf"
            print_message "${YELLOW}" "Nginx 网站目录: /var/www/html"
        else
            print_error "Nginx 服务启动失败"
            exit 1
        fi
    else
        print_warning "跳过 Nginx 安装"
    fi
}

# 配置防火墙
configure_firewall() {
    print_step "配置防火墙（UFW）"
    
    # 检查 UFW 是否已安装
    if ! command -v ufw &> /dev/null; then
        print_message "${YELLOW}" "正在安装 UFW 防火墙..."
        apt-get install -y ufw
    fi
    
    # 配置防火墙规则
    print_message "${YELLOW}" "配置防火墙规则..."
    
    # 允许 SSH
    ufw allow 22/tcp comment 'SSH'
    
    # 允许 HTTP/HTTPS（如果安装了 Nginx）
    if command -v nginx &> /dev/null; then
        ufw allow 80/tcp comment 'HTTP'
        ufw allow 443/tcp comment 'HTTPS'
    fi
    
    # 允许应用端口（3000）
    ufw allow 3000/tcp comment 'Texas Holdem App'
    
    # 允许 PostgreSQL（仅本地）
    # ufw allow from 127.0.0.1 to any port 5432 proto tcp comment 'PostgreSQL Local'
    
    # 允许 Redis（仅本地）
    # ufw allow from 127.0.0.1 to any port 6379 proto tcp comment 'Redis Local'
    
    # 启用防火墙
    read -p "是否启用防火墙？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_message "${YELLOW}" "启用防火墙..."
        ufw --force enable
        print_success "防火墙已启用"
    else
        print_warning "跳过防火墙启用"
    fi
    
    # 显示防火墙状态
    print_message "${YELLOW}" "当前防火墙状态："
    ufw status numbered
}

# 安装 PM2（进程管理器）
install_pm2() {
    print_step "安装 PM2 进程管理器"
    
    print_message "${YELLOW}" "正在安装 PM2..."
    npm install -g pm2
    
    # 验证安装
    if command -v pm2 &> /dev/null; then
        local pm2_version=$(pm2 -v)
        print_success "PM2 安装成功，版本: $pm2_version"
        print_message "${YELLOW}" "PM2 常用命令："
        echo "  pm2 start server.js           # 启动应用"
        echo "  pm2 stop all                  # 停止所有应用"
        echo "  pm2 restart all               # 重启所有应用"
        echo "  pm2 logs                      # 查看日志"
        echo "  pm2 startup                   # 设置开机自启"
    else
        print_error "PM2 安装失败"
        exit 1
    fi
}

# 配置项目环境
setup_project() {
    print_step "配置德州扑克项目环境"
    
    # 检查项目目录
    if [ ! -f "package.json" ]; then
        print_error "未找到 package.json，请确保在项目根目录运行此脚本"
        exit 1
    fi
    
    # 安装项目依赖
    print_message "${YELLOW}" "正在安装项目依赖..."
    npm install
    
    print_success "项目依赖安装完成"
    
    # 创建环境配置文件
    print_message "${YELLOW}" "创建环境配置文件..."
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            print_success "已从 .env.example 创建 .env 文件"
            
            # 更新数据库配置
            sed -i "s/PG_PASSWORD=.*/PG_PASSWORD=poker123/" .env
            sed -i "s/PG_DATABASE=.*/PG_DATABASE=poker/" .env
            sed -i "s/PG_USER=.*/PG_USER=poker_user/" .env
            
            print_success ".env 文件配置完成"
            print_warning "请根据需要编辑 .env 文件中的其他配置"
        else
            print_warning "未找到 .env.example，跳过环境配置文件创建"
        fi
    else
        print_success ".env 文件已存在"
    fi
    
    # 设置启动脚本权限
    if [ -f "start_texas_holdem.sh" ]; then
        chmod +x start_texas_holdem.sh
        print_success "启动脚本权限已设置"
    fi
    
    # 初始化数据库
    print_message "${YELLOW}" "初始化数据库..."
    if [ -f "database/schema.sql" ]; then
        read -p "是否现在初始化数据库？(y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo -u postgres psql -d poker -f database/schema.sql
            print_success "数据库初始化完成"
        else
            print_warning "跳过数据库初始化，稍后可运行: npm run init:db"
        fi
    else
        print_warning "未找到数据库初始化脚本"
    fi
}

# 安装完成后信息显示
show_completion_info() {
    print_step "环境配置完成！"
    
    echo ""
    print_message "${GREEN}" "🎉 所有组件已成功安装并配置！"
    echo ""
    
    print_message "${BLUE}" "已安装的组件："
    echo "  ✓ Node.js $(node -v)"
    echo "  ✓ npm $(npm -v)"
    echo "  ✓ PostgreSQL $(psql --version | grep -oP '\d+\.\d+')"
    echo "  ✓ Redis $(redis-server --version | grep -oP '\d+\.\d+\.\d+')"
    echo "  ✓ Docker $(docker --version | grep -oP '\d+\.\d+\.\d+')"
    echo "  ✓ Docker Compose"
    echo "  ✓ PM2 $(pm2 -v | grep -oP '\d+\.\d+\.\d+')"
    if command -v nginx &> /dev/null; then
        echo "  ✓ Nginx $(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')"
    fi
    echo ""
    
    print_message "${BLUE}" "数据库配置："
    echo "  数据库名: poker"
    echo "  用户名: poker_user"
    echo "  密码: poker123"
    echo ""
    
    print_message "${BLUE}" "接下来的步骤："
    echo ""
    echo "1. 如果刚添加了 docker 用户组，请重新登录："
    echo "   $ sudo logout"
    echo "   # 然后重新登录"
    echo ""
    echo "2. 安装项目依赖并初始化数据库（如果还没做）："
    echo "   $ npm install"
    echo "   $ npm run init:db"
    echo ""
    echo "3. 启动应用（选择其中一种方式）："
    echo ""
    echo "   方式一：直接启动"
    echo "   $ npm start"
    echo ""
    echo "   方式二：使用 PM2 管理（推荐生产环境）"
    echo "   $ pm2 start server.js --name texas-holdem"
    echo "   $ pm2 save"
    echo "   $ pm2 startup"
    echo ""
    echo "   方式三：使用 Docker（需要先重新登录）"
    echo "   $ docker-compose up -d"
    echo ""
    echo "4. 访问应用："
    echo "   http://localhost:3000"
    echo "   或 http://<服务器IP>:3000"
    echo ""
    echo "5. 运行测试："
    echo "   $ npm test"
    echo ""
    
    print_message "${YELLOW}" "有用的命令："
    echo "  查看应用日志: tail -f logs/app.log"
    echo "  PM2 状态: pm2 status"
    echo "  PM2 日志: pm2 logs"
    echo "  Docker 状态: docker-compose ps"
    echo "  Docker 日志: docker-compose logs -f"
    echo ""
    
    print_message "${BLUE}" "故障排除："
    echo "  查看服务状态: sudo systemctl status postgresql redis-server"
    echo "  重启服务: sudo systemctl restart postgresql redis-server"
    echo "  查看防火墙状态: sudo ufw status"
    echo "  查看端口占用: sudo netstat -tulpn"
    echo ""
    
    print_message "${GREEN}" "📚 更多信息请查看："
    echo "  - README.md: 项目说明"
    echo "  - DEPLOYMENT.md: 部署指南"
    echo "  - DEVELOPMENT.md: 开发指南"
    echo ""
    
    print_success "配置完成！祝您使用愉快！"
}

# 主函数
main() {
    echo ""
    print_message "${GREEN}" "╔═══════════════════════════════════════════════════════════╗"
    print_message "${GREEN}" "║   德州扑克网站 - Ubuntu 24.04.4 环境一键配置脚本          ║"
    print_message "${GREEN}" "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    check_root
    update_system
    install_nodejs
    install_postgresql
    configure_postgresql
    install_redis
    install_docker
    install_nginx
    configure_firewall
    install_pm2
    setup_project
    show_completion_info
}

# 运行主函数
main "$@"
