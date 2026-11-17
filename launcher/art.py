"""Launcher artwork: loads the painted UI pieces in launcher/assets and scales them for the canvas."""
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageTk


def assets_dir() -> Path:
    # PyInstaller unpacks bundled data next to sys._MEIPASS; in development it's launcher/assets.
    base = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
    return base / "assets"


class Art:
    """Caches every scaled PhotoImage (Tk drops images that nothing references)."""

    def __init__(self, scale: float):
        self.scale = scale
        self.dir = assets_dir()
        self._src = {}
        self._keep = []

    def source(self, name: str) -> Image.Image:
        if name not in self._src:
            self._src[name] = Image.open(self.dir / f"{name}.png").convert("RGBA")
        return self._src[name]

    def keep(self, photo):
        self._keep.append(photo)
        return photo

    def sized(self, name: str, w: int, h: int, dim: float = 1.0) -> Image.Image:
        img = self.source(name).resize((max(1, int(w)), max(1, int(h))), Image.LANCZOS)
        if dim != 1.0:
            rgb, alpha = img.convert("RGB"), img.getchannel("A")
            img = ImageEnhance.Brightness(rgb).enhance(dim).convert("RGBA")
            img.putalpha(alpha)
        return img

    def photo(self, name: str, w: int, h: int, dim: float = 1.0):
        return self.keep(ImageTk.PhotoImage(self.sized(name, w, h, dim)))

    def fit_width(self, name: str, w: int):
        src = self.source(name)
        return self.photo(name, w, w * src.height / src.width)

    def splash_names(self):
        return sorted((self.dir / "splash").glob("*.jpg"))

    def background(self, path: Path, w: int, h: int, bar_top: int) -> Image.Image:
        """A splash image cover-fitted to the window, darkened on the left (behind the text) and
        fading into the dark bottom bar."""
        img = Image.open(path).convert("RGB")
        k = max(w / img.width, h / img.height)
        img = img.resize((int(img.width * k + 1), int(img.height * k + 1)), Image.LANCZOS)
        x0 = (img.width - w) // 2
        img = img.crop((x0, 0, x0 + w, h)).convert("RGBA")
        shade = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(shade)
        left = int(w * 0.58)
        for x in range(left):   # dark on the left, clear by ~58% of the width
            a = int(170 * (1 - x / left) ** 1.6)
            d.line([(x, 0), (x, h)], fill=(10, 14, 24, a))
        fade = int(h * 0.12)
        for y in range(fade):   # darken into the bottom bar
            a = int(200 * (y / fade) ** 2)
            d.line([(0, bar_top - fade + y), (w, bar_top - fade + y)], fill=(12, 17, 28, a))
        return Image.alpha_composite(img, shade)
