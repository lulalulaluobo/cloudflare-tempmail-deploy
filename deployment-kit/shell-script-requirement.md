# 部署脚本需求基线

## 目标

在不影响其他资源的前提下，部署一套独立的 `cloudflare_temp_email` Worker + D1 + Vue 前端。

## 接口

- 输入：`deployment.env`，或通过环境变量覆盖同名配置。
- 部署入口：`deployment-kit/deploy.sh`。
- 验收入口：`deployment-kit/verify.sh`。
- 默认上游：`v1.11.1`。
- 默认前端构建：`frontend` 下的 `pnpm run build:pages`。
- 输出：非敏感资源名、网页/API 地址；不输出 secrets。

## 安全边界

- 禁止删除、替换或复用受保护旧资源。
- 禁止打印 `ADMIN_PASSWORD`、`JWT_SECRET`、OAuth token、Cookie 和凭据文件内容。
- Email Routing 的 zone-level 命令不得被当作子域 Catch-all 操作；无法证明目标范围时必须停在人工步骤。

## 验收

- `bash -n deployment-kit/*.sh scripts/*.sh`。
- 新 Worker `/health_check` 返回 `OK`。
- 管理员创建地址、JWT 收件箱查询、删除地址均成功。
- `https://<API_DOMAIN>/` 返回源项目 Vue 页面。
- 真实邮件收取只有在新邮箱子域 Catch-all 已完成后才算通过。
