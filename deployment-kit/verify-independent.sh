#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ENV_FILE="${DEPLOY_ENV_FILE:-$ROOT_DIR/deployment-kit/deployment.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

: "${API_DOMAIN:?请设置 API_DOMAIN}"
: "${MAIL_DOMAIN:?请设置 MAIL_DOMAIN}"
: "${ADMIN_PASSWORD:?请设置 ADMIN_PASSWORD}"

API_BASE="https://${API_DOMAIN}"
echo "==> 健康检查：$API_BASE/health_check"
health=$(curl -fsS "$API_BASE/health_check")
[[ "$health" == "OK" ]] || { echo "健康检查返回：$health" >&2; exit 1; }
echo "OK"

echo "==> 创建临时邮箱并读取空收件箱"
create_body=$(MAIL_DOMAIN="$MAIL_DOMAIN" node -e '
  const domain = process.env.MAIL_DOMAIN;
  process.stdout.write(JSON.stringify({
    enablePrefix: true,
    name: `cli-check-${Date.now()}`,
    domain,
  }));
')
create_response=$(curl -fsS "$API_BASE/admin/new_address" \
  -H 'content-type: application/json' \
  -H "x-admin-auth: $ADMIN_PASSWORD" \
  --data "$create_body")

parsed_create=$(node -e '
  const body = JSON.parse(process.argv[1]);
  if (!body.address || !body.jwt) throw new Error(JSON.stringify(body));
  process.stdout.write(`${body.address} ${body.jwt} ${body.address_id ?? ""}`);
' "$create_response")
read -r address jwt address_id <<< "$parsed_create"

mail_response=$(curl -fsS "$API_BASE/api/mails?limit=50&offset=0" \
  -H "authorization: Bearer $jwt")
node -e '
  const body = JSON.parse(process.argv[1]);
  if (!Array.isArray(body.results)) throw new Error(JSON.stringify(body));
  console.log(`address=${process.argv[2]} messages=${body.results.length}`);
' "$mail_response" "$address"

if [[ -n "$address_id" ]]; then
  echo "==> 删除验证邮箱：$address_id"
  curl -fsS -X DELETE "$API_BASE/admin/delete_address/$address_id" \
    -H "x-admin-auth: $ADMIN_PASSWORD" >/dev/null
fi

echo "基础 API 验证通过；真实收件需要从外部邮箱发送邮件到新邮箱地址。"
