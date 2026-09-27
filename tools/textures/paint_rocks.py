"""地帯ごとの岩肌の模様を描く（128 画素、ふちがつながって、くり返し貼れる）。

使い方:  python tools/textures/paint_rocks.py
書き出す物（assets/textures/）:
  rock_forest.png   樹海：黒っぽく湿った岩に、厚い緑の苔と、白い地衣
  rock_crag.png     岩場：灰色がかった花崗岩。細かな粒と、斜めの層、ひび、橙の地衣
  rock_snow.png     雪山：青みがかった灰色の岩に、霜と、筋になって残る雪
  rock_summit.png   霊峰：黒い玄武岩。紫がかった影と、白く浮かぶ細い筋
  moss_top.png      岩の上面をおおう苔（樹海の岩の上）
  snow_top.png      岩の上面に積もった雪（雪山の岩の上）
  dust_top.png      岩の上面にたまった砂ぼこり（岩場の岩の上）
  ash_top.png       岩の上面にかぶった灰（霊峰の岩の上）
"""
import os

import numpy as np
from PIL import Image

SIZE = 128
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "textures")
rng = np.random.default_rng(20260927)


def value_noise(cells):
    """ふちがつながる、なめらかな模様（0〜1）。cells は 1 辺の格子の数"""
    grid = rng.random((cells, cells))
    t = np.arange(SIZE) / SIZE * cells
    i0 = np.floor(t).astype(int) % cells
    i1 = (i0 + 1) % cells
    f = t - np.floor(t)
    f = f * f * (3 - 2 * f)
    rows = grid[i0][:, i0] * (1 - f)[None, :] + grid[i0][:, i1] * f[None, :]
    rows2 = grid[i1][:, i0] * (1 - f)[None, :] + grid[i1][:, i1] * f[None, :]
    return rows * (1 - f)[:, None] + rows2 * f[:, None]


def fractal(base=4, octaves=4, falloff=0.5):
    total = np.zeros((SIZE, SIZE))
    amp, norm = 1.0, 0.0
    cells = base
    for _ in range(octaves):
        total += value_noise(cells) * amp
        norm += amp
        amp *= falloff
        cells *= 2
    return total / norm


def ramp(values, stops):
    """0〜1 の値を、色の段（[位置, (r,g,b)] の並び）でぬる"""
    out = np.zeros((SIZE, SIZE, 3))
    positions = [s[0] for s in stops]
    for c in range(3):
        out[..., c] = np.interp(values, positions, [s[1][c] for s in stops])
    return out


def cracks(image, count, color, width=1, rng_local=rng):
    """細いひび（ふちを越えて反対側へつながる）"""
    for _ in range(count):
        x, y = rng_local.random() * SIZE, rng_local.random() * SIZE
        angle = rng_local.random() * np.pi * 2
        for _ in range(int(rng_local.integers(10, 40))):
            angle += rng_local.normal(0, 0.45)
            for w in range(width):
                ix, iy = int(x + w) % SIZE, int(y) % SIZE
                image[iy, ix] = image[iy, ix] * 0.35 + np.array(color) * 0.65
            x += np.cos(angle) * 1.3
            y += np.sin(angle) * 1.3


def speckle(image, amount, colors):
    for _ in range(amount):
        x, y = int(rng.random() * SIZE), int(rng.random() * SIZE)
        image[y, x] = colors[int(rng.integers(0, len(colors)))]


def blotches(image, mask, color, strength=1.0):
    image[:] = image * (1 - mask[..., None] * strength) + np.array(color) * mask[..., None] * strength


def save(name, image):
    image = np.clip(image, 0, 1)
    Image.fromarray((image * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def rock_forest():
    base = fractal(4, 5)
    img = ramp(base, [(0.0, (0.1, 0.11, 0.1)), (0.45, (0.22, 0.24, 0.21)), (0.7, (0.33, 0.34, 0.3)), (1.0, (0.42, 0.42, 0.37))])
    cracks(img, 18, (0.04, 0.05, 0.04), 2)
    moss = np.clip((fractal(4, 5) - 0.5) * 3.5, 0, 1) * 0.85
    tone = fractal(8, 3)
    moss_color = ramp(tone, [(0.0, (0.1, 0.17, 0.07)), (0.5, (0.18, 0.27, 0.1)), (1.0, (0.27, 0.36, 0.14))])
    img = img * (1 - moss[..., None]) + moss_color * moss[..., None]
    lichen = np.clip((fractal(8, 3) - 0.74) * 6.0, 0, 1)
    blotches(img, lichen, (0.5, 0.52, 0.44), 0.5)
    speckle(img, 160, [(0.05, 0.06, 0.05), (0.25, 0.35, 0.15)])
    return img


def rock_crag():
    warp = fractal(3, 3)
    y = np.arange(SIZE)[:, None] / SIZE
    x = np.arange(SIZE)[None, :] / SIZE
    strata = 0.5 + 0.5 * np.sin((y * 6 + x * 2 + warp * 1.5) * np.pi * 2)  # 斜めの層（ふちでつながる整数の周期）
    base = fractal(4, 5) * 0.7 + strata * 0.3
    img = ramp(base, [(0.0, (0.3, 0.29, 0.27)), (0.4, (0.5, 0.48, 0.44)), (0.75, (0.63, 0.6, 0.55)), (1.0, (0.74, 0.71, 0.66))])
    speckle(img, 900, [(0.18, 0.17, 0.16), (0.85, 0.83, 0.78), (0.55, 0.45, 0.38)])  # 花崗岩の粒
    cracks(img, 14, (0.12, 0.11, 0.1), 1)
    lichen = np.clip((fractal(6, 3) - 0.72) * 7.0, 0, 1)
    blotches(img, lichen, (0.7, 0.5, 0.25), 0.55)
    return img


def rock_snow():
    base = fractal(4, 5)
    img = ramp(base, [(0.0, (0.2, 0.23, 0.28)), (0.5, (0.36, 0.4, 0.47)), (1.0, (0.52, 0.56, 0.63))])
    cracks(img, 16, (0.1, 0.12, 0.16), 1)
    y = np.arange(SIZE)[:, None] / SIZE
    streak = np.clip((fractal(8, 2) - 0.55) * 6.0, 0, 1) * (0.5 + 0.5 * np.sin(y * np.pi * 2 * 4 + fractal(2, 2) * 6)) ** 2
    frost = np.clip((fractal(6, 3) - 0.6) * 5.0, 0, 1)
    blotches(img, np.maximum(streak, frost * 0.6), (0.88, 0.92, 0.98), 0.9)
    speckle(img, 300, [(0.95, 0.97, 1.0), (0.15, 0.17, 0.22)])
    return img


def rock_summit():
    base = fractal(4, 5)
    img = ramp(base, [(0.0, (0.06, 0.05, 0.07)), (0.5, (0.15, 0.13, 0.17)), (1.0, (0.27, 0.24, 0.29))])
    veins = fractal(3, 4)
    vein = np.clip(1.0 - np.abs(veins - 0.5) * 70.0, 0, 1)  # 模様の等高線に沿った、細い白っぽい筋
    blotches(img, vein * 0.55, (0.46, 0.44, 0.5), 1.0)
    purple = np.clip((fractal(5, 3) - 0.55) * 4.0, 0, 1)
    blotches(img, purple, (0.2, 0.13, 0.24), 0.35)
    cracks(img, 20, (0.02, 0.02, 0.03), 1)
    speckle(img, 200, [(0.5, 0.48, 0.55), (0.02, 0.02, 0.02)])
    return img


def moss_top():
    tone = fractal(6, 4)
    img = ramp(tone, [(0.0, (0.09, 0.16, 0.05)), (0.5, (0.17, 0.28, 0.09)), (1.0, (0.28, 0.4, 0.14))])
    speckle(img, 500, [(0.34, 0.45, 0.18), (0.06, 0.1, 0.04), (0.4, 0.38, 0.16)])
    return img


def snow_top():
    tone = fractal(5, 4)
    img = ramp(tone, [(0.0, (0.78, 0.83, 0.92)), (0.6, (0.9, 0.93, 0.98)), (1.0, (0.98, 0.99, 1.0))])
    speckle(img, 200, [(1.0, 1.0, 1.0), (0.7, 0.76, 0.88)])
    return img


def dust_top():
    tone = fractal(6, 4)
    img = ramp(tone, [(0.0, (0.45, 0.4, 0.33)), (0.6, (0.6, 0.55, 0.46)), (1.0, (0.7, 0.66, 0.57))])
    speckle(img, 700, [(0.3, 0.27, 0.23), (0.8, 0.77, 0.7)])
    return img


def ash_top():
    tone = fractal(6, 4)
    img = ramp(tone, [(0.0, (0.3, 0.29, 0.31)), (0.6, (0.45, 0.44, 0.46)), (1.0, (0.58, 0.57, 0.6))])
    speckle(img, 400, [(0.15, 0.14, 0.16), (0.72, 0.7, 0.74)])
    return img


if __name__ == "__main__":
    for name, painter in [("rock_forest", rock_forest), ("rock_crag", rock_crag), ("rock_snow", rock_snow), ("rock_summit", rock_summit),
                          ("moss_top", moss_top), ("snow_top", snow_top), ("dust_top", dust_top), ("ash_top", ash_top)]:
        save(name, painter())
