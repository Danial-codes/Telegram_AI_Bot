#!/usr/bin/env bash
# Setup / re-deploy the Telegram AI bot as a systemd service on the VPS.
#
# This script is idempotent and safe to run on the very first deploy AND on
# every subsequent `git push` to master:
#   - creates the system user if missing
#   - clones the repo on first run, otherwise `git fetch && git reset --hard`
#     (safe because `.env` is gitignored and rewritten below on each deploy)
#   - creates the virtualenv on first run, otherwise installs incrementally
#   - rewrites the `.env` from env vars forwarded by GitHub Actions
#   - (re)installs the systemd unit and restarts the service
#   - waits up to 20 seconds for the service to become active, then tails logs
#
# Required env vars (forwarded by the GH Action as secrets):
#   REPO                 — e.g. "octocat/telegram-ai-bot"
#   REPO_TOKEN           — PAT with read scope on REPO (used as HTTPS password)
#   TELEGRAM_BOT_TOKEN   — bot token from @BotFather
#   OPENAI_API_KEY       — OpenAI API key
#
# Optional env vars (forwarded via `vars:`, fall back to safe defaults):
#   OPENAI_MODEL              (default: gpt-4o-mini)
#   OPENAI_BASE_URL           (default: "")
#   TELEGRAM_BASE_URL         (default: "")
#   TELEGRAM_BASE_FILE_URL    (default: "")
#   SYSTEM_PROMPT             (default: helpful assistant)
#   MAX_HISTORY_MESSAGES      (default: 20)
#   DEPLOY_DIR                (default: /opt/telegram-ai-bot)
#   SERVICE_USER              (default: telegram-bot)
#
# Recommended: the SSH user is `root` (or a user with passwordless sudo).
# The bot itself runs as a non-login system user — `telegram-bot` — so a
# compromised bot cannot read the rest of the VPS.

set -euo pipefail

# ---- Required env vars ----------------------------------------------------

: "${REPO:?REPO env var is required (e.g. 'you/telegram-ai-bot')}"
: "${REPO_TOKEN:?REPO_TOKEN env var is required (GitHub PAT with read scope)}"
: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN env var is required}"
: "${OPENAI_API_KEY:?OPENAI_API_KEY env var is required}"

# ---- Defaults for optional env vars --------------------------------------

SERVICE_NAME="${SERVICE_NAME:-telegram-ai-bot}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/${SERVICE_NAME}}"
SERVICE_USER="${SERVICE_USER:-${SERVICE_NAME}}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

OPENAI_MODEL="${OPENAI_MODEL:-gpt-4o-mini}"
OPENAI_BASE_URL="${OPENAI_BASE_URL:-}"
TELEGRAM_BASE_URL="${TELEGRAM_BASE_URL:-}"
TELEGRAM_BASE_FILE_URL="${TELEGRAM_BASE_FILE_URL:-}"
SYSTEM_PROMPT="${SYSTEM_PROMPT:-You are a helpful assistant. Be concise, friendly, and clear. Format answers using Markdown when it improves readability.}"
MAX_HISTORY_MESSAGES="${MAX_HISTORY_MESSAGES:-20}"

# ---- Privilege helper ------------------------------------------------------
# If we're already root, skip sudo. Otherwise require passwordless sudo so the
# script never hangs waiting for input.
if [[ $EUID -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo -n"
  $SUDO true || { echo "ERROR: this script needs passwordless sudo" >&2; exit 1; }
fi

log() { printf '==> %s\n' "$*"; }

# ---- 1. System user -------------------------------------------------------
if ! id -u "$SERVICE_USER" &> /dev/null; then
  log "Creating system user '${SERVICE_USER}'"
  $SUDO useradd --system \
                --shell /usr/sbin/nologin \
                --home-dir "$DEPLOY_DIR" \
                --comment "Telegram AI bot service account" \
                "$SERVICE_USER"
fi

# ---- 2. Clone on first deploy, hard-reset on subsequent deploys ----------
# Build a credential helper up front so we never need to embed the PAT in the
# persistent git remote URL (which would otherwise leave the token in
# .git/config for the lifetime of the deployment).
HELPER_PATH="${DEPLOY_DIR}/.git-cred-helper"
{
  printf '#!/bin/sh\n'
  printf 'echo username=x-access-token\n'
  printf 'echo password=%s\n' "$REPO_TOKEN"
} > "${HELPER_PATH}.tmp"
$SUDO mv "${HELPER_PATH}.tmp" "$HELPER_PATH"

if [[ ! -d "${DEPLOY_DIR}/.git" ]]; then
  log "Cloning fresh into ${DEPLOY_DIR}"
  REPO_URL="https://x-access-token:${REPO_TOKEN}@github.com/${REPO}.git"
  $SUDO git clone "$REPO_URL" "$DEPLOY_DIR"
  log "Replacing persistent remote URL with credential-helper-backed version"
  $SUDO git -C "$DEPLOY_DIR" remote set-url origin "https://github.com/${REPO}.git"
  $SUDO git -C "$DEPLOY_DIR" config --local credential.helper "$HELPER_PATH"
else
  log "Hard-resetting ${DEPLOY_DIR} to origin/master"
  $SUDO git -C "$DEPLOY_DIR" remote set-url origin "https://github.com/${REPO}.git"
  $SUDO git -C "$DEPLOY_DIR" config --local credential.helper "$HELPER_PATH"
  $SUDO git -C "$DEPLOY_DIR" fetch origin
  $SUDO git -C "$DEPLOY_DIR" reset --hard origin/master
fi

# Tighten permissions on the helper file, and chown the deploy dir so the bot
# (which runs as SERVICE_USER) can read its own .git dir.
$SUDO chown -R "${SERVICE_USER}:${SERVICE_USER}" "$DEPLOY_DIR"
$SUDO chmod 700 "$HELPER_PATH"

# ---- 3. Virtualenv + dependencies ----------------------------------------
# `python3 -m venv` fails on minimalist Debian/Ubuntu VPS images because the
# `python3-venv` package (which provides `ensurepip`) isn't installed. Detect
# that case and install the package before we need to use it.
if ! "$PYTHON_BIN" -m venv "${DEPLOY_DIR}/.venv-probe" &> /dev/null; then
  log "python3-venv not usable; installing via the system package manager"
  $SUDO rm -rf "${DEPLOY_DIR}/.venv-probe"
  if command -v apt-get &> /dev/null; then
    $SUDO apt-get update -qq && $SUDO apt-get install -y python3 python3-venv python3-pip
  elif command -v dnf &> /dev/null; then
    $SUDO dnf install -y python3 python3-pip python3-virtualenv
  elif command -v yum &> /dev/null; then
    $SUDO yum install -y python3 python3-pip python3-virtualenv
  else
    echo "ERROR: cannot auto-install python3-venv on this distro" >&2
    exit 1
  fi
  if ! "$PYTHON_BIN" -m venv "${DEPLOY_DIR}/.venv-probe" &> /dev/null; then
    $SUDO rm -rf "${DEPLOY_DIR}/.venv-probe"
    echo "ERROR: python3 -m venv still broken after install attempt" >&2
    exit 1
  fi
fi
$SUDO rm -rf "${DEPLOY_DIR}/.venv-probe"

VENV_DIR="${DEPLOY_DIR}/.venv"
if [[ ! -d "${VENV_DIR}" ]]; then
  log "Creating venv at ${VENV_DIR}"
  $SUDO -u "$SERVICE_USER" "$PYTHON_BIN" -m venv "$VENV_DIR"
fi
log "Installing dependencies (first run takes a few minutes; later runs reuse pip's cache)"
$SUDO -u "$SERVICE_USER" "${VENV_DIR}/bin/pip" install --quiet --upgrade pip
$SUDO -u "$SERVICE_USER" "${VENV_DIR}/bin/pip" install --quiet --upgrade -e "$DEPLOY_DIR"

# ---- 4. Write .env from env vars -----------------------------------------
ENV_FILE="${DEPLOY_DIR}/.env"
ENV_TMP="${ENV_FILE}.tmp"
log "Writing ${ENV_FILE}"
umask 077
{
  printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TELEGRAM_BOT_TOKEN"
  printf 'OPENAI_API_KEY=%s\n'          "$OPENAI_API_KEY"
  printf 'OPENAI_MODEL=%s\n'            "$OPENAI_MODEL"
  printf 'OPENAI_BASE_URL=%s\n'         "$OPENAI_BASE_URL"
  printf 'TELEGRAM_BASE_URL=%s\n'       "$TELEGRAM_BASE_URL"
  printf 'TELEGRAM_BASE_FILE_URL=%s\n'  "$TELEGRAM_BASE_FILE_URL"
  printf 'SYSTEM_PROMPT=%s\n'           "$SYSTEM_PROMPT"
  printf 'MAX_HISTORY_MESSAGES=%s\n'    "$MAX_HISTORY_MESSAGES"
} > "$ENV_TMP"
# Atomic replace (cross-filesystem safe via cp + mv), then tighten perms.
$SUDO cp "$ENV_TMP" "$ENV_FILE"
$SUDO rm -f "$ENV_TMP"
$SUDO chown "${SERVICE_USER}:${SERVICE_USER}" "$ENV_FILE"
$SUDO chmod 600 "$ENV_FILE"

# ---- 5. Install systemd unit ---------------------------------------------
SERVICE_FILE_SRC="${DEPLOY_DIR}/deploy/${SERVICE_NAME}.service"
SERVICE_FILE_DST="/etc/systemd/system/${SERVICE_NAME}.service"
log "Installing systemd unit → ${SERVICE_FILE_DST}"
$SUDO cp "$SERVICE_FILE_SRC" "$SERVICE_FILE_DST"
$SUDO systemctl daemon-reload
$SUDO systemctl enable "${SERVICE_NAME}.service"
$SUDO systemctl restart "${SERVICE_NAME}.service"

# ---- 6. Health check ------------------------------------------------------
log "Service status:"
$SUDO systemctl --no-pager --full status "${SERVICE_NAME}.service" || true

log "Waiting up to 20s for ${SERVICE_NAME} to become active..."
for _ in $(seq 1 20); do
  if $SUDO systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    log "Service is ACTIVE ✅"
    log "Latest log lines:"
    $SUDO journalctl -u "${SERVICE_NAME}.service" -n 30 --no-pager || true
    exit 0
  fi
  sleep 1
done

echo "ERROR: ${SERVICE_NAME} did not become active within 20s" >&2
$SUDO journalctl -u "${SERVICE_NAME}.service" -n 80 --no-pager >&2 || true
exit 1
