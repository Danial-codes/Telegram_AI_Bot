"""Telegram AI bot powered by OpenAI.

Run:
    1. Copy .env.example to .env and fill in TELEGRAM_BOT_TOKEN and OPENAI_API_KEY.
    2. pip install -r requirements.txt
    3. python bot.py
"""

from __future__ import annotations

import logging
import os
from collections import defaultdict, deque
from typing import Deque, Dict, List

from dotenv import load_dotenv
from openai import OpenAI
from telegram import Update
from telegram.constants import ChatAction, ParseMode
from telegram.ext import (
    Application,
    CommandHandler,
    ContextTypes,
    MessageHandler,
    filters,
)

# ---- Configuration ---------------------------------------------------------

load_dotenv()

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
SYSTEM_PROMPT = os.getenv(
    "SYSTEM_PROMPT",
    "You are a helpful assistant. Be concise, friendly, and clear. "
    "Format answers using Markdown when it improves readability.",
)
MAX_HISTORY_MESSAGES = int(os.getenv("MAX_HISTORY_MESSAGES", "20"))
TELEGRAM_MAX_MESSAGE_LENGTH = 4096

if not TELEGRAM_BOT_TOKEN:
    raise RuntimeError("TELEGRAM_BOT_TOKEN is not set. Add it to your .env file.")
if not OPENAI_API_KEY:
    raise RuntimeError("OPENAI_API_KEY is not set. Add it to your .env file.")

# ---- Logging ---------------------------------------------------------------

logging.basicConfig(
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    level=logging.INFO,
)
# Silence extremely chatty httpx logs from the telegram library.
logging.getLogger("httpx").setLevel(logging.WARNING)

logger = logging.getLogger(__name__)

# ---- OpenAI client ---------------------------------------------------------

openai_client = OpenAI(api_key=OPENAI_API_KEY)

# Stores the rolling per-user chat history as a deque of {"role", "content"}.
# Bounded by MAX_HISTORY_MESSAGES to keep token usage predictable.
chat_history: Dict[int, Deque[dict]] = defaultdict(
    lambda: deque(maxlen=MAX_HISTORY_MESSAGES)
)


def build_messages(user_id: int, user_text: str) -> List[dict]:
    """Return the OpenAI message list for a user, appending their latest message."""
    history = chat_history[user_id]
    history.append({"role": "user", "content": user_text})
    return [{"role": "system", "content": SYSTEM_PROMPT}, *list(history)]


def ask_openai(user_id: int, user_text: str) -> str:
    """Send the user's prompt (with history) to OpenAI and return the reply."""
    messages = build_messages(user_id, user_text)
    completion = openai_client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=messages,
        temperature=0.7,
    )
    reply = completion.choices[0].message.content or ""
    chat_history[user_id].append({"role": "assistant", "content": reply})
    return reply


# ---- Helpers ---------------------------------------------------------------


def chunk_text(text: str, limit: int = TELEGRAM_MAX_MESSAGE_LENGTH) -> List[str]:
    """Split a long string into chunks respecting Telegram's message size limit.

    Splits on paragraph / line boundaries when possible so the output reads cleanly.
    """
    if len(text) <= limit:
        return [text]

    chunks: List[str] = []
    remaining = text
    while len(remaining) > limit:
        # Try to find a natural break point within the limit window.
        split_at = remaining.rfind("\n\n", 0, limit)
        if split_at == -1 or split_at < limit // 2:
            split_at = remaining.rfind("\n", 0, limit)
        if split_at == -1 or split_at < limit // 2:
            split_at = remaining.rfind(" ", 0, limit)
        if split_at == -1 or split_at < limit // 2:
            split_at = limit
        chunks.append(remaining[:split_at].rstrip())
        remaining = remaining[split_at:].lstrip()
    if remaining:
        chunks.append(remaining)
    return chunks


# ---- Bot handlers ----------------------------------------------------------


HELP_TEXT = (
    "🤖 *AI Telegram Bot*\n\n"
    "I forward your messages to OpenAI and send the answer back.\n\n"
    "*Commands:*\n"
    "• /start — welcome message\n"
    "• /help — show this help\n"
    "• /reset — clear your conversation history\n"
    "• /model — show the current model\n\n"
    "Just send any text message to chat with me."
)


async def start_command(update: Update, _context: ContextTypes.DEFAULT_TYPE) -> None:
    assert update.effective_message is not None
    await update.effective_message.reply_text(HELP_TEXT, parse_mode=ParseMode.MARKDOWN)


async def help_command(update: Update, _context: ContextTypes.DEFAULT_TYPE) -> None:
    assert update.effective_message is not None
    await update.effective_message.reply_text(HELP_TEXT, parse_mode=ParseMode.MARKDOWN)


async def reset_command(update: Update, _context: ContextTypes.DEFAULT_TYPE) -> None:
    assert update.effective_message is not None
    if update.effective_user is None:
        return
    chat_history.pop(update.effective_user.id, None)
    await update.effective_message.reply_text(
        "✅ Conversation history cleared. Let's start fresh."
    )


async def model_command(update: Update, _context: ContextTypes.DEFAULT_TYPE) -> None:
    assert update.effective_message is not None
    await update.effective_message.reply_text(f"🧠 Current model: `{OPENAI_MODEL}`", parse_mode=ParseMode.MARKDOWN)


async def handle_message(update: Update, _context: ContextTypes.DEFAULT_TYPE) -> None:
    message = update.effective_message
    user = update.effective_user
    if message is None or user is None or not message.text:
        return

    logger.info("Message from %s (%s): %s", user.full_name, user.id, message.text)

    try:
        await message.chat_action(ChatAction.TYPING)
    except Exception:  # pragma: no cover - best-effort UI hint
        pass

    try:
        reply = await run_in_thread(ask_openai, user.id, message.text)
    except Exception as exc:
        logger.exception("OpenAI call failed")
        safe_error = str(exc)[:200].replace("`", "'")
        await message.reply_text(
            f"⚠️ Sorry, I couldn't reach OpenAI.\nError: `{safe_error}`",
            parse_mode=ParseMode.MARKDOWN,
        )
        return

    for chunk in chunk_text(reply):
        # Use Markdown for the first chunk so formatting renders; plain text after,
        # in case a chunk splits a code block.
        try:
            await message.reply_text(
                chunk,
                parse_mode=ParseMode.MARKDOWN,
            )
        except Exception:
            await message.reply_text(chunk)


async def run_in_thread(func, *args, **kwargs):
    """Run a blocking call in the default executor so the event loop stays responsive."""
    import asyncio
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, lambda: func(*args, **kwargs))


def main() -> None:
    logger.info("Starting bot with model %s", OPENAI_MODEL)
    application = Application.builder().token(TELEGRAM_BOT_TOKEN).build()

    application.add_handler(CommandHandler("start", start_command))
    application.add_handler(CommandHandler("help", help_command))
    application.add_handler(CommandHandler("reset", reset_command))
    application.add_handler(CommandHandler("model", model_command))
    application.add_handler(
        MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message)
    )

    application.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
