"""Focused regression tests for the 714 email-link policy."""

from __future__ import annotations

import io
import os
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch
from urllib.parse import parse_qs, urlparse

from fastapi import HTTPException
from starlette.requests import Request

import server


class OemerExecutableTests(unittest.TestCase):
    def setUp(self) -> None:
        self.previous_setting = server.OEMER_EXECUTABLE_SETTING

    def tearDown(self) -> None:
        server.OEMER_EXECUTABLE_SETTING = self.previous_setting

    def test_legacy_setting_resolves_the_console_script_beside_worker_python(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            python = Path(directory) / "python.exe"
            expected = Path(directory) / ("oemer.exe" if os.name == "nt" else "oemer")
            expected.touch()
            server.OEMER_EXECUTABLE_SETTING = "oemer"
            with patch.object(server.sys, "executable", str(python)):
                self.assertEqual(server.resolved_oemer_executable(), expected)
                self.assertEqual(server.available_oemer_executable(), expected)

    def test_absolute_override_is_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / "custom-oemer.exe"
            executable.touch()
            server.OEMER_EXECUTABLE_SETTING = str(executable)
            self.assertEqual(server.available_oemer_executable(), executable)

    def test_missing_cli_is_reported_as_unavailable_without_a_windows_error(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            server.OEMER_EXECUTABLE_SETTING = str(Path(directory) / "missing-oemer.exe")
            self.assertFalse(server.engine_ready())
            with self.assertRaises(server.OemerEngineUnavailableError):
                server.available_oemer_executable()

    def test_worker_failure_codes_are_stable_and_do_not_include_host_error_text(self) -> None:
        self.assertEqual(server.worker_failure_code("rasterizing"), "source_processing_failed")
        self.assertEqual(server.worker_failure_code("recognizing"), "recognition_failed")
        self.assertEqual(server.worker_failure_code("assembling"), "result_assembly_failed")
        self.assertEqual(server.worker_failure_code("unexpected"), "worker_failed")


class RuntimeDiagnosticsTests(unittest.TestCase):
    class FakeProcess:
        def __init__(self, return_code: int | None, lines: str = "") -> None:
            self.return_code = return_code
            self.stdout = io.StringIO(lines)
            self.pid = 999999
            self.killed = False

        def poll(self) -> int | None:
            return self.return_code

        def wait(self) -> int:
            return -9 if self.killed else int(self.return_code or 0)

        def kill(self) -> None:
            self.killed = True
            self.return_code = -9

    def test_stage_parser_normalizes_oemer_readme_messages(self) -> None:
        self.assertEqual(server.oemer_stage_for_line("INFO Extracting staffline and symbols"), "model_stafflines")
        self.assertEqual(server.oemer_stage_for_line("Extracting layers of different symbols"), "model_symbols")
        self.assertEqual(server.oemer_stage_for_line("Dewarping"), "dewarping")
        self.assertEqual(server.oemer_stage_for_line("Extracting stafflines"), "stafflines")
        self.assertEqual(server.oemer_stage_for_line("Extracting noteheads"), "noteheads")
        self.assertEqual(server.oemer_stage_for_line("Extracting symbols"), "symbols")
        self.assertEqual(server.oemer_stage_for_line("Extracting rhythm types"), "rhythm")
        self.assertEqual(server.oemer_stage_for_line("Building MusicXML document"), "building_musicxml")
        self.assertIsNone(server.oemer_stage_for_line("unrelated output"))

    def test_runtime_data_handles_missing_and_malformed_json(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = server.JobStore(Path(directory) / "jobs.sqlite3")
            store.create(
                job_id="job", account_id="account", idempotency_key="key", source_name="score.png",
                job_root=Path(directory) / "job", total_pages=1,
            )
            row = store.get("job")
            self.assertEqual(server.runtime_data(row), {})
            with store._connect() as connection:
                connection.execute("UPDATE jobs SET runtime_json = 'not json' WHERE job_id = 'job'")
            self.assertEqual(server.runtime_data(store.get("job")), {})

    def test_runtime_snapshot_is_persisted_for_live_status(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = server.JobStore(Path(directory) / "jobs.sqlite3")
            store.create(
                job_id="job", account_id="account", idempotency_key="key", source_name="score.png",
                job_root=Path(directory) / "job", total_pages=1,
            )
            store.update_runtime(
                "job",
                {
                    "engine_stage": "noteheads",
                    "elapsed_seconds": 12,
                    "heartbeat_at": "2026-08-06T12:00:00Z",
                    "attention_needed": False,
                    "resources": {"gpu": {"utilization_percent": 60}},
                },
            )
            runtime = server.runtime_data(store.get("job"))
            self.assertEqual(runtime["engine_stage"], "noteheads")
            self.assertEqual(runtime["resources"]["gpu"]["utilization_percent"], 60)

    def test_nonzero_process_and_missing_output_have_stable_errors(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            page = root / "page.png"
            page.write_bytes(b"image")
            updates: list[dict[str, object]] = []
            with patch("server.available_oemer_executable", return_value=root / "oemer.exe"):
                with patch("server.subprocess.Popen", return_value=self.FakeProcess(3)):
                    with self.assertRaises(server.OemerRecognitionProcessError):
                        server.run_oemer(page, root / "diagnostics", 0, updates.append)
                with patch("server.subprocess.Popen", return_value=self.FakeProcess(0)):
                    with self.assertRaises(server.OemerNoMusicXMLError):
                        server.run_oemer(page, root / "diagnostics", 1, updates.append)
            self.assertTrue(updates)

    def test_timeout_terminates_the_process(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            page = root / "page.png"
            page.write_bytes(b"image")
            process = self.FakeProcess(None)
            previous_timeout = server.OEMER_PAGE_TIMEOUT_SECONDS
            server.OEMER_PAGE_TIMEOUT_SECONDS = 0
            try:
                with patch("server.available_oemer_executable", return_value=root / "oemer.exe"):
                    with patch("server.subprocess.Popen", return_value=process):
                        with self.assertRaises(server.OemerRecognitionTimeoutError):
                            server.run_oemer(page, root / "diagnostics", 0, lambda _value: None)
            finally:
                server.OEMER_PAGE_TIMEOUT_SECONDS = previous_timeout
            self.assertTrue(process.killed)

    def test_invalid_and_incompatible_musicxml_are_distinguished(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            invalid = root / "invalid.musicxml"
            invalid.write_text("<score-partwise>", encoding="utf-8")
            with self.assertRaises(server.OemerMusicXMLInvalidError):
                server.merge_musicxml([invalid], root / "candidate.musicxml")

            left = root / "left.musicxml"
            right = root / "right.musicxml"
            left.write_text('<score-partwise><part id="P1" /></score-partwise>', encoding="utf-8")
            right.write_text('<score-partwise><part id="P2" /></score-partwise>', encoding="utf-8")
            with self.assertRaises(server.OemerMusicXMLMergeIncompatibleError):
                server.merge_musicxml([left, right], root / "candidate.musicxml")


class EmailLinkRateLimitTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.previous_store = server.store
        self.previous_crm_store = server.crm_store
        self.previous_sender = server.send_verification_email
        self.previous_window = server.EMAIL_REQUEST_WINDOW_SECONDS
        self.previous_auth_link_ttl_hours = server.AUTH_LINK_TTL_HOURS
        self.previous_email_limit = server.EMAIL_REQUEST_LIMIT
        self.previous_ip_limit = server.IP_REQUEST_LIMIT
        server.store = server.JobStore(Path(self.temporary_directory.name) / "jobs.sqlite3")
        server.crm_store = server.CRMStore(
            Path(self.temporary_directory.name) / "crm.sqlite3",
            legacy_jobs_path=Path(self.temporary_directory.name) / "jobs.sqlite3",
        )
        server.EMAIL_REQUEST_WINDOW_SECONDS = 15 * 60
        server.AUTH_LINK_TTL_HOURS = 24
        server.EMAIL_REQUEST_LIMIT = 10
        server.IP_REQUEST_LIMIT = 40
        server.send_verification_email = lambda _email, _url: None

    def tearDown(self) -> None:
        server.store = self.previous_store
        server.crm_store = self.previous_crm_store
        server.send_verification_email = self.previous_sender
        server.EMAIL_REQUEST_WINDOW_SECONDS = self.previous_window
        server.AUTH_LINK_TTL_HOURS = self.previous_auth_link_ttl_hours
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

    def test_auth_lifecycle_issues_a_device_credential_for_the_verified_session(self) -> None:
        captured_urls: list[str] = []
        server.send_verification_email = lambda _email, url: captured_urls.append(url)

        link = self.request_link("singer@example.com")
        self.assertTrue(link.expires_at.endswith("Z"))
        self.assertNotIn(".", link.expires_at)
        expires_at = datetime.fromisoformat(link.expires_at.replace("Z", "+00:00"))
        self.assertGreaterEqual(expires_at, datetime.now(timezone.utc) + timedelta(hours=23, minutes=59))
        self.assertLessEqual(expires_at, datetime.now(timezone.utc) + timedelta(hours=24, minutes=1))
        magic_secret = parse_qs(urlparse(captured_urls[0]).query)["token"][0]

        verified_page = server.verify_auth_link(magic_secret)
        self.assertIn("requested this link", verified_page.body.decode("utf-8"))
        completed = server.poll_auth_link(
            server.AuthPollRequest(login_id=link.login_id, poll_secret=link.poll_secret)
        )

        self.assertEqual(completed.state, "connected")
        self.assertEqual(completed.device_token, link.poll_secret)
        identity = server.require_device(f"Bearer {link.poll_secret}")
        self.assertTrue(identity.account_id)

    def test_utc_values_are_rfc3339_utc_and_expiry_accepts_legacy_fractional_values(self) -> None:
        future = server.utc_after(15)
        self.assertTrue(future.endswith("Z"))
        self.assertNotIn(".", future)
        self.assertFalse(server.is_expired(future))
        self.assertTrue(server.is_expired("2000-01-01T00:00:00.123456+00:00"))

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
