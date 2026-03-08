"""
Root/health handler. GET / or /api returns service info.
"""
import json
from http.server import BaseHTTPRequestHandler


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({
            "service": "supabase-resend-agent",
            "status": "ok",
            "message": "Bob is ready. POST to /api/webhook for Supabase webhooks.",
            "webhook": "/api/webhook",
        }).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass
