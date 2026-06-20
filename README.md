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
