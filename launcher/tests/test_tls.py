"""Regression coverage for first-install TLS trust and certificate error handling."""
import json
from pathlib import Path
import ssl
import sys
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from updater import (
    HTTPSRedirectHandler, UpdateError, check_update_connection,
    create_tls_context, open_url,
)


class TLSUpdaterTests(unittest.TestCase):
    def test_bundle_supplies_roots_when_system_store_is_empty(self):
        empty = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        self.assertEqual(empty.cert_store_stats()["x509_ca"], 0)
        with patch("updater.ssl.create_default_context", return_value=empty) as factory:
            context = create_tls_context()
        factory.assert_called_once_with()  # Preserve default system trust loading.
        self.assertGreater(context.cert_store_stats()["x509_ca"], 0)
        self.assertEqual(context.verify_mode, ssl.CERT_REQUIRED)
        self.assertTrue(context.check_hostname)

    def test_system_roots_remain_available(self):
        original = ssl.create_default_context()
        roots_before = set(original.get_ca_certs(binary_form=True))
        with patch("updater.ssl.create_default_context", return_value=original):
            combined = create_tls_context()
        self.assertTrue(roots_before.issubset(set(combined.get_ca_certs(binary_form=True))))
        self.assertEqual(combined.verify_mode, ssl.CERT_REQUIRED)
        self.assertTrue(combined.check_hostname)

    def test_https_handler_receives_verified_context(self):
        with patch("updater.urllib.request.HTTPSHandler") as handler, \
                patch("updater.urllib.request.build_opener") as build:
            open_url("https://github.com/example")
        context = handler.call_args.kwargs["context"]
        self.assertGreater(context.cert_store_stats()["x509_ca"], 0)
        self.assertEqual(context.verify_mode, ssl.CERT_REQUIRED)
        self.assertTrue(context.check_hostname)
        self.assertEqual(build.return_value.open.call_args.kwargs["timeout"], 30)

    def test_wrapped_and_direct_certificate_errors_are_actionable_without_retry(self):
        for wrapped in (False, True):
            with self.subTest(wrapped=wrapped):
                cert_error = ssl.SSLCertVerificationError(1, "unable to get local issuer certificate")
                error = urllib.error.URLError(cert_error) if wrapped else cert_error
                with patch("updater.urllib.request.build_opener") as build:
                    build.return_value.open.side_effect = error
                    with self.assertRaisesRegex(UpdateError, "Cannot verify GitHub's certificate") as caught:
                        open_url("https://github.com/example")
                    build.return_value.open.assert_called_once()
                self.assertIs(caught.exception.__cause__, error)

    def test_unrelated_network_errors_are_not_misdiagnosed_as_certificates(self):
        error = urllib.error.URLError("DNS lookup failed")
        with patch("updater.urllib.request.build_opener") as build:
            build.return_value.open.side_effect = error
            with self.assertRaises(urllib.error.URLError) as caught:
                open_url("https://github.com/example")
        self.assertIs(caught.exception, error)

    def test_http_and_insecure_redirects_still_rejected(self):
        with self.assertRaises(UpdateError):
            open_url("http://github.com/example")
        with self.assertRaises(UpdateError):
            HTTPSRedirectHandler().redirect_request(
                None, None, 302, "", {}, "http://example.com/file"
            )

    def test_connection_probe_writes_success_without_installing(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "report.json"
            with patch("updater.fetch_manifest", return_value={"version": "build-test"}), \
                    patch("updater.Installation.install") as install:
                self.assertEqual(check_update_connection(report), 0)
            install.assert_not_called()
            data = json.loads(report.read_text())
            self.assertTrue(data["ok"])
            self.assertEqual(data["release"], "build-test")

    def test_connection_probe_writes_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "report.json"
            with patch("updater.fetch_manifest", side_effect=UpdateError("certificate failure")):
                self.assertEqual(check_update_connection(report), 1)
            data = json.loads(report.read_text())
            self.assertFalse(data["ok"])
            self.assertIn("certificate failure", data["error"])


if __name__ == "__main__":
    unittest.main()
