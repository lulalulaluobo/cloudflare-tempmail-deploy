# 最终验证清单

## A. 前置条件与本地安全

- [ ] `deployment-kit/deployment.env` 未被 Git 跟踪。
- [ ] `JWT_SECRET`、OAuth token 未出现在脚本输出、截图或 Git diff。
- [ ] 自动生成的管理员密码只在部署成功摘要中显示给用户，没有进入 Git 或公开日志。
- [ ] Cloudflare 账号已登录，目标域名已经添加到 Cloudflare 且 DNS/Nameserver 已生效。
- [ ] `npx wrangler --version` 和 `npx wrangler whoami` 均成功。

## B. Cloudflare 资源

- [ ] 新 Worker 存在且名称与本地 env 一致。
- [ ] 新 D1 存在并绑定为 `DB`。
- [ ] 远程 schema 已执行。
- [ ] API Custom Domain 返回 HTTPS 200。
- [ ] Worker secrets 列表包含 `JWT_SECRET` 和 `ADMIN_PASSWORDS`，但值不可读取/不可打印。
- [ ] 邮箱子域已在 Dashboard 开通，MX/SPF 记录可见。
- [ ] Catch-all 已明确指向本次新 Worker，且没有创建逐地址规则代替 Catch-all。

## C. API

- [ ] `GET https://<API_DOMAIN>/health_check` 返回 `OK`。
- [ ] 管理员 `POST /admin/new_address` 返回地址、JWT、ID。
- [ ] `GET /api/mails?limit=50&offset=0` 携带 JWT 返回 200 和 `results` 数组。
- [ ] `DELETE /admin/delete_address/:id` 返回 200。

可执行基础验证：

```bash
./deployment-kit/verify.sh
```

真实收件还需要从外部邮箱发送邮件，并确认新地址的邮件已进入 D1、API 和网页。

## D. 源项目网页

- [ ] 上游 `frontend/` 已按 `build:pages` 构建。
- [ ] Worker Wrangler 配置包含 `[assets]`、`binding = "ASSETS"` 和 `run_worker_first = true`。
- [ ] `GET https://<API_DOMAIN>/` 返回源项目 Vue 页面。
- [ ] 页面使用当前 `API_DOMAIN`，不会请求其他 API。
- [ ] 浏览器页面中创建邮箱、登录邮箱并查看真实邮件。

## E. 回归与发布

- [ ] 新邮箱 MX 传播完成；必要时等待 DNS TTL。
- [ ] Cloudflare Email Routing 活动日志显示邮件到达本次新 Worker。
- [ ] 未修改其他 Worker、D1、KV、Pages、DNS 或 Email Routing 资源。
- [ ] `bash -n deployment-kit/*.sh` 和 `git diff --check` 通过。
- [ ] 完成 Git commit。

## 完成标准

只有当 Worker、D1、API、网页、Email Routing Catch-all 和真实外部邮件都验证通过，才可以把本次部署标记为完成。
