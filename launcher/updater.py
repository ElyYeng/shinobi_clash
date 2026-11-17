"""Verified game updater. Downloads never replace the active installation in place."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import ssl
import tempfile
import threading
import urllib.error
import urllib.request
import uuid
import zipfile

import certifi

REPOSITORY = "ElyYeng/shinobi_clash"
RELEASES_URL = f"https://github.com/{REPOSITORY}/releases"
MANIFEST_URL = f"{RELEASES_URL}/latest/download/launcher-manifest.json"
LAUNCHER_VERSION = "1.1.1"
MAX_ARCHIVE_SIZE = 2 * 1024**3  # GitHub's per-asset limit
MAX_INSTALL_SIZE = 8 * 1024**3
MAX_MANIFEST_SIZE = 2 * 1024**2
CHUNK = 1024 * 1024


class UpdateError(Exception):
    pass


class Cancelled(UpdateError):
    pass


def check_cancel(cancel):
    if cancel.is_set():
        raise Cancelled("Update cancelled. Your installed game has not changed.")


def safe_path(value):
    """Validate against Windows path rules even when packaging/testing on Linux."""
    if not isinstance(value, str) or not value or "\\" in value:
        raise UpdateError("Invalid file path in update.")
    parts = value.split("/")
    for part in parts:
        if (not part or part in (".", "..") or part[-1:] in (" ", ".")
                or re.search(r'[<>:"|?*\x00-\x1f]', part)
                or re.fullmatch(r"(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?", part)):
            raise UpdateError("Unsafe file path in update.")
    return PurePosixPath(value)


def sha256_file(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(CHUNK), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_manifest(data):
    if not isinstance(data, dict) or data.get("schema") != 1:
        raise UpdateError("This update needs a newer launcher. Download it from Releases.")
    version = data.get("version", "")
    if not isinstance(version, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,99}", version):
        raise UpdateError("Invalid release version.")
    archive = data.get("archive")
    if not isinstance(archive, dict):
        raise UpdateError("Missing game download information.")
    expected_url = f"{RELEASES_URL}/download/{version}/shinobi-clash-windows.zip"
    if archive.get("url") != expected_url:
        raise UpdateError("The update does not point to this game's official release.")
    if not isinstance(archive.get("sha256"), str) or not re.fullmatch(r"[0-9a-f]{64}", archive["sha256"]):
        raise UpdateError("Invalid download checksum.")
    if type(archive.get("size")) is not int or not 0 < archive["size"] <= MAX_ARCHIVE_SIZE:
        raise UpdateError("Invalid game download size.")
    files = data.get("files")
    if not isinstance(files, dict) or not files or len(files) > 20000:
        raise UpdateError("Invalid update file list.")
    seen = set()
    total = 0
    for name, info in files.items():
        safe_path(name)
        if name.casefold() in seen or not isinstance(info, dict):
            raise UpdateError("Duplicate or invalid update file.")
        seen.add(name.casefold())
        if type(info.get("size")) is not int or info["size"] < 0:
            raise UpdateError("Invalid file size.")
        total += info["size"]
        if not isinstance(info.get("sha256"), str) or not re.fullmatch(r"[0-9a-f]{64}", info["sha256"]):
            raise UpdateError("Invalid file checksum.")
    if total > MAX_INSTALL_SIZE:
        raise UpdateError("Update is too large.")
    executable = data.get("executable")
    if not isinstance(executable, str) or executable not in files or not executable.endswith(".exe"):
        raise UpdateError("The game executable is missing from the update.")
    if not isinstance(data.get("notes", ""), str):
        raise UpdateError("Invalid release notes.")
    return data


class HTTPSRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not newurl.startswith("https://"):
            raise UpdateError("Refusing an insecure download redirect.")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


CERTIFICATE_ERROR = (
    "Cannot verify the secure connection to GitHub. "
    "Update Windows and check whether your network or security software "
    "is inspecting HTTPS. Details: %LOCALAPPDATA%\\ShinobiClashLauncher\\launcher.log"
)


def create_tls_context():
    # Retain Windows/system trust (including managed network roots), then add
    # Mozilla's public roots so first installs do not depend on Windows having
    # already downloaded the particular root needed by GitHub or its asset CDN.
    context = ssl.create_default_context()
    context.load_verify_locations(cafile=certifi.where())
    return context


def open_url(url):
    if not url.startswith("https://"):
        raise UpdateError("Updates require HTTPS.")
    request = urllib.request.Request(url, headers={
        "User-Agent": f"ShinobiClashLauncher/{LAUNCHER_VERSION}",
        "Cache-Control": "no-cache",
    })
    opener = urllib.request.build_opener(
        HTTPSRedirectHandler(),
        urllib.request.HTTPSHandler(context=create_tls_context()),
    )
    try:
        return opener.open(request, timeout=30)
    except ssl.SSLCertVerificationError as exc:
        raise UpdateError(CERTIFICATE_ERROR) from exc
    except urllib.error.URLError as exc:
        if isinstance(exc.reason, ssl.SSLCertVerificationError):
            raise UpdateError(CERTIFICATE_ERROR) from exc
        raise


def fetch_manifest():
    with open_url(MANIFEST_URL) as response:
        raw = response.read(MAX_MANIFEST_SIZE + 1)
    if len(raw) > MAX_MANIFEST_SIZE:
        raise UpdateError("Update information is too large.")
    return validate_manifest(json.loads(raw))


def check_update_connection(output_path):
    """Probe the real manifest/CDN from the frozen EXE without installing a game."""
    result = {"launcher_version": LAUNCHER_VERSION, "ok": False}
    try:
        manifest = fetch_manifest()
        result.update(ok=True, release=manifest["version"])
    except Exception as exc:
        result["error"] = str(exc)
        result["cause"] = repr(exc.__cause__ or exc)
    Path(output_path).write_text(json.dumps(result, indent=2), encoding="utf-8")
    return 0 if result["ok"] else 1


def download(archive, destination, progress, cancel):
    digest = hashlib.sha256()
    received = 0
    with open_url(archive["url"]) as response, Path(destination).open("wb") as output:
        while True:
            check_cancel(cancel)
            chunk = response.read(CHUNK)
            if not chunk:
                break
            received += len(chunk)
            if received > archive["size"]:
                raise UpdateError("Download is larger than the published release.")
            output.write(chunk)
            digest.update(chunk)
            progress("Downloading", received, archive["size"])
    if received != archive["size"] or digest.hexdigest() != archive["sha256"]:
        raise UpdateError("Download verification failed. Please retry.")


def extract_verified(archive_path, target, manifest, progress, cancel):
    expected = manifest["files"]
    with zipfile.ZipFile(archive_path) as archive:
        members = archive.infolist()
        # Our packager writes files only, no directory entries or symlinks.
        if len(members) != len(expected):
            raise UpdateError("Unexpected files in game archive.")
        seen = set()
        for index, member in enumerate(members):
            check_cancel(cancel)
            relative = safe_path(member.filename)
            if member.filename in seen or member.filename not in expected:
                raise UpdateError("Unexpected or duplicate file in game archive.")
            seen.add(member.filename)
            mode = member.external_attr >> 16
            if stat.S_ISLNK(mode) or member.is_dir() or member.file_size != expected[member.filename]["size"]:
                raise UpdateError("Invalid file in game archive.")
            path = Path(target).joinpath(*relative.parts)
            path.parent.mkdir(parents=True, exist_ok=True)
            digest = hashlib.sha256()
            written = 0
            with archive.open(member) as source, path.open("xb") as output:
                while True:
                    check_cancel(cancel)
                    chunk = source.read(CHUNK)
                    if not chunk:
                        break
                    written += len(chunk)
                    if written > member.file_size:
                        raise UpdateError("Expanded file exceeds its declared size.")
                    digest.update(chunk)
                    output.write(chunk)
            if written != member.file_size or digest.hexdigest() != expected[member.filename]["sha256"]:
                raise UpdateError(f"Game file verification failed: {member.filename}")
            progress("Installing", index + 1, len(members))


def default_root():
    return Path(os.environ.get("LOCALAPPDATA", Path.home() / ".local" / "share")) / "ShinobiClashLauncher"


class InstanceLock:
    """OS-owned lock automatically releases after a crash (no stale PID files)."""
    def __init__(self, root):
        Path(root).mkdir(parents=True, exist_ok=True)
        self.file = (Path(root) / "launcher.lock").open("a+b")
        self.file.write(b"\0")
        self.file.flush()
        self.file.seek(0)
        try:
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(self.file.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            self.file.close()
            raise UpdateError("Shinobi Clash Launcher is already open.") from exc

    def close(self):
        self.file.close()


class Installation:
    def __init__(self, root=None):
        self.root = Path(root) if root is not None else default_root()
        self.versions = self.root / "versions"
        self.versions.mkdir(parents=True, exist_ok=True)
        self.state_path = self.root / "installed.json"

    def current(self):
        try:
            state = json.loads(self.state_path.read_text(encoding="utf-8"))
            directory = state["directory"]
            if not re.fullmatch(r"install-[0-9a-f]{32}", directory):
                return None
            manifest = validate_manifest(state["manifest"])
            executable = self.versions / directory / manifest["executable"]
            if not executable.is_file():
                return None
            return state
        except (OSError, ValueError, KeyError, TypeError, UpdateError):
            return None

    def executable(self):
        state = self.current()
        if state is None:
            raise UpdateError("Install the game first.")
        return self.versions / state["directory"] / state["manifest"]["executable"]

    def is_current(self, manifest):
        state = self.current()
        return state is not None and state["manifest"]["archive"]["sha256"] == manifest["archive"]["sha256"]

    def verify(self, progress, cancel):
        state = self.current()
        if state is None:
            return False
        files = state["manifest"]["files"]
        for index, (name, info) in enumerate(files.items()):
            check_cancel(cancel)
            path = self.versions / state["directory"] / name
            if not path.is_file() or path.stat().st_size != info["size"] or sha256_file(path) != info["sha256"]:
                return False
            progress("Verifying", index + 1, len(files))
        return True

    def install(self, manifest, progress, cancel, downloader=download):
        validate_manifest(manifest)
        needed = manifest["archive"]["size"] + sum(f["size"] for f in manifest["files"].values()) + 64 * CHUNK
        if shutil.disk_usage(self.root).free < needed:
            raise UpdateError("Not enough free disk space for this update.")
        previous = self.current()
        final = self.versions / f"install-{uuid.uuid4().hex}"
        committed = False
        try:
            with tempfile.TemporaryDirectory(prefix="staging-", dir=self.root) as temp:
                temp = Path(temp)
                archive = temp / "game.zip"
                downloader(manifest["archive"], archive, progress, cancel)
                check_cancel(cancel)
                staged = temp / "game"
                staged.mkdir()
                extract_verified(archive, staged, manifest, progress, cancel)
                check_cancel(cancel)
                # Complete installation first, then atomically select it. The old
                # executable/PCK are never overwritten, even during a power cut.
                staged.rename(final)
                state = {"directory": final.name, "manifest": manifest}
                state_tmp = temp / "installed.json"
                with state_tmp.open("w", encoding="utf-8") as output:
                    json.dump(state, output, indent=2)
                    output.flush()
                    os.fsync(output.fileno())
                os.replace(state_tmp, self.state_path)
                committed = True
        finally:
            if not committed and final.exists():
                shutil.rmtree(final, ignore_errors=True)
        # Keep the immediately previous build; remove only older managed builds.
        keep = {final.name, previous["directory"] if previous else ""}
        for path in self.versions.glob("install-*"):
            if path.name not in keep and re.fullmatch(r"install-[0-9a-f]{32}", path.name):
                shutil.rmtree(path, ignore_errors=True)
