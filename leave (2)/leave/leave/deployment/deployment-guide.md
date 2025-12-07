# 部署指南

本指南介绍了如何在 Windows Server 上部署 Go 后端和 React 前端。

## 环境要求

1.  **Windows Server 2019/2022/2025**
2.  **Go 1.21+** (编译后端)
3.  **Node.js 18+** (构建前端)
4.  **Elasticsearch 8.x**
5.  **Redis 6.x+**
6.  **Nginx** (反向代理)
7.  **IIS** (可选，作为 Web 服务器)

## 部署步骤

### 1. 后端部署

1.  在开发机上编译 Go 后端：
    ```powershell
    cd backend
    go build -o search-engine.exe cmd/server/main.go
    ```
2.  将 `search-engine.exe` 和 `config` 目录复制到服务器。
3.  配置环境变量 (System Environment Variables)：
    *   `SERVER_PORT`: 8080
    *   `ELASTICSEARCH_URL`: http://localhost:9200
    *   `REDIS_ADDR`: localhost:6379
4.  使用 NSSM (Non-Sucking Service Manager) 将其安装为 Windows 服务：
    ```powershell
    nssm install SearchEngineBackend "C:\path\to\search-engine.exe"
    nssm start SearchEngineBackend
    ```

### 2. 前端部署

1.  构建 React 前端：
    ```powershell
    cd frontend
    npm install
    npm run build
    ```
2.  将 `frontend/dist` 目录的内容复制到服务器的 Web 目录 (例如 `C:\inetpub\wwwroot\search-engine`).

### 3. Nginx 配置 (推荐)

安装 Nginx for Windows，并配置 `nginx.conf`：

```nginx
server {
    listen 80;
    server_name localhost;

    location / {
        root   C:/inetpub/wwwroot/search-engine;
        index  index.html index.htm;
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://localhost:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 4. IIS 配置 (替代方案)

1.  安装 IIS 和 URL Rewrite 模块。
2.  添加网站，指向 `frontend/dist` 目录。
3.  配置反向代理规则，将 `/api` 转发到 `http://localhost:8080`。

## 故障排除

*   **后端无法启动**：检查 Elasticsearch 和 Redis 是否正在运行。检查日志输出。
*   **前端 404**：确保 Nginx `try_files` 配置正确，或 IIS URL Rewrite 规则正确。
*   **跨域问题**：检查 Nginx 反向代理配置，确保 `/api` 转发正确。
