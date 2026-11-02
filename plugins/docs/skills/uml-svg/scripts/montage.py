"""SVG群をPNG化して2列のモンタージュ1枚にまとめる（シリーズの統一感・はみ出し確認用）。
使い方: python3 montage.py out/montage.png a.svg b.svg ..."""
import sys
import cairosvg
from PIL import Image

out, svgs = sys.argv[1], sys.argv[2:]
ims = []
for s in svgs:
    png = s[:-4] + ".png"
    cairosvg.svg2png(url=s, write_to=png)
    ims.append(Image.open(png).convert("RGB"))
w, h = ims[0].size[0] // 2, ims[0].size[1] // 2
rows = (len(ims) + 1) // 2
m = Image.new("RGB", (w * 2, h * rows), "white")
for i, im in enumerate(ims):
    m.paste(im.resize((w, h)), ((i % 2) * w, (i // 2) * h))
m.save(out)
print("saved", out)
