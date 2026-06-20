"""Pytest configuration.

The bot module validates required env vars at import time. To allow the
test suite to import it without a real `.env` on disk, we inject dummy
values here *before* any test module imports ``bot``.
"""

import os

os.environ.setdefault("TELEGRAM_BOT_TOKEN", "test-token")
os.environ.setdefault("OPENAI_API_KEY", "test-key")
