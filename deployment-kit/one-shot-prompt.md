# Codex 一次性部署提示词

把下面整段复制给 Codex。不要把任何密码或 Token 写入提示词或 Git；管理员密码留空，由部署脚本自动生成并在成功摘要中显示给用户。

```text
请在当前已 clone 的仓库中完成一次可复现的 Cloudflare 临时邮箱服务部署。如果当前目录不是 `https://github.com/lulalulaluobo/cloudflare-tempmail-deploy.git`，先执行 `git clone https://github.com/lulalulaluobo/cloudflare-tempmail-deploy.git` 并进入该仓库。这个任务只包含 temp mail 服务，不访问其他工程或附加构建目标。严格按以下要求执行：

1. 先读取并执行 https://developers.cloudflare.com/agent-setup/prompt.md；随后读取 deployment-kit/README.md、deployment-kit/shell-script-requirement.md、deployment-kit/docs/ 下的部署文档；使用 rg 检查部署资料和 git status。禁止 reset、checkout --、删除无关资源，禁止输出 JWT、OAuth token、Cookie、账号 ID 或凭据文件内容。

2. 先做环境和 Cloudflare 前置检查：确认 git、node、npm、pnpm、curl 和 npx 可用；执行 `npx wrangler --version` 检查 Wrangler CLI；执行 `npx wrangler whoami` 检查 Cloudflare 登录与账号访问；在不打印账号 ID 的前提下，用只读命令检查 D1 等 Cloudflare 资源查询是否可用。若 Wrangler 不可用或未登录，停止并说明如何安装或执行 `npx wrangler login`，不要假装部署成功。

3. 确认用户拥有 Cloudflare 账号和目标域名：域名必须已添加到 Cloudflare 且 DNS/Nameserver 已生效；deployment-kit/deployment.env 不存在时，才从 deployment-kit/deployment.env.example 复制，已存在则绝不覆盖。所有 Worker、D1、Zone、API 域和邮箱域都以本地 env 为准，不能用 Prompt 中的示例值覆盖配置。Account ID 和 Zone ID 能通过已授权 Cloudflare 能力确认时就读取并写入本地 env，否则询问用户；询问用户确认根域、API 子域和邮箱子域，不能猜测或使用示例域名。API_DOMAIN 与 MAIL_DOMAIN 必须是同一 Zone 下的不同子域。ADMIN_PASSWORD 必须保持为空，让部署脚本自动生成。关闭所有非 temp mail 的可选集成和附加构建目标。

4. 执行 `./deployment-kit/deploy.sh`。它必须固定配置中的上游版本，构建源项目 frontend/build:pages，用 Worker [assets] 提供网页和 API，创建或复用本次配置指定的 D1，执行远程 schema，部署 fetch/email/scheduled Worker，并上传新的 JWT_SECRET 和 ADMIN_PASSWORDS。管理员密码由脚本随机生成，不要向用户索取，也不要写入 Prompt；脚本会把它放入本机被 Git 忽略且权限为 600 的状态文件。

5. Email Routing 先判断 Zone 边界：
   - 如果 CF_ZONE_ID 对应一套新建且独立的 Cloudflare 根 Zone，Catch-all 只影响这套新 Zone；完成 Email Routing onboarding、MX/SPF 检查和 Worker 部署后，可以把该 Zone 的唯一 Catch-all 指向本次新 Worker。
   - 如果 MAIL_DOMAIN 只是现有 Zone 的子域，不能因为命令里出现子域名就假设 Catch-all 只作用于子域；必须证明 Cloudflare 当前 API/控制台提供了子域范围的 Catch-all，否则停在精确的人工步骤，不要改动现有 Zone Catch-all。
   - 当前 Wrangler 版本可能拒绝 `catch-all --action-type worker`；遇到该错误，不要改成 forward/drop，也不要创建单地址规则。对于已确认是新独立 Zone 的场景，使用 Cloudflare Email Routing API 或已登录的 Cloudflare 控制台，精确更新目标 Zone 的 Catch-all 到本次 WORKER_NAME，并在更新后重新读取验证。API token 只能从安全环境读取，绝不打印。

6. 执行 `./deployment-kit/verify.sh`，并运行 `bash -n deployment-kit/*.sh`、`git diff --check`。验证 API /health_check、管理员创建/删除地址、JWT 收件箱查询、网页首页、DNS/MX、Catch-all 目标；从外部邮箱向新地址发送一封真实测试邮件，确认邮件已写入 D1 并能通过 API 查询。不要访问或构建其他工程。

7. 最终汇报前端页面地址、后端 API 地址、管理后台地址、邮箱域、自动生成的管理员登录密码、每项验证结果和剩余人工步骤。管理员密码是本次用户明确要求的交付信息，只显示在最终摘要中，不写入 Git 或公开日志；不要泄露 JWT secret、OAuth token、Cookie、账号 ID 或其他个人 Cloudflare 信息。部署新实例默认不删除其他 Worker、D1、KV、Pages、DNS 或 Email Routing 资源。
```
