.PHONY: help skill install export-requirements dev deploy env clean ping ping-prod test-webhook test-webhook-prod test coverage coverage-report lint lint-fix format pre-commit

# Production URL for ping-prod / test-webhook-prod (override: DEPLOY_URL=https://your-app.vercel.app make ping-prod)
DEPLOY_URL ?= https://agent-supabase-resend-py.vercel.app

skill:
	@test -f SKILL.md || { echo "SKILL.md not found"; exit 1; }
	@cat SKILL.md

help:
	@echo "Supabase → Resend email agent"
	@echo ""
	@echo "  make skill           Show SKILL.md (project context for tools / contributors)"
	@echo "  make install          Install dependencies (uv)"
	@echo "  make env             Create .env.local from .env.example"
	@echo "  make dev             Run local dev server (Python 3.12+, Vercel CLI)"
	@echo "  make deploy          Deploy to Vercel production"
	@echo "  make ping            GET health check (local, dev server must be running)"
	@echo "  make ping-prod       GET health check (production)"
	@echo "  make test-webhook    POST sample payload (local)"
	@echo "  make test-webhook-prod  POST sample payload (production, sends email if env set)"
	@echo "  make clean           Remove .venv, cache, build artifacts"
	@echo "  make test            Run pytest"
	@echo "  make coverage        Run pytest with coverage report (terminal)"
	@echo "  make coverage-report Run pytest with coverage and open html report"
	@echo "  make lint            Run ruff check"
	@echo "  make lint-fix        Run ruff check --fix"
	@echo "  make format          Run ruff format"
	@echo "  make pre-commit      Install pre-commit hooks and run"

install:
	@command -v uv >/dev/null 2>&1 || { \
		echo "uv not found. Install it with:"; \
		echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"; \
		echo "  or: brew install uv"; \
		exit 1; \
	}
	uv sync

export-requirements: install
	uv export --no-dev -o requirements.txt --no-hashes

env:
	@test -f .env.example || { echo "RESEND_API_KEY=" > .env.example; echo "RESEND_TO_EMAILS=" >> .env.example; echo "Created .env.example"; }
	@if [ ! -f .env.local ]; then cp .env.example .env.local; echo "Created .env.local"; fi
	@ls -la .env.local && echo "Edit .env.local with your RESEND_API_KEY and RESEND_TO_EMAILS"

dev: install
	@VENV_PY="$(PWD)/.venv/bin/python"; \
	VENV_BIN="$(PWD)/.venv/bin"; \
	if [ ! -x "$$VENV_PY" ] || ! $$VENV_PY -c "import sys; exit(0 if sys.version_info >= (3, 12) else 1)" 2>/dev/null; then \
		echo "Python 3.12+ required. Run: uv python install 3.12 && uv sync"; exit 1; \
	fi; \
	if ! command -v vercel >/dev/null 2>&1; then \
		echo "Vercel CLI not found. Install: npm i -g vercel"; exit 1; \
	fi; \
	cp .env.local api/local_env.txt 2>/dev/null || true; \
	(set -a; [ -f .env.local ] && . ./.env.local; set +a; PATH="$$VENV_BIN:$$PATH" vercel dev)

deploy: export-requirements
	vercel --prod

clean:
	rm -rf .venv
	rm -rf __pycache__ .pytest_cache .mypy_cache
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name '*.pyc' -delete 2>/dev/null || true
	rm -rf .vercel
	rm -rf build dist *.egg-info .eggs

test: install
	uv run pytest

coverage: install
	uv run pytest --cov=api --cov-report=term-missing

coverage-report: install
	uv run pytest --cov=api --cov-report=term-missing --cov-report=html
	@echo "Open htmlcov/index.html in a browser"

lint: install
	uv run ruff check .

lint-fix: install
	uv run ruff check . --fix

format: install
	uv run ruff format .

pre-commit: install
	uv run pre-commit install
	uv run pre-commit run --all-files

ping:
	@curl -s http://localhost:3000/api/webhook | python3 -m json.tool

test-webhook:
	@curl -s -X POST http://localhost:3000/api/webhook \
		-H "Content-Type: application/json" \
		-d '{"type":"INSERT","table":"orders","schema":"public","record":{"id":1,"email":"test@example.com"},"old_record":null}' \
		| python3 -m json.tool

# Test production deployment (override DEPLOY_URL if your app has a different URL)
ping-prod:
	@echo "GET $(DEPLOY_URL)/"
	@curl -s "$(DEPLOY_URL)/" | python3 -m json.tool
	@echo "\nGET $(DEPLOY_URL)/api/webhook (health)"
	@curl -s "$(DEPLOY_URL)/api/webhook" | python3 -m json.tool

test-webhook-prod:
	@echo "POST $(DEPLOY_URL)/api/webhook"
	@curl -s -X POST "$(DEPLOY_URL)/api/webhook" \
		-H "Content-Type: application/json" \
		-d '{"type":"INSERT","table":"orders","schema":"public","record":{"id":1,"email":"test@example.com"},"old_record":null}' \
		| python3 -m json.tool
