"""Focused regression tests for the 714 email-link policy."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from fastapi import HTTPException
from starlette.requests import Request

import server


class EmailLinkRateLimitTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.previous_store = server.store
        self.previous_sender = server.send_verification_email
        self.previous_window = server.EMAIL_REQUEST_WINDOW_SECONDS
        self.previous_email_limit = server.EMAIL_REQUEST_LIMIT
        self.previous_ip_limit = server.IP_REQUEST_LIMIT
        server.store = server.JobStore(Path(self.temporary_directory.name) / "jobs.sqlite3")
        server.EMAIL_REQUEST_WINDOW_SECONDS = 15 * 60
        server.EMAIL_REQUEST_LIMIT = 10
        server.IP_REQUEST_LIMIT = 40
        server.send_verification_email = lambda _email, _url: None

    def tearDown(self) -> None:
        server.store = self.previous_store
        server.send_verification_email = self.previous_sender
        server.EMAIL_REQUEST_WINDOW_SECONDS = self.previous_window
        server.EMAIL_REQUEST_LIMIT = self.previous_email_limit
        server.IP_REQUEST_LIMIT = self.previous_ip_limit
        self.temporary_directory.cleanup()

    @staticmethod
    def request(ip: str = "203.0.113.10") -> Request:
        return Request(
            {
                "type": "http",
                "method": "POST",
                "path": "/v1/auth/request-link",
                "headers": [],
                "client": (ip, 443),
                "scheme": "https",
                "server": ("omr.vocaldive.com", 443),
            }
        )

    def request_link(self, email: str, ip: str = "203.0.113.10") -> server.AuthLinkResponse:
        return server.request_auth_link(server.AuthLinkRequest(email=email), self.request(ip))

    def test_email_limit_returns_retry_after_after_ten_accepted_requests(self) -> None:
        for _ in range(10):
            response = self.request_link("singer@example.com")
            self.assertTrue(response.login_id)

        with self.assertRaises(HTTPException) as raised:
            self.request_link("singer@example.com")

        self.assertEqual(raised.exception.status_code, 429)
        self.assertEqual(raised.exception.detail["code"], "email_link_rate_limited")
        self.assertGreater(raised.exception.detail["retry_after_seconds"], 0)
        self.assertIn("Retry-After", raised.exception.headers)
        with server.store._connect() as connection:
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM auth_sessions").fetchone()[0], 10)

    def test_ip_limit_returns_retry_after_after_forty_accepted_requests(self) -> None:
        for index in range(40):
            self.request_link(f"singer-{index}@example.com")

        with self.assertRaises(HTTPException) as raised:
            self.request_link("singer-over-limit@example.com")

        self.assertEqual(raised.exception.status_code, 429)
        self.assertGreater(raised.exception.detail["retry_after_seconds"], 0)
        with server.store._connect() as connection:
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM auth_sessions").fetchone()[0], 40)

    def test_failed_resend_delivery_does_not_create_a_session_or_consume_a_limit(self) -> None:
        def fail_delivery(_email: str, _url: str) -> None:
            raise HTTPException(status_code=503, detail="Could not send the verification email")

        server.send_verification_email = fail_delivery
        email = "singer@example.com"
        with self.assertRaises(HTTPException) as raised:
            self.request_link(email)

        self.assertEqual(raised.exception.status_code, 503)
        self.assertFalse(server.store.rate_limit_decision("email", server.hash_secret(email), 10).is_limited)
        self.assertFalse(server.store.rate_limit_decision("ip", "203.0.113.10", 40).is_limited)
        with server.store._connect() as connection:
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM auth_sessions").fetchone()[0], 0)


if __name__ == "__main__":
    unittest.main()
