# 高性能中文搜索引擎部署指南

本指南详细说明了如何将搜索引擎项目部署到 Windows Server 或 Linux 生产环境。

## 1. 环境要求

| 组件 | 版本要求 | 说明 |
|------|----------|------|
| **Operating System** | Windows Server 2019+ / Linux | 推荐 Linux 以获得最佳性能和 CGO 支持 |
| **Elasticsearch** | 8.x | 搜索引擎核心 |
| **Redis** | 6.x+ | 缓存与热搜统计 |
| **Go** | 1.21+ | 编译后端 (如果未提供二进制文件) |
| **Node.js** | 18+ | 构建前端 |
| **Nginx/IIS** | 最新稳定版 | Web 服务器与反向代理 |

## 2. 编译与构建

### 后端 (Go)
在项目根目录执行：
```powershell
cd backend
# 设置 Go 代理 (可选)
go env -w GOPROXY=https://goproxy.cn,direct
# 整理依赖
go mod tidy
# 编译 (Windows)
go build -o search-engine.exe cmd/server/main.go
# 编译 (Linux Cross-Compile)
# $Env:GOOS = "linux"; $Env:GOARCH = "amd64"; go build -o search-engine-linux cmd/server/main.go
```

### 前端 (React)
```powershell
cd frontend
npm install
npm run build
# 构建产物位于 frontend/dist/ 目录
```

## 3. 部署步骤

### 步骤 1: 部署后端服务

1.  将 `search-engine.exe` (或 Linux 二进制) 上传至服务器 `/app/backend`。
2.  配置环境变量 (System Environment Variables 或 `.env` 文件):
    *   `SERVER_PORT`: 8080
    *   `ELASTICSEARCH_URL`: http://localhost:9200
    *   `REDIS_ADDR`: localhost:6379
    *   `REDIS_PASSWORD`: (如果有)
3.  **Windows**: 使用 NSSM 安装为服务。
    ```powershell
    nssm install SearchEngineBackend "C:\app\backend\search-engine.exe"
    nssm start SearchEngineBackend
    ```
4.  **Linux**: 使用 Systemd。
    创建 `/etc/systemd/system/search-engine.service`。

### 步骤 2: 部署前端静态资源

1.  将 `frontend/dist` 目录下的所有文件上传至服务器 `/var/www/search-engine` (Linux) 或 `C:\inetpub\wwwroot\search-engine` (Windows)。

### 步骤 3: 配置反向代理 (Nginx 推荐)

配置 `nginx.conf` 以托管前端并代理 API 请求：

```nginx
server {
    listen 80;
    server_name search.yourdomain.com;

    # 前端静态文件
    location / {
        root   /var/www/search-engine;
        index  index.html index.htm;
        try_files $uri $uri/ /index.html; # 支持 React Router History 模式
    }

    # 后端 API 代理
    location /api/ {
        proxy_pass http://localhost:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

## 4. 验证与监控

1.  访问 `http://localhost:8080/health` 检查后端健康状态。
2.  访问 `http://search.yourdomain.com` 检查前端页面加载。
3.  **Swagger 文档**: 访问 `http://localhost:8080/swagger/index.html` 查看 API 文档。
4.  **日志**: 检查后端控制台输出或日志文件，确保没有 ES/Redis 连接错误。

## 5. 常见问题 (FAQ)

*   **Q: 为什么中文分词效果不好？**
    *   A: 在 Windows 环境编译时，为了规避 CGO 问题，临时使用了空格分词。请在 Linux 环境安装 GCC 后，恢复使用 `gojieba` 或切换到 `gse` 等纯 Go 分词库。
*   **Q: 前端刷新页面报 404？**
    *   A: 确保 Nginx/IIS 配置了 URL Rewrite (try_files)，将所有非静态资源请求重定向到 `index.html`。
