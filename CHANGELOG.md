# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
