"""Focused regression tests for the 714 email-link policy."""

from __future__ import annotations

import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi import HTTPException
from starlette.requests import Request

import server


class EmailLinkRateLimitTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.previous_store = server.store
        self.previous_crm_store = server.crm_store
        self.previous_sender = server.send_verification_email
        self.previous_window = server.EMAIL_REQUEST_WINDOW_SECONDS
        self.previous_email_limit = server.EMAIL_REQUEST_LIMIT
        self.previous_ip_limit = server.IP_REQUEST_LIMIT
        server.store = server.JobStore(Path(self.temporary_directory.name) / "jobs.sqlite3")
        server.crm_store = server.CRMStore(
            Path(self.temporary_directory.name) / "crm.sqlite3",
            legacy_jobs_path=Path(self.temporary_directory.name) / "jobs.sqlite3",
        )
        server.EMAIL_REQUEST_WINDOW_SECONDS = 15 * 60
        server.EMAIL_REQUEST_LIMIT = 10
        server.IP_REQUEST_LIMIT = 40
        server.send_verification_email = lambda _email, _url: None

    def tearDown(self) -> None:
        server.store = self.previous_store
        server.crm_store = self.previous_crm_store
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
        return server.request_auth_link(
            server.AuthLinkRequest(
                email=email,
                installation_id="installation-test-0001",
                consent_version="714-beta-data-v1",
            ),
            self.request(ip),
        )

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
        with server.crm_store._connect() as connection:
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM auth_sessions").fetchone()[0], 10)

    def test_ip_limit_returns_retry_after_after_forty_accepted_requests(self) -> None:
        for index in range(40):
            self.request_link(f"singer-{index}@example.com")

        with self.assertRaises(HTTPException) as raised:
            self.request_link("singer-over-limit@example.com")

        self.assertEqual(raised.exception.status_code, 429)
        self.assertGreater(raised.exception.detail["retry_after_seconds"], 0)
        with server.crm_store._connect() as connection:
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM auth_sessions").fetchone()[0], 40)

    def test_failed_resend_delivery_does_not_create_a_session_or_consume_a_limit(self) -> None:
        def fail_delivery(_email: str, _url: str) -> None:
            raise HTTPException(status_code=503, detail="Could not send the verification email")

        server.send_verification_email = fail_delivery
        email = "singer@example.com"
        with self.assertRaises(HTTPException) as raised:
            self.request_link(email)

        self.assertEqual(raised.exception.status_code, 503)
        self.assertFalse(server.crm_store.rate_limit_decision("email", server.hash_secret(email), 10).is_limited)
        self.assertFalse(server.crm_store.rate_limit_decision("ip", "203.0.113.10", 40).is_limited)
        with server.crm_store._connect() as connection:
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM auth_sessions").fetchone()[0], 0)

    def test_same_installation_rotates_the_prior_device_token(self) -> None:
        account_id = server.crm_store.find_or_create_account(
            "singer@example.com", server.hash_secret("singer@example.com"), "714-beta-data-v1"
        )
        first_hash = server.hash_secret("first-token")
        second_hash = server.hash_secret("second-token")
        server.crm_store.rotate_device(account_id, "installation-test-0001", first_hash, "VocalDive test")
        server.crm_store.rotate_device(account_id, "installation-test-0001", second_hash, "VocalDive test")

        self.assertIsNone(server.crm_store.device_for_token(first_hash))
        current = server.crm_store.device_for_token(second_hash)
        self.assertIsNotNone(current)
        self.assertEqual(current["account_id"], account_id)

    def test_profile_and_deletion_remove_personal_crm_fields(self) -> None:
        account_id = server.crm_store.find_or_create_account(
            "singer@example.com", server.hash_secret("singer@example.com"), "714-beta-data-v1"
        )
        server.crm_store.update_profile(account_id, "2000-01-02", ["Choral practice", "Sight reading"])
        profile = server.crm_store.account_profile(account_id)
        self.assertEqual(profile["birth_date"], "2000-01-02")
        self.assertEqual(server.account_profile_response(profile).goals, ["Choral practice", "Sight reading"])

        server.crm_store.delete_account(account_id)
        self.assertIsNone(server.crm_store.account_profile(account_id))

        reconnected_account_id = server.crm_store.find_or_create_account(
            "singer@example.com", server.hash_secret("singer@example.com"), "714-beta-data-v1"
        )
        self.assertEqual(reconnected_account_id, account_id)
        self.assertEqual(server.crm_store.account_profile(account_id)["email_address"], "singer@example.com")


class EmailLinkDeliveryDiagnosticsTests(unittest.TestCase):
    def test_resend_rejection_logs_sanitized_provider_reason(self) -> None:
        previous_key = server.RESEND_API_KEY
        server.RESEND_API_KEY = "test-key"
        captured_request = []
        rejection = server.urllib.error.HTTPError(
            url="https://api.resend.com/emails",
            code=403,
            msg="Forbidden",
            hdrs=None,
            fp=io.BytesIO(b'{"message":"Sender domain is not authorized"}'),
        )
        try:
            def reject(request, **_kwargs):
                captured_request.append(request)
                raise rejection

            with patch("server.urllib.request.urlopen", side_effect=reject):
                with self.assertLogs(server.LOGGER, level="WARNING") as captured:
                    with self.assertRaises(HTTPException) as raised:
                        server.send_verification_email(
                            "singer@example.com",
                            "https://omr.vocaldive.com/v1/auth/verify?token=secret",
                        )
        finally:
            server.RESEND_API_KEY = previous_key

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(captured_request[0].get_header("User-agent"), "VocalDiveOMR/1.0")
        joined_logs = "\n".join(captured.output)
        self.assertIn("Sender domain is not authorized", joined_logs)
        self.assertNotIn("singer@example.com", joined_logs)
        self.assertNotIn("token=secret", joined_logs)


if __name__ == "__main__":
    unittest.main()
