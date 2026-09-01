# Cloudflare Temp Mail · Codex 部署方案

这是一个通过 Codex 和 Wrangler 从命令行部署 Cloudflare Temp Mail 的资料仓库。它不开发前端，也不包含 Chrome 插件；部署时直接拉取上游项目已经提供的 Vue 页面，并把页面、API 和邮件处理部署到同一个 Worker。

仓库中的部署资料不包含任何真实 Cloudflare 账号、Zone、域名、Worker、D1、密码或 Token。使用者只需要 clone 本仓库，把一次性 Prompt 交给 Codex；缺少的账号/域名配置在部署过程中询问，管理员密码自动生成。

## 你将得到什么

- 一个新的 Cloudflare Worker。
- 一个独立的 D1 数据库和初始化 schema。
- 一个 API Custom Domain，同时提供源项目网页。
- 一个用于收信的邮箱子域和 Email Routing/Catch-all 配置指引。
- 一组可审计的部署、验证和安全检查脚本。

## 前置条件

1. 有 Cloudflare 账号，并拥有目标 Zone 的 Workers、D1、Secrets 和 Email Routing 权限。
2. 有一个已经添加到 Cloudflare、Nameserver/DNS 已生效的域名。
3. 本机有 Node.js、npm、pnpm、git 和 curl。
4. 可以使用 `npx wrangler login` 登录 Cloudflare。

## 推荐使用方式

```bash
git clone https://github.com/lulalulaluobo/cloudflare-tempmail-deploy.git
cd cloudflare-tempmail-deploy
cp deployment-kit/deployment.env.example deployment-kit/deployment.env
```

如果想预先保存配置，可以编辑 `deployment-kit/deployment.env`；也可以保持模板为空，由 Codex 在授权检查后询问并写入本机配置：

```dotenv
CLOUDFLARE_ACCOUNT_ID=<你的 Cloudflare Account ID>
CF_ZONE_ID=<你的 Zone ID>
ZONE_NAME=<你的根域>
API_DOMAIN=<你的 API 子域>
MAIL_DOMAIN=<你的邮箱子域>
ADMIN_PASSWORD=
```

如果尚未登录，先执行：

```bash
npx wrangler login
```

把 [`deployment-kit/one-shot-prompt.md`](deployment-kit/one-shot-prompt.md) 全文复制给 Codex。它会先检查 Wrangler CLI、Cloudflare 登录状态、D1 等相关服务查询能力和域名配置，再询问缺失信息并执行：

```bash
./deployment-kit/deploy.sh
./deployment-kit/verify.sh
```

如果只需要一句调用指令：

```text
请读取当前仓库 deployment-kit/one-shot-prompt.md，按其中要求只完成一次完整的 Cloudflare temp mail 部署；先检查 Wrangler CLI、Cloudflare 登录和域名配置，询问缺失部署信息，自动生成管理员密码，再执行 deployment-kit/deploy.sh 与 deployment-kit/verify.sh，最终输出前端地址、后端 API 地址、管理后台地址、邮箱域和管理员密码，禁止输出 JWT、OAuth token、Cookie、账号 ID 或个人 Cloudflare 信息。
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

`API_DOMAIN` 和 `MAIL_DOMAIN` 必须是 `ZONE_NAME` 下的不同子域。真实收信前，需要在 Cloudflare Dashboard 为 `MAIL_DOMAIN` 完成 Email Routing 子域 onboarding，并确认 MX/SPF 已生成。

如果目标是全新的独立 Zone，Zone 级 Catch-all 不会影响其他 Zone；如果只是现有 Zone 下的新子域，不能把 Zone 级 Catch-all 误当成子域 Catch-all。部署脚本不会猜测或覆盖已有 Catch-all，也不会用逐地址规则代替 Catch-all。

## 资料目录

- [`deployment-kit/one-shot-prompt.md`](deployment-kit/one-shot-prompt.md)：交给 Codex 的完整部署提示词。
- [`deployment-kit/deployment.env.example`](deployment-kit/deployment.env.example)：本地配置模板，不含真实值。
- [`deployment-kit/deploy.sh`](deployment-kit/deploy.sh)：部署入口。
- [`deployment-kit/verify.sh`](deployment-kit/verify.sh)：脱敏验收入口。
- [`deployment-kit/docs/independent-cli-deployment.md`](deployment-kit/docs/independent-cli-deployment.md)：部署原理与执行顺序。
- [`deployment-kit/docs/verification-checklist.md`](deployment-kit/docs/verification-checklist.md)：最终验证清单。
- [`deployment-kit/patches/`](deployment-kit/patches/)：上游版本需要的兼容补丁。

完整边界和安全约束见 [`deployment-kit/README.md`](deployment-kit/README.md)。
