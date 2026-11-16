"""Windows launcher UI. Run with Python for development; ship the bundled EXE."""
import logging
from logging.handlers import RotatingFileHandler
import os
import queue
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import messagebox, ttk
import urllib.error
import webbrowser

from updater import (
    Cancelled, Installation, InstanceLock, LAUNCHER_VERSION, RELEASES_URL,
    UpdateError, default_root, fetch_manifest,
)

BG = "#0c101b"
PANEL = "#151c2b"
TEXT = "#f0f2f8"
MUTED = "#9aa8bf"
ACCENT = "#ef654e"


class Launcher(tk.Tk):
    def __init__(self, installation):
        super().__init__()
        self.installation = installation
        self.events = queue.Queue()
        self.cancel = threading.Event()
        self.busy = False
        self.process = None
        self.title("Shinobi Clash Launcher")
        self.geometry("860x600")
        self.minsize(760, 580)
        self.configure(bg=BG)
        self.protocol("WM_DELETE_WINDOW", self.close)
        style = ttk.Style(self)
        style.theme_use("clam")
        style.configure("Chakra.Horizontal.TProgressbar", troughcolor=BG,
                        background=ACCENT, bordercolor=BG, lightcolor=ACCENT, darkcolor=ACCENT)

        header = tk.Frame(self, bg=BG)
        header.pack(fill="x", padx=34, pady=(28, 18))
        tk.Label(header, text="YENG STUDIOS  /  WINDOWS", fg=ACCENT, bg=BG,
                 font=("Segoe UI", 10, "bold")).pack(anchor="w")
        tk.Label(header, text="SHINOBI CLASH", fg=TEXT, bg=BG,
                 font=("Segoe UI", 32, "bold")).pack(anchor="w", pady=(8, 0))
        tk.Label(header, text="Your next mission starts here.", fg=MUTED, bg=BG,
                 font=("Segoe UI", 12)).pack(anchor="w")

        panel = tk.Frame(self, bg=PANEL, padx=24, pady=20)
        panel.pack(fill="both", expand=True, padx=34)
        row = tk.Frame(panel, bg=PANEL)
        row.pack(fill="x")
        tk.Label(row, text="LATEST DISPATCH", fg=TEXT, bg=PANEL,
                 font=("Segoe UI", 11, "bold")).pack(side="left")
        self.version = tk.StringVar(value="Game not installed")
        tk.Label(row, textvariable=self.version, fg=MUTED, bg=PANEL,
                 font=("Segoe UI", 10)).pack(side="right")
        self.notes = tk.Text(panel, height=6, bg=PANEL, fg=MUTED, bd=0,
                             wrap="word", font=("Segoe UI", 11), padx=0, pady=16,
                             highlightthickness=0, state="disabled")
        self.notes.pack(fill="both", expand=True)
        self.set_notes("Welcome, shinobi. The launcher installs the game and keeps it up to date automatically. Your saved progress stays with you.")
        self.status = tk.StringVar(value="Preparing launcher…")
        tk.Label(panel, textvariable=self.status, bg=PANEL, fg=TEXT, anchor="w",
                 justify="left", wraplength=680, font=("Segoe UI", 11)).pack(fill="x", pady=(10, 12))
        self.progress = ttk.Progressbar(panel, style="Chakra.Horizontal.TProgressbar", maximum=100)
        self.progress.pack(fill="x")

        actions = tk.Frame(self, bg=BG)
        actions.pack(fill="x", padx=34, pady=(22, 12))
        self.play_button = self.button(actions, "PLAY", self.play, primary=True)
        self.play_button.pack(side="right", ipadx=32, ipady=7)
        self.check_button = self.button(actions, "Check for updates", self.check)
        self.check_button.pack(side="left", ipady=7)
        self.repair_button = self.button(actions, "Repair", lambda: self.check(repair=True))
        self.repair_button.pack(side="left", padx=10, ipady=7)
        self.cancel_button = self.button(actions, "Cancel", self.cancel.set)
        self.cancel_button.pack(side="left", ipady=7)
        footer = tk.Frame(self, bg=BG)
        footer.pack(fill="x", padx=34, pady=(0, 22))
        tk.Label(footer, text=f"Launcher {LAUNCHER_VERSION}  •  Updates checked automatically",
                 bg=BG, fg=MUTED, font=("Segoe UI", 9)).pack(side="left")
        self.button(footer, "Release history ↗", lambda: webbrowser.open(RELEASES_URL)).pack(side="right")
        self.refresh_buttons()
        self.after(100, self.poll)
        self.after(250, self.check)
        self.after(300000, self.periodic_check)

    def button(self, parent, label, command, primary=False):
        return tk.Button(parent, text=label, command=command, bd=0, padx=12,
                         bg=ACCENT if primary else PANEL, fg=TEXT,
                         activebackground="#ff806b" if primary else "#26334b",
                         activeforeground=TEXT, disabledforeground="#64718a",
                         cursor="hand2", font=("Segoe UI", 11, "bold" if primary else "normal"))

    def set_notes(self, notes):
        self.notes.configure(state="normal")
        self.notes.delete("1.0", "end")
        self.notes.insert("1.0", notes[:16000])
        self.notes.configure(state="disabled")

    def refresh_buttons(self):
        running = self.process is not None
        state = self.installation.current()
        self.version.set(f"Installed: {state['manifest']['version']}" if state else "Game not installed")
        self.play_button.configure(state="normal" if state and not self.busy and not running else "disabled",
                                   text="IN GAME" if running else "PLAY")
        self.check_button.configure(state="disabled" if self.busy or running else "normal")
        self.repair_button.configure(state="normal" if state and not self.busy and not running else "disabled")
        self.cancel_button.configure(state="normal" if self.busy else "disabled")

    def report(self, phase, done, total):
        self.events.put(("progress", (phase, done, total)))

    def check(self, repair=False):
        if self.busy or self.process is not None:
            return
        self.busy = True
        self.cancel.clear()
        self.status.set("Checking for updates…")
        self.progress["value"] = 0
        self.refresh_buttons()
        threading.Thread(target=self.update_worker, args=(repair,), daemon=True).start()

    def update_worker(self, repair):
        try:
            manifest = fetch_manifest()
            self.events.put(("notes", manifest.get("notes") or "A fresh mission awaits. See Release history for the full changelog."))
            if self.cancel.is_set():
                raise Cancelled("Update cancelled.")
            current = self.installation.is_current(manifest)
            if current and repair:
                current = self.installation.verify(self.report, self.cancel)
            if not current:
                self.installation.install(manifest, self.report, self.cancel)
            self.events.put(("done", "Up to date. Ready to play."))
        except Cancelled as exc:
            self.events.put(("error", str(exc)))
        except Exception as exc:
            logging.exception("Update failed")
            if isinstance(exc, urllib.error.HTTPError) and exc.code == 404:
                detail = "No game release is available yet. Please try again after the first release is published."
            elif isinstance(exc, UpdateError):
                detail = str(exc)
            else:
                detail = "Could not complete the update. Check your connection and disk space, then retry."
            self.events.put(("error", detail))

    def poll(self):
        try:
            while True:
                kind, value = self.events.get_nowait()
                if kind == "progress":
                    phase, done, total = value
                    self.progress["value"] = done / max(total, 1) * 100
                    suffix = f"{done / 1024**2:.1f} / {total / 1024**2:.1f} MB" if phase == "Downloading" else f"{done} / {total} files"
                    self.status.set(f"{phase} — {suffix}")
                elif kind == "notes":
                    self.set_notes(value)
                else:
                    self.busy = False
                    self.progress["value"] = 100 if kind == "done" else 0
                    if kind == "error" and self.installation.current():
                        value += " You can still play the installed version."
                    self.status.set(value)
                    self.refresh_buttons()
        except queue.Empty:
            pass
        if self.process is not None and self.process.poll() is not None:
            code = self.process.returncode
            self.process = None
            self.status.set("Welcome back, shinobi." if code == 0 else "The game closed unexpectedly. Try Repair if the problem continues.")
            self.refresh_buttons()
            self.after(1000, self.check)
        self.after(100, self.poll)

    def periodic_check(self):
        self.check()
        self.after(300000, self.periodic_check)

    def play(self):
        if self.busy or self.process is not None:
            return
        try:
            executable = self.installation.executable()
            # PyInstaller alters the Windows DLL search path. Do not let Godot
            # inherit the launcher's bundled DLL directory.
            if os.name == "nt" and getattr(sys, "frozen", False):
                import ctypes
                ctypes.windll.kernel32.SetDllDirectoryW(None)
                try:
                    self.process = subprocess.Popen([str(executable)], cwd=str(executable.parent))
                finally:
                    ctypes.windll.kernel32.SetDllDirectoryW(sys._MEIPASS)
            else:
                self.process = subprocess.Popen([str(executable)], cwd=str(executable.parent))
            self.status.set("Game running. Updates will wait until you finish playing.")
            self.refresh_buttons()
        except (OSError, UpdateError):
            logging.exception("Could not start game")
            self.status.set("Could not start the game. Click Repair and try again.")

    def close(self):
        if self.busy:
            self.cancel.set()
            self.status.set("Cancelling update… You can close the launcher when it finishes.")
            return
        if self.process is not None:
            self.iconify()
            return
        self.destroy()


def main():
    root = default_root()
    root.mkdir(parents=True, exist_ok=True)
    handler = RotatingFileHandler(root / "launcher.log", maxBytes=1024**2, backupCount=2, encoding="utf-8")
    logging.basicConfig(level=logging.INFO, handlers=[handler], format="%(asctime)s %(levelname)s %(message)s")
    if os.name == "nt":
        import ctypes
        try:
            ctypes.windll.shcore.SetProcessDpiAwareness(1)
        except (AttributeError, OSError):
            pass
    try:
        lock = InstanceLock(root)
    except UpdateError as exc:
        window = tk.Tk()
        window.withdraw()
        messagebox.showinfo("Shinobi Clash Launcher", str(exc))
        window.destroy()
        return
    try:
        Launcher(Installation(root)).mainloop()
    finally:
        lock.close()


if __name__ == "__main__":
    main()
