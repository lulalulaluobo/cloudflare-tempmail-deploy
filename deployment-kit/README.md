# Cloudflare Temp Mail 部署包

这个目录是给 Codex 复用的部署资料，只负责部署上游 `cloudflare_temp_email` 的 Worker、D1、源项目 Vue 页面、API 和 Email Routing 前置检查。不包含插件源码、公众号文章、视频脚本，也不包含任何真实账号、域名、资源名或密钥。

## 使用前提

1. 有可登录的 Cloudflare 账号，并拥有目标 Zone 的 Workers、D1、Secrets 和 Email Routing 权限。
2. 有一个已经添加到 Cloudflare、Nameserver/DNS 已生效的域名；`ZONE_NAME`、`API_DOMAIN` 和 `MAIL_DOMAIN` 必须属于同一个 Zone。
3. 本机有 Node.js、npm、pnpm、git、curl；Codex 会先检查 Wrangler CLI 和 Cloudflare 登录状态。
4. 要收信时，先在 Cloudflare Dashboard 为 `MAIL_DOMAIN` 完成 Email Routing 子域 onboarding，并确认 MX/SPF 已生成，再将 `EMAIL_ROUTING_READY=1` 写入本地 env。

## 首次使用

```bash
cp deployment-kit/deployment.env.example deployment-kit/deployment.env
# 编辑 deployment-kit/deployment.env，填写自己的 Cloudflare、域名和管理员密码
npx wrangler login
./deployment-kit/deploy.sh
./deployment-kit/verify.sh
```

`deployment.env` 只保存在本机，已被 Git 忽略。部署会复用上游项目已经提供的 Vue 页面，并把页面作为同一个 Worker 的静态资源；`/health_check`、API 和页面共用 `API_DOMAIN`。

## 给 Codex 的一句话

把 `one-shot-prompt.md` 的全文复制给 Codex。它会先检查 Wrangler CLI、Cloudflare 登录和本机前置条件，再读取本地配置，执行部署脚本和验证脚本；不满足条件时会停下来说明原因，不会假装成功。

最短调用句：

```text
请读取当前仓库 deployment-kit/one-shot-prompt.md，按其中要求只完成一次完整的 Cloudflare temp mail 部署；先检查 Wrangler CLI、Cloudflare 登录和域名配置，再执行 deployment-kit/deploy.sh 与 deployment-kit/verify.sh，禁止输出任何 secret、账号 ID 或个人 Cloudflare 信息。
```

## Email Routing 边界

部署脚本不会猜测或覆盖已有 Zone 的 Catch-all。全新的独立 Zone 完成 Email Routing onboarding 后，可以把该 Zone 的 Catch-all 指向本次新 Worker；如果只是现有 Zone 下的新子域，必须先确认 Cloudflare 当前是否提供子域范围的 Catch-all，不能把 Zone 级规则当成子域规则，也不能用逐地址规则代替 Catch-all。

## 文件

- `deploy.sh`：部署入口。
- `verify.sh`：脱敏验收入口。
- `deployment.env.example`：可复制的本地配置模板。
- `one-shot-prompt.md`：可直接交给 Codex 的完整提示词。
- `shell-script-requirement.md`：脚本接口、安全边界和验收要求。
- `docs/`：部署说明、Email Routing 边界和最终验证清单。
