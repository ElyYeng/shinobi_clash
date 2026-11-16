import copy
import io
import json
from pathlib import Path
import shutil
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from package_release import package
from updater import (
    Cancelled, Installation, InstanceLock, UpdateError, download,
    extract_verified, safe_path, validate_manifest,
)


def progress(*args):
    pass


class UpdaterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "export"
        self.source.mkdir()
        (self.source / "ShinobiClash.exe").write_bytes(b"game version one")
        (self.source / "ShinobiClash.pck").write_bytes(b"Godot pack")
        (self.source / "lib").mkdir()
        (self.source / "lib" / "example.dll").write_bytes(b"library")
        self.release = self.root / "release"
        self.manifest = package(self.source, self.release, "build-1")
        self.installation = Installation(self.root / "local")
        self.cancel = threading.Event()

    def local_download(self, archive, destination, report, cancel):
        shutil.copyfile(self.release / "shinobi-clash-windows.zip", destination)

    def install(self, manifest=None, downloader=None):
        self.installation.install(manifest or self.manifest, progress, self.cancel,
                                  downloader or self.local_download)

    def test_first_install_update_and_save_preservation(self):
        saves = self.root / "Godot" / "app_userdata" / "Shinobi Clash"
        saves.mkdir(parents=True)
        save = saves / "save.json"
        save.write_text('{"level": 80}')
        self.install()
        old_executable = self.installation.executable()
        (self.source / "ShinobiClash.exe").write_bytes(b"game version two")
        next_manifest = package(self.source, self.release, "build-2")
        self.install(next_manifest)
        self.assertEqual(self.installation.executable().read_bytes(), b"game version two")
        self.assertEqual(old_executable.read_bytes(), b"game version one")
        self.assertTrue(self.installation.is_current(next_manifest))
        self.assertEqual(save.read_text(), '{"level": 80}')

    def test_network_failure_preserves_active_install(self):
        self.install()
        previous = self.installation.state_path.read_bytes()
        def interrupted(*args):
            raise OSError("connection lost")
        with self.assertRaises(OSError):
            self.install(downloader=interrupted)
        self.assertEqual(previous, self.installation.state_path.read_bytes())
        self.assertFalse(list(self.installation.root.glob("staging-*")))

    def test_cancel_preserves_active_install(self):
        self.install()
        previous = self.installation.state_path.read_bytes()
        self.cancel.set()
        with self.assertRaises(Cancelled):
            self.install()
        self.assertEqual(previous, self.installation.state_path.read_bytes())

    def test_failed_atomic_commit_preserves_active_install(self):
        self.install()
        previous = self.installation.state_path.read_bytes()
        with patch("updater.os.replace", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                self.install()
        self.assertEqual(previous, self.installation.state_path.read_bytes())
        self.assertEqual(len(list(self.installation.versions.iterdir())), 1)

    def test_corrupt_zip_member_rejected(self):
        self.install()
        previous = self.installation.state_path.read_bytes()
        damaged = copy.deepcopy(self.manifest)
        damaged["files"]["ShinobiClash.exe"]["sha256"] = "0" * 64
        with self.assertRaises(UpdateError):
            self.install(damaged)
        self.assertEqual(previous, self.installation.state_path.read_bytes())

    def test_download_hash_and_length_checks(self):
        raw = (self.release / "shinobi-clash-windows.zip").read_bytes()
        for payload in (raw, raw[:-1], raw + b"extra", bytes(len(raw))):
            with self.subTest(size=len(payload)), patch("updater.open_url", return_value=io.BytesIO(payload)):
                target = self.root / "download.zip"
                if payload == raw:
                    download(self.manifest["archive"], target, progress, self.cancel)
                    self.assertEqual(target.read_bytes(), raw)
                else:
                    with self.assertRaises(UpdateError):
                        download(self.manifest["archive"], target, progress, self.cancel)

    def test_zip_path_traversal_and_symlinks_rejected(self):
        archive = self.root / "bad.zip"
        for name in ("../escape.exe", "/escape.exe", "C:/escape.exe", "lib/../../escape.exe"):
            with self.subTest(name=name), zipfile.ZipFile(archive, "w") as zip_file:
                zip_file.writestr(name, b"bad")
            # Match the member count so path validation itself rejects it.
            manifest = {"files": {name: {"size": 3, "sha256": "0" * 64}}}
            with self.assertRaises(UpdateError):
                extract_verified(archive, self.root / "staged", manifest, progress, self.cancel)
        with zipfile.ZipFile(archive, "w") as zip_file:
            info = zipfile.ZipInfo("link.exe")
            info.external_attr = 0o120777 << 16
            zip_file.writestr(info, b"bad")
        with self.assertRaises(UpdateError):
            extract_verified(archive, self.root / "staged", {"files": {"link.exe": {"size": 3}}}, progress, self.cancel)

    def test_windows_unsafe_names_rejected(self):
        for name in ("../a", "C:/a", "a\\b", "CON", "nul.exe", "a:b", "a.", "a/", "a//b", "a\x00b", "a/../b"):
            with self.subTest(name=name), self.assertRaises(UpdateError):
                safe_path(name)

    def test_manifest_rejects_untrusted_url_and_case_collisions(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["archive"]["url"] = "https://example.com/game.zip"
        with self.assertRaises(UpdateError):
            validate_manifest(manifest)
        manifest = copy.deepcopy(self.manifest)
        manifest["files"]["SHINOBICLASH.EXE"] = manifest["files"]["ShinobiClash.exe"]
        with self.assertRaises(UpdateError):
            validate_manifest(manifest)

    def test_repair_detects_corruption_and_reinstalls(self):
        self.install()
        self.assertTrue(self.installation.verify(progress, self.cancel))
        self.installation.executable().with_suffix(".pck").write_bytes(b"broken")
        self.assertFalse(self.installation.verify(progress, self.cancel))
        self.install()
        self.assertTrue(self.installation.verify(progress, self.cancel))

    def test_corrupt_local_state_is_treated_as_uninstalled(self):
        self.installation.state_path.write_text('{"directory":"../../outside"}')
        self.assertIsNone(self.installation.current())

    def test_only_one_launcher_instance_can_install(self):
        first = InstanceLock(self.installation.root)
        try:
            with self.assertRaises(UpdateError):
                InstanceLock(self.installation.root)
        finally:
            first.close()
        second = InstanceLock(self.installation.root)
        second.close()

    def test_cleanup_keeps_only_current_and_previous_builds(self):
        for _ in range(3):
            self.install()
        self.assertEqual(len(list(self.installation.versions.iterdir())), 2)

    def test_disk_space_failure_preserves_state(self):
        self.install()
        previous = self.installation.state_path.read_bytes()
        with patch("updater.shutil.disk_usage", return_value=shutil._ntuple_diskusage(100, 100, 0)):
            with self.assertRaises(UpdateError):
                self.install()
        self.assertEqual(previous, self.installation.state_path.read_bytes())


if __name__ == "__main__":
    unittest.main()
