# 一次性 Codex 部署 Prompt（仅 temp mail）

最终可复制版本位于 [`one-shot-prompt.md`](../one-shot-prompt.md)。

这个 Prompt 只负责部署完整的 Cloudflare temp mail 服务：Worker、D1、源项目 Vue 前端、API、Email Routing 自动配置和验证；不访问其他工程或附加构建目标。使用者只需要提供一个已经添加到 Cloudflare 且 DNS/Nameserver 已生效的根域名，其他部署目标由授权能力自动确认或按根域名推导。

在当前仓库中直接调用：

```text
如果当前目录不是该仓库，请先执行 `git clone https://github.com/lulalulaluobo/cloudflare-tempmail-deploy.git` 并进入目录；然后读取当前仓库 `deployment-kit/one-shot-prompt.md`，按其中要求只完成一次完整的 Cloudflare temp mail 部署：先检查 Wrangler CLI、Cloudflare 登录和域名配置，只询问用户提供 Cloudflare 根域名，其余账号、Zone、API 子域、邮箱子域、Worker 和 D1 参数由已授权能力自动确认或按根域名稳定生成，自动生成管理员密码，自动完成邮箱子域 Email Routing onboarding 和 Catch-all Worker 绑定，再执行 `deployment-kit/deploy.sh` 与 `deployment-kit/verify.sh`，最终输出前端地址、后端 API 地址、管理后台地址、邮箱域和管理员密码，禁止输出 JWT、OAuth token、Cookie、账号 ID 或个人 Cloudflare 信息。
```
