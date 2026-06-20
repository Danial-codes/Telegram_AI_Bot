# Contributing to Telegram AI Bot

Thanks for your interest in contributing! 🎉

## Development setup

```bash
# Clone the repo
git clone https://github.com/example/telegram-ai-bot.git
cd telegram-ai-bot

# Create a virtual environment
python -m venv .venv
# Activate it
.venv\Scripts\activate          # Windows
source .venv/bin/activate       # macOS / Linux

# Install the package with the dev extras
pip install -e ".[dev]"

# Configure secrets
copy .env.example .env          # Windows
cp .env.example .env            # macOS / Linux
# …then fill in TELEGRAM_BOT_TOKEN and OPENAI_API_KEY.
```

## Common commands

The `Makefile` exposes the day-to-day tasks. On Windows, run them through
Git Bash / WSL, or invoke `python -m ruff …` / `python -m pytest …` directly.

| Command       | What it does                                    |
| ------------- | ----------------------------------------------- |
| `make install`| Install the package and dev extras (editable).  |
| `make lint`   | Run `ruff check .`                              |
| `make test`   | Run `pytest -q`                                 |
| `make run`    | Start the bot (`python bot.py`).                |
| `make clean`  | Remove build / cache artefacts.                 |

## Workflow

1. Create a feature branch from `master`:
   ```bash
   git checkout master
   git pull
   git checkout -b feature/<short-description>
   ```
2. Commit logically scoped changes. We use [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat:` — new user-facing feature
   - `fix:` — bug fix
   - `docs:` — documentation only
   - `chore:` — tooling, CI, deps
   - `refactor:` — internal change without behaviour change
3. Run `make lint` and `make test` before pushing.
4. Open a pull request. CI will run on every push.
5. Merge via a **non fast-forward** merge commit so the feature branch is
   preserved in history:
   ```bash
   git checkout master
   git merge --no-ff feature/<short-description>
   ```

## Code style

- Python ≥ 3.9, formatted to `ruff`'s defaults (line length 100).
- Keep functions small and side-effect free where possible.
- Add or update tests for any behavioural change.

## Reporting bugs

Open an issue at <https://github.com/example/telegram-ai-bot/issues> with
the bot version, Python version, the relevant log output, and (if possible)
a minimal reproduction.

## License

By contributing, you agree that your contributions will be licensed under the
MIT License (see [`LICENSE`](LICENSE)).
