# 德州扑克网站 Docker 配置文件
# 使用多阶段构建优化镜像大小

# 阶段1: 构建阶段
FROM node:18-alpine AS builder

# 设置工作目录
WORKDIR /app

# 复制 package 文件
COPY package*.json ./

# 安装生产依赖
RUN npm ci --only=production

# 阶段2: 运行阶段
FROM node:18-alpine

# 安装必要的系统依赖
RUN apk add --no-cache \
    postgresql-client \
    redis-tools \
    curl

# 设置工作目录
WORKDIR /app

# 从构建阶段复制 node_modules
COPY --from=builder /app/node_modules ./node_modules

# 复制应用代码
COPY . .

# 创建必要的目录
RUN mkdir -p /app/public /app/logs /app/tmp

# 设置文件权限
RUN chown -R node:node /app

# 切换到非 root 用户
USER node

# 暴露端口
EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# 启动应用
CMD ["node", "server.js"]