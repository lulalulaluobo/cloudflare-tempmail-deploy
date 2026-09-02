# Cloudflare Temp Mail 部署包

这个目录是给 Codex 复用的部署资料，只负责部署上游 `cloudflare_temp_email` 的 Worker、D1、源项目 Vue 页面、API 和 Email Routing。不包含任何真实 Cloudflare 账号、域名、资源名或密钥。

## 使用前提

1. 有可登录的 Cloudflare 账号，并拥有目标 Zone 的 Workers、D1、Secrets 和 Email Routing 权限。
2. 有一个已经添加到 Cloudflare、Nameserver/DNS 已生效的根域名；它是唯一需要提供的部署业务输入。
3. 本机有 Node.js、npm、pnpm、git、curl；Codex 会先检查 Wrangler CLI 和 Cloudflare 登录状态。
4. Wrangler 必须具备 Workers、D1、Secrets、DNS/Email Routing 的授权；脚本会自动确认 Zone，并根据根域名推导 API 子域、邮箱子域、Worker 和 D1 名称，再为邮箱子域 onboarding、核验 MX/SPF，并设置 Catch-all Worker。

## 首次使用

```bash
npx wrangler login
```

然后把 `one-shot-prompt.md` 交给 Codex，并在它询问时只提供 Cloudflare 根域名。Codex 会利用已授权的 Wrangler/Cloudflare 能力自动读取账号和 Zone 信息，并稳定推导 `tempmail-api.<根域名>`、`tempmail.<根域名>`、Worker 和 D1 名称。管理员密码留空即可，脚本会自动生成。Email Routing 也由脚本自动配置；若目标 Zone 已有启用中的邮件路由，脚本会为安全起见停止，不会覆盖现有服务。本目录中的 `deploy.sh` 和 `verify.sh` 是由该 Prompt 调用的实现，不是另一套需要用户手动编排的部署流程。

`deployment.env` 和自动生成的本地状态文件只保存在本机，已被 Git 忽略。部署会复用上游项目已经提供的 Vue 页面，并把页面作为同一个 Worker 的静态资源；`/health_check`、API 和页面共用 `API_DOMAIN`。

## 唯一部署入口：给 Codex 的 Prompt

把 `one-shot-prompt.md` 的全文复制给 Codex。它会先检查 Wrangler CLI、Cloudflare 登录和本机前置条件，再读取或创建本地配置；不满足条件时会停下来说明原因，不会假装成功。部署成功摘要会显示前端、后端 API、管理后台、邮箱域和管理员密码。

最短调用句：

```text
如果当前目录不是该仓库，请先执行 `git clone https://github.com/lulalulaluobo/cloudflare-tempmail-deploy.git` 并进入目录；然后读取当前仓库 `deployment-kit/one-shot-prompt.md`，按其中要求只完成一次完整的 Cloudflare temp mail 部署：先检查 Wrangler CLI、Cloudflare 登录和域名配置，只询问用户提供 Cloudflare 根域名，其余账号、Zone、API 子域、邮箱子域、Worker 和 D1 参数由已授权能力自动确认或按根域名稳定生成，自动生成管理员密码，自动完成邮箱子域 Email Routing onboarding 和 Catch-all Worker 绑定，再执行 `deployment-kit/deploy.sh` 与 `deployment-kit/verify.sh`，最终输出前端地址、后端 API 地址、管理后台地址、邮箱域和管理员密码，禁止输出 JWT、OAuth token、Cookie、账号 ID 或个人 Cloudflare 信息。
```

## Email Routing 边界

部署脚本不会猜测或覆盖已有启用中的 Zone Catch-all。对于未启用 Email Routing 且没有启用中非丢弃规则的目标 Zone，脚本会通过 Cloudflare 当前 API onboarding `MAIL_DOMAIN`，核验子域 MX/SPF，并设置 Catch-all 到本次 Worker；onboarding API 失败或范围无法证明时会停止，不会改用逐地址规则。

## 文件

- `deploy.sh`：部署入口。
- `verify.sh`：脱敏验收入口。
- `deployment.env.example`：可复制的本地配置模板。
- `one-shot-prompt.md`：可直接交给 Codex 的完整提示词。
- `shell-script-requirement.md`：脚本接口、安全边界和验收要求。
- `docs/`：部署说明、Email Routing 边界和最终验证清单。
