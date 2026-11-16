# Shinobi Clash Launcher

Players download **ShinobiClashLauncher.exe once**. Opening it checks the latest
published GitHub release, downloads and verifies the game, then enables Play.
Further game updates install automatically on startup and every five minutes
while the launcher is idle. Nothing updates during a game session.

## First release

1. Merge the launcher changes into `main`.
2. In GitHub **Actions → Build game and launcher**, wait for the first successful
   run. The workflow builds the Windows game and standalone launcher, then
   publishes a complete GitHub release. GitHub Actions must be enabled.
3. Share this permanent link with players:

   https://github.com/ElyYeng/shinobi_clash/releases/latest/download/ShinobiClashLauncher.exe

The link works **after the first successful release**, not before. Players do
not need Python, Godot, a GitHub account, or administrator access. Keep the EXE
somewhere convenient, such as the Desktop, and use it to start the game.

## Every subsequent update

Push or merge the game changes into `main`. The same workflow exports the game,
runs launcher tests, builds the EXE, creates the archive and checksums, and
publishes a release. Existing launchers pick it up automatically. There is no
need to send another ZIP or tell players which version to install.

Only successful builds publish. Pull requests produce downloadable build
artifacts for testing, but do not publish to players. Use **Run workflow** on
`main` to retry a build without changing game code. Each release gets a unique
`build-<run number>-<attempt>` tag. Do not replace assets on existing release tags.

The workflow pins Godot **4.7.2**, matching the project's 4.7 engine family.
When upgrading the project, update `GODOT_VERSION` in
`.github/workflows/release-game.yml` and test the exported game before merging.
Godot import/export script errors block a release; logs are retained as workflow
artifacts. Other gameplay issues still require playtesting.

## Player behavior and recovery

- **Play** opens the installed game. The launcher stays open; closing its window
  while the game is running minimizes it so updates cannot race with gameplay.
- **Repair** verifies every installed file, downloading a fresh copy if needed.
- **Check for updates** retries immediately. **Cancel** stops an in-progress
  download or installation; a blocked network request can take up to 30 seconds
  to time out. Closing during an update requests cancellation first.
- If the internet is unavailable, an existing installation remains playable.
  Multiplayer may require everyone to update to the same version.
- A SHA-256 check verifies both the downloaded ZIP and every extracted file.
  HTTPS protects release metadata in transit. This is not independent code
  signing; the GitHub repository and release publishers are trusted.
- The active installation changes only after the complete new version is ready.
  Failed downloads, corrupt archives and cancelled installs leave it unchanged.
- Current and previous builds are kept. Older managed builds are cleaned up.
  A hard power loss may leave a `staging-*` folder; it can be removed while the
  launcher is closed. Normal cancellation cleans up automatically.

Game files and launcher logs live in `%LOCALAPPDATA%\ShinobiClashLauncher`.
Godot saves remain in `%APPDATA%\Godot\app_userdata\Shinobi Clash` (the game's
existing `user://` location). The updater never deletes or migrates these saves.
Existing standalone game copies are left alone; the first launcher run downloads
its own copy. Removing `%LOCALAPPDATA%\ShinobiClashLauncher` uninstalls that copy.

Updates currently download the full compressed game, not binary deltas. Allow
space for the download, extracted build, current build and previous build.
GitHub limits each release asset to 2 GiB. This launcher targets **Windows x64**;
macOS and Linux distributables are not included.

## Troubleshooting publishing

- **404 / no release yet:** check the Actions run. All three assets must exist on
  the latest non-draft, non-prerelease release: `ShinobiClashLauncher.exe`,
  `shinobi-clash-windows.zip`, and `launcher-manifest.json`.
- **Build failed:** download `godot-build-logs` from the workflow, fix the first
  import/export error, and push again. A failed build does not replace the
  previous release.
- **Publication failed:** the publishing job needs `contents: write`, declared
  in the workflow. Organization policies may still restrict it.
- **Private repository:** this launcher intentionally contains no credentials.
  Releases must remain publicly downloadable, as this repository currently is.
- **Windows warning:** the launcher is not Authenticode-signed. Windows may show
  an unknown-publisher warning. For wider distribution, sign the EXE with a
  trusted signing certificate in CI before publishing it.
- **Launcher bug:** the game updates itself through the launcher, but the
  launcher EXE does not replace itself. Publish a fixed launcher and ask players
  to download it from the same permanent link. Game releases normally do not
  require this. Future incompatible manifest schemas must use a new schema ID.

## Local development

Use Python 3.12 with Tk support:

```sh
python launcher/main.py
python -m unittest discover -s launcher/tests -v
```

Build the standalone launcher **on Windows**:

```powershell
python -m pip install -r launcher/requirements-build.txt
python -m PyInstaller --noconfirm --clean --onefile --windowed --name ShinobiClashLauncher --distpath release --workpath build/pyinstaller --specpath build launcher/main.py
```

To package a manually exported Windows game, put its EXE, matching PCK, and any
DLLs in `build/game`, then run:

```powershell
python launcher/package_release.py --source build/game --output release --version v0.2.0 --executable ShinobiClash.exe --notes "New missions and fixes."
```

Create a **draft release with exactly that tag**, upload all three assets, then
publish it as the latest release only after uploads finish. The launcher uses
the manifest's immutable, tag-specific ZIP URL so a new release appearing during
a download cannot mix versions. The automatic workflow handles this sequence.

Before sharing a first release, on a clean Windows PC verify first install,
launch, existing saves, update from an older release, Repair, and offline play.
The workflow also runs the updater tests on Windows and a basic bundled-EXE
startup smoke test; this does not substitute for a real gameplay check.
