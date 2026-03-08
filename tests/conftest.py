"""Pytest fixtures and env for tests."""

import pytest


@pytest.fixture(autouse=True)
def env_for_webhook(monkeypatch):
    """Set minimal env so webhook module can be imported and _send_email runs with mocks."""
    monkeypatch.setenv("RESEND_API_KEY", "re_test")
    monkeypatch.setenv("RESEND_TO_EMAILS", "test@example.com")
