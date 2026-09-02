# Codex 一次性部署提示词

把下面整段复制给 Codex。不要把任何密码或 Token 写入提示词或 Git；管理员密码留空，由部署脚本自动生成并在成功摘要中显示给用户。

```text
请在当前已 clone 的仓库中完成一次可复现的 Cloudflare 临时邮箱服务部署。如果当前目录不是 `https://github.com/lulalulaluobo/cloudflare-tempmail-deploy.git`，先执行 `git clone https://github.com/lulalulaluobo/cloudflare-tempmail-deploy.git` 并进入该仓库。这个任务只包含 temp mail 服务，不访问其他工程或附加构建目标。严格按以下要求执行：

1. 先读取并执行 https://developers.cloudflare.com/agent-setup/prompt.md；随后读取 deployment-kit/README.md、deployment-kit/shell-script-requirement.md、deployment-kit/docs/ 下的部署文档；使用 rg 检查部署资料和 git status。禁止 reset、checkout --、删除无关资源，禁止输出 JWT、OAuth token、Cookie、账号 ID 或凭据文件内容。

2. 先做环境和 Cloudflare 前置检查：确认 git、node、npm、pnpm、curl 和 npx 可用；执行 `npx wrangler --version` 检查 Wrangler CLI；执行 `npx wrangler whoami` 检查 Cloudflare 登录与账号访问；在不打印账号 ID 的前提下，用只读命令检查 D1 等 Cloudflare 资源查询是否可用。若 Wrangler 不可用或未登录，停止并说明如何安装或执行 `npx wrangler login`，不要假装部署成功。

3. 确认用户拥有 Cloudflare 账号和目标域名：用户只需要提供一个已经添加到 Cloudflare 且 DNS/Nameserver 已生效的根域名。`deployment-kit/deployment.env` 不存在时，才从 `deployment-kit/deployment.env.example` 复制，已存在则绝不覆盖整个文件；如果其中 `ZONE_NAME` 为空，只补写用户提供的根域名，不改动其他已有值。不要询问或要求用户填写 Account ID、Zone ID、API 子域、邮箱子域、Worker 名称或 D1 名称；通过已授权的 Wrangler/Cloudflare API 自动确认账号和 Zone，并按根域名稳定生成 `tempmail-api.<ZONE_NAME>`、`tempmail.<ZONE_NAME>`、Worker 名称和 D1 名称。高级本地 env 覆盖可以保留，但不能用 Prompt 示例值覆盖已有配置；如果自动确认失败或生成的目标与现有资源冲突，停止并明确报告原因。`ADMIN_PASSWORD` 必须保持为空，让部署脚本自动生成。关闭所有非 temp mail 的可选集成和附加构建目标。

4. 执行 `./deployment-kit/deploy.sh`。它必须固定配置中的上游版本，构建源项目 frontend/build:pages，用 Worker [assets] 提供网页和 API，创建或复用本次配置指定的 D1，执行远程 schema，部署 fetch/email/scheduled Worker，并上传新的 JWT_SECRET 和 ADMIN_PASSWORDS。管理员密码由脚本随机生成，不要向用户索取，也不要写入 Prompt；脚本会把它放入本机被 Git 忽略且权限为 600 的状态文件。

5. Email Routing 必须由 Codex 自动完成，不要求用户再操作控制台：执行 `deployment-kit/deploy.sh` 的自动 Email Routing 流程，为 `MAIL_DOMAIN` onboarding，显式核验该子域的 MX/SPF，然后把 Catch-all 设置为 `Send to a Worker -> WORKER_NAME` 并重新读取验证。不要执行 `npx wrangler email routing enable <MAIL_DOMAIN>` 或 `npx wrangler email routing rules update <MAIL_DOMAIN> catch-all ...` 来猜测子域范围；脚本会从安全的 Wrangler OAuth 会话读取 Cloudflare API 授权，绝不打印 Token。
   - 为保护已有邮件服务，自动流程只允许在目标 Zone 原本未启用 Email Routing、且没有启用中的非丢弃规则时执行；如果发现已有活动规则，停止并明确报告原因，不要覆盖、删除、转发或创建逐地址规则。

6. 执行 `./deployment-kit/verify.sh`，并运行 `bash -n deployment-kit/*.sh`、`git diff --check`。验证 API /health_check、管理员创建/删除地址、JWT 收件箱查询、网页首页、DNS/MX、Catch-all 目标；从外部邮箱向新地址发送一封真实测试邮件，确认邮件已写入 D1 并能通过 API 查询。不要访问或构建其他工程。

7. 最终汇报前端页面地址、后端 API 地址、管理后台地址、邮箱域、自动生成的管理员登录密码和每项验证结果。只有在 Cloudflare API 明确拒绝自动配置时，才报告阻塞原因；不要把“请用户手动创建规则”当作成功。管理员密码是本次用户明确要求的交付信息，只显示在最终摘要中，不写入 Git 或公开日志；不要泄露 JWT secret、OAuth token、Cookie、账号 ID 或其他个人 Cloudflare 信息。部署新实例默认不删除其他 Worker、D1、KV、Pages、DNS 或 Email Routing 资源。
```
