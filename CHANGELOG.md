# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Optional `OPENAI_BASE_URL` env var, so the bot can talk to any
  OpenAI-compatible endpoint (Azure OpenAI, Together, Ollama, vLLM, …)
  without code changes.
- Optional `TELEGRAM_BASE_URL` and `TELEGRAM_BASE_FILE_URL` env vars for
  pointing the bot at a self-hosted Telegram Bot API server.
- Helpers `build_openai_client()` and `build_application()` exported from
  `bot.py` so the configuration layer can be unit-tested.
- Smoke tests for both helpers (`tests/test_helpers.py`).
- `deploy/setup-vps.sh` — idempotent script that creates a dedicated
  `telegram-bot` system user, clones (or hard-resets) the repo on the VPS,
  sets up a per-user venv, writes `.env` from GitHub Actions secrets, and
  installs/starts the bot as a `systemd` service.
- `deploy/telegram-ai-bot.service` — `systemd` unit template, run as
  `telegram-bot` user with `EnvironmentFile=/opt/telegram-ai-bot/.env`,
  `Restart=on-failure`, and a `MemoryMax=512M` cap.
- README has a new **Deploy** section documenting the required GitHub
  secrets/vars and an ops cheatsheet.

### Changed
- Replaced `.github/workflows/ci.yml` with `.github/workflows/deploy.yml`.
  The new workflow runs `ruff` + `pytest` on a Python 3.10/3.11/3.12
  matrix, then (only if tests pass) SSHes to a VPS whose address lives in
  GitHub Secrets, copies the `deploy/` folder over, and runs
  `setup-vps.sh` to install and start the bot as a `systemd` service.
  Trigger: push to `master` only.

## [0.1.0] — 2026-06-20

### Added
- Async Telegram bot using `python-telegram-bot` v20+ and the `openai` v1.x SDK.
- Per-user conversation memory with a configurable rolling message window.
- Automatic splitting of long model completions to fit Telegram's 4096-character
  message limit.
- Commands: `/start`, `/help`, `/reset`, `/model`.
- Configuration via `.env` (see `.env.example`).
- Project scaffolding: `LICENSE`, `pyproject.toml`, `ruff` + `pytest` config,
  GitHub Actions CI, smoke tests, `Makefile`, `CONTRIBUTING.md`, this changelog.

[Unreleased]: https://github.com/example/telegram-ai-bot/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/example/telegram-ai-bot/releases/tag/v0.1.0
