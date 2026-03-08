.PHONY: install export-requirements dev deploy env clean ping ping-prod test-webhook test-webhook-prod

# Test deployed app: set DEPLOY_URL first, e.g. export DEPLOY_URL=https://your-app.vercel.app
DEPLOY_URL ?= https://agent-supabase-resend-py.vercel.app

POETRY := $(shell command -v poetry 2>/dev/null || command -v pipx 2>/dev/null | xargs -I {} echo "{} run poetry")

install:
	@if [ -z "$(POETRY)" ]; then \
		echo "Poetry not found. Install it with:"; \
		echo "  brew install poetry"; \
		echo "  or: curl -sSL https://install.python-poetry.org | python3 -"; \
		exit 1; \
	fi
	$(POETRY) config virtualenvs.in-project true
	$(POETRY) install

export-requirements: install
	@$(POETRY) export -f requirements.txt --without-hashes -o requirements.txt 2>/dev/null || \
	(.venv/bin/python -c "\
import re; \
s=open('pyproject.toml').read(); \
m=re.search(r'\[project\].*?dependencies\s*=\s*\[(.*?)\]', s, re.DOTALL); \
deps=re.findall(r'\"([^\"]+)\"', m.group(1)) if m else ['resend>=2.0.0']; \
open('requirements.txt','w').write('\n'.join(deps)); \
print('Wrote requirements.txt from pyproject.toml')" )

env:
	@test -f .env.example || { echo "RESEND_API_KEY=" > .env.example; echo "RESEND_TO_EMAILS=" >> .env.example; echo "Created .env.example"; }
	@if [ ! -f .env.local ]; then cp .env.example .env.local; echo "Created .env.local"; fi
	@ls -la .env.local && echo "Edit .env.local with your RESEND_API_KEY and RESEND_TO_EMAILS"

dev: install
	@VENV_PY="$(PWD)/.venv/bin/python"; \
	VENV_BIN="$(PWD)/.venv/bin"; \
	if [ ! -x "$$VENV_PY" ] || ! $$VENV_PY -c "import sys; exit(0 if sys.version_info >= (3, 12) else 1)" 2>/dev/null; then \
		echo "Python 3.12+ required. Run: poetry env use python3.12 && poetry install"; exit 1; \
	fi; \
	if [ ! -x "$$VENV_BIN/uv" ]; then \
		echo "uv not found in venv. Run: poetry install"; exit 1; \
	fi; \
	PATH="$$VENV_BIN:$$PATH" vercel dev

deploy: export-requirements
	vercel --prod

clean:
	rm -rf .venv
	rm -rf __pycache__ .pytest_cache .mypy_cache
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name '*.pyc' -delete 2>/dev/null || true
	rm -rf .vercel
	rm -rf build dist *.egg-info .eggs

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
