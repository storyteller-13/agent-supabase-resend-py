# 👱🏿‍♂️ Bob, the Agent Who Gets Excited on `INSERT`

<br>

> *A small agent that runs as a Vercel serverless function. When Supabase sends a **database webhook** (on row INSERT), this endpoint receives the payload and sends an email via **Resend** with a summary of the change.*

<br>

----

## Quick start

```bash
make install    # install dependencies
make env        # copy .env.example → .env.local (then edit with your keys)
make dev        # run locally at http://localhost:3000
make ping       # health check (with dev server running)
make test-webhook   # send a sample POST payload (local)
make deploy     # deploy to Vercel
make ping-prod  # test production deployment
```

Run `make help` for all targets.


<br>

---

## Setup

### 1. Resend

- Sign up at [resend.com](https://resend.com) and create an API key.
- Add your domain and verify it if you want a custom "from" address; otherwise you can use `onboarding@resend.dev` for testing.

### 2. Environment variables

- **Local:** Run `make env`, then edit `.env.local` with your values.
- **Vercel:** Project → Settings → Environment Variables.

| Variable | Required | Description |
|----------|----------|-------------|
| `RESEND_API_KEY` | Yes | Your Resend API key |
| `RESEND_TO_EMAILS` | Yes | Comma-separated recipient emails |
| `RESEND_FROM_EMAIL` | No | From address (default: `onboarding@resend.dev`) |
| `RESEND_FROM_NAME` | No | From display name |
| `SUPABASE_WEBHOOK_SECRET` | No | If set, requests must send this in `Authorization: Bearer <secret>` |

### 3. Deploy to Vercel

```bash
make deploy
```

Note the deployed URL (e.g. `https://agent-supabase-resend-py.vercel.app`). Configure it in Supabase as the webhook URL.

### 4. Supabase Database Webhook

1. In the [Supabase Dashboard](https://supabase.com/dashboard), open your project.
2. Go to **Database** → **Webhooks** (or **Project Settings** → **Database** → **Webhooks**).
3. Click **Create a new webhook**.
4. Configure:
   - **Name**: e.g. `Email on change`
   - **Table(s)**: e.g. `public.orders`
   - **Events**: INSERT, UPDATE, and/or DELETE
   - **HTTP Request**
     - **Method**: POST
     - **URL**: `https://your-project.vercel.app/api/webhook`
     - **Headers** (optional): if you set `SUPABASE_WEBHOOK_SECRET`, add `Authorization: Bearer your_shared_secret`

Supabase sends a JSON body like:

```json
{
  "type": "INSERT",
  "table": "orders",
  "schema": "public",
  "record": { "id": 1, "email": "user@example.com", ... },
  "old_record": null
}
```

The agent turns this into an email and sends it via Resend to `RESEND_TO_EMAILS`.

<br>

---

## Local development

- **Python 3.12+** and **uv** (installed as a dev dependency) are required for `make dev`.
- If you don’t have Python 3.12: `brew install python@3.12` then `poetry env use $(brew --prefix python@3.12)/bin/python3.12`.

```bash
make dev
```

Then open http://localhost:3000 (root returns service info). Use `make ping` and `make test-webhook` against the local server. For Supabase to hit your machine, use a tunnel (e.g. ngrok).

`make dev` loads `.env.local` into the environment before starting Vercel. If you see **"RESEND_API_KEY is not set"**, check that `.env.local` exists, contains `RESEND_API_KEY=your_key` (no spaces around `=`), and restart the dev server.

<br>

---

## Testing the deployment

Production URL is set in the Makefile as `DEPLOY_URL` (default: `https://agent-supabase-resend-py.vercel.app`).

```bash
make ping-prod              # GET / and GET /api/webhook (health)
make test-webhook-prod      # POST sample payload (sends email if Vercel env vars are set)
```

Override the URL: `DEPLOY_URL=https://your-app.vercel.app make ping-prod`.

<br>

---

## Testing and linting

- **Tests:** `make test` (pytest)
- **Coverage:** `make coverage` (pytest with terminal report), `make coverage-report` (adds `htmlcov/` for browser)
- **Lint:** `make lint` (ruff check), `make lint-fix` (auto-fix), `make format` (ruff format)
- **Pre-commit:** Run `make pre-commit` once to install hooks; then `git commit` will run ruff (check + format) automatically. Pytest runs in CI only.

CI runs on push/PR (see [.github/workflows/ci.yml](.github/workflows/ci.yml)): ruff check, ruff format --check, pytest with coverage.

<br>

---
## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Service info (rewrites to `/api`) |
| GET | `/api` | Same as `/` |
| GET | `/api/webhook` | Health check |
| POST | `/api/webhook` | Supabase database webhook → sends email via Resend |
