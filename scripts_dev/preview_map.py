#!/usr/bin/env python3
"""preview_map.py — render what MapBuilder.gd paints, as a PNG.

Godot is not installed in every environment this repo gets worked on, so this
mirrors MapBuilder's layout constants and composites the real tile art. It is a
verification aid, not a second source of truth: if MapBuilder.gd changes, the
constants below must be updated to match (the script asserts they still parse
out of the .gd file, so drift is caught rather than silently rendered).

    python3 scripts_dev/preview_map.py   ->  scripts_dev/_preview/map.png
"""
import os
import re
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

GRID = (30, 20)
CELL = 64
RIVER_COLUMNS = [10, 19]
RIVER_GAP = (8, 11)
PONDS = [(13, 0, 3, 2), (14, 18, 3, 2), (0, 9, 2, 2), (28, 9, 2, 2)]
ROADS = [
    [(3, 3), (10, 4), (15, 6)],
    [(26, 3), (19, 4), (15, 6)],
    [(3, 16), (10, 15), (15, 13)],
    [(26, 16), (19, 15), (15, 13)],
    [(15, 6), (15, 13)],
    [(3, 3), (3, 16)],
    [(26, 3), (26, 16)],
]
CASTLES = {(3, 3): "P", (26, 3): "R", (3, 16): "B", (26, 16): "Y", (15, 10): "K"}
GOLD = [(6, 9), (23, 10), (15, 2), (15, 17)]
IRON = [(5, 6), (24, 13)]
VILLAGES = [(7, 13), (22, 6), (12, 7), (18, 12), (8, 17), (21, 2)]

GRASS_ORIGIN = (0, 0)
SAND_ORIGIN = (5, 0)


def check_drift() -> None:
    """Fail loudly if MapBuilder.gd's layout no longer matches this mirror."""
    gd = open("scripts/managers/MapBuilder.gd").read()
    cols = [int(x) for x in re.search(r"RIVER_COLUMNS: Array\[int\] = \[([^\]]+)\]", gd).group(1).split(",")]
    gap = re.search(r"RIVER_GAP_ROWS: Vector2i = Vector2i\((\d+), (\d+)\)", gd)
    assert cols == RIVER_COLUMNS, f"river columns drifted: {cols} vs {RIVER_COLUMNS}"
    assert (int(gap.group(1)), int(gap.group(2))) == RIVER_GAP, "river gap drifted"
    ponds_block = re.search(r"const PONDS: Array\[Rect2i\] = \[(.*?)\n\]", gd, re.S).group(1)
    n_ponds = len(re.findall(r"Rect2i\(", ponds_block))
    assert n_ponds == len(PONDS), f"pond count drifted: {n_ponds} vs {len(PONDS)}"


def in_bounds(c):
    return 0 <= c[0] < GRID[0] and 0 <= c[1] < GRID[1]


def build():
    water, roads = set(), set()
    for col in RIVER_COLUMNS:
        for y in range(GRID[1]):
            if RIVER_GAP[0] <= y <= RIVER_GAP[1]:
                continue
            water.add((col, y))
    for px, py, pw, ph in PONDS:
        for x in range(px, px + pw):
            for y in range(py, py + ph):
                if in_bounds((x, y)):
                    water.add((x, y))
    for route in ROADS:
        for i in range(len(route) - 1):
            a, b = route[i], route[i + 1]
            x = a[0]
            while x != b[0]:
                roads.add((x, a[1]))
                x += 1 if b[0] > x else -1
            y = a[1]
            while y != b[1]:
                roads.add((b[0], y))
                y += 1 if b[1] > y else -1
            roads.add(b)
    bridges = {c for c in roads if c in water}
    return water, roads, bridges


def blob_offset(l, r, u, d):
    col = 1 if (l and r) else 0 if r else 2 if l else 3
    row = 1 if (u and d) else 0 if d else 2 if u else 3
    return col, row


def paint_blob(canvas, atlas, origin, cells):
    present = set(cells)
    for c in cells:
        l = (c[0] - 1, c[1]) in present
        r = (c[0] + 1, c[1]) in present
        u = (c[0], c[1] - 1) in present
        d = (c[0], c[1] + 1) in present
        ox, oy = blob_offset(l, r, u, d)
        tx, ty = origin[0] + ox, origin[1] + oy
        tile = atlas.crop((tx * CELL, ty * CELL, (tx + 1) * CELL, (ty + 1) * CELL))
        canvas.alpha_composite(tile, (c[0] * CELL, c[1] * CELL))


def main():
    check_drift()
    water, roads, bridges = build()
    atlas = Image.open("assets/terrain/Ground/Tilemap_Flat.png").convert("RGBA")
    watertex = Image.open("assets/terrain/Water/Water.png").convert("RGBA")
    bridgetex = Image.open("assets/terrain/Bridge/Bridge_All.png").convert("RGBA")

    canvas = Image.new("RGBA", (GRID[0] * CELL, GRID[1] * CELL))
    for x in range(GRID[0]):
        for y in range(GRID[1]):
            canvas.alpha_composite(watertex, (x * CELL, y * CELL))

    land = [(x, y) for x in range(GRID[0]) for y in range(GRID[1])
            if (x, y) not in water or (x, y) in bridges]
    paint_blob(canvas, atlas, GRASS_ORIGIN, land)
    paint_blob(canvas, atlas, SAND_ORIGIN, sorted(roads))

    for c in bridges:
        horiz = (c[0] - 1, c[1]) in roads or (c[0] + 1, c[1]) in roads
        tx, ty = (1, 0) if horiz else (0, 2)
        canvas.alpha_composite(
            bridgetex.crop((tx * CELL, ty * CELL, (tx + 1) * CELL, (ty + 1) * CELL)),
            (c[0] * CELL, c[1] * CELL))

    # Markers for everything the scene places on top.
    from PIL import ImageDraw
    d = ImageDraw.Draw(canvas)
    def mark(cells, color, label):
        for c in cells:
            x, y = c[0] * CELL, c[1] * CELL
            d.rectangle([x + 6, y + 6, x + CELL - 6, y + CELL - 6], outline=color, width=4)
            d.text((x + 22, y + 22), label, fill=color)
    mark(GOLD, (255, 210, 0, 255), "G")
    mark(IRON, (200, 210, 225, 255), "I")
    mark(VILLAGES, (140, 255, 150, 255), "V")
    for c, lab in CASTLES.items():
        x, y = c[0] * CELL, c[1] * CELL
        d.rectangle([x + 2, y + 2, x + CELL - 2, y + CELL - 2], outline=(255, 60, 200, 255), width=5)
        d.text((x + 24, y + 22), lab, fill=(255, 60, 200, 255))

    os.makedirs("scripts_dev/_preview", exist_ok=True)
    canvas.save("scripts_dev/_preview/map.png")

    # Reachability sanity check: flood-fill from the Blue castle over walkable
    # cells and confirm every castle and resource node can actually be reached.
    walkable = {(x, y) for x in range(GRID[0]) for y in range(GRID[1])
                if (x, y) not in water or (x, y) in bridges}
    seen, stack = set(), [(3, 16)]
    while stack:
        c = stack.pop()
        if c in seen or c not in walkable:
            continue
        seen.add(c)
        stack += [(c[0] + 1, c[1]), (c[0] - 1, c[1]), (c[0], c[1] + 1), (c[0], c[1] - 1)]
    targets = list(CASTLES) + GOLD + IRON + VILLAGES
    unreachable = [t for t in targets if t not in seen]
    print(f"map {GRID[0]}x{GRID[1]}: {len(water)} water, {len(bridges)} bridge, "
          f"{len(roads)} road, {len(walkable)} walkable cells")
    print(f"reachable from Blue castle: {len(seen)}/{len(walkable)}")
    if unreachable:
        print(f"!! UNREACHABLE objectives: {unreachable}")
        sys.exit(1)
    print(f"all {len(targets)} objectives reachable")


if __name__ == "__main__":
    main()
