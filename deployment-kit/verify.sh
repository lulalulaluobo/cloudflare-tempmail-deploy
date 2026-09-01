#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [[ -z "${DEPLOY_ENV_FILE:-}" ]]; then
  if [[ -f "$ROOT_DIR/deployment-kit/deployment.env" ]]; then
    export DEPLOY_ENV_FILE="$ROOT_DIR/deployment-kit/deployment.env"
  else
    export DEPLOY_ENV_FILE="$ROOT_DIR/config/deployment.env"
  fi
fi

exec "$ROOT_DIR/deployment-kit/verify-independent.sh" "$@"
