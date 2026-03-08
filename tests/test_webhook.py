"""Tests for api.webhook handler and helpers."""

import io
from unittest.mock import MagicMock, patch

import pytest


@pytest.fixture
def mock_handler():
    """Minimal mock for handler-like object (headers, rfile)."""
    h = MagicMock()
    h.wfile = io.BytesIO()
    h.headers = {}
    h.rfile = io.BytesIO(b"")
    return h


def test_validate_secret_no_secret(env_for_webhook):
    from api.webhook import _validate_secret

    h = MagicMock()
    h.headers = {}
    assert _validate_secret(h) is True


def test_validate_secret_with_secret_valid(env_for_webhook, monkeypatch):
    monkeypatch.setenv("SUPABASE_WEBHOOK_SECRET", "mysecret")
    from api.webhook import _validate_secret

    h = MagicMock()
    h.headers = {"Authorization": "Bearer mysecret"}
    assert _validate_secret(h) is True
    h.headers = {"Authorization": "mysecret"}
    assert _validate_secret(h) is True


def test_validate_secret_with_secret_invalid(env_for_webhook, monkeypatch):
    monkeypatch.setenv("SUPABASE_WEBHOOK_SECRET", "mysecret")
    from api.webhook import _validate_secret

    h = MagicMock()
    h.headers = {"Authorization": "Bearer wrong"}
    assert _validate_secret(h) is False


def test_read_body_empty(mock_handler):
    from api.webhook import _read_body

    mock_handler.headers = {"Content-Length": "0"}
    assert _read_body(mock_handler) == b""


def test_read_body_with_content(mock_handler):
    from api.webhook import _read_body

    body = b'{"type":"INSERT","table":"orders"}'
    mock_handler.headers = {"Content-Length": str(len(body))}
    mock_handler.rfile = io.BytesIO(body)
    assert _read_body(mock_handler) == body


def test_send_email_missing_api_key(env_for_webhook, monkeypatch):
    monkeypatch.delenv("RESEND_API_KEY", raising=False)
    from api.webhook import _send_email

    with pytest.raises(ValueError, match="RESEND_API_KEY"):
        _send_email({"type": "INSERT", "table": "t", "record": {}})


def test_send_email_missing_to_emails(env_for_webhook, monkeypatch):
    monkeypatch.setenv("RESEND_API_KEY", "re_xxx")
    monkeypatch.delenv("RESEND_TO_EMAILS", raising=False)
    from api.webhook import _send_email

    with pytest.raises(ValueError, match="RESEND_TO_EMAILS"):
        _send_email({"type": "INSERT", "table": "t", "record": {}})


@patch("api.webhook.resend.Emails.send")
def test_send_email_success(mock_send, env_for_webhook):
    mock_send.return_value = MagicMock(id="mock-id")
    from api.webhook import _send_email

    result = _send_email(
        {
            "type": "INSERT",
            "table": "orders",
            "schema": "public",
            "record": {"id": 1, "email": "a@b.com"},
        }
    )
    assert result is not None
    mock_send.assert_called_once()
    # Resend SDK may pass params as first arg or kwargs
    call = mock_send.call_args
    params = call.kwargs if call.kwargs else (call.args[0] if call.args else {})
    if isinstance(params, dict):
        assert "[Supabase] INSERT on public.orders" in params.get("subject", "")
