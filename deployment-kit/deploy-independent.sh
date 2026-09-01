#!/usr/bin/env bash
set -Eeuo pipefail

# Deploy a fresh cloudflare_temp_email Worker + D1 instance without touching
# the existing instance. Cloudflare's current Wrangler Email Routing commands
# are zone-scoped, so subdomain onboarding/Catch-all is an explicit prerequisite
# and is never mutated by this script.

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ENV_FILE="${DEPLOY_ENV_FILE:-$ROOT_DIR/deployment-kit/deployment.env}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

CLOUDFLARE_ACCOUNT_ID=${CLOUDFLARE_ACCOUNT_ID:-${CF_ACCOUNT_ID:-}}
CF_ZONE_ID=${CF_ZONE_ID:-}
ZONE_NAME=${ZONE_NAME:-}
WORKER_NAME=${WORKER_NAME:-temp-mail-worker}
D1_NAME=${D1_NAME:-temp-mail-db}
D1_ID=${D1_ID:-}
API_DOMAIN=${API_DOMAIN:-}
MAIL_DOMAIN=${MAIL_DOMAIN:-}
SOURCE_REPO=${SOURCE_REPO:-https://github.com/dreamhunter2333/cloudflare_temp_email.git}
SOURCE_REF=${SOURCE_REF:-v1.11.1}
SOURCE_CACHE_DIR=${SOURCE_CACHE_DIR:-.cache/cloudflare_temp_email}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-}
JWT_SECRET=${JWT_SECRET:-}
ENABLE_EMAIL_ROUTING=${ENABLE_EMAIL_ROUTING:-1}
EMAIL_ROUTING_READY=${EMAIL_ROUTING_READY:-0}
DEPLOY_FRONTEND=${DEPLOY_FRONTEND:-1}
FRONTEND_BUILD_COMMAND=${FRONTEND_BUILD_COMMAND:-build:pages}
SKIP_SCHEMA=${SKIP_SCHEMA:-0}
SKIP_SECRETS=${SKIP_SECRETS:-0}
STATE_FILE=${DEPLOY_STATE_FILE:-$ROOT_DIR/.cache/temp-mail-deployment-state.env}

die() {
  echo "错误：$*" >&2
  exit 1
}

log() {
  echo
  echo "==> $*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

valid_hostname() {
  [[ "$1" =~ ^[A-Za-z0-9.-]+$ ]] && [[ "$1" != .* ]] && [[ "$1" != *..* ]]
}

extract_uuid() {
  sed -nE 's/.*([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}).*/\1/p' | head -n 1
}

require_value() {
  [[ -n "$2" ]] || die "$1 未设置，请填写 $ENV_FILE"
}

prompt_for_missing() {
  local variable_name="$1"
  local prompt_text="$2"
  local current_value="${!variable_name:-}"
  local entered_value

  [[ -n "$current_value" ]] && return
  [[ -t 0 ]] || die "$variable_name 未设置；请让 Codex 先询问并写入 $ENV_FILE，或使用交互式终端运行部署脚本"
  read -r -p "$prompt_text: " entered_value
  [[ -n "$entered_value" ]] || die "$variable_name 不能为空"
  printf -v "$variable_name" '%s' "$entered_value"
}

write_runtime_state() {
  mkdir -p "$(dirname "$STATE_FILE")"
  umask 077
  {
    printf 'API_DOMAIN=%s\n' "$API_DOMAIN"
    printf 'MAIL_DOMAIN=%s\n' "$MAIL_DOMAIN"
    printf 'ADMIN_PASSWORD=%s\n' "$ADMIN_PASSWORD"
  } > "$STATE_FILE"
  chmod 600 "$STATE_FILE"
}

# Wrangler's OAuth flow in some versions treats an account-id environment
# variable differently from the same value in wrangler.toml. Keep the value
# for config generation, but let OAuth select the current account for the
# initial account-scoped D1 lookup/create.
export -n CLOUDFLARE_ACCOUNT_ID 2>/dev/null || true
export -n CF_ACCOUNT_ID 2>/dev/null || true

for command_name in git node npm pnpm npx sed; do
  require_command "$command_name"
done

log "检查 Wrangler CLI"
npx wrangler --version >/dev/null || die "Wrangler CLI 不可用；请确认 npm/npx 正常，或先安装 Wrangler"

log "检查 Wrangler 登录状态"
npx wrangler whoami >/dev/null || die "Wrangler 未登录，请先执行 npx wrangler login"

prompt_for_missing CLOUDFLARE_ACCOUNT_ID "Cloudflare Account ID"
prompt_for_missing CF_ZONE_ID "Cloudflare Zone ID"
prompt_for_missing ZONE_NAME "Cloudflare 根域名"
prompt_for_missing API_DOMAIN "API 子域名（例如 api.example.com）"
prompt_for_missing MAIL_DOMAIN "邮箱子域名（例如 inbox.example.com）"

require_value CLOUDFLARE_ACCOUNT_ID "$CLOUDFLARE_ACCOUNT_ID"
require_value CF_ZONE_ID "$CF_ZONE_ID"
require_value ZONE_NAME "$ZONE_NAME"
require_value API_DOMAIN "$API_DOMAIN"
require_value MAIL_DOMAIN "$MAIL_DOMAIN"

if [[ "$SKIP_SECRETS" != "1" && -z "$ADMIN_PASSWORD" ]]; then
  ADMIN_PASSWORD=$(node -e 'process.stdout.write(require("node:crypto").randomBytes(18).toString("hex"))')
fi

for value in "$ZONE_NAME" "$API_DOMAIN" "$MAIL_DOMAIN"; do
  valid_hostname "$value" || die "非法域名：$value"
done

[[ "$API_DOMAIN" != "$MAIL_DOMAIN" ]] || die "API_DOMAIN 和 MAIL_DOMAIN 必须不同"
[[ "$API_DOMAIN" != "$ZONE_NAME" ]] || die "API_DOMAIN 不能是根域"
[[ "$MAIL_DOMAIN" != "$ZONE_NAME" ]] || die "MAIL_DOMAIN 不能是根域"
[[ "$API_DOMAIN" == *".$ZONE_NAME" ]] || die "API_DOMAIN 必须属于 ZONE_NAME"
[[ "$MAIL_DOMAIN" == *".$ZONE_NAME" ]] || die "MAIL_DOMAIN 必须属于 ZONE_NAME"

if [[ "$ENABLE_EMAIL_ROUTING" == "1" && "$EMAIL_ROUTING_READY" != "1" ]]; then
  die "请先在 Cloudflare Dashboard 为 $MAIL_DOMAIN 开通 Email Routing 子域；确认 DNS/MX 已就绪后设置 EMAIL_ROUTING_READY=1。脚本不会调用 zone-level Catch-all 命令，以免覆盖其他 Zone 路由。"
fi

SOURCE_DIR="$ROOT_DIR/$SOURCE_CACHE_DIR"
WRANGLER_CONFIG="$SOURCE_DIR/worker/wrangler.toml"
WORKER_ASSETS_PATCH="$ROOT_DIR/deployment-kit/patches/upstream-worker-assets-health.patch"

log "准备固定版本源码：$SOURCE_REF"
if [[ ! -d "$SOURCE_DIR/.git" ]]; then
  mkdir -p "$(dirname "$SOURCE_DIR")"
  git clone --depth 1 --branch "$SOURCE_REF" "$SOURCE_REPO" "$SOURCE_DIR"
else
  git -C "$SOURCE_DIR" remote set-url origin "$SOURCE_REPO"
  git -C "$SOURCE_DIR" fetch --depth 1 origin "$SOURCE_REF"
  git -C "$SOURCE_DIR" checkout --detach FETCH_HEAD
fi

SOURCE_COMMIT=$(git -C "$SOURCE_DIR" rev-parse --short HEAD)
SCHEMA_FILE="$SOURCE_DIR/db/schema.sql"
[[ -f "$SCHEMA_FILE" ]] || die "找不到上游 schema：$SCHEMA_FILE"

if [[ "$DEPLOY_FRONTEND" == "1" ]]; then
  [[ -f "$WORKER_ASSETS_PATCH" ]] || die "找不到 Worker Assets 兼容补丁：$WORKER_ASSETS_PATCH"
  git -C "$SOURCE_DIR" apply --ignore-whitespace --check "$WORKER_ASSETS_PATCH" || die "上游 Worker Assets 兼容补丁无法应用；请检查 SOURCE_REF 是否仍受支持"
  git -C "$SOURCE_DIR" apply --ignore-whitespace "$WORKER_ASSETS_PATCH"
fi

log "安装 Worker 依赖"
(cd "$SOURCE_DIR/worker" && pnpm install --frozen-lockfile)

if [[ "$DEPLOY_FRONTEND" == "1" ]]; then
  FRONTEND_DIR="$SOURCE_DIR/frontend"
  [[ -d "$FRONTEND_DIR" ]] || die "上游源码没有 frontend 目录：$FRONTEND_DIR"
  [[ -f "$FRONTEND_DIR/package.json" ]] || die "找不到前端 package.json：$FRONTEND_DIR/package.json"

  log "安装并构建源项目 Vue 前端"
  (cd "$FRONTEND_DIR" && pnpm install --frozen-lockfile)
  (cd "$FRONTEND_DIR" && \
    VITE_API_BASE="https://$API_DOMAIN" \
    VITE_IS_TELEGRAM=false \
    pnpm run "$FRONTEND_BUILD_COMMAND")
  [[ -f "$FRONTEND_DIR/dist/index.html" ]] || die "前端构建完成但没有找到 dist/index.html"
fi

log "查找或创建独立 D1：$D1_NAME"
if [[ -z "$D1_ID" && -f "$WRANGLER_CONFIG" ]]; then
  CONFIG_WORKER_NAME=$(sed -n 's/^name = "\(.*\)"$/\1/p' "$WRANGLER_CONFIG" | head -n 1)
  CONFIG_D1_NAME=$(sed -n 's/^database_name = "\(.*\)"$/\1/p' "$WRANGLER_CONFIG" | head -n 1)
  CONFIG_D1_ID=$(sed -n 's/^database_id = "\(.*\)"$/\1/p' "$WRANGLER_CONFIG" | head -n 1)
  if [[ "$CONFIG_WORKER_NAME" == "$WORKER_NAME" && "$CONFIG_D1_NAME" == "$D1_NAME" ]]; then
    D1_ID="$CONFIG_D1_ID"
    log "复用配置中的 D1 ID"
  fi
fi

if [[ -z "$D1_ID" ]]; then
  if D1_LIST=$(npx wrangler d1 list --json 2>/dev/null); then
    D1_ID=$(node -e '
      const rows = JSON.parse(process.argv[1]);
      const name = process.argv[2];
      const row = rows.find((item) => item.name === name);
      if (row) process.stdout.write(row.uuid);
    ' "$D1_LIST" "$D1_NAME")
  else
    log "当前 OAuth 无法读取 D1 列表，将尝试创建指定名称的 D1"
  fi
fi

if [[ -z "$D1_ID" ]]; then
  CREATE_OUTPUT=$(npx wrangler d1 create "$D1_NAME" --location apac 2>&1) || {
    echo "$CREATE_OUTPUT" >&2
    die "D1 创建失败；没有执行任何删除或替换操作"
  }
  echo "$CREATE_OUTPUT"
  D1_ID=$(printf '%s\n' "$CREATE_OUTPUT" | extract_uuid)
fi

[[ "$D1_ID" =~ ^[0-9a-fA-F-]{36}$ ]] || die "无法解析 D1 ID"

log "生成独立 Wrangler 配置"
mkdir -p "$(dirname "$WRANGLER_CONFIG")"
cat > "$WRANGLER_CONFIG" <<EOF
name = "$WORKER_NAME"
main = "src/worker.ts"
compatibility_date = "2025-04-01"
compatibility_flags = ["nodejs_compat"]
keep_vars = true

routes = [{ pattern = "$API_DOMAIN", custom_domain = true }]

[vars]
PREFIX = "tmp"
DEFAULT_DOMAINS = ["$MAIL_DOMAIN"]
DOMAINS = ["$MAIL_DOMAIN"]
ENABLE_USER_CREATE_EMAIL = true
ENABLE_USER_DELETE_EMAIL = true
ENABLE_AUTO_REPLY = false

[[d1_databases]]
binding = "DB"
database_name = "$D1_NAME"
database_id = "$D1_ID"
EOF

if [[ "$DEPLOY_FRONTEND" == "1" ]]; then
  cat >> "$WRANGLER_CONFIG" <<EOF

[assets]
directory = "../frontend/dist/"
binding = "ASSETS"
run_worker_first = true
EOF
fi

if [[ "$SKIP_SCHEMA" == "1" ]]; then
  log "跳过远程 D1 schema（SKIP_SCHEMA=1；适用于已初始化的独立 D1）"
else
  log "初始化远程 D1 schema"
  npx wrangler d1 execute "$D1_NAME" --config "$WRANGLER_CONFIG" --remote --file "$SCHEMA_FILE" --yes
fi

log "部署 Worker 和 API Custom Domain"
(cd "$ROOT_DIR" && npx wrangler deploy --config "$WRANGLER_CONFIG" --minify)

if [[ "$SKIP_SECRETS" == "1" ]]; then
  log "跳过 Worker secrets（SKIP_SECRETS=1）"
else
  if [[ -z "$JWT_SECRET" ]]; then
    JWT_SECRET=$(node -e 'console.log(require("node:crypto").randomBytes(32).toString("hex"))')
  fi

  log "写入 Worker secrets（值不会打印）"
  printf '%s' "$JWT_SECRET" | npx wrangler secret put JWT_SECRET --name "$WORKER_NAME" --config "$WRANGLER_CONFIG"
  printf '["%s"]' "$ADMIN_PASSWORD" | npx wrangler secret put ADMIN_PASSWORDS --name "$WORKER_NAME" --config "$WRANGLER_CONFIG"
fi

if [[ "$ENABLE_EMAIL_ROUTING" == "1" ]]; then
  log "Email Routing 子域已由前置步骤确认：$MAIL_DOMAIN"
  echo "注意：未执行 Wrangler 的 zone-level Catch-all 命令；请在子域范围内将 Catch-all 指向 $WORKER_NAME。"
else
  log "跳过 Email Routing；ENABLE_EMAIL_ROUTING=$ENABLE_EMAIL_ROUTING"
fi

write_runtime_state

cat <<EOF

部署完成（JWT 和 API token 未输出；管理员密码按请求显示一次）：
  Worker:     $WORKER_NAME
  D1:         $D1_NAME ($D1_ID)
  前端页面:   https://$API_DOMAIN/
  后端 API:   https://$API_DOMAIN
  管理后台:   https://$API_DOMAIN/admin
  邮箱域:     $MAIL_DOMAIN
  管理员密码: $ADMIN_PASSWORD
  源码:       $SOURCE_REF ($SOURCE_COMMIT)

下一步：
  1. 执行 deployment-kit/verify.sh 验证健康检查、创建邮箱和 JWT 查询。
  2. 等待 DNS/MX 传播后，从外部邮箱发送一封邮件到新邮箱域。
  3. 管理后台没有单独的用户名，使用上面的管理员密码登录。
EOF
