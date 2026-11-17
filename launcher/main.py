"""Windows launcher UI. Run with Python for development; ship the bundled EXE."""
import logging
from logging.handlers import RotatingFileHandler
import os
import queue
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import font as tkfont, messagebox

from PIL import Image, ImageTk
import urllib.error
import webbrowser

from updater import (
    Cancelled, Installation, InstanceLock, LAUNCHER_VERSION, RELEASES_URL,
    UpdateError, default_root, fetch_manifest, check_update_connection,
)

from art import Art

# Layout is authored on the 1586 x 992 mockup and scaled to the window.
MOCK_W, MOCK_H = 1586, 992
CREAM = "#efe6d2"
WHITE = "#fff5e6"
MUTED = "#aab3c4"
ORANGE = "#ef6a3a"
FOOTER = "#0b0f19"
SPLASH_SECONDS = 8


class CanvasButton:
    """A painted button on the canvas: normal / hover / pressed / disabled images + a label."""

    def __init__(self, app, box, label, command, kind="dark", font_px=22, icon=None):
        self.app, self.command, self.kind = app, command, kind
        self.enabled, self.hover, self.down = True, False, False
        x0, y0, x1, y1 = [app.px(v) for v in box]
        w, h = x1 - x0, y1 - y0
        art = app.art
        if kind == "play":
            self.images = {"normal": art.photo("btn_orange", w, h), "hover": art.photo("btn_orange_hover", w, h),
                           "down": art.photo("btn_orange_pressed", w, h), "off": art.photo("btn_orange", w, h, dim=0.45)}
        else:
            self.images = {"normal": art.photo("btn_dark", w, h), "hover": art.photo("btn_dark_hover", w, h),
                           "down": art.photo("btn_dark_hover", w, h), "off": art.photo("btn_disabled", w, h)}
        c = app.canvas
        self.tag = f"btn{id(self)}"
        self.img = c.create_image(x0, y0, anchor="nw", image=self.images["normal"], tags=(self.tag,))
        tx = (x0 + x1) / 2
        if icon:
            iw = app.px(42)
            self.icon_photo = art.photo(icon, iw, iw * 1.2)
            c.create_image(x0 + w * 0.27, (y0 + y1) / 2, image=self.icon_photo, tags=(self.tag,))
            tx = x0 + w * 0.62
        self.text = c.create_text(tx, (y0 + y1) / 2, text=label, fill=CREAM if kind != "play" else WHITE,
                                  font=app.font(font_px, "bold" if kind == "play" else "normal"), tags=(self.tag,))
        c.tag_bind(self.tag, "<Enter>", lambda e: self._set(hover=True))
        c.tag_bind(self.tag, "<Leave>", lambda e: self._set(hover=False, down=False))
        c.tag_bind(self.tag, "<ButtonPress-1>", lambda e: self._set(down=True))
        c.tag_bind(self.tag, "<ButtonRelease-1>", self._release)

    def _set(self, **kw):
        for k, v in kw.items():
            setattr(self, k, v)
        self._draw()

    def _release(self, _event):
        fire = self.down and self.hover and self.enabled
        self._set(down=False)
        if fire:
            self.command()

    def _draw(self):
        state = "off" if not self.enabled else ("down" if self.down else ("hover" if self.hover else "normal"))
        c = self.app.canvas
        c.itemconfigure(self.img, image=self.images[state])
        c.itemconfigure(self.text, fill=("#7d8494" if not self.enabled else (WHITE if self.kind == "play" else CREAM)))
        c.configure(cursor="hand2" if self.hover and self.enabled else "")

    def configure(self, state=None, text=None):
        if state is not None:
            self.enabled = state == "normal"
        if text is not None:
            self.app.canvas.itemconfigure(self.text, text=text)
        self._draw()


class Launcher(tk.Tk):
    def __init__(self, installation):
        super().__init__()
        self.installation = installation
        self.events = queue.Queue()
        self.cancel = threading.Event()
        self.busy = False
        self.process = None
        self.title("Shinobi Clash Launcher")
        dpi = max(self.winfo_fpixels("1i") / 96.0, 1.0)
        width = int(min(1120 * dpi, self.winfo_screenwidth() * 0.9))
        height = int(width * MOCK_H / MOCK_W)
        self.geometry(f"{width}x{height}")
        self.resizable(False, False)
        self.configure(bg=FOOTER)
        self.protocol("WM_DELETE_WINDOW", self.close)
        self.W, self.H = width, height
        self.s = width / MOCK_W
        self.art = Art(self.s)
        self._window_chrome()

        c = self.canvas = tk.Canvas(self, width=width, height=height, highlightthickness=0, bd=0, bg=FOOTER)
        c.pack(fill="both", expand=True)
        # background splash art (cross-fades between the images in assets/splash)
        self.splashes = self.art.splash_names()
        self.splash_index = 0
        self._bg_pil = self.art.background(self.splashes[0], width, height, self.px(700)) if self.splashes else None
        self._bg_photo = ImageTk.PhotoImage(self._bg_pil) if self._bg_pil else None
        self.bg_item = c.create_image(0, 0, anchor="nw", image=self._bg_photo)
        # brand
        c.create_text(self.px(92), self.px(88), anchor="w", text="YENG STUDIOS", fill=ORANGE, font=self.font(22, "bold"))
        c.create_line(self.px(282), self.px(90), self.px(380), self.px(86), fill=ORANGE, width=max(2, self.px(4)))
        self.logo = self.art.fit_width("logo", self.px(400))
        c.create_image(self.px(52), self.px(108), anchor="nw", image=self.logo)
        c.create_rectangle(self.px(64), self.px(336), self.px(69), self.px(372), fill=ORANGE, outline="")
        c.create_text(self.px(90), self.px(354), anchor="w", text="Your next mission starts here.", fill=CREAM,
                      font=self.font(25, "italic"))
        # news scroll
        self.scroll = self.art.photo("scroll_big", self.px(805), self.px(300))
        c.create_image(self.px(40), self.px(385), anchor="nw", image=self.scroll)
        c.create_text(self.px(123), self.px(440), anchor="w", text="LATEST DISPATCH", fill=CREAM, font=self.font(29, "bold"))
        c.create_line(self.px(123), self.px(466), self.px(400), self.px(466), fill=ORANGE, width=max(2, self.px(4)))
        self.pill = self.art.photo("pill", self.px(262), self.px(48))
        c.create_image(self.px(690), self.px(440), image=self.pill)
        self.version_item = c.create_text(self.px(694), self.px(440), text="Game not installed", fill=CREAM, font=self.font(17))
        self.notes_title = c.create_text(self.px(123), self.px(520), anchor="w", text="", fill=CREAM, font=self.font(31, "bold"))
        self.notes_body = c.create_text(self.px(125), self.px(546), anchor="nw", text="", fill="#d9d4c7",
                                        width=self.px(660), font=self.font(20))
        # bottom bar: status, progress, buttons, PLAY
        self.bar = self.art.photo("bottom_bar", width, self.px(218))
        c.create_image(0, self.px(698), anchor="nw", image=self.bar)
        c.create_rectangle(self.px(94), self.px(729), self.px(101), self.px(758), fill=ORANGE, outline="")
        self.status_item = c.create_text(self.px(118), self.px(743), anchor="w", text="Preparing launcher…",
                                         fill=WHITE, font=self.font(24, "bold"), width=self.px(900))
        self.frame = self.art.photo("progress_frame", self.px(915), self.px(30))
        c.create_image(self.px(95), self.px(775), anchor="nw", image=self.frame)
        self._fill_box = (self.px(105), self.px(781), self.px(1000), self.px(799))
        self._fill_src = self.art.source("progress_fill")
        self._fill_photo = None
        self.fill_item = c.create_image(self._fill_box[0], self._fill_box[1], anchor="nw")
        self.check_button = CanvasButton(self, (95, 828, 345, 878), "Check for updates", self.check)
        self.repair_button = CanvasButton(self, (370, 828, 517, 878), "Repair", lambda: self.check(repair=True))
        self.cancel_button = CanvasButton(self, (543, 828, 690, 878), "Cancel", self.cancel.set)
        self.play_button = CanvasButton(self, (1060, 742, 1510, 868), "PLAY", self.play, kind="play", font_px=58,
                                        icon="icon_play")
        # footer
        c.create_rectangle(0, self.px(916), width, height, fill=FOOTER, outline="")
        c.create_line(0, self.px(916), width, self.px(916), fill="#1f2738")
        c.create_text(self.px(57), self.px(953), anchor="w", fill=MUTED, font=self.font(18),
                      text=f"Launcher {LAUNCHER_VERSION}     |     Automatic updates enabled")
        link = c.create_text(self.px(1530), self.px(953), anchor="e", text="Release history ↗", fill=CREAM,
                             font=self.font(19), tags=("history",))
        c.tag_bind("history", "<Button-1>", lambda e: webbrowser.open(RELEASES_URL))
        c.tag_bind("history", "<Enter>", lambda e: (c.itemconfigure(link, fill=ORANGE), c.configure(cursor="hand2")))
        c.tag_bind("history", "<Leave>", lambda e: (c.itemconfigure(link, fill=CREAM), c.configure(cursor="")))

        self.set_notes("Welcome, shinobi.\nInstall the game once. Get every update automatically. Your saved progress stays with you.")
        self.set_progress(0)
        self.refresh_buttons()
        self.after(100, self.poll)
        self.after(250, self.check)
        self.after(300000, self.periodic_check)
        if len(self.splashes) > 1:
            self.after(SPLASH_SECONDS * 1000, self.next_splash)

    # ---------------------------------------------------------------- drawing helpers
    def px(self, v):
        return int(round(v * self.s))

    def font(self, px, style="normal"):
        weight = "bold" if "bold" in style else "normal"
        slant = "italic" if "italic" in style else "roman"
        return tkfont.Font(family="Segoe UI", size=-max(8, self.px(px)), weight=weight, slant=slant)

    def _window_chrome(self):
        icon = self.art.dir / "icon.ico"
        try:
            if os.name == "nt" and icon.exists():
                self.iconbitmap(default=str(icon))
            else:
                self.iconphoto(True, self.art.keep(ImageTk.PhotoImage(self.art.sized("icon", 64, 64))))
        except tk.TclError:
            pass
        if os.name == "nt":   # dark title bar (Windows 10 2004+ / 11)
            try:
                import ctypes
                self.update_idletasks()
                hwnd = ctypes.windll.user32.GetParent(self.winfo_id())
                on = ctypes.c_int(1)
                for attr in (20, 19):
                    if ctypes.windll.dwmapi.DwmSetWindowAttribute(hwnd, attr, ctypes.byref(on), ctypes.sizeof(on)) == 0:
                        break
            except (AttributeError, OSError):
                pass

    def next_splash(self):
        """Cross-fade to the next splash image."""
        self.splash_index = (self.splash_index + 1) % len(self.splashes)
        target = self.art.background(self.splashes[self.splash_index], self.W, self.H, self.px(700))
        start = self._bg_pil
        steps = 16

        def step(i):
            frame = Image.blend(start, target, i / steps)
            self._bg_photo = ImageTk.PhotoImage(frame)
            self.canvas.itemconfigure(self.bg_item, image=self._bg_photo)
            if i < steps:
                self.after(40, step, i + 1)
            else:
                self._bg_pil = target
                self.after(SPLASH_SECONDS * 1000, self.next_splash)
        step(1)

    def set_status(self, text):
        self.canvas.itemconfigure(self.status_item, text=text)

    def set_progress(self, percent):
        x0, y0, x1, y1 = self._fill_box
        w = int((x1 - x0) * max(0.0, min(percent, 100.0)) / 100.0)
        if w < 2:
            self.canvas.itemconfigure(self.fill_item, image="")
            return
        full = self._fill_src.resize((x1 - x0, y1 - y0), Image.LANCZOS)
        self._fill_photo = ImageTk.PhotoImage(full.crop((0, 0, w, y1 - y0)))
        self.canvas.itemconfigure(self.fill_item, image=self._fill_photo)

    def set_notes(self, notes):
        text = (notes or "").strip()
        title, _, body = text.partition("\n")
        if not body:
            title, body = "What's new", title
        body = " ".join(body.split())
        if len(body) > 260:
            body = body[:257].rsplit(" ", 1)[0] + "…"
        self.canvas.itemconfigure(self.notes_title, text=title[:48])
        self.canvas.itemconfigure(self.notes_body, text=body)

    def refresh_buttons(self):
        running = self.process is not None
        state = self.installation.current()
        self.canvas.itemconfigure(self.version_item,
                                  text=f"Installed: {state['manifest']['version']}" if state else "Game not installed")
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
        self.set_status("Checking for updates…")
        self.set_progress(0)
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
                    self.set_progress(done / max(total, 1) * 100)
                    suffix = f"{done / 1024**2:.1f} / {total / 1024**2:.1f} MB" if phase == "Downloading" else f"{done} / {total} files"
                    self.set_status(f"{phase} — {suffix}")
                elif kind == "notes":
                    self.set_notes(value)
                else:
                    self.busy = False
                    self.set_progress(100 if kind == "done" else 0)
                    if kind == "error" and self.installation.current():
                        value += " You can still play the installed version."
                    self.set_status(value)
                    self.refresh_buttons()
        except queue.Empty:
            pass
        if self.process is not None and self.process.poll() is not None:
            code = self.process.returncode
            self.process = None
            self.set_status("Welcome back, shinobi." if code == 0 else "The game closed unexpectedly. Try Repair if the problem continues.")
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
            self.set_status("Game running. Updates will wait until you finish playing.")
            self.refresh_buttons()
        except (OSError, UpdateError):
            logging.exception("Could not start game")
            self.set_status("Could not start the game. Click Repair and try again.")

    def close(self):
        if self.busy:
            self.cancel.set()
            self.set_status("Cancelling update… You can close the launcher when it finishes.")
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
    if len(sys.argv) == 3 and sys.argv[1] == "--check-update-connection":
        raise SystemExit(check_update_connection(sys.argv[2]))
    main()
