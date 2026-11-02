"""元画像と再現SVGを4分割で比較する。
使い方: python3 compare.py out.svg original.png result_cmp.png
左上=元画像 / 右上=再現 / 左下=赤青オーバーレイ(紫=一致) / 右下=差分"""
import sys
import cairosvg
from PIL import Image, ImageChops, ImageOps

svg, orig_path, out = sys.argv[1:4]
png = svg[:-4] + ".png"
cairosvg.svg2png(url=svg, write_to=png)
orig = Image.open(orig_path).convert("RGB")
mine = Image.open(png).convert("RGB").resize(orig.size)
a = ImageOps.colorize(ImageOps.grayscale(orig), "red", "white")
b = ImageOps.colorize(ImageOps.grayscale(mine), "blue", "white")
W, H = orig.size
c = Image.new("RGB", (W * 2, H * 2), "white")
c.paste(orig, (0, 0)); c.paste(mine, (W, 0)); c.paste(ImageChops.multiply(a, b), (0, H))
c.paste(ImageOps.invert(ImageChops.difference(orig, mine).convert("L")).convert("RGB"), (W, H))
c.resize((W, H)).save(out)
print("saved", out)
