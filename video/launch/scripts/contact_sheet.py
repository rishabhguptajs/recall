"""Contact sheet: uv run --with pillow python scripts/contact_sheet.py <dir> <out.jpg> [cols] [thumb_width]"""
import sys, glob, os
from PIL import Image, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 4
tw = int(sys.argv[4]) if len(sys.argv) > 4 else 640
files = sorted(glob.glob(os.path.join(src, '*.png')) + glob.glob(os.path.join(src, '*.jpg')))
ims = [Image.open(f).convert('RGB') for f in files]
th = round(tw * ims[0].height / ims[0].width)
pad, label = 14, 28
rows = (len(ims) + cols - 1) // cols
sheet = Image.new('RGB', (cols * (tw + pad) + pad, rows * (th + pad + label) + pad), (12, 13, 11))
d = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype('/System/Library/Fonts/SFNSMono.ttf', 18)
except Exception:
    font = ImageFont.load_default()
for i, (f, im) in enumerate(zip(files, ims)):
    x, y = pad + (i % cols) * (tw + pad), pad + (i // cols) * (th + pad + label)
    sheet.paste(im.resize((tw, th), Image.LANCZOS), (x, y))
    name = os.path.splitext(os.path.basename(f))[0]
    frame = name.split('-')[-1]
    try:
        n = int(frame); stamp = f'{name.rsplit("-",1)[0]}  f{n}  {n/60:05.2f}s'
    except ValueError:
        stamp = name
    d.text((x, y + th + 5), stamp, fill=(168, 172, 163), font=font)
sheet.save(out, quality=90)
print(out, sheet.size)
