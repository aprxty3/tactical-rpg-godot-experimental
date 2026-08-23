"""spritegen_lib — palette-derivation toolkit for War Perang Tactics.

No image-generation model is available to this project, so Tier-3 art is
DERIVED from its Tier-2 parent sheet rather than drawn from scratch:

  faction  -> hue          (rotate the garment palette onto the faction hue)
  role     -> value / saturation treatment + rim light + a pixel accessory

That keeps every unit unmistakably its faction's color (Advance Wars reads
ownership by color first) while still giving each promotion its own silhouette
cue, instead of five factions sharing one uncolored sprite.

Pure functions only; scripts_dev/generate_sprites.py drives it.
"""
from __future__ import annotations

import colorsys
import numpy as np
from PIL import Image

# Target on-screen height (in world pixels) of a unit's *drawn body*, used to
# bake UnitData.sprite_scale. Source frames range from 16x16 icons to 320x320
# TinySwords sheets, so without this every mage renders microscopic.
TARGET_CHAR_PX = 38.0
# Where the feet land, in world pixels below the unit node's origin (= cell
# center). A 64px cell with the body 38px tall leaves room for the HP bar.
FOOT_OFFSET_PX = 19.0

SAT_FLOOR = 0.16  # below this a pixel is treated as neutral (outline/white/bone)

# Skin is detected on the SOURCE art (before any rotation) and excluded from
# the garment remap — otherwise a Red Legion wizard ends up with a jaundiced
# face and a Blue Kingdom one with a corpse-blue one.
SKIN_HUE = (0.015, 0.115)
SKIN_SAT = (0.18, 0.78)
SKIN_VAL = 0.50


# ---------------------------------------------------------------- colour core

def _to_hsv(rgb: np.ndarray) -> np.ndarray:
    """Vectorised RGB->HSV. rgb float32 in 0..1, shape (...,3)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    nz = d > 1e-6
    rm = nz & (mx == r)
    gm = nz & (mx == g) & ~rm
    bm = nz & (mx == b) & ~rm & ~gm
    h[rm] = ((g - b)[rm] / d[rm]) % 6.0
    h[gm] = ((b - r)[gm] / d[gm]) + 2.0
    h[bm] = ((r - g)[bm] / d[bm]) + 4.0
    h = h / 6.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    return np.stack([h, s, mx], -1)


def _to_rgb(hsv: np.ndarray) -> np.ndarray:
    h, s, v = hsv[..., 0] % 1.0, hsv[..., 1], hsv[..., 2]
    i = np.floor(h * 6.0)
    f = h * 6.0 - i
    p = v * (1.0 - s)
    q = v * (1.0 - f * s)
    t = v * (1.0 - (1.0 - f) * s)
    i = (i % 6).astype(np.int32)
    r = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [v, q, p, p, t, v])
    g = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [t, v, v, q, p, p])
    b = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [p, p, t, v, v, q])
    return np.stack([r, g, b], -1)


def dominant_hue(img: Image.Image) -> float:
    """Pixel-count-weighted hue of the sheet's saturated 'garment' pixels."""
    a = np.asarray(img.convert("RGBA"), dtype=np.float32) / 255.0
    opaque = a[..., 3] > 0.5
    hsv = _to_hsv(a[..., :3])
    mask = opaque & (hsv[..., 1] > 0.30) & (hsv[..., 2] > 0.15)
    if not mask.any():
        return 0.0
    hues = hsv[..., 0][mask]
    # Circular mean so hues straddling the red wrap-around don't average to cyan.
    ang = hues * 2.0 * np.pi
    return float((np.arctan2(np.sin(ang).mean(), np.cos(ang).mean()) / (2.0 * np.pi)) % 1.0)


def recolor(img: Image.Image, *, hue_target: float | None = None,
            hue_nudge: float = 0.0, sat_mul: float = 1.0, val_mul: float = 1.0,
            alpha_mul: float = 1.0) -> Image.Image:
    """Rotate the garment palette onto `hue_target`, then apply role treatment.

    Rotating (rather than flat-setting) the hue preserves the art's internal
    hue relationships — a knight's brown boots stay distinct from his armour.
    Near-neutral pixels (outlines, bone, white beards) are left alone so the
    linework survives.
    """
    a = np.asarray(img.convert("RGBA"), dtype=np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3]
    hsv = _to_hsv(rgb)
    skin = ((hsv[..., 0] >= SKIN_HUE[0]) & (hsv[..., 0] <= SKIN_HUE[1])
            & (hsv[..., 1] >= SKIN_SAT[0]) & (hsv[..., 1] <= SKIN_SAT[1])
            & (hsv[..., 2] >= SKIN_VAL))
    garment = (alpha > 0.5) & (hsv[..., 1] > SAT_FLOOR) & ~skin

    delta = hue_nudge
    if hue_target is not None:
        delta += hue_target - dominant_hue(img)

    h = hsv[..., 0].copy()
    s = hsv[..., 1].copy()
    v = hsv[..., 2].copy()
    h[garment] = (h[garment] + delta) % 1.0
    s[garment] = np.clip(s[garment] * sat_mul, 0.0, 1.0)
    # Value applies to every visible pixel so "darker assassin" darkens the
    # linework too, otherwise the outline detaches from the body.
    vis = alpha > 0.5
    v[vis] = np.clip(v[vis] * val_mul, 0.0, 1.0)

    out = _to_rgb(np.stack([h, s, v], -1))
    out_a = np.clip(alpha * alpha_mul, 0.0, 1.0)
    arr = (np.concatenate([out, out_a[..., None]], -1) * 255.0).round().astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def add_rim(img: Image.Image, color: tuple[float, float, float],
            width: int = 1, alpha: float = 0.85) -> Image.Image:
    """Paint an outward rim light around the silhouette — the elite tell."""
    a = np.asarray(img.convert("RGBA"), dtype=np.float32) / 255.0
    solid = a[..., 3] > 0.35
    grown = solid.copy()
    for _ in range(max(1, width)):
        g = grown
        nxt = g.copy()
        nxt[1:, :] |= g[:-1, :]
        nxt[:-1, :] |= g[1:, :]
        nxt[:, 1:] |= g[:, :-1]
        nxt[:, :-1] |= g[:, 1:]
        grown = nxt
    rim = grown & ~solid
    a[rim, 0], a[rim, 1], a[rim, 2] = color
    a[rim, 3] = alpha
    return Image.fromarray((a * 255.0).round().astype(np.uint8), "RGBA")


# ------------------------------------------------------------------ accessory

def _px(arr, x, y, rgba):
    h, w = arr.shape[:2]
    if 0 <= x < w and 0 <= y < h:
        arr[y, x] = rgba


def draw_accessory(frame: Image.Image, kind: str, bbox, unit: int) -> Image.Image:
    """Stamp a small role marker relative to the frame's content bbox.

    `unit` is the accessory pixel size, scaled from the body height so a halo
    reads the same on a 32px sheet and on a 192px TinySwords frame.
    """
    if not kind or bbox is None:
        return frame
    arr = np.asarray(frame.convert("RGBA")).copy()
    x0, y0, x1, y1 = bbox
    cx = (x0 + x1) // 2
    u = max(1, unit)

    def blob(px, py, rgba, size=1):
        for dx in range(size):
            for dy in range(size):
                _px(arr, px + dx, py + dy, rgba)

    if kind == "halo":  # Paladin / High Priest — thin gold ring above the head
        gold = (255, 216, 92, 255)
        rx, ry = max(2, int(2.6 * u)), max(1, int(1.0 * u))
        yc = y0 - int(1.6 * u)
        for t in range(0, 360, 10):
            ang = np.deg2rad(t)
            blob(int(cx + rx * np.cos(ang)), int(yc + ry * np.sin(ang)), gold, u)
    elif kind == "orb":  # Archmage — arcane orb held at hand height
        ox, oy = x1 - u, y0 + int((y1 - y0) * 0.42)
        blob(ox, oy, (120, 220, 255, 255), max(2, 2 * u))
        blob(ox + u, oy - u, (215, 248, 255, 255), u)
    elif kind == "flame":  # Elementalist — ember licking up from the hand
        ox, oy = x1 - u, y0 + int((y1 - y0) * 0.52)
        for i, c in enumerate([(255, 110, 25, 255), (255, 185, 60, 255), (255, 242, 170, 255)]):
            blob(ox, oy - i * u, c, max(1, u * (3 - i) // 2 + 1))
    elif kind == "glint":  # Assassin / Bone Reaper / Sniper — blood-red eye glint
        ey = y0 + int((y1 - y0) * 0.22)
        blob(cx - int(1.6 * u), ey, (255, 45, 45, 255), u)
        blob(cx + int(1.2 * u), ey, (255, 45, 45, 255), u)
    elif kind == "crown":  # Lich — necrotic crown spikes on the skull
        green = (150, 255, 160, 255)
        for k in (-2, 0, 2):
            blob(cx + int(k * u), y0 - u, green, u)
        blob(cx - int(1.4 * u), y0 + int((y1 - y0) * 0.18), green, u)
        blob(cx + int(1.0 * u), y0 + int((y1 - y0) * 0.18), green, u)
    elif kind == "ghost":  # Wraith / Shadowblade / Nightstalker — trailing wisps
        wisp = (200, 215, 255, 140)
        for i in range(3):
            blob(x0 - int((i + 1) * u), y1 - int((y1 - y0) * (0.10 + 0.13 * i)), wisp, u)
    elif kind == "fang":  # Vampire Lord — gold circlet across the brow
        gold = (255, 216, 92, 255)
        for k in (-2, -1, 0, 1, 2):
            blob(cx + int(k * u), y0 + int((y1 - y0) * 0.10), gold, u)
    return Image.fromarray(arr, "RGBA")


# ------------------------------------------------------------------- geometry

def frames_of(img: Image.Image, hf: int, vf: int):
    fw, fh = img.width // hf, img.height // vf
    for r in range(vf):
        for c in range(hf):
            yield c, r, img.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh))


def union_bbox(img: Image.Image, hf: int, vf: int, row: int | None = None):
    """Bounding box of the drawn body, unioned across frames.

    `row=0` restricts it to the idle row. Sizing off *every* row would let a
    unit with a big attack swing (Warrior, Pawn) shrink its resting pose to
    keep the widest frame in budget — the idle pose is what the player stares
    at, so that is what gets normalised.
    """
    box = None
    for _, r, f in frames_of(img, hf, vf):
        if row is not None and r != row:
            continue
        bb = f.getbbox()
        if bb is None:
            continue
        box = bb if box is None else (min(box[0], bb[0]), min(box[1], bb[1]),
                                      max(box[2], bb[2]), max(box[3], bb[3]))
    return box


def sprite_metrics(img: Image.Image, hf: int, vf: int) -> tuple[float, float, float]:
    """-> (sprite_scale, offset_x, offset_y) for UnitData, in texture pixels.

    Sprite2D draws the frame centred on the node origin, so the offset shifts
    the *body* (not the padded frame) to sit centred and standing on the tile.
    """
    fw, fh = img.width // hf, img.height // vf
    bb = union_bbox(img, hf, vf, row=0) or union_bbox(img, hf, vf) or (0, 0, fw, fh)
    body_h = max(1, bb[3] - bb[1])
    scale = TARGET_CHAR_PX / float(body_h)
    off_x = fw / 2.0 - (bb[0] + bb[2]) / 2.0
    off_y = (FOOT_OFFSET_PX / scale) - (bb[3] - fh / 2.0)
    return round(scale, 4), round(off_x, 2), round(off_y, 2)


def build_sheet(rows: list[Image.Image], hf: int) -> Image.Image:
    """Stack single-row strips into one multi-row sheet (row 0 idle, 1 run)."""
    fw = rows[0].width // hf
    fh = rows[0].height
    out = Image.new("RGBA", (fw * hf, fh * len(rows)), (0, 0, 0, 0))
    for i, row in enumerate(rows):
        out.alpha_composite(row.resize((fw * hf, fh), Image.NEAREST), (0, i * fh))
    return out
