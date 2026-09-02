# 部署脚本需求基线

## 目标

在不影响其他资源的前提下，部署一套独立的 `cloudflare_temp_email` Worker + D1 + Vue 前端。

## 接口

- 输入：`deployment.env`，或通过环境变量覆盖同名配置。
- 部署入口：`deployment-kit/deploy.sh`。
- 验收入口：`deployment-kit/verify.sh`。
- 默认上游：`v1.11.1`。
- 默认前端构建：`frontend` 下的 `pnpm run build:pages`。
- 输出：Worker/D1 名称、前端页面地址、后端 API 地址、管理后台地址、邮箱域和管理员密码；JWT secret、API token、Cookie 等其他 secrets 不输出。

## 安全边界

- 禁止删除、替换或复用受保护旧资源。
- `ADMIN_PASSWORD` 留空时必须随机生成，并只在部署成功摘要中显示一次；它不写入 Git，且本地状态文件必须使用忽略规则和 `600` 权限。
- 禁止打印 `JWT_SECRET`、OAuth token、Cookie 和凭据文件内容。
- 不得用 Wrangler 的 zone-level 命令猜测子域 Catch-all 范围。自动 Email Routing 只允许在目标 Zone 原本未启用且没有启用中非丢弃规则时执行；无法证明安全范围时必须停止并报告原因。

## 验收

- `bash -n deployment-kit/*.sh`。
- 新 Worker `/health_check` 返回 `OK`。
- 管理员创建地址、JWT 收件箱查询、删除地址均成功。
- `https://<API_DOMAIN>/` 返回源项目 Vue 页面。
- 自动 onboarding、MX/SPF 和目标 Worker Catch-all 均完成后，再以真实 SMTP 邮件确认收件。
