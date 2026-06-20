.PHONY: install lint test run clean help

help:
	@echo "Available targets:"
	@echo "  install  - install the package and dev extras (editable)"
	@echo "  lint     - run ruff"
	@echo "  test     - run pytest"
	@echo "  run      - start the bot"
	@echo "  clean    - remove build / cache artefacts"

install:
	python -m pip install --upgrade pip
	pip install -e ".[dev]"

lint:
	ruff check .

test:
	pytest -q

run:
	python bot.py

clean:
	rm -rf build dist *.egg-info .pytest_cache .ruff_cache
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
