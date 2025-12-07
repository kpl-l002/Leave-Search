# 部署检查清单 (Deployment Checklist)

## 1. 项目结构完整性
- [x] **后端代码**: `backend/` 目录包含完整的 Go 源码。
- [x] **前端代码**: `frontend/` 目录包含 React 源码。
- [x] **配置文件**: `backend/internal/config/config.go` 定义了环境变量配置。
- [x] **依赖管理**: 
    - `backend/go.mod`: 依赖已通过 `go mod tidy` 整理。
    - `frontend/package.json`: 包含所有必要的前端依赖。

## 2. 功能测试
- [x] **后端单元测试**: 
    - `go test ./...` 运行结果: API层测试通过，Crawler/Storage/Search 模块测试通过或已规避 CGO 问题。
    - **注意**: `gojieba` 在 Windows 上因缺少 GCC 无法编译，已临时替换为简易分词器。生产环境建议在 Linux + GCC 环境下恢复 `gojieba` 或切换到纯 Go 分词库 (如 `gse`)。
- [x] **前端构建**: 
    - `npm run build` 成功生成 `dist/` 目录。
    - 修复了未使用的导入错误 (TypeScript strict check)。

## 3. 部署准备检查
- [ ] **服务器环境**:
    - 操作系统: Windows Server 2019/2022/2025 或 Linux。
    - 依赖: Elasticsearch 8.x, Redis 6.x+。
    - 端口: 8080 (后端), 80 (前端/Nginx)。
- [ ] **数据库连接**:
    - 检查 `ELASTICSEARCH_URL` 环境变量是否正确。
    - 检查 `REDIS_ADDR` 和 `REDIS_PASSWORD` 是否正确。
- [ ] **日志配置**:
    - 确认应用程序有权写入日志目录 (默认 stdout/stderr，建议配置 Log 收集)。

## 4. 性能评估
- [ ] **基准测试**:
    - 建议运行 `backend/internal/search/service_test.go` 中的 Benchmark。
- [ ] **并发能力**:
    - Go `gin` 框架默认支持高并发，建议使用 `k6` 或 `wrk` 进行压测。
- [ ] **索引优化**:
    - 确保 Elasticsearch 分片和副本配置符合生产标准 (默认 1 副本)。

## 5. 安全审查
- [x] **输入验证**:
    - API 层已实现 `validateSearchInput`，限制查询长度 (100 chars) 并过滤 XSS。
- [ ] **敏感信息**:
    - 确保 `REDIS_PASSWORD` 等敏感信息通过环境变量注入，不硬编码。
- [x] **CORS 配置**:
    - 后端已配置 CORS 中间件，生产环境需将 `AllowOrigins: []string{"*"}` 修改为具体的前端域名。
- [ ] **HTTPS**:
    - 建议在 Nginx 层配置 SSL/TLS 证书，反向代理到后端。

## 6. 故障排除
- **后端启动失败**: 检查 ES/Redis 连接，查看控制台日志。
- **分词效果差**: Windows 环境下使用了简易分词，请在 Linux 环境重新编译启用 `gojieba`。
- **前端 404**: 检查 Nginx `try_files` 配置是否指向 `index.html`。
