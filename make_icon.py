from PIL import Image, ImageDraw
import math

S = 1024
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# Wood gradient background (rounded square)
top = (227, 183, 120)
bot = (160, 110, 60)
bg = Image.new("RGB", (S, S))
bd = ImageDraw.Draw(bg)
for y in range(S):
    t = y / S
    r = int(top[0] + (bot[0] - top[0]) * t)
    g = int(top[1] + (bot[1] - top[1]) * t)
    b = int(top[2] + (bot[2] - top[2]) * t)
    bd.line([(0, y), (S, y)], fill=(r, g, b))
# mask rounded corners
mask = Image.new("L", (S, S), 0)
md = ImageDraw.Draw(mask)
md.rounded_rectangle([0, 0, S, S], radius=180, fill=255)
img.paste(bg, (0, 0), mask)

# wood grain lines
for y in range(60, S, 70):
    d.line([(40, y), (S - 40, y)], fill=(0, 0, 0, 30), width=3)

def plank(cx, cy, length, thick, angle, col):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.rounded_rectangle(
        [cx - length / 2, cy - thick / 2, cx + length / 2, cy + thick / 2],
        radius=thick / 2, fill=col, outline=(0, 0, 0, 90), width=4)
    layer = layer.rotate(math.degrees(angle), center=(cx, cy))
    img.alpha_composite(layer)

# a couple of wooden planks crossing
plank(512, 512, 620, 95, math.radians(28), (185, 132, 79, 255))
plank(512, 512, 560, 95, math.radians(-35), (172, 122, 72, 255))

def screw(cx, cy, r, color):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(45, 45, 45, 255))
    # head
    inner = r - 14
    d.ellipse([cx - inner, cy - inner, cx + inner, cy + inner], fill=color)
    hl = tuple(min(255, c + 70) for c in color[:3]) + (255,)
    d.ellipse([cx - inner * 0.5, cy - inner * 0.55, cx, cy - inner * 0.05], fill=hl)
    # cross slot
    a = int(r * 0.5)
    w = int(r * 0.2)
    d.line([(cx - a, cy), (cx + a, cy)], fill=(0, 0, 0, 150), width=w)
    d.line([(cx, cy - a), (cx, cy + a)], fill=(0, 0, 0, 150), width=w)

screw(512, 512, 150, (46, 196, 182, 255))   # teal center
screw(300, 300, 80, (231, 29, 54, 255))      # red
screw(740, 300, 80, (255, 159, 28, 255))     # orange
screw(740, 740, 80, (72, 149, 239, 255))     # blue
screw(300, 740, 80, (138, 201, 38, 255))     # green

img.save("assets/app_icon.png")
print("icon saved")
