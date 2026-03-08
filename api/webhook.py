"""
Supabase Database Webhook → Resend Email Agent

Triggered by Supabase database webhooks (INSERT/UPDATE/DELETE).
Sends an email via Resend with a summary of the change.
"""

import json
import os
from http.server import BaseHTTPRequestHandler
from pathlib import Path

import resend
from dotenv import load_dotenv

# Load env for local dev: api/local_env.txt (make dev copies .env.local there)
_env_file = Path(__file__).resolve().parent / "local_env.txt"
if _env_file.exists():
    load_dotenv(_env_file, override=True)
else:
    load_dotenv(Path(__file__).resolve().parent.parent / ".env.local", override=True)


def _read_body(handler: BaseHTTPRequestHandler) -> bytes:
    content_length = int(handler.headers.get("Content-Length", 0))
    if content_length:
        return handler.rfile.read(content_length)
    return b""


def _send_email(payload: dict) -> dict | None:
    """Send email via Resend with the webhook payload summary."""
    api_key = os.environ.get("RESEND_API_KEY")
    if not api_key:
        raise ValueError("RESEND_API_KEY is not set")

    resend.api_key = api_key

    event_type = payload.get("type", "UNKNOWN")
    table = payload.get("table", "unknown")
    schema = payload.get("schema", "public")
    record = payload.get("record")
    old_record = payload.get("old_record")

    # Build a readable summary
    lines = [
        f"Database event: {event_type}",
        f"Table: {schema}.{table}",
        "",
    ]
    if record:
        lines.append("New/current record:")
        lines.append(json.dumps(record, indent=2, default=str))
    if old_record and event_type in ("UPDATE", "DELETE"):
        lines.append("")
        lines.append("Previous record:")
        lines.append(json.dumps(old_record, indent=2, default=str))

    body_text = "\n".join(lines)
    body_html = f"<pre style='font-family: monospace; white-space: pre-wrap;'>{body_text.replace('<', '&lt;').replace('>', '&gt;')}</pre>"

    from_email = os.environ.get("RESEND_FROM_EMAIL", "onboarding@resend.dev")
    from_name = os.environ.get("RESEND_FROM_NAME", "Supabase Webhook")
    to_emails = os.environ.get("RESEND_TO_EMAILS", "")
    if not to_emails:
        raise ValueError("RESEND_TO_EMAILS is not set (comma-separated list)")

    params: resend.Emails.SendParams = {
        "from": f"{from_name} <{from_email}>",
        "to": [e.strip() for e in to_emails.split(",") if e.strip()],
        "subject": f"[Supabase] {event_type} on {schema}.{table}",
        "html": body_html,
        "text": body_text,
    }

    return resend.Emails.send(params)


def _validate_secret(handler: BaseHTTPRequestHandler) -> bool:
    """Optional: validate Supabase webhook secret from header or query."""
    secret = os.environ.get("SUPABASE_WEBHOOK_SECRET")
    if not secret:
        return True
    # Supabase can send secret in header or as query param depending on config
    auth = handler.headers.get("Authorization", "").strip()
    if auth == f"Bearer {secret}" or auth == secret:
        return True
    return False


class handler(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            if not _validate_secret(self):
                self._respond(401, {"error": "Unauthorized"})
                return

            body = _read_body(self)
            if not body:
                self._respond(400, {"error": "Missing body"})
                return

            payload = json.loads(body.decode("utf-8"))

            if not isinstance(payload, dict) or "type" not in payload:
                self._respond(400, {"error": "Invalid webhook payload: expected type and table"})
                return

            result = _send_email(payload)
            self._respond(
                200,
                {
                    "ok": True,
                    "resend_id": getattr(result, "get", lambda k: None)("id") or str(result),
                },
            )
        except json.JSONDecodeError as e:
            self._respond(400, {"error": f"Invalid JSON: {e}"})
        except ValueError as e:
            self._respond(500, {"error": str(e)})
        except Exception as e:
            self._respond(500, {"error": str(e)})

    def do_GET(self):
        """Health check for Supabase webhook URL validation."""
        self._respond(200, {"service": "supabase-resend-agent", "status": "ok"})

    def _respond(self, status: int, data: dict):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        """Suppress default request logging."""
        pass
