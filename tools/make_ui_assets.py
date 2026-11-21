#!/usr/bin/env python3
"""Generate Theseus' pixel UI font and carved-marble UI textures.

Writes:
  assets/fonts/inscription.fnt/.png        8 px Greek lapidary capitals (lowercase as small caps)
  assets/fonts/inscription_large.fnt/.png  16 px chiselled, gilded headings (doubled from the above)
  assets/art/ui/marble_*.png               slab, button, plaque and meander textures

Run from the project root:  python3 tools/make_ui_assets.py
Requires Pillow. Output is deterministic, so re-running only changes files when this script changes.
"""

from pathlib import Path
import math

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
FONT_DIR = ROOT / "assets" / "fonts"
UI_DIR = ROOT / "assets" / "art" / "ui"

# --------------------------------------------------------------------------------------------
# Glyphs. Each frame is 9 rows: rows 0-6 hold capitals, rows 7-8 hold descenders. A glyph is
# (top_row, rows). Capitals are 7 tall; lowercase letters are 5-tall small capitals, as on a
# stone inscription.
# --------------------------------------------------------------------------------------------

CAPS = {
    "A": "..#.. .#.#. .#.#. #...# ##### #...# #...#",
    "B": "####. #...# #...# ####. #...# #...# ####.",
    "C": ".###. #...# #.... #.... #.... #...# .###.",
    "D": "####. #...# #...# #...# #...# #...# ####.",
    "E": "##### #.... #.... ####. #.... #.... #####",
    "F": "##### #.... #.... ####. #.... #.... #....",
    "G": ".###. #...# #.... #.### #...# #...# .###.",
    "H": "#...# #...# #...# ##### #...# #...# #...#",
    "I": "### .#. .#. .#. .#. .#. ###",
    "J": "..### ...#. ...#. ...#. ...#. #..#. .##..",
    "K": "#...# #..#. #.#.. ##... #.#.. #..#. #...#",
    "L": "#.... #.... #.... #.... #.... #.... #####",
    "M": "#...# ##.## #.#.# #.#.# #...# #...# #...#",
    "N": "#...# #...# ##..# #.#.# #..## #...# #...#",
    "O": ".###. #...# #...# #...# #...# #...# .###.",
    "P": "####. #...# #...# ####. #.... #.... #....",
    "Q": ".###. #...# #...# #...# #.#.# #..#. .##.#",
    "R": "####. #...# #...# ####. #.#.. #..#. #...#",
    "S": ".#### #.... #.... .###. ....# ....# ####.",
    "T": "##### ..#.. ..#.. ..#.. ..#.. ..#.. ..#..",
    "U": "#...# #...# #...# #...# #...# #...# .###.",
    "V": "#...# #...# #...# .#.#. .#.#. .#.#. ..#..",
    "W": "#...# #...# #...# #.#.# #.#.# ##.## #...#",
    "X": "#...# #...# .#.#. ..#.. .#.#. #...# #...#",
    "Y": "#...# #...# .#.#. ..#.. ..#.. ..#.. ..#..",
    "Z": "##### ....# ...#. ..#.. .#... #.... #####",
}

SMALL_CAPS = {
    "a": ".##. #..# #### #..# #..#",
    "b": "###. #..# ###. #..# ###.",
    "c": ".### #... #... #... .###",
    "d": "###. #..# #..# #..# ###.",
    "e": "#### #... ###. #... ####",
    "f": "#### #... ###. #... #...",
    "g": ".### #... #.## #..# .###",
    "h": "#..# #..# #### #..# #..#",
    "i": "### .#. .#. .#. ###",
    "j": "..## ...# ...# #..# .##.",
    "k": "#..# #.#. ##.. #.#. #..#",
    "l": "#... #... #... #... ####",
    "m": "#...# ##.## #.#.# #...# #...#",
    "n": "#..# ##.# #.## #..# #..#",
    "o": ".##. #..# #..# #..# .##.",
    "p": "###. #..# #..# ###. #...",
    "q": ".##. #..# #..# #.#. .#.#",
    "r": "###. #..# ###. #.#. #..#",
    "s": ".### #... .##. ...# ###.",
    "t": "### .#. .#. .#. .#.",
    "u": "#..# #..# #..# #..# .##.",
    "v": "#...# #...# .#.#. .#.#. ..#..",
    "w": "#...# #...# #.#.# ##.## #...#",
    "x": "#..# #..# .##. #..# #..#",
    "y": "#...# .#.#. ..#.. ..#.. ..#..",
    "z": "#### ..#. .#.. #... ####",
}

DIGITS = {
    "0": ".###. #...# #..## #.#.# ##..# #...# .###.",
    "1": ".#. ##. .#. .#. .#. .#. ###",
    "2": ".###. #...# ....# ...#. ..#.. .#... #####",
    "3": "####. ....# ....# .###. ....# ....# ####.",
    "4": "...#. ..##. .#.#. #..#. ##### ...#. ...#.",
    "5": "##### #.... ####. ....# ....# #...# .###.",
    "6": ".###. #.... #.... ####. #...# #...# .###.",
    "7": "##### ....# ...#. ..#.. ..#.. ..#.. ..#..",
    "8": ".###. #...# #...# .###. #...# #...# .###.",
    "9": ".###. #...# #...# .#### ....# ....# .###.",
}

# (top_row, rows) for punctuation and symbols.
SYMBOLS = {
    ".": (6, "#"),
    ",": (6, ".# #."),
    ":": (3, "# . . #"),
    ";": (3, ".# .. .. .# #."),
    "!": (0, "# # # # # . #"),
    "?": (0, ".###. #...# ....# ...#. ..#.. ..... ..#.."),
    "'": (0, "# #"),
    '"': (0, "#.# #.#"),
    "`": (0, "#. .#"),
    "-": (3, "###"),
    "_": (7, "#####"),
    "+": (2, ".#. ### .#."),
    "=": (2, "### ... ###"),
    "*": (1, "#.# .#. #.#"),
    "/": (0, "...# ...# ..#. ..#. .#.. .#.. #..."),
    "\\": (0, "#... #... .#.. .#.. ..#. ..#. ...#"),
    "|": (0, "# # # # # # # # #"),
    "(": (0, ".# #. #. #. #. #. .#"),
    ")": (0, "#. .# .# .# .# .# #."),
    "[": (0, "## #. #. #. #. #. ##"),
    "]": (0, "## .# .# .# .# .# ##"),
    "{": (0, ".## .#. .#. #.. .#. .#. .##"),
    "}": (0, "##. .#. .#. ..# .#. .#. ##."),
    "<": (1, "..# .#. #.. .#. ..#"),
    ">": (1, "#.. .#. ..# .#. #.."),
    "#": (1, ".#.#. ##### .#.#. ##### .#.#."),
    "%": (0, "##..# ##.#. ...#. ..#.. .#... .#.## #..##"),
    "&": (0, ".##.. #..#. #.#.. .#... #.#.# #..#. .##.#"),
    "$": (0, "..#.. .#### #.#.. .###. ..#.# ####. ..#.."),
    "@": (0, ".###. #...# #.### #.#.# #.### #.... .###."),
    "^": (0, ".#. #.#"),
    "~": (2, ".#.# #.#."),
    "—": (3, "#####"),  # em dash
    "–": (3, "####"),  # en dash
    "…": (6, "#.#.#"),  # ellipsis
    "‘": (0, ".# #."),
    "’": (0, "#. .#"),
    "“": (0, ".#.# #.#."),
    "”": (0, "#.#. .#.#"),
}

SPACE_ADVANCE = 3
FRAME_ROWS = 9


def _bitmap(top: int, spec: str) -> list[list[int]]:
    rows = spec.split()
    width = len(rows[0])
    frame = [[0] * width for _ in range(FRAME_ROWS)]
    for y, row in enumerate(rows):
        assert len(row) == width, f"ragged glyph row {row!r} in {spec!r}"
        for x, ch in enumerate(row):
            frame[top + y][x] = 1 if ch == "#" else 0
    return frame


def build_glyphs() -> dict[str, list[list[int]]]:
    glyphs: dict[str, list[list[int]]] = {}
    for ch, spec in CAPS.items():
        glyphs[ch] = _bitmap(0, spec)
    for ch, spec in SMALL_CAPS.items():
        glyphs[ch] = _bitmap(2, spec)
    for ch, spec in DIGITS.items():
        glyphs[ch] = _bitmap(0, spec)
    for ch, (top, spec) in SYMBOLS.items():
        glyphs[ch] = _bitmap(top, spec)
    return glyphs


def double(frame: list[list[int]]) -> list[list[int]]:
    """Doubles a 1-bit glyph, keeping square corners but bridging diagonal-only joints so
    slanted strokes read as one continuous chisel cut instead of touching blocks."""
    h, w = len(frame), len(frame[0])

    def px(x: int, y: int) -> int:
        return frame[y][x] if 0 <= x < w and 0 <= y < h else 0

    out = [[frame[y // 2][x // 2] for x in range(w * 2)] for y in range(h * 2)]
    for y in range(h - 1):
        for x in range(w - 1):
            if px(x, y) and px(x + 1, y + 1) and not px(x + 1, y) and not px(x, y + 1):
                out[y * 2 + 1][x * 2 + 2] = 1
                out[y * 2 + 2][x * 2 + 1] = 1
            if px(x + 1, y) and px(x, y + 1) and not px(x, y) and not px(x + 1, y + 1):
                out[y * 2 + 1][x * 2 + 1] = 1
                out[y * 2 + 2][x * 2 + 2] = 1
    return out


# Gilded V-cut lit from the upper left: the groove's upper/left walls fall into shadow and its
# lower/right walls catch the light.
GOLD_SHADOW = (122, 78, 22, 255)
GOLD_MID = (196, 140, 50, 255)
GOLD_LIGHT = (250, 216, 120, 255)


def chisel(bitmap: list[list[int]]) -> list[list[tuple[int, int, int, int] | None]]:
    h, w = len(bitmap), len(bitmap[0])

    def empty(x: int, y: int) -> int:
        return 0 if (0 <= x < w and 0 <= y < h and bitmap[y][x]) else 1

    out: list[list[tuple[int, int, int, int] | None]] = []
    for y in range(h):
        row: list[tuple[int, int, int, int] | None] = []
        for x in range(w):
            if not bitmap[y][x]:
                row.append(None)
                continue
            lit = empty(x + 1, y) + empty(x, y + 1) - empty(x - 1, y) - empty(x, y - 1)
            row.append(GOLD_LIGHT if lit > 0 else GOLD_SHADOW if lit < 0 else GOLD_MID)
        out.append(row)
    return out


def write_font(name: str, face: str, size: int, glyph_images: dict[str, Image.Image],
               line_height: int, base: int, top_pad: int, space: int, spacing: int) -> None:
    pad = 1
    cols = 16
    chars = sorted(glyph_images, key=ord)
    cell_w = max(img.width for img in glyph_images.values()) + pad
    cell_h = max(img.height for img in glyph_images.values()) + pad
    rows = math.ceil(len(chars) / cols)
    sheet_w = 1 << (cols * cell_w - 1).bit_length()
    sheet_h = 1 << (rows * cell_h - 1).bit_length()
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))

    lines = []
    for i, ch in enumerate(chars):
        img = glyph_images[ch]
        x, y = (i % cols) * cell_w, (i // cols) * cell_h
        sheet.paste(img, (x, y))
        lines.append(
            f"char id={ord(ch)} x={x} y={y} width={img.width} height={img.height} "
            f"xoffset=0 yoffset={top_pad} xadvance={img.width + spacing} page=0 chnl=15"
        )
    lines.append(
        f"char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance={space} page=0 chnl=15"
    )

    png = f"{name}.png"
    header = [
        f'info face="{face}" size={size} bold=0 italic=0 charset="" unicode=1 stretchH=100 '
        f"smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0",
        f"common lineHeight={line_height} base={base} scaleW={sheet_w} scaleH={sheet_h} "
        f"pages=1 packed=0 alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0",
        f'page id=0 file="{png}"',
        f"chars count={len(lines)}",
    ]
    sheet.save(FONT_DIR / png, optimize=True)
    (FONT_DIR / f"{name}.fnt").write_text("\n".join(header + lines) + "\n", encoding="utf-8")


def make_fonts() -> None:
    glyphs = build_glyphs()

    small: dict[str, Image.Image] = {}
    for ch, frame in glyphs.items():
        img = Image.new("RGBA", (len(frame[0]), FRAME_ROWS), (0, 0, 0, 0))
        for y, row in enumerate(frame):
            for x, on in enumerate(row):
                if on:
                    img.putpixel((x, y), (255, 255, 255, 255))
        small[ch] = img
    # 1 px of headroom above the capitals; 11 px lines leave room for a 1 px carved highlight.
    write_font("inscription", "Theseus Inscription", 8, small,
               line_height=11, base=8, top_pad=1, space=SPACE_ADVANCE, spacing=1)

    large: dict[str, Image.Image] = {}
    for ch, frame in glyphs.items():
        shaded = chisel(double(frame))
        img = Image.new("RGBA", (len(shaded[0]), len(shaded)), (0, 0, 0, 0))
        for y, row in enumerate(shaded):
            for x, color in enumerate(row):
                if color:
                    img.putpixel((x, y), color)
        large[ch] = img
    write_font("inscription_large", "Theseus Inscription Large", 16, large,
               line_height=22, base=16, top_pad=2, space=SPACE_ADVANCE * 2, spacing=2)


# --------------------------------------------------------------------------------------------
# Marble. The vein field repeats every 64 px in both axes so slab centres tile without seams;
# veins stay low-contrast so incised text on top remains the strongest mark.
# --------------------------------------------------------------------------------------------

TILE = 64
MARBLE_BASE = (230, 224, 210)
MARBLE_LIGHT = (240, 236, 226)
MARBLE_VEIN = (218, 211, 196)
MARBLE_DEEP_VEIN = (203, 195, 179)
BEVEL_LIGHT = (252, 249, 241)
BEVEL_SHADOW = (163, 154, 135)
OUTLINE = (74, 67, 55)
GOLD_RIM = (200, 150, 46)
GOLD_CARVED = (176, 122, 40)


def _hash(x: int, y: int) -> float:
    n = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 0xFFFF


def marble(x: int, y: int) -> tuple[int, int, int]:
    u, v = (x % TILE) / TILE, (y % TILE) / TILE
    tau = 2 * math.pi
    # abs(sin(pi * k)) repeats whenever k moves by a whole number, so both veins tile.
    warp = 0.45 * math.sin(tau * (2 * u - v)) + 0.25 * math.sin(tau * (u + 3 * v))
    vein = abs(math.sin(math.pi * (u + v) + warp))
    thread = abs(math.sin(math.pi * (u - 2 * v) + 0.6 * math.sin(tau * (u + v))))
    if vein < 0.035:
        return MARBLE_DEEP_VEIN
    if vein < 0.09 or thread < 0.025:
        return MARBLE_VEIN
    if _hash(x % TILE, y % TILE) > 0.975:
        return MARBLE_LIGHT
    return MARBLE_BASE


def slab(size: int, border: int, rim: tuple[int, int, int]) -> Image.Image:
    """Raised marble slab: dark rim, lit top/left bevel, shaded bottom/right bevel."""
    img = Image.new("RGBA", (size, size))
    for y in range(size):
        for x in range(size):
            if x == 0 or y == 0 or x == size - 1 or y == size - 1:
                c = rim
            elif x == size - 2 or y == size - 2:
                c = BEVEL_SHADOW
            elif x == 1 or y == 1:
                c = BEVEL_LIGHT
            else:
                c = marble(x - border, y - border)
            img.putpixel((x, y), (*c, 255))
    return img


def recessed(size: int, rim: tuple[int, int, int], face: tuple[int, int, int]) -> Image.Image:
    """Recessed marble button: shaded top/left inner wall, lit bottom/right inner wall."""
    img = Image.new("RGBA", (size, size))
    for y in range(size):
        for x in range(size):
            if x == 0 or y == 0 or x == size - 1 or y == size - 1:
                c = rim
            elif x == 1 or y == 1:
                c = BEVEL_SHADOW
            elif x == size - 2 or y == size - 2:
                c = BEVEL_LIGHT
            else:
                c = face
            img.putpixel((x, y), (*c, 255))
    return img


def meander(width: int) -> Image.Image:
    """Greek key band, 7 px tall, repeating every 8 px, cut in gold."""
    unit = [
        "########",
        "#.......",
        "#.#####.",
        "#.#...#.",
        "#.#.#.#.",
        "#...#...",
        "#####.##",
    ]
    img = Image.new("RGBA", (width, len(unit)), (0, 0, 0, 0))
    for y, row in enumerate(unit):
        for x in range(width):
            if row[x % len(row)] == "#":
                img.putpixel((x, y), (*GOLD_CARVED, 255))
    return img


def make_ui_textures() -> None:
    slab(TILE + 8, 4, OUTLINE).save(UI_DIR / "marble_slab.png", optimize=True)
    recessed(12, OUTLINE, (222, 215, 199)).save(UI_DIR / "marble_button.png", optimize=True)
    recessed(12, GOLD_RIM, (238, 228, 203)).save(UI_DIR / "marble_button_focus.png", optimize=True)
    recessed(12, GOLD_RIM, (206, 197, 178)).save(UI_DIR / "marble_button_pressed.png", optimize=True)
    meander(96).save(UI_DIR / "meander.png", optimize=True)


if __name__ == "__main__":
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    UI_DIR.mkdir(parents=True, exist_ok=True)
    make_fonts()
    make_ui_textures()
    print("Wrote", FONT_DIR.relative_to(ROOT), "and", UI_DIR.relative_to(ROOT))
