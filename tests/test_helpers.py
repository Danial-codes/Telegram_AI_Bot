"""Smoke tests for the bot's pure helper functions."""

from collections import deque

import bot
from bot import (
    MAX_HISTORY_MESSAGES,
    TELEGRAM_MAX_MESSAGE_LENGTH,
    build_messages,
    chunk_text,
)


def test_chunk_text_short_returns_single_chunk():
    text = "hello world"
    assert chunk_text(text) == [text]


def test_chunk_text_long_splits_within_limit():
    text = ("word " * (TELEGRAM_MAX_MESSAGE_LENGTH // 4)).strip()
    chunks = chunk_text(text)
    assert len(chunks) > 1
    assert all(len(c) <= TELEGRAM_MAX_MESSAGE_LENGTH for c in chunks)
    # The reassembled text should contain the same words in the same order.
    assert " ".join(c.split()) == text


def test_build_messages_includes_system_and_appends_user_message():
    bot.chat_history[99999] = deque(maxlen=MAX_HISTORY_MESSAGES)
    try:
        msgs = build_messages(99999, "hello there")
        assert msgs[0]["role"] == "system"
        assert msgs[-1]["role"] == "user"
        assert msgs[-1]["content"] == "hello there"
        # The just-appended user message should be present in the stored history.
        assert any(m["role"] == "user" and m["content"] == "hello there" for m in bot.chat_history[99999])
    finally:
        bot.chat_history.pop(99999, None)
