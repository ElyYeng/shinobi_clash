"""Package an exported Windows game and produce the launcher's update manifest."""
import argparse
import json
from pathlib import Path
import zipfile

from updater import MAX_ARCHIVE_SIZE, RELEASES_URL, sha256_file, validate_manifest, safe_path


def package(source, output, version, executable="ShinobiClash.exe", notes=""):
    source, output = Path(source).resolve(), Path(output).resolve()
    if source == output or source in output.parents:
        raise ValueError("Release output must be outside the exported game directory.")
    if not (source / executable).is_file():
        raise ValueError(f"Missing game executable: {executable}")
    if not (source / Path(executable).with_suffix(".pck")).is_file():
        raise ValueError("Missing Godot PCK beside the executable. Export with embed_pck=false.")
    output.mkdir(parents=True, exist_ok=True)
    archive_path = output / "shinobi-clash-windows.zip"
    files = {}
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(source.rglob("*")):
            if path.is_symlink():
                raise ValueError("Symlinks are not allowed in the game export.")
            if not path.is_file():
                continue
            name = path.relative_to(source).as_posix()
            safe_path(name)
            files[name] = {"size": path.stat().st_size, "sha256": sha256_file(path)}
            archive.write(path, name)
    if archive_path.stat().st_size > MAX_ARCHIVE_SIZE:
        raise ValueError("Game archive exceeds GitHub's 2 GiB per-asset limit.")
    manifest = validate_manifest({
        "schema": 1, "version": version, "executable": executable,
        "notes": notes,
        "archive": {"url": f"{RELEASES_URL}/download/{version}/{archive_path.name}",
                    "size": archive_path.stat().st_size, "sha256": sha256_file(archive_path)},
        "files": files,
    })
    (output / "launcher-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="Folder containing the exported EXE, PCK and DLLs")
    parser.add_argument("--output", required=True)
    parser.add_argument("--version", required=True, help="Exact GitHub release tag")
    parser.add_argument("--executable", default="ShinobiClash.exe")
    parser.add_argument("--notes", default="A new Shinobi Clash build is ready. See Release history for details.")
    args = parser.parse_args()
    package(args.source, args.output, args.version, args.executable, args.notes)
    print(f"Packaged {args.version} in {args.output}")
