# Cloudflare Temp Mail · Codex 部署方案

这是一个通过 Codex 和 Wrangler 从命令行部署 Cloudflare Temp Mail 的资料仓库。它不开发前端，也不包含 Chrome 插件；部署时直接拉取上游项目已经提供的 Vue 页面，并把页面、API 和邮件处理部署到同一个 Worker。

仓库中的部署资料不包含任何真实 Cloudflare 账号、Zone、域名、Worker、D1、密码或 Token。使用者只需要 clone 本仓库，把一次性 Prompt 交给 Codex，并提供一个已经解析到 Cloudflare 的根域名；账号、Zone ID、API/邮箱子域和资源名由部署流程自动确认或推导，管理员密码自动生成。

## 你将得到什么

- 一个新的 Cloudflare Worker。
- 一个独立的 D1 数据库和初始化 schema。
- 一个 API Custom Domain，同时提供源项目网页。
- 一个自动生成的邮箱子域和 Email Routing/Catch-all Worker 配置。
- 一组可审计的部署、验证和安全检查脚本。

## 前置条件

1. 有 Cloudflare 账号，并拥有目标 Zone 的 Workers、D1、Secrets 和 Email Routing 权限。
2. 有一个已经添加到 Cloudflare、Nameserver/DNS 已生效的域名。
3. 本机有 Node.js、npm、pnpm、git 和 curl。
4. 可以使用 `npx wrangler login` 登录 Cloudflare。

## 唯一部署方案：Codex Prompt

```bash
git clone https://github.com/lulalulaluobo/cloudflare-tempmail-deploy.git
cd cloudflare-tempmail-deploy
```

唯一需要提供给 Codex 的部署业务输入是 Cloudflare 中已生效的根域名，例如 `example.com`。脚本会按根域名稳定推导默认目标：

```text
API_DOMAIN=tempmail-api.<根域名>
MAIL_DOMAIN=tempmail.<根域名>
WORKER_NAME=cloudflare-tempmail-<根域名安全短名>
D1_NAME=temp-mail-db-<根域名安全短名>
```

Account ID 和 Zone ID 通过已授权的 Wrangler/Cloudflare API 自动确认；不要求用户复制这些 ID。若 Wrangler 尚未登录，先执行：

```bash
npx wrangler login
```

把 [`deployment-kit/one-shot-prompt.md`](deployment-kit/one-shot-prompt.md) 全文复制给 Codex，并在它询问时只提供根域名。它会先检查 Wrangler CLI、Cloudflare 登录状态、D1 等相关服务查询能力和域名配置，再自动创建/复用本次实例资源、配置 Email Routing 并执行部署和验收。用户不需要手动执行 `deploy.sh`、创建 D1、添加 Worker 域名或配置 Email Routing。

如果只需要一句调用指令：

```text
如果当前目录不是该仓库，请先执行 `git clone https://github.com/lulalulaluobo/cloudflare-tempmail-deploy.git` 并进入目录；然后读取当前仓库 `deployment-kit/one-shot-prompt.md`，按其中要求只完成一次完整的 Cloudflare temp mail 部署：先检查 Wrangler CLI、Cloudflare 登录和域名配置，只询问用户提供 Cloudflare 根域名，其余 Account ID、Zone ID、API 子域、邮箱子域、Worker 名称和 D1 名称由已授权能力自动确认或按根域名稳定生成，自动生成管理员密码，自动完成邮箱子域 Email Routing onboarding 和 Catch-all Worker 绑定，再执行 `deployment-kit/deploy.sh` 与 `deployment-kit/verify.sh`，最终输出前端地址、后端 API 地址、管理后台地址、邮箱域和管理员密码，禁止输出 JWT、OAuth token、Cookie、账号 ID 或个人 Cloudflare 信息。
```

## 部署成功后的输出

部署脚本会在成功摘要中输出以下信息：

```text
前端页面:   https://<API_DOMAIN>/
后端 API:   https://<API_DOMAIN>
管理后台:   https://<API_DOMAIN>/admin
邮箱域:     <MAIL_DOMAIN>
管理员密码: <自动生成的密码>
```

管理后台没有单独的用户名。管理员密码只在成功摘要中显示，并保存在本机被 Git 忽略的状态文件中；不要把终端截图或日志公开发布。

## Email Routing 注意事项

`API_DOMAIN` 和 `MAIL_DOMAIN` 会自动生成在 `ZONE_NAME` 下，并且互不相同。部署脚本会自动为 `MAIL_DOMAIN` 完成 Email Routing 子域 onboarding、MX/SPF 检查和 Catch-all Worker 绑定；如果目标 Zone 已有启用中的邮件路由，为避免覆盖现有服务会停止并报告原因，不会要求用户手动逐条创建规则。

如果目标是全新的独立 Zone，脚本可以自动完成该 Zone 的 Email Routing；如果只是现有 Zone 下的新子域，脚本只在确认 Zone 尚未启用邮件路由且没有现有活动规则时自动配置，不会覆盖其他收件服务，也不会用逐地址规则代替 Catch-all。

## 资料目录

- [`deployment-kit/one-shot-prompt.md`](deployment-kit/one-shot-prompt.md)：交给 Codex 的完整部署提示词。
- [`deployment-kit/deployment.env.example`](deployment-kit/deployment.env.example)：本地配置模板，不含真实值。
- [`deployment-kit/deploy.sh`](deployment-kit/deploy.sh)：部署入口。
- [`deployment-kit/verify.sh`](deployment-kit/verify.sh)：脱敏验收入口。
- [`deployment-kit/docs/independent-cli-deployment.md`](deployment-kit/docs/independent-cli-deployment.md)：部署原理与执行顺序。
- [`deployment-kit/docs/verification-checklist.md`](deployment-kit/docs/verification-checklist.md)：最终验证清单。
- [`deployment-kit/patches/`](deployment-kit/patches/)：上游版本需要的兼容补丁。

完整边界和安全约束见 [`deployment-kit/README.md`](deployment-kit/README.md)。
