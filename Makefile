.PHONY: install export-requirements dev deploy env clean ping test-webhook

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
	$(POETRY) export -f requirements.txt --without-hashes -o requirements.txt

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
	@curl -s http://localhost:3000/api/webhook | python -m json.tool

test-webhook:
	@curl -s -X POST http://localhost:3000/api/webhook \
		-H "Content-Type: application/json" \
		-d '{"type":"INSERT","table":"orders","schema":"public","record":{"id":1,"email":"test@example.com"},"old_record":null}' \
		| python -m json.tool
