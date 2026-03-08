# Supabase → Resend Email Agent

A small agent that runs as a Vercel serverless function. When Supabase sends a **database webhook** (on row INSERT, UPDATE, or DELETE), this endpoint receives the payload and sends an email via **Resend** with a summary of the change.

## Quick start

```bash
make install    # install dependencies
make env        # copy .env.example → .env.local (then edit with your keys)
make dev        # run locally at http://localhost:3000
make ping       # health check (with dev server running)
make test-webhook   # send a sample POST payload (with dev server running)
make deploy     # deploy to Vercel
```

See `make help` for all targets.

## Setup

### 1. Resend

- Sign up at [resend.com](https://resend.com) and create an API key.
- Add your domain and verify it if you want a custom "from" address; otherwise you can use `onboarding@resend.dev` for testing.

### 2. Environment variables

Copy `.env.example` to `.env.local` (for local dev) and set in Vercel (Project → Settings → Environment Variables):

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

Or `vercel --prod` from the project directory. Note the deployed URL, e.g. `https://your-project.vercel.app`.

### 4. Supabase Database Webhook

1. In the [Supabase Dashboard](https://supabase.com/dashboard), open your project.
2. Go to **Database** → **Webhooks** (or **Project Settings** → **Database** → **Webhooks** depending on UI).
3. Click **Create a new webhook**.
4. Configure:
   - **Name**: e.g. `Email on change`
   - **Table(s)**: choose the table(s) you want to trigger on (e.g. `public.orders`).
   - **Events**: INSERT, UPDATE, and/or DELETE.
   - **HTTP Request**:
     - **Method**: POST
     - **URL**: `https://your-project.vercel.app/api/webhook`
     - **Headers** (optional): if you set `SUPABASE_WEBHOOK_SECRET`, add `Authorization: Bearer your_shared_secret`.

Supabase will send a JSON body like:

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

## Local development

```bash
make dev
```

Or run `pip install -r requirements.txt` and `vercel dev` manually. Trigger with a POST to `http://localhost:3000/api/webhook` with the same JSON shape, or use `make test-webhook`. For Supabase to hit your machine, use a tunnel (e.g. `ngrok`).

## Makefile

| Target | Description |
|--------|-------------|
| `make help` | Show all targets (default) |
| `make install` | Install Python dependencies |
| `make env` | Copy `.env.example` → `.env.local` |
| `make dev` | Run local dev server (`vercel dev`) |
| `make deploy` | Deploy to Vercel (production) |
| `make ping` | GET health check (requires dev server) |
| `make test-webhook` | POST sample Supabase payload (requires dev server) |

## Endpoints

- **POST /api/webhook** — Receives Supabase database webhook payload and sends the email.
- **GET /api/webhook** — Health check; returns `{"service": "supabase-resend-agent", "status": "ok"}`.
