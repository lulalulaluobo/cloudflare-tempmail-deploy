# 一次性 Codex 部署 Prompt（仅 temp mail）

最终可复制版本位于 [`one-shot-prompt.md`](../one-shot-prompt.md)。

这个 Prompt 只负责部署完整的 Cloudflare temp mail 服务：Worker、D1、源项目 Vue 前端、API、Email Routing 前置检查和验证；不访问其他工程或附加构建目标。使用者必须提供自己的 Cloudflare 账号、Zone 和已生效域名配置。

在当前仓库中直接调用：

```text
请读取当前仓库 deployment-kit/one-shot-prompt.md，按其中要求只完成一次完整的 Cloudflare temp mail 部署；先检查 Wrangler CLI、Cloudflare 登录和域名配置，再执行 deployment-kit/deploy.sh 与 deployment-kit/verify.sh，禁止输出任何 secret、账号 ID 或个人 Cloudflare 信息。
```
