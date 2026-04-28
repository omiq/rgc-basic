#!/usr/bin/env python3
"""Pack a sparse map's used tiles into a compact tileset PNG.

Reads a v1 map JSON (docs/map-format.md), gathers every unique non-zero
tile id referenced from any tile-layer's `data` array (and from the
tileset's `tiles` flag table), and emits:

  - <out_png>   a packed N-cell PNG laid out in `cols` columns
  - <out_json>  the same map with `data` arrays remapped to the new ids
                and `tilesets[0].src` repointed at <out_png>

Old tile ids in the source PNG can be 4-digit (Overworld.png is 1440
cells); after packing they renumber starting at 1, so the IDE map
editor's 8x4 tile picker fits the whole sheet without paging.

Usage:
  scripts/pack_tileset.py <map.json> [--cols 8] [--out-png NAME] [--out-json NAME]

Defaults:
  --cols 8
  --out-png   <stem>_mini.png   (next to <map.json>)
  --out-json  <map.json>        (overwrite in place)
"""

import argparse
import json
import os
import sys
from PIL import Image


def collect_used_ids(doc):
    """Return sorted unique non-zero tile ids referenced by any tile layer."""
    used = set()
    for layer in doc.get("layers", []):
        if layer.get("type") != "tiles":
            continue
        for v in layer.get("data", []):
            if isinstance(v, int) and v > 0:
                used.add(v)
    # Also keep any id that has a `tiles[id]` flag entry, even if the
    # designer hasn't stamped it yet (so solid/kind metadata survives
    # for future paints).
    for ts in doc.get("tilesets", []):
        for k in (ts.get("tiles") or {}).keys():
            try:
                tid = int(k)
                if tid > 0:
                    used.add(tid)
            except ValueError:
                pass
    return sorted(used)


def pack_png(src_png_path, used_ids, cell_w, cell_h, cols, out_png_path):
    """Slice each used tile from src_png and stack into a cols-wide grid."""
    src = Image.open(src_png_path).convert("RGBA")
    sheet_cols = src.width // cell_w
    if sheet_cols <= 0:
        raise SystemExit(f"source sheet width {src.width} < cell_w {cell_w}")
    n = len(used_ids)
    rows = (n + cols - 1) // cols if n > 0 else 1
    out = Image.new("RGBA", (cols * cell_w, rows * cell_h), (0, 0, 0, 0))
    # Tile ids are 1-based in TILEMAP DRAW; row/col in source sheet are
    # zero-based, so subtract 1 before splitting.
    for new_idx, old_id in enumerate(used_ids, start=1):
        zero = old_id - 1
        sx = (zero % sheet_cols) * cell_w
        sy = (zero // sheet_cols) * cell_h
        cell = src.crop((sx, sy, sx + cell_w, sy + cell_h))
        nz = new_idx - 1
        dx = (nz % cols) * cell_w
        dy = (nz // cols) * cell_h
        out.paste(cell, (dx, dy))
    out.save(out_png_path)


def remap_doc(doc, id_map, out_png_basename):
    """Rewrite every layer.data and tilesets[0].tiles entry with new ids."""
    for layer in doc.get("layers", []):
        if layer.get("type") != "tiles":
            continue
        layer["data"] = [id_map.get(v, 0) if v > 0 else 0 for v in layer.get("data", [])]
    for ts in doc.get("tilesets", []):
        old_tiles = ts.get("tiles") or {}
        new_tiles = {}
        for k, meta in old_tiles.items():
            try:
                old_id = int(k)
            except ValueError:
                continue
            if old_id in id_map:
                new_tiles[str(id_map[old_id])] = meta
        if new_tiles:
            ts["tiles"] = new_tiles
        ts["src"] = out_png_basename


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("map_json")
    p.add_argument("--cols", type=int, default=8)
    p.add_argument("--out-png")
    p.add_argument("--out-json")
    args = p.parse_args()

    with open(args.map_json) as f:
        doc = json.load(f)

    if int(doc.get("format", 0)) != 1:
        print("error: unsupported map format", doc.get("format"), file=sys.stderr)
        return 1

    tilesets = doc.get("tilesets") or []
    if not tilesets:
        print("error: map has no tilesets", file=sys.stderr)
        return 1
    ts = tilesets[0]
    cell_w = int(ts.get("cellW", 16))
    cell_h = int(ts.get("cellH", 16))
    src_png = ts.get("src")
    if not src_png:
        print("error: tileset[0].src missing", file=sys.stderr)
        return 1

    map_dir = os.path.dirname(os.path.abspath(args.map_json))
    src_png_path = os.path.join(map_dir, src_png)
    if not os.path.isfile(src_png_path):
        print(f"error: source PNG not found: {src_png_path}", file=sys.stderr)
        return 1

    used = collect_used_ids(doc)
    if not used:
        print("warning: no non-zero tile ids found; producing 1x1 transparent png")

    stem = os.path.splitext(os.path.basename(args.map_json))[0]
    out_png = args.out_png or f"{stem}_mini.png"
    out_json = args.out_json or args.map_json
    out_png_path = os.path.join(map_dir, os.path.basename(out_png))

    pack_png(src_png_path, used, cell_w, cell_h, args.cols, out_png_path)

    id_map = {old: new for new, old in enumerate(used, start=1)}
    remap_doc(doc, id_map, os.path.basename(out_png))

    with open(out_json, "w") as f:
        json.dump(doc, f, indent=2)

    print(f"packed {len(used)} tiles -> {out_png_path}")
    print(f"remapped json    -> {out_json}")
    print("id map:")
    for old in used:
        print(f"  {old} -> {id_map[old]}")


if __name__ == "__main__":
    sys.exit(main() or 0)
