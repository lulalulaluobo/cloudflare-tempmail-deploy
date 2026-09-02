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
5. 用户只需要提供已生效的 `ZONE_NAME` 根域名；脚本自动确认 Account/Zone ID，并推导同一 Zone 下的 `API_DOMAIN`、`MAIL_DOMAIN`、`WORKER_NAME` 和 `D1_NAME`。
6. Email Routing 默认自动配置：目标 Zone 在部署前必须未启用 Email Routing，且没有启用中的非丢弃路由；脚本会为 `MAIL_DOMAIN` onboarding 并设置 Catch-all。
7. 管理员密码留空，由部署脚本随机生成；成功摘要显示一次，随后只保存在本机被 Git 忽略的状态文件中。

Cloudflare 官方的子域流程见 [Email Routing subdomains](https://developers.cloudflare.com/email-service/configuration/subdomains/)。Worker API 域名使用 Custom Domain，见 [Workers Custom Domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)。

## 配置

```bash
cp deployment-kit/deployment.env.example deployment-kit/deployment.env
```

如果由 Codex 按唯一部署 Prompt 执行，用户只需要提供：

```dotenv
ZONE_NAME=<你的根域>
```

其他开关保持模板默认值即可：前端构建、自动 Email Routing、远程 schema 和随机管理员密码均由脚本负责。

默认情况下，脚本会自动生成：

```text
API_DOMAIN=tempmail-api.<ZONE_NAME>
MAIL_DOMAIN=tempmail.<ZONE_NAME>
WORKER_NAME=cloudflare-tempmail-<ZONE_NAME 安全短名>
D1_NAME=temp-mail-db-<ZONE_NAME 安全短名>
```

`CLOUDFLARE_ACCOUNT_ID`、`CF_ZONE_ID` 以及上述名称仍可在本机 `deployment.env` 中作为高级覆盖，但不属于一键 Prompt 的用户输入。脚本不会用 Prompt 示例值覆盖已有本地配置；管理员密码不需要询问。

首次部署可以留空 `D1_ID`，脚本会查找或创建；如果当前 OAuth 无法读取 D1 列表，使用创建输出中的 UUID 填回 `D1_ID` 后重跑。脚本不会删除资源，也不会把 `JWT_SECRET` 或 `ADMIN_PASSWORDS` 放进 `wrangler.toml`。

## Prompt 调用的执行顺序

本文件用于解释唯一部署 Prompt 调用的脚本流程；用户不需要把下面的脚本命令另行编排成第二套部署方案。

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

部署摘要会输出：

- 前端页面：`https://<API_DOMAIN>/`
- 后端 API：`https://<API_DOMAIN>`
- 管理后台：`https://<API_DOMAIN>/admin`
- 邮箱域：`<MAIL_DOMAIN>`
- 管理员登录密码：脚本自动生成的密码；没有单独的管理员用户名

## Email Routing 的自动处理

不要执行下面两类命令来猜测子域范围：

```bash
npx wrangler email routing enable <MAIL_DOMAIN>
npx wrangler email routing rules update <MAIL_DOMAIN> catch-all ...
```

部分 Wrangler 版本会将它们按 Zone 处理。部署脚本改用当前 Cloudflare API onboarding `MAIL_DOMAIN`，随后显式读取子域 DNS 状态并更新 Catch-all，再验证 Worker 目标；不会用逐地址规则代替 Catch-all。

为防止覆盖现有邮件服务，脚本只有在目标 Zone 原本未启用 Email Routing、且不存在启用中的非丢弃规则时才自动执行。若目标 Zone 不满足这一条件，脚本会停止并报告原因，不会要求用户手动创建逐地址规则，也不会覆盖或删除既有路由。

## 回滚与清理

- 代码回滚：重新部署已确认的上游版本，或使用 Git 恢复部署项目中的对应提交。
- Worker 回滚：使用 Cloudflare Dashboard 或 `npx wrangler rollback` 指定版本；先确认目标版本。
- 删除新资源：必须由管理员单独确认 Worker、D1、Custom Domain 和子域路由的精确目标，部署脚本默认不提供删除动作。
