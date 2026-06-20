# Telegram AI Bot

A simple Telegram bot written in Python that forwards user messages to the
OpenAI Chat Completions API and replies with the model's answer. Conversation
history is kept per user so the bot can hold a multi-turn chat.

## Features

- 💬 Multi-turn chat memory per user (configurable size)
- 🧠 Uses any OpenAI chat model (default: `gpt-4o-mini`)
- ✂️ Automatically splits long responses (>4096 chars) to fit Telegram limits
- 🛡️ Errors are caught and reported back to the user instead of crashing
- ⚙️ All configuration via `.env`

## Prerequisites

- Python 3.9+
- A Telegram bot token — create one via [@BotFather](https://t.me/BotFather)
- An OpenAI API key — get one at <https://platform.openai.com/api-keys>

## Setup

```bash
# 1. Clone or copy this folder, then cd into it
cd Telegram_AI_Bot

# 2. Create a virtual environment
python -m venv .venv
# Windows
.venv\Scripts\activate
# macOS / Linux
source .venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Configure secrets
copy .env.example .env        # Windows
cp .env.example .env          # macOS / Linux
# Open .env and fill in TELEGRAM_BOT_TOKEN and OPENAI_API_KEY.
```

## Run

```bash
python bot.py
```

Open Telegram, find your bot, press **Start**, and send any text message.

## Commands

| Command  | Description                            |
| -------- | -------------------------------------- |
| `/start` | Welcome message                        |
| `/help`  | Show the help / command list           |
| `/reset` | Clear your conversation history        |
| `/model` | Show which OpenAI model is in use      |

## Configuration

All settings live in `.env`. Anything left unset falls back to the defaults
documented in `.env.example`.

| Variable                 | Default                | Purpose                                                       |
| ------------------------ | ---------------------- | ------------------------------------------------------------- |
| `TELEGRAM_BOT_TOKEN`     | _required_             | Bot token from @BotFather                                     |
| `OPENAI_API_KEY`         | _required_             | OpenAI API key                                                |
| `OPENAI_MODEL`           | `gpt-4o-mini`          | Any OpenAI chat model name                                    |
| `OPENAI_BASE_URL`        | `https://api.openai.com/v1` | Base URL of an OpenAI-compatible endpoint (Azure, Together, Ollama, vLLM, …) |
| `TELEGRAM_BASE_URL`      | `https://api.telegram.org`  | Telegram Bot API base URL (useful when self-hosting the Bot API server) |
| `TELEGRAM_BASE_FILE_URL` | = `TELEGRAM_BASE_URL` | Override only the Telegram file-download endpoint             |
| `SYSTEM_PROMPT`          | helpful assistant      | Sets the assistant's persona                                  |
| `MAX_HISTORY_MESSAGES`   | `20`                   | Past messages kept per user for chat memory                   |

### Pointing at alternative endpoints

```ini
# Local Ollama running on the same machine (llama3 model)
OPENAI_BASE_URL=http://localhost:11434/v1
OPENAI_MODEL=llama3

# Self-hosted Telegram Bot API server (https://github.com/tdlib/telegram-bot-api)
TELEGRAM_BASE_URL=http://localhost:8081
```

## Notes

- The bot keeps history in memory only. Restarting the bot clears every user's
  conversation. Swap the `chat_history` dict for a database (SQLite, Redis, …)
  if you need persistence.
- Long completions are split on paragraph / line / word boundaries so they
  read cleanly inside Telegram's 4096-character message limit.
- `python-telegram-bot` v20+ uses an asyncio event loop. The blocking OpenAI
  call is dispatched via `run_in_executor` so the bot stays responsive.

## Deploy

This repo ships a GitHub Actions pipeline that, on every push to `master`,
runs `ruff` + `pytest` on a GitHub-hosted runner, then SSHes into your VPS,
clones the repo, installs it as a `systemd` service under a dedicated
`telegram-bot` system user, and waits for it to come up. **PRs do not deploy.**
The pipeline is defined in [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)
and the actual installation script in [`deploy/setup-vps.sh`](deploy/setup-vps.sh).

### Required secrets (Settings → Secrets and variables → Actions)

| Name | Purpose |
| ---- | ------- |
| `VPS_HOST`           | hostname / IP of your VPS |
| `VPS_USER`           | SSH user (recommend `root`, or a sudo user with NOPASSWD) |
| `VPS_SSH_KEY`        | SSH private key whose public key is in the VPS's `authorized_keys` |
| `VPS_PORT`           | (optional) SSH port, defaults to `22` |
| `REPO_TOKEN`         | GitHub fine-grained PAT with `Contents: read` on this repo |
| `TELEGRAM_BOT_TOKEN` | bot token from [@BotFather](https://t.me/BotFather) |
| `OPENAI_API_KEY`     | OpenAI API key |

### Optional vars (Settings → Secrets and variables → Actions → Variables tab)

| Name | Default | Purpose |
| ---- | ------- | ------- |
| `OPENAI_MODEL`         | `gpt-4o-mini`     | Any OpenAI chat model |
| `OPENAI_BASE_URL`      | empty             | OpenAI-compatible endpoint (Azure, Together, Ollama, vLLM, …) |
| `TELEGRAM_BASE_URL`    | empty             | Self-hosted Telegram Bot API server |
| `TELEGRAM_BASE_FILE_URL` | empty           | Override only Telegram file-download endpoint |
| `SYSTEM_PROMPT`        | helpful assistant | Persona |
| `MAX_HISTORY_MESSAGES` | `20`              | Per-user history window |
| `DEPLOY_DIR`           | `/opt/telegram-ai-bot` | Install path on the VPS |
| `SERVICE_USER`         | `telegram-bot`    | Dedicated system user that runs the bot |

### One-time VPS prep

1. Install the matching public SSH key for `$VPS_SSH_KEY` in
   `~<VPS_USER>/.ssh/authorized_keys` on the VPS.
2. Make sure systemd is the init system (Ubuntu 16.04+, Debian 8+, all modern
   RHEL/Fedora do this by default).
3. (Optional) `sudo apt install -y python3 python3-venv` to make sure the
   dependencies for `python -m venv` are present.

### Operations cheatsheet

```bash
# Live logs from the running bot
ssh $VPS_USER@$VPS_HOST journalctl -u telegram-ai-bot -f

# Restart / stop the bot manually
ssh $VPS_USER@$VPS_HOST sudo systemctl restart telegram-ai-bot
ssh $VPS_USER@$VPS_HOST sudo systemctl stop telegram-ai-bot

# Re-run the deploy script by hand (e.g. after a partial failure):
sudo \
  REPO=<owner>/telegram-ai-bot \
  REPO_TOKEN=<github-pat> \
  TELEGRAM_BOT_TOKEN=<bot-token> \
  OPENAI_API_KEY=<openai-key> \
  bash /tmp/telegram-ai-bot-deploy/setup-vps.sh
```
