# 独立临时邮箱实例：Codex + CLI 部署说明

## 目标

使用用户自己的 Cloudflare 账号和域名，创建一套相互隔离的新资源：

```text
源项目 Vue 网页 ─┐
                 ├─ HTTPS ─► <API_DOMAIN>
                 │             <WORKER_NAME> Worker ──► <D1_NAME> D1
                 │
<MAIL_DOMAIN> ──── Email Routing Catch-all ──────────────────────────────┘
```

部署脚本只操作配置中明确指定的新 Worker、D1、API 域和邮箱域，不删除或替换其他资源。

## 前置条件

1. 有 Cloudflare 账号，且目标域名已经添加到 Cloudflare，Nameserver/DNS 已生效。
2. 账号拥有目标 Zone 的 Workers、D1、Secrets 和 Email Routing 权限。
3. 本机安装 Node.js、npm、pnpm、git 和 curl；Codex 会额外检查 `npx wrangler --version`。
4. 已在本机执行 `npx wrangler login`，或准备在 Codex 检查失败时执行它。
5. `ZONE_NAME`、`API_DOMAIN`、`MAIL_DOMAIN` 属于同一个 Cloudflare Zone。
6. 如果要做真实收件，已在 Dashboard 为 `MAIL_DOMAIN` 开通 Email Routing 子域，并等待状态与 DNS/MX 记录就绪。
7. 管理员密码只通过本地 env 或交互式安全输入提供，不写入 Git。

Cloudflare 官方的子域流程见 [Email Routing subdomains](https://developers.cloudflare.com/email-service/configuration/subdomains/)。Worker API 域名使用 Custom Domain，见 [Workers Custom Domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)。

## 配置

```bash
cp deployment-kit/deployment.env.example deployment-kit/deployment.env
```

至少填写：

```dotenv
CLOUDFLARE_ACCOUNT_ID=<你的账号 ID>
CF_ZONE_ID=<你的 Zone ID>
ZONE_NAME=<你的根域>
API_DOMAIN=<你的 API 子域>
MAIL_DOMAIN=<你的邮箱子域>
ADMIN_PASSWORD=<本地管理员密码>
DEPLOY_FRONTEND=1
EMAIL_ROUTING_READY=0
```

首次部署可以留空 `D1_ID`，脚本会查找或创建；如果当前 OAuth 无法读取 D1 列表，使用创建输出中的 UUID 填回 `D1_ID` 后重跑。脚本不会删除资源，也不会把 `JWT_SECRET` 或 `ADMIN_PASSWORDS` 放进 `wrangler.toml`。

## 执行顺序

```bash
npx wrangler --version
npx wrangler whoami
./deployment-kit/deploy.sh
./deployment-kit/verify.sh
```

脚本实际完成：

1. 拉取配置中固定的上游版本，避免直接跟随漂移的 `main`。
2. 安装上游 Worker 和 Vue 前端依赖。
3. 用 `VITE_API_BASE=https://<API_DOMAIN>` 构建源项目 `frontend/` 的 `build:pages` 产物。
4. 生成独立 Wrangler 配置，绑定 D1 `DB`、新邮箱域、API Custom Domain，并用 `[assets]` 挂载 `frontend/dist/`。
5. 用 `npx wrangler d1 execute ... --remote --file=...` 初始化远程 schema。
6. 部署同一个 Worker：网页由静态资源处理，API、邮件处理和定时任务继续由 Worker 处理；随后上传新的 `JWT_SECRET` 和 `ADMIN_PASSWORDS`。

部署成功后，访问 `https://<API_DOMAIN>/` 就是源项目提供的网页，不需要另建 Pages 项目或再配置一个网页域名。

## Email Routing 的安全处理

不要执行下面两类命令来“猜测”子域范围：

```bash
npx wrangler email routing enable <MAIL_DOMAIN>
npx wrangler email routing rules update <MAIL_DOMAIN> catch-all ...
```

部分 Wrangler 版本会将它们按 Zone 处理，且 Catch-all 的 Worker 参数可能被拒绝；继续尝试可能误改同一 Zone 的其他收件路由。通用路由规则表单中的具体地址规则也不能代替 `*@<MAIL_DOMAIN>` Catch-all。

正确做法：先完成官方 Dashboard 子域 onboarding；随后只使用能明确证明目标范围的 Cloudflare API 操作，或由管理员在 Cloudflare 当前支持的子域 Catch-all 界面完成。完成后再执行 `EMAIL_ROUTING_READY=1 ./deployment-kit/deploy.sh`，脚本只做前置确认，不猜测或修改其他 Catch-all。

## 回滚与清理

- 代码回滚：重新部署已确认的上游版本，或使用 Git 恢复部署项目中的对应提交。
- Worker 回滚：使用 Cloudflare Dashboard 或 `npx wrangler rollback` 指定版本；先确认目标版本。
- 删除新资源：必须由管理员单独确认 Worker、D1、Custom Domain 和子域路由的精确目标，部署脚本默认不提供删除动作。
