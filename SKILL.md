# Supabase → Resend webhook agent

Concise context for humans, scripts, or any automation that works on this repo (not tied to a specific editor).

## Stack

- **Python 3.12+**, dependencies via **[uv](https://docs.astral.sh/uv/)** (`pyproject.toml`, `uv.lock`). Run `uv sync` / `make install`.
- **Deploy:** Vercel (`vercel.json`, `make deploy`). Before deploy, run `make export-requirements` so `requirements.txt` matches the lockfile.
- **Entry:** `api/webhook.py` (POST `/api/webhook`). Local dev: `make dev` (Vercel CLI + copies `.env.local` → `api/local_env.txt` for `load_dotenv`).

## Environment

- **Local:** `.env.local` (create with `make env` from `.env.example`).
- **Production:** Vercel project env vars.

| Variable | Notes |
|----------|--------|
| `RESEND_API_KEY` | Required to send mail |
| `RESEND_TO_EMAILS` | Comma-separated recipients |
| `RESEND_FROM_EMAIL` | Optional; default `onboarding@resend.dev` |
| `RESEND_FROM_NAME` | Optional display name |
| `SUPABASE_WEBHOOK_SECRET` | Optional; if set, validate `Authorization: Bearer …` |

## Webhook payload

Supabase sends JSON like:

```json
{
  "type": "INSERT",
  "table": "orders",
  "schema": "public",
  "record": { },
  "old_record": null
}
```

`type` may be INSERT, UPDATE, or DELETE; `old_record` used for UPDATE/DELETE in the email body.

## Commands (Makefile)

Run `make help` for the full list. Common checks:

- `make test`, `make lint`, `make format` — CI parity (see `.github/workflows/ci.yml`).
- `make dev` — local server at http://localhost:3000
- `make ping` / `make test-webhook` — local health + sample POST
- `make ping-prod` / `make test-webhook-prod` — against `DEPLOY_URL` (override in env)
- `make skill` — print this file (`SKILL.md`)

## Conventions

- Prefer matching existing patterns in `api/webhook.py` and `tests/`.
- After changing dependencies: `uv lock` (or `uv add`), `uv sync`, `make export-requirements`, commit `uv.lock` and `requirements.txt`.

Full setup and Supabase dashboard steps: [README.md](README.md).
