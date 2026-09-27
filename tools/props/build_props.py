"""Blender で建物と置き物のモデルを作る（山小屋・御神木・崩れた石垣・地蔵・石灯籠・祠・鳥居・卒塔婆・遭難者の荷物、
山の上の置き物：慰霊碑・石仏・遭難者の亡骸・道標・ビバーク跡・鎖場・磨崖仏・廃坑の入り口・古い梯子・お札の岩・吊り橋の残骸・草鞋掛け）。

使い方（Blender 4.5 で実行する）:
    blender -b --factory-startup --python tools/props/build_props.py [-- 名前 名前 ... --preview]

先に tools/flora/build_flora.py を実行しておく（杉の葉と樹皮の絵を使う）。
座標は Godot の向き（Y が上、+Z が手前・戸口の側）。原点は地面の真ん中。
崖に取りつける物（鎖場・磨崖仏・お札の岩）は、原点が崖の表面で、+Z が崖の外。
崖のふもとに置く物（廃坑・梯子）は、原点が崖の根元の地面で、+Z が崖から離れる向き。
崖っぷちに置く物（吊り橋の残骸）は、原点が崖の縁で、+Z が谷の側。
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meshkit as mk  # noqa: E402
from meshkit import Canvas  # noqa: E402

T = mk.TEX


# --- 模様 ---

def planks(rng):
    """風雨にさらされた縦板：板ごとに色が違い、すき間は暗く、木目と節がある"""
    c = Canvas(color=(0.4, 0.3, 0.2, 1.0))
    x = 0
    while x < T:
        w = rng.randint(14, 22)
        tone = rng.uniform(0.75, 1.15)
        base = (0.42 * tone, 0.31 * tone, 0.21 * tone)
        c.rect(x, 0, x + w, T, base)
        for _ in range(6):
            gx = x + rng.uniform(2, w - 2)
            c.line(gx, 0, gx + rng.uniform(-2, 2), T, 0.5, (base[0] * 0.75, base[1] * 0.75, base[2] * 0.75), 0.7)
        if rng.random() < 0.5:
            c.ellipse(x + w / 2, rng.uniform(10, T - 10), 2.5, 3.5, 0.0, (0.2, 0.14, 0.09))
        c.rect(x, 0, x + 1, T, (0.08, 0.06, 0.04))
        x += w
    c.noise(rng, 0.08, 2)
    # 雨だれの黒ずみ
    for _ in range(10):
        gx = rng.uniform(0, T)
        c.line(gx, T, gx, T - rng.uniform(20, 60), 1.5, (0.15, 0.12, 0.1), 0.35)
    return c.save("tex_planks")


def tin_roof(rng):
    """錆びたトタン屋根：波板の筋と、赤茶色の錆"""
    c = Canvas(color=(0.45, 0.2, 0.14, 1.0))
    for x in range(T):
        f = 0.8 + 0.25 * math.sin(x / T * math.tau * 8)
        for y in range(T):
            i = (y * T + x) * 4
            c.px[i:i + 3] = [0.45 * f, 0.2 * f, 0.14 * f]
    for _ in range(40):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(3, 10), rng.uniform(2, 6), 0.0,
                  rng.choice([(0.55, 0.28, 0.12), (0.3, 0.14, 0.1), (0.5, 0.45, 0.4)]), 0.6)
    c.noise(rng, 0.1, 2)
    return c.save("tex_tin")


def stone_blocks(rng, name="tex_stone_blocks", mossy=False):
    """石垣：ずらして積んだ石と、暗い目地。苔むしたものは、上の方に緑の苔"""
    c = Canvas(color=(0.18, 0.17, 0.16, 1.0))
    y = 0
    row = 0
    while y < T:
        h = rng.randint(14, 22)
        x = -rng.randint(0, 20) if row % 2 else 0
        while x < T:
            w = rng.randint(18, 34)
            tone = rng.uniform(0.8, 1.15)
            c.rect(x + 1, y + 1, x + w - 1, y + h - 1, (0.5 * tone, 0.49 * tone, 0.46 * tone))
            c.rect(x + 2, y + h - 3, x + w - 2, y + h - 1, (0.6 * tone, 0.59 * tone, 0.56 * tone))  # 上の縁の明るさ
            x += w
        y += h
        row += 1
    c.noise(rng, 0.1, 2)
    if mossy:
        for _ in range(26):
            c.ellipse(rng.uniform(0, T), rng.uniform(T * 0.4, T), rng.uniform(6, 16), rng.uniform(3, 8), 0.0,
                      rng.choice([(0.28, 0.38, 0.16), (0.34, 0.44, 0.18)]), 0.85)
    return c.save(name)


def stone_plain(rng, name="tex_stone", tint=(0.52, 0.51, 0.48)):
    """石仏や灯籠の石：なめらかな灰色に、細かな斑点と、白っぽい地衣"""
    c = Canvas(color=(*tint, 1.0))
    c.noise(rng, 0.07, 1)
    for _ in range(90):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), 1, 1, 0.0, (tint[0] * 0.6, tint[1] * 0.6, tint[2] * 0.6))
    for _ in range(14):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(3, 8), rng.uniform(2, 6), 0.0,
                  rng.choice([(0.7, 0.72, 0.62), (0.36, 0.42, 0.22)]), 0.6)
    return c.save(name)


def rope(rng):
    """しめ縄：黄金色の藁が、ななめにねじれる"""
    c = Canvas(color=(0.78, 0.66, 0.38, 1.0))
    for k in range(-T, T * 2, 9):
        c.line(k, 0, k + T * 0.6, T, 1.6, (0.55, 0.45, 0.24), 0.9)
        c.line(k + 3, 0, k + 3 + T * 0.6, T, 0.8, (0.9, 0.8, 0.5), 0.7)
    c.noise(rng, 0.08, 2)
    return c.save("tex_rope")


def paper(rng):
    """紙垂：白い紙を、稲妻のように折り下げた形（透ける所は描かない）"""
    c = Canvas()
    widths = [(0, 40), (22, 62), (4, 44), (26, 66), (8, 48)]
    step = T // len(widths)
    for k, (a, b) in enumerate(widths):
        c.rect(a + 30, k * step, b + 30, (k + 1) * step - 3, (0.95, 0.95, 0.92))
    return c.save("leaf_paper")


def lacquer(rng):
    """朱塗り：鮮やかな朱に、ところどころ剥げて木地が見える"""
    c = Canvas(color=(0.72, 0.18, 0.1, 1.0))
    c.noise(rng, 0.06, 2)
    for _ in range(18):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(2, 7), rng.uniform(1, 4), rng.uniform(0, 3),
                  (0.35, 0.25, 0.18), 0.8)
    return c.save("tex_lacquer")


def dark_wood(rng):
    """黒ずんだ古い木（鳥居の笠木、祠の屋根）"""
    c = Canvas(color=(0.14, 0.12, 0.11, 1.0))
    for _ in range(40):
        y = rng.uniform(0, T)
        c.line(0, y, T, y + rng.uniform(-2, 2), 0.5, (0.2, 0.17, 0.15), 0.6)
    c.noise(rng, 0.1, 2)
    return c.save("tex_dark_wood")


def red_cloth(rng):
    """地蔵のよだれかけと帽子：赤い布に、しわの影"""
    c = Canvas(color=(0.7, 0.1, 0.08, 1.0))
    for _ in range(12):
        x = rng.uniform(0, T)
        c.line(x, 0, x + rng.uniform(-8, 8), T, 2.0, (0.5, 0.06, 0.05), 0.5)
    c.noise(rng, 0.06, 2)
    return c.save("tex_red_cloth")


def tent_cloth(rng):
    """テントの布：色あせた青に、泥のしみ。破れた所は透ける"""
    c = Canvas(color=(0.3, 0.42, 0.52, 1.0))
    c.noise(rng, 0.08, 3)
    for _ in range(12):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T * 0.5), rng.uniform(4, 12), rng.uniform(2, 6), 0.0, (0.3, 0.26, 0.2), 0.6)
    for _ in range(4):  # 破れ目
        cx, cy = rng.uniform(20, T - 20), rng.uniform(20, T - 20)
        for k in range(30):
            a = k / 30 * math.tau
            r = rng.uniform(3, 11)
            x, y = int(cx + math.cos(a) * r), int(cy + math.sin(a) * r)
            i = ((y % T) * T + (x % T)) * 4
            c.px[i + 3] = 0.0
        c.ellipse(cx, cy, 5, 4, 0.0, (0, 0, 0, 0), 1.0)
        for y in range(int(cy - 5), int(cy + 5)):
            for x in range(int(cx - 6), int(cx + 6)):
                if (x - cx) ** 2 / 36 + (y - cy) ** 2 / 25 < 1:
                    c.px[((y % T) * T + (x % T)) * 4 + 3] = 0.0
    return c.save("leaf_tent")


def pack_cloth(rng):
    """ザックの布：色あせた赤いナイロンに、黒いベルト"""
    c = Canvas(color=(0.62, 0.22, 0.14, 1.0))
    c.noise(rng, 0.08, 3)
    for x in (30, 90):
        c.rect(x, 0, x + 8, T, (0.1, 0.1, 0.1))
    c.rect(0, 60, T, 66, (0.1, 0.1, 0.1))
    return c.save("tex_pack")


def sotoba_wood(rng):
    """卒塔婆：白っぽく色あせた板に、墨の文字（読めない崩し字）"""
    c = Canvas(color=(0.72, 0.66, 0.54, 1.0))
    c.noise(rng, 0.06, 2)
    for col in (T * 0.3, T * 0.62):
        y = 8
        while y < T - 8:
            h = rng.uniform(4, 9)
            for _ in range(3):
                c.line(col + rng.uniform(-5, 5), y + rng.uniform(0, h), col + rng.uniform(-5, 5), y + rng.uniform(0, h), 0.9, (0.08, 0.07, 0.06), 0.9)
            y += h + 3
    return c.save("tex_sotoba")


def engraved(rng):
    """文字を刻んだ石：灰色の石に、縦書きの彫り（溝は暗く、下の縁は明るい）。風化した筋と地衣"""
    c = Canvas(color=(0.5, 0.49, 0.46, 1.0))
    c.noise(rng, 0.07, 1)
    for col in (T * 0.28, T * 0.5, T * 0.72):
        y = 12
        while y < T - 14:
            h = rng.uniform(6, 11)
            for _ in range(rng.randint(3, 5)):
                x0, y0 = col + rng.uniform(-6, 6), y + rng.uniform(0, h)
                x1, y1 = col + rng.uniform(-6, 6), y + rng.uniform(0, h)
                c.line(x0, y0 + 1, x1, y1 + 1, 0.8, (0.68, 0.67, 0.63), 0.8)
                c.line(x0, y0, x1, y1, 0.8, (0.16, 0.15, 0.14), 0.95)
            y += h + 4
    for _ in range(8):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(3, 9), rng.uniform(2, 5), 0.0,
                  rng.choice([(0.7, 0.72, 0.6), (0.34, 0.4, 0.22)]), 0.55)
    return c.save("tex_engraved")


def bone(rng):
    """骨：くすんだ白に、土の染みと細かなひび"""
    c = Canvas(color=(0.78, 0.74, 0.64, 1.0))
    c.noise(rng, 0.06, 2)
    for _ in range(14):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(4, 12), rng.uniform(2, 6), rng.uniform(0, 3), (0.48, 0.4, 0.3), 0.4)
    for _ in range(10):
        x, y = rng.uniform(0, T), rng.uniform(0, T)
        c.line(x, y, x + rng.uniform(-12, 12), y + rng.uniform(-12, 12), 0.4, (0.35, 0.3, 0.24), 0.7)
    return c.save("tex_bone")


def jacket(rng):
    """遭難者の雨具：色あせた橙色のナイロン。泥と黒い染み、裂け目"""
    c = Canvas(color=(0.72, 0.36, 0.12, 1.0))
    c.noise(rng, 0.08, 3)
    for x in (T * 0.5,):
        c.rect(x - 2, 0, x + 2, T, (0.2, 0.2, 0.22))  # ファスナー
    for _ in range(12):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(5, 16), rng.uniform(3, 9), rng.uniform(0, 3),
                  rng.choice([(0.3, 0.24, 0.18), (0.18, 0.12, 0.1)]), 0.55)
    for _ in range(5):
        x, y = rng.uniform(0, T), rng.uniform(0, T)
        c.line(x, y, x + rng.uniform(-14, 14), y + rng.uniform(4, 14), 1.0, (0.1, 0.08, 0.07), 0.9)
    return c.save("tex_jacket")


def rust(rng):
    """錆びた鉄：赤茶色の錆に、黒い地金と、ところどころ明るい錆の粉"""
    c = Canvas(color=(0.36, 0.2, 0.12, 1.0))
    c.noise(rng, 0.12, 2)
    for _ in range(40):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(2, 7), rng.uniform(1, 5), 0.0,
                  rng.choice([(0.55, 0.3, 0.14), (0.16, 0.13, 0.12), (0.62, 0.38, 0.18)]), 0.6)
    return c.save("tex_rust")


def signboard(rng):
    """道標の板：白いペンキの剥げた板に、かすれた墨の字と矢印"""
    c = Canvas(color=(0.66, 0.62, 0.52, 1.0))
    c.noise(rng, 0.07, 2)
    for _ in range(20):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(3, 10), rng.uniform(2, 5), 0.0, (0.4, 0.3, 0.2), 0.7)  # 剥げて木地が見える
    for row in (T * 0.3, T * 0.62):
        x = 14
        while x < T - 30:
            w = rng.uniform(8, 13)
            for _ in range(4):
                c.line(x + rng.uniform(0, w), row + rng.uniform(-8, 8), x + rng.uniform(0, w), row + rng.uniform(-8, 8), 1.0, (0.08, 0.07, 0.06), 0.85)
            x += w + 4
    c.line(T - 26, T * 0.46, T - 8, T * 0.46, 1.5, (0.5, 0.08, 0.06))  # 赤い矢印
    c.line(T - 14, T * 0.38, T - 8, T * 0.46, 1.5, (0.5, 0.08, 0.06))
    c.line(T - 14, T * 0.54, T - 8, T * 0.46, 1.5, (0.5, 0.08, 0.06))
    return c.save("tex_signboard")


def tape(rng):
    """目印の赤いテープ：色あせた赤と、ほつれた端（透ける）"""
    c = Canvas()
    for x in range(34, 94):
        for y in range(T):
            if y > T - 10 and rng.random() < 0.5:
                continue
            fade = 0.75 + 0.25 * math.sin(y * 0.2)
            c.blend(x, y, (0.75 * fade, 0.12 * fade, 0.1 * fade))
    return c.save("leaf_tape")


def ofuda(rng):
    """お札：黄ばんだ細長い紙に、朱の印と、墨で書きなぐった呪文"""
    c = Canvas(color=(0.86, 0.8, 0.62, 1.0))
    c.noise(rng, 0.05, 2)
    c.rect(4, 4, T - 4, 7, (0.6, 0.12, 0.08))
    c.rect(4, T - 7, T - 4, T - 4, (0.6, 0.12, 0.08))
    c.ellipse(T / 2, T * 0.2, 12, 12, 0.0, (0.72, 0.14, 0.1), 0.9)
    y = T * 0.34
    while y < T - 16:
        for _ in range(4):
            c.line(T / 2 + rng.uniform(-18, 18), y + rng.uniform(0, 8), T / 2 + rng.uniform(-18, 18), y + rng.uniform(0, 8), 1.4, (0.06, 0.05, 0.05), 0.95)
        y += 11
    for _ in range(6):  # 雨のしみ
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(4, 12), rng.uniform(4, 12), 0.0, (0.55, 0.48, 0.34), 0.35)
    return c.save("tex_ofuda")


def charcoal(rng):
    """焚き火の跡：黒い炭と灰"""
    c = Canvas(color=(0.08, 0.07, 0.07, 1.0))
    for _ in range(60):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(1, 5), rng.uniform(1, 4), 0.0,
                  rng.choice([(0.35, 0.33, 0.31), (0.02, 0.02, 0.02), (0.2, 0.18, 0.16)]), 0.8)
    return c.save("tex_charcoal")


def void(rng):
    """坑道の奥の暗がり"""
    c = Canvas(color=(0.02, 0.02, 0.025, 1.0))
    c.noise(rng, 0.3, 4)
    return c.save("tex_void")


def dry_flowers(rng):
    """しおれた供花：茶色く枯れた菊と、白い花、細い茎（透ける）"""
    c = Canvas()
    for _ in range(9):
        x, y = rng.uniform(20, T - 20), rng.uniform(10, T * 0.45)
        c.line(x, y, x + rng.uniform(-10, 10), T, 1.0, (0.3, 0.3, 0.14))
        color = rng.choice([(0.55, 0.42, 0.2), (0.75, 0.72, 0.6), (0.5, 0.25, 0.2)])
        for k in range(10):
            a = k / 10 * math.tau
            c.ellipse(x + math.cos(a) * 5, y + math.sin(a) * 5, 3.5, 1.8, a, color)
        c.ellipse(x, y, 3, 3, 0.0, (0.35, 0.28, 0.12))
    return c.save("leaf_flowers")


def straw(rng):
    """草鞋の藁：編み目の筋"""
    c = Canvas(color=(0.7, 0.58, 0.34, 1.0))
    for y in range(0, T, 6):
        c.rect(0, y, T, y + 2, (0.52, 0.42, 0.22))
    for x in range(0, T, 16):
        c.rect(x, 0, x + 2, T, (0.45, 0.36, 0.2))
    c.noise(rng, 0.1, 2)
    return c.save("tex_straw")


def ice(rng):
    """氷：縦に流れる筋（流れたまま凍った跡）、青の濃淡、閉じこめられた白い泡の列、白いひび、ふちの霜"""
    c = Canvas(color=(0.55, 0.75, 0.9, 1.0))
    for x in range(T):
        band = 0.5 + 0.5 * math.sin(x / T * math.tau * 5 + math.sin(x * 0.21) * 1.5)
        for y in range(T):
            i = (y * T + x) * 4
            f = 0.82 + 0.3 * band + 0.08 * math.sin(y * 0.09 + x * 0.05)
            c.px[i:i + 3] = [min(0.5 * f, 1.0), min(0.72 * f, 1.0), min(0.9 * f, 1.0)]
    for _ in range(26):  # 流れ筋（白く濁った筋と、透きとおった濃い筋）
        x = rng.uniform(0, T)
        bright = rng.random() < 0.5
        c.line(x, 0, x + rng.uniform(-6, 6), T, rng.uniform(0.6, 2.2),
               (0.9, 0.96, 1.0) if bright else (0.22, 0.42, 0.62), rng.uniform(0.25, 0.55))
    for _ in range(18):  # 閉じこめられた泡の列
        x, y = rng.uniform(0, T), rng.uniform(0, T)
        for k in range(rng.randint(3, 8)):
            c.ellipse(x + rng.uniform(-2, 2), y + k * rng.uniform(2.5, 4.5), rng.uniform(0.6, 1.6), rng.uniform(0.6, 1.8), 0.0, (0.95, 0.98, 1.0), 0.85)
    for _ in range(7):  # ひび
        x, y = rng.uniform(0, T), rng.uniform(0, T)
        for k in range(rng.randint(3, 6)):
            nx, ny = x + rng.uniform(-14, 14), y + rng.uniform(-14, 14)
            c.line(x, y, nx, ny, 0.5, (0.97, 0.99, 1.0), 0.8)
            x, y = nx, ny
    for _ in range(14):  # 霜
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(4, 12), rng.uniform(2, 6), rng.uniform(0, 3), (0.93, 0.96, 1.0), 0.35)
    c.noise(rng, 0.05, 2)
    return c.save("ice_body")


# --- モデル ---

def build_hut(rng, m):
    """山小屋（避難小屋）：縦板の壁、錆びたトタンの切妻屋根、壊れて傾いた戸、雨戸の窓、薪の山、煙突"""
    s = mk.Model("prop_hut", rng)
    w, d, h = 4.0, 5.0, 2.8
    wall = m["tex_planks"]
    # 土台の石と床
    for x in (-w / 2, 0, w / 2):
        for z in (-d / 2, 0, d / 2):
            s.box((x, 0.1, z), (0.5, 0.35, 0.5), m["tex_stone"], density=1.0, jitter=0.04)
    s.box((0, 0.3, 0), (w, 0.14, d), wall, density=0.6)
    # 壁（戸口と窓の穴をあけて、板を組む）
    s.box((0, 0.3 + h / 2, -d / 2), (w, h, 0.12), wall, density=0.5)
    for side in (-1, 1):
        x = side * w / 2
        s.box((x, 0.3 + h / 2, -d / 2 + 0.9), (0.12, h, 1.8), wall, rot=(0, math.pi / 2, 0), density=0.5)
        s.box((x, 0.3 + h / 2, d / 2 - 0.8), (0.12, h, 1.6), wall, rot=(0, math.pi / 2, 0), density=0.5)
        s.box((x, 0.3 + 0.55, 0.5), (0.12, 1.1, 1.6), wall, rot=(0, math.pi / 2, 0), density=0.5)   # 窓の下
        s.box((x, 0.3 + h - 0.35, 0.5), (0.12, 0.7, 1.6), wall, rot=(0, math.pi / 2, 0), density=0.5)  # 窓の上
        # 半分はずれた雨戸
        s.box((x + side * 0.12, 0.3 + 1.5, 0.05), (0.05, 1.1, 0.8), m["tex_dark_wood"], rot=(0, math.pi / 2 + side * 0.4, 0.15 * side), density=1.0)
    s.box((-w / 2 + 0.7, 0.3 + h / 2, d / 2), (1.4, h, 0.12), wall, density=0.5)
    s.box((w / 2 - 0.7, 0.3 + h / 2, d / 2), (1.4, h, 0.12), wall, density=0.5)
    s.box((0, 0.3 + h - 0.3, d / 2), (1.2, 0.6, 0.12), wall, density=0.5)
    # 妻壁（三角の所は、短い縦板を並べる）
    for zz in (-d / 2, d / 2):
        for k in range(6):
            x = -w / 2 + 0.33 + k * 0.67
            tall = max(0.1, 1.2 * (1 - abs(x) / (w / 2)))
            s.box((x, 0.3 + h + tall / 2, zz), (0.66, tall, 0.1), wall, density=0.5)
    # 柱
    for x in (-w / 2, w / 2):
        for z in (-d / 2, d / 2):
            s.box((x, 0.3 + h / 2, z), (0.18, h, 0.18), m["tex_dark_wood"], density=1.0)
    # 屋根（トタン）と、軒下の垂木
    s.roof((0, 0.3 + h, 0), w + 1.0, d + 1.2, 1.3, m["tex_tin"], thickness=0.08, density=0.35)
    for k in range(6):
        z = -d / 2 - 0.4 + k * (d + 0.8) / 5
        for side in (-1, 1):
            s.box((side * (w / 2 + 0.2), 0.3 + h - 0.05, z), (0.8, 0.08, 0.08), m["tex_dark_wood"], rot=(0, 0, -side * 0.55), density=1.0)
    # 壊れて傾いた戸
    s.box((0.55, 0.3 + 1.0, d / 2 + 0.35), (1.1, 2.0, 0.06), wall, rot=(0.12, 0.9, -0.08), density=0.5)
    # 煙突（ストーブの管）
    s.cylinder((1.1, 0.3 + h + 0.6, -1.2), 1.6, 0.1, 0.1, m["tex_tin"], sides=8, density=1.0)
    s.cylinder((1.1, 0.3 + h + 2.2, -1.2), 0.12, 0.16, 0.16, m["tex_dark_wood"], sides=8)
    # 壁ぎわに積んだ薪と、斧の刺さった台
    for row in range(3):
        for k in range(5 - row):
            s.cylinder((-w / 2 - 0.35, 0.45 + row * 0.2, -1.6 + k * 0.22 + row * 0.11), 0.9, 0.09, 0.09, m["tex_log_end"], sides=6,
                       axis=(1.0, 0.0, 0.0), density=1.0)
    s.cylinder((1.6, 0.0, d / 2 + 1.2), 0.5, 0.28, 0.25, m["tex_log_end"], sides=8)
    s.box((1.6, 0.75, d / 2 + 1.2), (0.06, 0.5, 0.14), m["tex_dark_wood"], rot=(0.3, 0, 0))
    # 入り口の標（名前の消えた板）
    s.box((-1.6, 0.8, d / 2 + 1.0), (0.08, 1.6, 0.08), m["tex_dark_wood"], density=1.0)
    s.box((-1.6, 1.5, d / 2 + 1.04), (0.7, 0.3, 0.04), m["tex_sotoba"], rot=(0, 0, 0.12), density=1.5)
    return s.finish()


def build_shinboku(rng, m):
    """御神木：見上げるほどの杉の巨木。張り出した根、しめ縄と紙垂、足場になる太い枝、幾重にも重なる葉"""
    s = mk.Model("prop_shinboku", rng)
    height = 24.0
    bark = m["bark_cedar"]
    trunk = [Vector((rng.uniform(-0.2, 0.2), y, rng.uniform(-0.2, 0.2))) for y in (0, 1.5, 4, 8, 12, 16, 20, height)]
    s.tube(trunk, [1.7, 1.5, 1.4, 1.25, 1.05, 0.85, 0.6, 0.25], bark, sides=14, density=0.3, wobble=0.05)
    # 根：幹から外へ張り出して、地面にもぐる
    for k in range(7):
        a = k / 7 * math.tau + rng.uniform(-0.2, 0.2)
        out = Vector((math.cos(a), 0, math.sin(a)))
        s.tube([out * 0.8 + Vector((0, 1.6, 0)), out * 1.9 + Vector((0, 0.7, 0)), out * 3.0 + Vector((0, 0.15, 0)), out * 3.8 + Vector((0, -0.4, 0))],
               [0.55, 0.45, 0.28, 0.1], bark, sides=7, density=0.4)
    # しめ縄（太い縄と、細い縄をねじって巻く）と紙垂
    ring = []
    thin = []
    for k in range(25):
        a = k / 24 * math.tau
        ring.append(Vector((math.cos(a) * 1.72, 2.7 + math.sin(a * 3) * 0.05, math.sin(a) * 1.72)))
        thin.append(Vector((math.cos(a) * 1.8, 2.55 + math.sin(a * 6) * 0.08, math.sin(a) * 1.8)))
    s.tube(ring, [0.2] * len(ring), m["tex_rope"], sides=8, density=2.0)
    s.tube(thin, [0.08] * len(thin), m["tex_rope"], sides=6, density=3.0)
    for k in range(5):
        a = k / 5 * math.tau + 0.3
        out = Vector((math.cos(a), 0, math.sin(a)))
        s.card(out * 1.95 + Vector((0, 2.0, 0)), 0.35, 0.7, m["leaf_paper"], out, (0, -1, 0))
    # 太い枝（上に乗れる）と、枝先の葉
    golden = 2.39996
    angle = rng.uniform(0, math.tau)
    for k in range(13):
        angle += golden
        y = 6.5 + k * 1.3
        out = Vector((math.cos(angle), 0.0, math.sin(angle)))
        length = 5.5 - k * 0.28
        start = Vector((0, y, 0)) + out * 0.9
        mid = start + out * length * 0.55 + Vector((0, 0.5, 0))
        tip = start + out * length + Vector((0, 0.2 - k * 0.05, 0))
        s.tube([start, mid, tip], [0.42 - k * 0.02, 0.28, 0.12], bark, sides=7, density=0.4)
        # 枝に沿って、こんもりと葉を重ねる
        for _ in range(30):
            along = start.lerp(tip, rng.uniform(0.35, 1.1))
            base = along + Vector((rng.uniform(-1.6, 1.6), rng.uniform(-0.5, 1.0), rng.uniform(-1.6, 1.6)))
            facing = Vector((rng.uniform(-1, 1), 0, rng.uniform(-1, 1))).normalized()
            size = rng.uniform(2.0, 3.2)
            s.card(base - Vector((0, size * 0.45, 0)), size * 1.2, size, m["leaf_cedar"], facing, (facing.x * 0.5, 1.0, facing.z * 0.5))
    # てっぺんの葉
    for _ in range(40):
        base = Vector((rng.uniform(-2.2, 2.2), height - rng.uniform(0, 5), rng.uniform(-2.2, 2.2)))
        facing = Vector((rng.uniform(-1, 1), 0, rng.uniform(-1, 1))).normalized()
        s.card(base, 2.6, 2.8, m["leaf_cedar"], facing, (0, 1, 0))
    return s.finish()


def build_ruins(rng, m, name):
    """崩れた石垣：高さのばらばらな石積みの壁が、ところどころ崩れて途切れる。落ちた石と、苔と、壁を這う蔦"""
    s = mk.Model(name, rng)
    x = -7.0
    while x < 7.0:
        length = rng.uniform(1.8, 3.6)
        height = rng.uniform(1.2, 5.0)
        mossy = rng.random() < 0.5
        mat = m["tex_stone_mossy"] if mossy else m["tex_stone_blocks"]
        z = rng.uniform(-0.3, 0.3)
        # 下から石を積む（上の段ほど小さく、少しずつずれる）
        y = 0.0
        width = 1.1
        while y < height:
            step = min(rng.uniform(0.5, 0.9), height - y)
            s.box((x + length / 2 + rng.uniform(-0.08, 0.08), y + step / 2, z), (length, step, width), mat, rot=(0, rng.uniform(-0.05, 0.05), 0),
                  density=0.45, jitter=0.05)
            y += step
            width *= 0.94
        if rng.random() < 0.6:  # 壁を這う蔦
            for _ in range(3):
                s.card((x + rng.uniform(0.2, length - 0.2), height - 0.2, z + 0.58), 0.9, -rng.uniform(1.5, 3.0), m["leaf_ivy"], (0, 0, 1))
        x += length + rng.uniform(0.2, 1.8)
    for _ in range(rng.randint(5, 9)):  # 崩れ落ちた石
        size = rng.uniform(0.5, 1.2)
        s.box((rng.uniform(-7, 7), size * 0.35, rng.uniform(-3, 3)), (size, size * 0.8, size * 0.9), m["tex_stone_blocks"],
              rot=(rng.uniform(0, 0.5), rng.uniform(0, 3), rng.uniform(0, 0.5)), density=0.45, jitter=0.06)
    return s.finish()


def build_jizo(rng, m):
    """お地蔵さま：丸い石の体に、赤いよだれかけと帽子。台石と、供えられた湯のみ"""
    s = mk.Model("prop_jizo", rng)
    stone = m["tex_stone_statue"]
    s.box((0, 0.12, 0), (0.62, 0.24, 0.55), m["tex_stone"], density=1.2, jitter=0.02)
    s.tube([(0, 0.24, 0), (0, 0.36, 0), (0, 0.55, 0), (0, 0.72, 0), (0, 0.78, 0)], [0.24, 0.25, 0.22, 0.17, 0.12], stone, sides=12, density=1.0)
    # 頭（丸い石）と顔の彫り
    head = [(0, 0.76, 0), (0, 0.8, 0), (0, 0.88, 0), (0, 0.96, 0), (0, 1.0, 0)]
    s.tube(head, [0.08, 0.13, 0.15, 0.12, 0.02], stone, sides=12, density=1.0)
    s.box((0, 0.9, 0.145), (0.1, 0.012, 0.02), m["tex_dark_wood"])  # 閉じた目
    # 合わせた手
    s.box((0, 0.58, 0.2), (0.12, 0.16, 0.08), stone, rot=(0.3, 0, 0), density=1.5)
    # よだれかけ（胸から垂れる赤い布）と、毛糸の帽子
    s.box((0, 0.62, 0.17), (0.34, 0.26, 0.04), m["tex_red_cloth"], rot=(0.25, 0, 0), density=2.0)
    s.tube([(0, 0.93, 0), (0, 0.99, 0), (0, 1.06, 0)], [0.155, 0.14, 0.05], m["tex_red_cloth"], sides=12, density=2.0)
    # 供えた湯のみ
    s.cylinder((0.2, 0.24, 0.25), 0.07, 0.04, 0.05, m["tex_stone"], sides=8)
    return s.finish()


def build_lantern(rng, m):
    """石灯籠：六角の台と竿、火袋、反った笠、宝珠。苔がつく"""
    s = mk.Model("prop_lantern", rng)
    stone = m["tex_stone"]
    s.cylinder((0, 0, 0), 0.22, 0.4, 0.36, stone, sides=6)
    s.cylinder((0, 0.22, 0), 0.8, 0.11, 0.1, stone, sides=6)
    s.cylinder((0, 1.02, 0), 0.12, 0.3, 0.3, stone, sides=6)
    s.box((0, 1.34, 0), (0.42, 0.4, 0.42), stone, density=1.2)
    for side in range(4):
        a = side * math.pi / 2
        out = Vector((math.sin(a), 0, math.cos(a)))
        s.box(tuple(Vector((0, 1.34, 0)) + out * 0.215), (0.2, 0.2, 0.01), m["tex_dark_wood"], rot=(0, a, 0))  # 火袋の窓
    s.cylinder((0, 1.54, 0), 0.22, 0.55, 0.12, stone, sides=6)
    s.cylinder((0, 1.76, 0), 0.1, 0.12, 0.05, stone, sides=6)
    s.tube([(0, 1.84, 0), (0, 1.9, 0), (0, 1.97, 0), (0, 2.02, 0)], [0.06, 0.09, 0.07, 0.0], stone, sides=8)
    return s.finish()


def build_hokora(rng, m):
    """祠：石の台の上の、観音開きの小さな木の社。反った屋根としめ縄"""
    s = mk.Model("prop_hokora", rng)
    s.box((0, 0.3, 0), (1.3, 0.6, 1.1), m["tex_stone_blocks"], density=0.8, jitter=0.02)
    s.box((0, 0.95, 0), (0.8, 0.7, 0.65), m["tex_planks"], density=1.0)
    s.box((-0.19, 0.95, 0.33), (0.36, 0.6, 0.03), m["tex_dark_wood"], rot=(0, -0.3, 0))  # 少し開いた扉
    s.box((0.2, 0.95, 0.33), (0.36, 0.6, 0.03), m["tex_dark_wood"])
    s.roof((0, 1.3, 0), 1.25, 1.1, 0.4, m["tex_dark_wood"], thickness=0.07, density=1.0)
    s.box((0, 1.72, 0), (0.12, 0.08, 1.2), m["tex_dark_wood"])
    rope_points = [(x, 1.25 + 0.04 * math.cos(x * 5), 0.36) for x in [-0.45 + k * 0.1 for k in range(10)]]
    s.tube(rope_points, [0.035] * len(rope_points), m["tex_rope"], sides=6, density=3.0)
    for x in (-0.25, 0.0, 0.25):
        s.card((x, 1.22, 0.37), 0.1, -0.22, m["leaf_paper"], (0, 0, 1))
    return s.finish()


def build_torii(rng, m):
    """鳥居：朱塗りの二本の柱、黒い笠木、貫、額束。根元は黒く、しめ縄と紙垂"""
    s = mk.Model("prop_torii", rng)
    red = m["tex_lacquer"]
    for x in (-1.3, 1.3):
        s.cylinder((x, 0, 0), 0.5, 0.2, 0.2, m["tex_dark_wood"], sides=10)
        s.cylinder((x, 0.5, 0), 2.9, 0.19, 0.17, red, sides=10)
        s.cylinder((x, 0, 0), 0.25, 0.3, 0.3, m["tex_stone"], sides=10)
    s.box((0, 2.75, 0), (3.4, 0.2, 0.22), red, density=0.8)  # 貫
    s.box((0, 3.2, 0), (3.6, 0.24, 0.3), red, density=0.8)    # 島木
    # 笠木（両端が反り上がる黒い梁）：まん中のまっすぐな梁と、少し上へ反った両端
    s.box((0, 3.42, 0), (2.9, 0.2, 0.42), m["tex_dark_wood"], density=0.8)
    for side in (-1, 1):
        s.box((side * 1.78, 3.49, 0), (0.95, 0.2, 0.42), m["tex_dark_wood"], rot=(0, 0, side * 0.16), density=0.8)
    s.box((0, 3.0, 0.02), (0.3, 0.4, 0.14), m["tex_dark_wood"])  # 額束
    rope_points = [(x, 2.45 - 0.12 * math.cos(x / 1.3 * math.pi / 2), 0.0) for x in [-1.3 + k * 0.26 for k in range(11)]]
    s.tube(rope_points, [0.07] * len(rope_points), m["tex_rope"], sides=6, density=2.0)
    for x in (-0.65, 0.0, 0.65):
        s.card((x, 2.4, 0.05), 0.16, -0.36, m["leaf_paper"], (0, 0, 1))
    return s.finish()


def build_sotoba(rng, m):
    """卒塔婆：先を刻んだ細長い板が、何本も傾いて立つ。石の台と、欠けた湯のみ"""
    s = mk.Model("prop_sotoba", rng)
    s.box((0, 0.15, 0.25), (1.6, 0.3, 0.4), m["tex_stone_blocks"], density=1.0, jitter=0.03)
    for k in range(7):
        x = -0.9 + k * 0.3
        height = rng.uniform(1.3, 1.9)
        rot = (rng.uniform(-0.1, 0.1), rng.uniform(-0.15, 0.15), rng.uniform(-0.12, 0.12))
        s.box((x, height / 2, 0), (0.12, height, 0.02), m["tex_sotoba"], rot=rot, density=1.2)
        for notch in range(3):  # 五輪塔の形に刻んだ頭
            s.box((x, height + 0.03 - notch * 0.09, 0), (0.13 - notch * 0.02, 0.05, 0.022), m["tex_sotoba"], rot=rot)
    s.cylinder((0.5, 0.3, 0.3), 0.06, 0.05, 0.045, m["tex_stone"], sides=8)
    return s.finish()


def build_backpack(rng, m):
    """遭難者のザック：口の開いた古いザック、こぼれた寝袋とコッヘル、切れたロープ"""
    s = mk.Model("prop_backpack", rng)
    s.box((0, 0.3, 0), (0.45, 0.6, 0.3), m["tex_pack"], rot=(0.35, 0.4, 0.1), density=1.5)
    s.box((0.02, 0.62, -0.1), (0.4, 0.12, 0.28), m["tex_pack"], rot=(0.8, 0.4, 0.1), density=1.5)  # 開いたふた
    s.tube([(0.35, 0.12, 0.25), (0.9, 0.12, 0.35)], [0.12, 0.12], m["tent_cloth_solid"], sides=8, density=2.0, cap=True)  # 寝袋
    s.cylinder((-0.35, 0.0, 0.3), 0.1, 0.09, 0.09, m["tex_tin"], sides=8)  # コッヘル
    rope_points = [(-0.2 + k * 0.15, 0.03, 0.5 + math.sin(k * 1.3) * 0.12) for k in range(10)]
    s.tube(rope_points, [0.02] * len(rope_points), m["tex_rope"], sides=5, density=3.0)
    return s.finish()


def build_tent(rng, m):
    """破れたテント：傾いた三角の布と、折れたポール、はためく切れ端"""
    s = mk.Model("prop_tent", rng)
    cloth = m["leaf_tent"]
    for side in (-1, 1):
        s.card((side * 0.95, 0.0, -1.1), 2.2, 1.35, cloth, (side, 0, 0), (-side * 0.62, 0.78, 0), uv=(0, 0, 1, 1))
    s.cylinder((0, 0, -1.2), 1.1, 0.02, 0.02, m["tex_tin"], sides=5)
    s.cylinder((0, 0, 1.1), 0.7, 0.02, 0.02, m["tex_tin"], sides=5, axis=(0.5, 0.8, 0.2))
    s.card((0.2, 0.0, 1.2), 1.0, 0.8, cloth, (0, 0.8, 0.6), (0.4, 0.2, -1), bend=0.2)
    return s.finish()


# --- 山の上の置き物 ---

def build_memorial(rng, m):
    """慰霊碑：二段の台石に立つ、ごつごつした自然石の碑。前の面に遭難者の名を刻み、
    竹の花立てにしおれた花、欠けた湯のみ、積まれた小石、立てかけた錆びたピッケル"""
    s = mk.Model("prop_memorial", rng)
    stone = m["tex_stone"]
    s.box((0, 0.12, 0), (1.5, 0.24, 1.05), m["tex_stone_blocks"], density=1.0, jitter=0.03)
    s.box((0, 0.34, -0.08), (1.1, 0.22, 0.72), stone, density=1.0, jitter=0.03)
    # 碑：上ほど細く、少しずつずれた、でこぼこの板石
    s.box((0, 0.9, -0.12), (0.84, 0.92, 0.3), m["tex_engraved"], density=1.1, jitter=0.035)
    s.box((0.03, 1.58, -0.12), (0.72, 0.46, 0.28), m["tex_engraved"], rot=(0, 0, 0.04), density=1.1, jitter=0.045)
    s.box((0.07, 1.92, -0.13), (0.5, 0.24, 0.25), stone, rot=(0.05, 0, 0.14), density=1.1, jitter=0.05)
    # 竹の花立てと、しおれた花
    for side in (-1, 1):
        s.cylinder((side * 0.42, 0.45, 0.2), 0.34, 0.055, 0.055, m["bark_bamboo"], sides=7, density=2.0)
        s.card((side * 0.42, 0.62, 0.2), 0.34, 0.42, m["leaf_flowers"], (0, 0, 1), (side * 0.25, 1, 0))
        s.card((side * 0.42, 0.62, 0.2), 0.34, 0.4, m["leaf_flowers"], (1, 0, 0), (0, 1, side * 0.2))
    s.cylinder((0.12, 0.45, 0.24), 0.06, 0.045, 0.05, stone, sides=8)  # 湯のみ
    s.box((0.2, 0.47, 0.25), (0.05, 0.03, 0.05), m["tex_stone"], rot=(0, 0.6, 0))  # 欠けら
    # 台の上に積まれた小石
    for k in range(9):
        size = rng.uniform(0.07, 0.14)
        s.box((rng.uniform(-0.45, -0.15), 0.45 + size * 0.4 + (k // 4) * 0.08, rng.uniform(0.05, 0.3)), (size, size * 0.7, size * 0.9),
              m["tex_stone_statue"], rot=(rng.uniform(0, 1), rng.uniform(0, 3), rng.uniform(0, 1)), density=2.0, jitter=0.015)
    # 立てかけたピッケル
    s.cylinder((0.62, 0.24, 0.35), 0.95, 0.022, 0.018, m["tex_dark_wood"], sides=6, axis=(-0.08, 1, -0.28), density=2.0)
    s.box((0.55, 1.15, 0.1), (0.36, 0.05, 0.05), m["tex_rust"], rot=(0, 0.3, 0.1), density=3.0)
    s.box((0.5, 1.13, 0.08), (0.12, 0.04, 0.1), m["tex_rust"], rot=(0, 0.3, 0.1), density=3.0)
    return s.finish()


def build_buddha(rng, m):
    """石仏：蓮の台座に座り、手を組んで目を閉じた仏さま。舟の形の光背は欠けていて、苔と地衣がつく。赤い前掛けと、供えた小石"""
    s = mk.Model("prop_buddha", rng)
    stone = m["tex_stone_statue"]
    # 八角の台と、蓮の花びら
    s.cylinder((0, 0, 0), 0.28, 0.62, 0.66, m["tex_stone_blocks"], sides=8, density=1.0)
    s.cylinder((0, 0.28, 0), 0.12, 0.5, 0.56, stone, sides=8, density=1.0)
    for k in range(12):
        a = k / 12 * math.tau
        out = Vector((math.sin(a), 0, math.cos(a)))
        c = Vector((0, 0.46, 0)) + out * 0.44
        s.box(tuple(c), (0.2, 0.08, 0.26), stone, rot=(0.5, a, 0), density=2.0, jitter=0.01)
    # 組んだ脚
    s.tube([(-0.36, 0.5, 0.05), (-0.15, 0.53, 0.14), (0.15, 0.53, 0.14), (0.36, 0.5, 0.05)], [0.1, 0.13, 0.13, 0.1], stone, sides=8, density=1.2)
    s.cylinder((0, 0.42, -0.02), 0.14, 0.34, 0.32, stone, sides=10, density=1.2)
    # 体（衣のひだは、少しずつ太さを変えて）
    s.tube([(0, 0.5, -0.04), (0, 0.66, -0.04), (0, 0.84, -0.05), (0, 0.98, -0.06), (0, 1.05, -0.06)],
           [0.28, 0.27, 0.23, 0.17, 0.08], stone, sides=12, density=1.2, wobble=0.03)
    # 衣の襟と、組んだ手
    s.box((0, 0.93, 0.1), (0.2, 0.22, 0.04), stone, rot=(0.25, 0, 0.6), density=2.0)
    s.box((0, 0.93, 0.1), (0.2, 0.22, 0.04), stone, rot=(0.25, 0, -0.6), density=2.0)
    s.box((0, 0.62, 0.19), (0.24, 0.1, 0.14), stone, rot=(0.2, 0, 0), density=2.0, jitter=0.01)
    # 頭：丸い頭、盛り上がった頭頂、長い耳たぶ、閉じた目
    s.tube([(0, 1.03, -0.05), (0, 1.07, -0.05), (0, 1.16, -0.05), (0, 1.25, -0.05), (0, 1.3, -0.05)],
           [0.06, 0.125, 0.14, 0.115, 0.03], stone, sides=12, density=1.5)
    s.tube([(0, 1.27, -0.06), (0, 1.32, -0.06), (0, 1.36, -0.06)], [0.08, 0.07, 0.0], stone, sides=8, density=1.5)
    for side in (-1, 1):
        s.box((side * 0.135, 1.12, -0.05), (0.03, 0.12, 0.05), stone, rot=(0, 0, side * 0.1), density=2.0)
        s.box((side * 0.045, 1.16, 0.085), (0.05, 0.008, 0.012), m["tex_dark_wood"], rot=(0, 0, side * -0.25))
    s.box((0, 1.1, 0.095), (0.05, 0.008, 0.01), m["tex_dark_wood"])  # 口
    # 舟の形の光背（体の後ろの板と、頭の後ろの丸い板。上の端が欠けている）
    rows = [(0.62, 0.5), (0.78, 0.66), (0.94, 0.74), (1.1, 0.72), (1.26, 0.62), (1.4, 0.42)]
    for k, (y, w) in enumerate(rows):
        chipped = k == len(rows) - 1
        s.box((-0.05 if chipped else 0.0, y, -0.38), (w, 0.17, 0.08), stone, rot=(0, 0, 0.25 if chipped else 0.0), density=1.0, jitter=0.012)
    s.cylinder((0, 1.17, -0.34), 0.05, 0.25, 0.25, stone, sides=14, axis=(0, 0, 1), density=1.0)
    # 赤い前掛けと、供えた小石
    s.box((0, 0.82, 0.18), (0.3, 0.2, 0.03), m["tex_red_cloth"], rot=(0.22, 0, 0), density=2.0)
    for k in range(5):
        s.box((rng.uniform(-0.3, 0.3), 0.43, rng.uniform(0.38, 0.5)), (0.07, 0.05, 0.06), m["tex_stone"], rot=(0, rng.uniform(0, 3), 0), jitter=0.01)
    return s.finish()


def build_remains(rng, m):
    """遭難者の亡骸：うつ伏せに倒れた、橙色の雨具を着た白骨。前へ伸ばした腕の先に、錆びたピッケル。
    脱げたヘルメット、裂けたザック、散らばった骨"""
    s = mk.Model("prop_remains", rng)
    bone_m = m["tex_bone"]
    coat = m["tex_jacket"]
    # 胴（雨具の中はしぼんでいる）
    s.box((0, 0.13, 0), (0.46, 0.2, 0.64), coat, rot=(0, 0, 0.08), density=1.4, jitter=0.03)
    s.box((0, 0.2, -0.15), (0.34, 0.1, 0.3), m["tex_pack"], rot=(0.1, 0.1, 0.05), density=1.5, jitter=0.02)  # 背中の裂けたザック
    # 頭蓋骨（横を向いて、眼窩が暗い）
    skull = [(0.02, 0.1, 0.42), (0.02, 0.12, 0.47), (0.02, 0.13, 0.55), (0.02, 0.12, 0.61), (0.02, 0.1, 0.64)]
    s.tube(skull, [0.05, 0.1, 0.11, 0.09, 0.03], bone_m, sides=10, density=2.0)
    for side in (-1, 1):
        s.box((0.1, 0.13 + side * 0.035, 0.57), (0.02, 0.035, 0.04), m["tex_void"])
    s.box((0.1, 0.07, 0.6), (0.03, 0.03, 0.07), bone_m, density=3.0)  # あご
    # 腕：片方は前へ伸ばし、片方は体の下に
    s.tube([(0.2, 0.14, 0.25), (0.3, 0.1, 0.5), (0.34, 0.07, 0.72)], [0.07, 0.06, 0.05], coat, sides=6, density=1.5)
    s.tube([(0.34, 0.06, 0.72), (0.36, 0.04, 0.92)], [0.022, 0.018], bone_m, sides=5, density=2.0)
    for k in range(4):
        s.tube([(0.36 + (k - 1.5) * 0.02, 0.03, 0.92), (0.36 + (k - 1.5) * 0.03, 0.02, 1.0)], [0.008, 0.006], bone_m, sides=4, density=4.0)
    s.tube([(-0.2, 0.14, 0.2), (-0.26, 0.08, 0.02), (-0.14, 0.05, -0.1)], [0.07, 0.06, 0.05], coat, sides=6, density=1.5)
    # 脚（ズボンと登山靴）
    for side, bend in ((-1, 0.0), (1, 0.25)):
        s.tube([(side * 0.12, 0.12, -0.3), (side * 0.14, 0.09, -0.62), (side * (0.16 + bend * 0.3), 0.08, -0.95)], [0.08, 0.07, 0.06],
               m["tex_dark_wood"], sides=6, density=1.5)
        s.box((side * (0.17 + bend * 0.3), 0.07, -1.05), (0.12, 0.13, 0.26), m["tex_dark_wood"], rot=(0.3, bend, side * 0.3), density=2.0)
    # 肋骨がのぞく裂け目
    for k in range(3):
        z = 0.05 + k * 0.07
        s.tube([(-0.12, 0.2, z), (0.0, 0.25, z + 0.02), (0.12, 0.2, z)], [0.012, 0.014, 0.012], bone_m, sides=4, density=3.0)
    # 伸ばした手の先のピッケル、転がったヘルメット、散らばった骨
    s.cylinder((0.5, 0.03, 0.8), 0.75, 0.02, 0.018, m["tex_dark_wood"], sides=6, axis=(0.3, 0, 1), density=2.0)
    s.box((0.72, 0.04, 1.5), (0.35, 0.05, 0.06), m["tex_rust"], rot=(0, 1.2, 0), density=3.0)
    s.tube([(-0.55, 0.0, 0.45), (-0.55, 0.08, 0.45), (-0.55, 0.15, 0.45), (-0.55, 0.18, 0.45)], [0.15, 0.15, 0.12, 0.0],
           m["tex_helmet"], sides=10, density=1.0)
    s.box((-0.55, 0.01, 0.45), (0.3, 0.02, 0.34), m["tex_helmet"], density=1.0)
    for k in range(4):
        x, z = rng.uniform(-0.8, 0.8), rng.uniform(-0.6, 1.1)
        a = rng.uniform(0, math.pi)
        s.tube([(x, 0.02, z), (x + math.cos(a) * 0.22, 0.02, z + math.sin(a) * 0.22)], [0.018, 0.015], bone_m, sides=4, density=3.0)
    return s.finish()


def build_signpost(rng, m):
    """道標：傾いた柱に、行き先の消えかけた矢印の板。一枚は割れてぶら下がる。赤い目印のテープと、根元の積み石"""
    s = mk.Model("prop_signpost", rng)
    lean = (0.06, 0, -0.05)
    s.box((0, 1.1, 0), (0.13, 2.2, 0.13), m["tex_dark_wood"], rot=lean, density=1.0)
    s.box((0, 2.22, 0), (0.17, 0.06, 0.17), m["tex_dark_wood"], rot=lean)
    for k, (y, yaw) in enumerate([(1.9, 0.3), (1.6, -1.9)]):
        d = Vector((math.cos(yaw), 0, -math.sin(yaw)))
        c = Vector((0, y, 0)) + d * 0.48
        s.box(tuple(c), (0.9, 0.2, 0.035), m["tex_signboard"], rot=(0, yaw, 0), density=1.2)
        tip = Vector((0, y, 0)) + d * 0.97
        s.box(tuple(tip), (0.14, 0.14, 0.034), m["tex_signboard"], rot=(0, yaw, math.pi / 4), density=1.2)
    s.box((0.3, 1.18, 0.05), (0.62, 0.18, 0.035), m["tex_signboard"], rot=(0, 0.2, -0.7), density=1.2)  # 割れてぶら下がる板
    s.cylinder((0, 1.3, 0), 0.04, 0.09, 0.09, m["tex_rust"], sides=6)  # 留めた針金
    # 柱に結んだ赤いテープ
    for k in range(3):
        a = k * 2.1
        s.card((0.07 * math.cos(a), 2.05 - k * 0.03, 0.07 * math.sin(a)), 0.05, -0.4, m["leaf_tape"], (math.cos(a), 0, math.sin(a)),
               (math.cos(a) * 0.5, 1, math.sin(a) * 0.5))
    s.tube([(0.07 * math.cos(a), 2.05, 0.07 * math.sin(a)) for a in [k / 8 * math.tau for k in range(9)]], [0.012] * 9, m["tex_red_cloth"], sides=4, density=4.0)
    # 根元の積み石
    y = 0.0
    for k in range(5):
        size = 0.42 - k * 0.07
        s.box((rng.uniform(-0.03, 0.03) + 0.05, y + size * 0.3, 0.04), (size, size * 0.6, size * 0.9), m["tex_stone"],
              rot=(0, rng.uniform(0, 3), rng.uniform(-0.1, 0.1)), density=1.5, jitter=0.03)
        y += size * 0.55
    return s.finish()


def build_bivouac(rng, m):
    """ビバークの跡：風よけに半円に積んだ石垣、黒く焦げた焚き火の跡、錆びた空き缶、丸めた銀マット、
    石垣にかぶせたぼろぼろのシート（真ん中に物を置ける）"""
    s = mk.Model("prop_bivouac", rng)
    # 半円の石垣（奥の側、-Z）
    for layer in range(3):
        for k in range(11):
            a = math.pi + (k + 0.5 * (layer % 2)) / 10 * math.pi
            r = 1.45 - layer * 0.05
            c = (math.cos(a) * r, 0.15 + layer * 0.24, math.sin(a) * r * 0.9 - 0.1)
            size = rng.uniform(0.38, 0.52)
            s.box(c, (size, 0.26, 0.34), m["tex_stone"], rot=(rng.uniform(-0.1, 0.1), -a + math.pi / 2, rng.uniform(-0.1, 0.1)),
                  density=1.5, jitter=0.04)
    # 石垣の上にかぶせて、外側へ垂らしたシート
    s.card((0.1, 0.78, -1.15), 1.6, 0.75, m["leaf_tent"], (0, 0.3, 1), (0, -0.9, -0.45), bend=0.1)
    # 焚き火の跡：石の輪と炭
    for k in range(8):
        a = k / 8 * math.tau
        s.box((0.55 + math.cos(a) * 0.32, 0.05, 0.45 + math.sin(a) * 0.32), (0.14, 0.1, 0.12), m["tex_stone_blocks"], rot=(0, a, 0), jitter=0.02)
    s.box((0.55, 0.012, 0.45), (0.5, 0.02, 0.5), m["tex_charcoal"], density=2.0)
    for k in range(4):
        a = rng.uniform(0, math.tau)
        s.tube([(0.55 + math.cos(a) * 0.2, 0.04, 0.45 + math.sin(a) * 0.2), (0.55 - math.cos(a) * 0.1, 0.07, 0.45 - math.sin(a) * 0.1)],
               [0.025, 0.02], m["tex_charcoal"], sides=5, density=3.0)
    # 空き缶、銀マット、飯ごう
    s.cylinder((1.0, 0.0, 0.0), 0.12, 0.04, 0.04, m["tex_rust"], sides=8)
    s.cylinder((0.85, 0.04, -0.2), 0.12, 0.04, 0.04, m["tex_rust"], sides=8, axis=(1, 0, 0.3))
    s.cylinder((-0.8, 0.1, 0.2), 0.6, 0.1, 0.1, m["tex_helmet"], sides=8, axis=(0.2, 0, 1), density=2.0)
    s.box((0.3, 0.07, 0.8), (0.16, 0.14, 0.1), m["tex_tin"], rot=(0, 0.4, 0), density=2.0)
    return s.finish()


def build_chain(rng, m):
    """鎖場：岩に打ち込んだ太い鉄の環から、錆びた鎖が崖を垂れ下がる。途中にも支点の環（崖の表面に沿って -Y へ）"""
    s = mk.Model("prop_chain", rng)
    iron = m["tex_rust"]
    length = 4.2
    y = 0.0
    k = 0
    while y > -length:
        # 輪（前後で向きを変える）。遠くからも見えるように、太い鎖にする
        w, h = 0.075, 0.19
        if k % 2 == 0:
            pts = [(-w, y, 0.11), (-w, y - h, 0.11), (w, y - h, 0.11), (w, y, 0.11), (-w, y, 0.11)]
        else:
            pts = [(0, y, 0.11 - w), (0, y - h, 0.11 - w), (0, y - h, 0.11 + w), (0, y, 0.11 + w), (0, y, 0.11 - w)]
        s.tube(pts, [0.024] * 5, iron, sides=4, density=4.0, smooth=False)
        y -= h * 0.78
        k += 1
    for anchor_y in (0.08, -length * 0.5, -length):
        s.box((0, anchor_y, 0.0), (0.22, 0.22, 0.1), iron, density=3.0)  # 支点の板
        s.tube([(0, anchor_y + 0.02, 0.04), (0, anchor_y + 0.1, 0.1), (0, anchor_y + 0.02, 0.16), (0, anchor_y - 0.06, 0.1), (0, anchor_y + 0.02, 0.04)],
               [0.02] * 5, iron, sides=5, density=3.0)
    # 先の、ほつれたロープ
    s.tube([(0, -length, 0.1), (0.05, -length - 0.3, 0.12), (0.02, -length - 0.6, 0.1)], [0.02, 0.018, 0.015], m["tex_rope"], sides=5, density=3.0)
    return s.finish()


def build_carving(rng, m):
    """磨崖仏：崖を浅く彫りくぼめて、立ち姿の観音さまを浮き彫りにしたもの。まわりは苔むし、足もとの石の棚に供え物"""
    s = mk.Model("prop_carving", rng)
    stone = m["tex_stone_statue"]
    mossy = m["tex_stone_mossy"]
    # 崖にめりこんだ板と、くぼみのふち（原点が崖の表面、+Z が外）
    s.box((0, 1.1, -0.25), (1.5, 2.4, 0.5), mossy, density=0.8, jitter=0.03)
    s.box((0, 2.35, -0.05), (1.6, 0.25, 0.3), stone, density=1.0, jitter=0.03)
    for side in (-1, 1):
        s.box((side * 0.72, 1.1, -0.05), (0.22, 2.4, 0.3), mossy, density=1.0, jitter=0.03)
    s.box((0, 1.1, 0.0), (1.22, 2.2, 0.02), m["tex_stone_blocks"], density=0.3)  # くぼみの奥（暗い）
    # 浮き彫りの観音さま：光背、体、頭、宝冠、合わせた手
    s.cylinder((0, 1.72, 0.02), 0.04, 0.34, 0.34, stone, sides=14, axis=(0, 0, 1))
    s.tube([(0, 0.35, 0.08), (0, 0.8, 0.1), (0, 1.25, 0.11), (0, 1.5, 0.1)], [0.2, 0.22, 0.19, 0.1], stone, sides=10, density=1.2)
    s.tube([(0, 1.5, 0.1), (0, 1.56, 0.11), (0, 1.66, 0.12), (0, 1.76, 0.11), (0, 1.8, 0.1)], [0.05, 0.1, 0.11, 0.09, 0.03], stone, sides=10)
    s.box((0, 1.86, 0.1), (0.16, 0.1, 0.06), stone, jitter=0.01)
    s.box((0, 1.2, 0.26), (0.08, 0.16, 0.06), stone)
    for side in (-1, 1):
        s.tube([(side * 0.16, 1.4, 0.12), (side * 0.2, 1.22, 0.18), (side * 0.05, 1.16, 0.26)], [0.045, 0.04, 0.035], stone, sides=6)
        s.box((side * 0.035, 1.66, 0.215), (0.035, 0.006, 0.01), m["tex_dark_wood"])  # 閉じた目
    for k in range(4):  # 衣のひだ
        s.box((0, 0.5 + k * 0.18, 0.28 - k * 0.02), (0.3 - k * 0.03, 0.015, 0.02), stone, rot=(0, 0, 0.1 * (k % 2 * 2 - 1)))
    s.box((0, 0.3, 0.1), (0.5, 0.14, 0.26), stone, jitter=0.02)  # 蓮の台
    # 足もとの石の棚と供え物
    s.box((0, 0.1, 0.25), (1.0, 0.18, 0.4), m["tex_stone_blocks"], density=1.0, jitter=0.03)
    s.cylinder((-0.25, 0.19, 0.3), 0.06, 0.045, 0.05, m["tex_stone"], sides=8)
    s.cylinder((0.2, 0.19, 0.32), 0.15, 0.03, 0.03, m["bark_bamboo"], sides=6)
    s.card((0.2, 0.3, 0.32), 0.22, 0.3, m["leaf_flowers"], (0, 0, 1))
    return s.finish()


def build_mine(rng, m):
    """廃坑の入り口：崖の根元に口をあけた坑道。太い木の枠と筋交い、打ちつけて半分はがれた板、
    奥の暗がり、外へ伸びる錆びたレール、倒れたトロッコ、釘に掛かったカンテラ"""
    s = mk.Model("prop_mine", rng)
    wood = m["tex_dark_wood"]
    beam = m["tex_planks"]
    # 石積みの坑口（崖に押しこんで据える）と、奥の暗がり
    blocks = m["tex_stone_blocks"]
    for side in (-1, 1):
        s.box((side * 1.62, 1.6, -0.75), (1.0, 3.3, 1.5), blocks, density=0.6, jitter=0.04)
    s.box((0, 2.95, -0.75), (4.2, 0.9, 1.5), blocks, density=0.6, jitter=0.04)
    s.box((0, 1.25, -0.8), (2.2, 2.5, 1.4), m["tex_void"], density=0.5)
    # 枠：二本の柱と、太い梁、その上の小さな庇
    for side in (-1, 1):
        s.box((side * 1.05, 1.2, 0.15), (0.24, 2.5, 0.24), wood, rot=(0, 0, side * -0.04), density=0.8, jitter=0.02)
        s.box((side * 1.05, 0.12, 0.15), (0.34, 0.24, 0.34), m["tex_stone"], jitter=0.03)
        s.box((side * 0.8, 2.05, 0.18), (0.6, 0.12, 0.12), wood, rot=(0, 0, side * 0.75), density=1.0)  # 筋交い
    s.box((0, 2.52, 0.15), (2.6, 0.3, 0.3), wood, rot=(0, 0, 0.03), density=0.8, jitter=0.02)
    s.box((0, 2.75, 0.35), (2.8, 0.08, 0.7), beam, rot=(0.25, 0, 0), density=0.8)
    # 打ちつけた板（一枚ははがれて、斜めにぶら下がる）
    for k, (y, rot) in enumerate([(0.7, 0.1), (1.35, -0.14), (1.95, 0.05)]):
        s.box((0, y, 0.3), (2.2, 0.22, 0.04), beam, rot=(0, 0, rot), density=0.8)
    s.box((0.55, 1.0, 0.33), (1.2, 0.2, 0.04), beam, rot=(0, 0, 0.9), density=0.8)
    # 立入禁止の札
    s.box((-0.6, 1.62, 0.34), (0.5, 0.3, 0.03), m["tex_signboard"], rot=(0, 0, -0.08), density=1.6)
    # レールと枕木（外へ伸びて、途中で途切れる）
    for side in (-1, 1):
        s.box((side * 0.35, 0.06, 0.9), (0.05, 0.06, 2.9), m["tex_rust"], rot=(0, side * 0.02, 0), density=2.0)
    for k in range(6):
        s.box((rng.uniform(-0.05, 0.05), 0.02, -0.2 + k * 0.5), (1.0, 0.07, 0.16), wood, rot=(0, rng.uniform(-0.1, 0.1), 0), density=1.0)
    # 倒れたトロッコ
    cart = Vector((1.5, 0.35, 1.6))
    s.box(tuple(cart), (0.8, 0.5, 1.0), m["tex_rust"], rot=(0, 0.5, 1.35), density=1.0)
    for k in range(2):
        s.cylinder((1.2 + k * 0.1, 0.18, 1.2 + k * 0.7), 0.06, 0.14, 0.14, m["tex_rust"], sides=8, axis=(0.9, 0.2, 0.4))
    # 釘に掛かったカンテラ
    s.cylinder((1.05, 1.9, 0.33), 0.2, 0.012, 0.012, m["tex_rust"], sides=4, axis=(0, -1, 0))
    s.cylinder((1.05, 1.55, 0.33), 0.16, 0.07, 0.07, m["tex_rust"], sides=6)
    s.box((1.05, 1.63, 0.33), (0.1, 0.1, 0.1), m["tex_void"])
    return s.finish()


def build_ladder(rng, m):
    """古い木の梯子：崖に立てかけた、縄で継いだ長い梯子。横木は何本か抜け落ち、一本は折れてぶら下がる
    （原点が崖の根元、+Z が崖から離れる向き。上の端が崖に寄りかかる）"""
    s = mk.Model("prop_ladder", rng)
    wood = m["tex_planks"]
    length = 5.4
    foot = Vector((0, 0, 1.3))
    top = Vector((0, length * 0.97, 0.05))
    axis = (top - foot).normalized()
    for side in (-1, 1):
        off = Vector((side * 0.24, 0, 0))
        mid = foot.lerp(top, 0.5) + off + Vector((rng.uniform(-0.03, 0.03), 0, 0))
        s.tube([foot + off, mid, top + off], [0.05, 0.045, 0.04], wood, sides=6, density=0.8, wobble=0.1)
        # 継ぎ目の縄
        joint = foot.lerp(top, 0.5) + off
        s.cylinder(tuple(joint - axis * 0.1), 0.2, 0.065, 0.065, m["tex_rope"], sides=6, axis=tuple(axis), density=3.0)
    missing = {3, 7, 8}
    for k in range(14):
        t = (k + 0.7) / 14.5
        c = foot.lerp(top, t)
        if k in missing:
            continue
        if k == 10:  # 折れてぶら下がる横木
            s.box(tuple(c + Vector((-0.12, -0.1, 0.02))), (0.26, 0.05, 0.05), wood, rot=(0, 0, 1.1), density=1.0)
            continue
        s.box(tuple(c), (0.52, 0.05, 0.06), wood, rot=(math.atan2(axis.z, axis.y), 0, rng.uniform(-0.04, 0.04)), density=1.0)
    return s.finish()


def build_talisman(rng, m):
    """お札の岩：崖の割れ目をふさぐように、びっしりと貼られたお札。割れ目の上には、鉄の杭に張ったしめ縄と紙垂
    （原点が崖の表面、+Z が外、崖に沿って貼る）"""
    s = mk.Model("prop_talisman", rng)
    # 割れ目（暗い筋）
    y = 1.4
    x = 0.0
    for k in range(6):
        nx, ny = x + rng.uniform(-0.12, 0.12), y - rng.uniform(0.22, 0.34)
        mid = ((x + nx) / 2, (y + ny) / 2, 0.005)
        s.box(mid, (0.05, math.hypot(nx - x, ny - y) + 0.04, 0.02), m["tex_void"], rot=(0, 0, math.atan2(nx - x, y - ny)))
        x, y = nx, ny
    # お札（割れ目のまわりに、少しずつ重ねて）
    for k in range(16):
        px = rng.gauss(0, 0.28)
        py = rng.uniform(-0.3, 1.5)
        s.box((px, py, 0.012 + k * 0.002), (0.085, 0.24, 0.004), m["tex_ofuda"], rot=(0, 0, rng.uniform(-0.35, 0.35)), density=4.0)
    # 鉄の杭としめ縄、紙垂
    for side in (-1, 1):
        s.cylinder((side * 0.75, 1.8, 0.0), 0.2, 0.03, 0.02, m["tex_rust"], sides=5, axis=(0, 0, 1))
    rope_pts = [(-0.75 + k * 0.15, 1.8 - 0.14 * math.sin(k / 10 * math.pi), 0.18) for k in range(11)]
    s.tube(rope_pts, [0.04] * 11, m["tex_rope"], sides=6, density=3.0)
    for px in (-0.4, 0.0, 0.4):
        s.card((px, 1.72, 0.2), 0.1, -0.24, m["leaf_paper"], (0, 0, 1))
    return s.finish()


def build_bridge(rng, m):
    """吊り橋の残骸：崖っぷちに残る二本の親柱と、谷へ垂れ下がる切れた主綱、綱にぶら下がった踏み板。
    親柱には「通行止」の札（原点が崖の縁、+Z が谷の側）"""
    s = mk.Model("prop_bridge", rng)
    wood = m["tex_dark_wood"]
    for side in (-1, 1):
        s.box((side * 0.7, 0.7, -0.7), (0.2, 1.6, 0.2), wood, rot=(0.05, 0, side * 0.04), density=1.0, jitter=0.02)
        s.box((side * 0.7, 0.1, -0.7), (0.4, 0.3, 0.4), m["tex_stone"], jitter=0.04)
        s.cylinder((side * 0.7, 1.2, -0.7), 0.12, 0.13, 0.13, m["tex_rope"], sides=6, density=3.0)  # 巻きつけた綱
        # 垂れ下がる主綱（崖の縁を越えて、下へ）
        pts = [(side * 0.7, 1.25, -0.6), (side * 0.62, 0.3, 0.1), (side * 0.6, -0.4, 0.45), (side * 0.55, -1.6, 0.55),
               (side * 0.5, -2.8, 0.6), (side * 0.52, -3.6, 0.62)]
        s.tube(pts, [0.03] * len(pts), m["tex_rope"], sides=5, density=2.0)
    # 綱にぶら下がった踏み板（何枚か抜け落ちている）
    for k, y in enumerate([-0.5, -0.95, -1.4, -2.3, -2.75, -3.3]):
        s.box((0, y, 0.5 + k * 0.015), (1.1, 0.07, 0.24), m["tex_planks"], rot=(1.35, 0, rng.uniform(-0.15, 0.15)), density=1.0)
    s.box((0.2, 0.03, 0.0), (1.2, 0.07, 0.25), m["tex_planks"], rot=(0, 0.1, 0.05), density=1.0)  # 縁に引っかかった板
    s.box((-0.7, 1.0, -0.58), (0.38, 0.24, 0.03), m["tex_signboard"], rot=(0, 0, 0.1), density=1.6)
    return s.finish()


def build_ema(rng, m):
    """草鞋掛け：小さな屋根のついた木の枠に、奉納された草鞋と絵馬がびっしり掛かる。風にゆれる紙垂"""
    s = mk.Model("prop_ema", rng)
    wood = m["tex_dark_wood"]
    for side in (-1, 1):
        s.box((side * 0.75, 0.85, 0), (0.1, 1.7, 0.1), wood, density=1.0)
    s.box((0, 1.55, 0), (1.7, 0.08, 0.08), wood)
    s.box((0, 1.05, 0), (1.6, 0.06, 0.06), wood)
    s.roof((0, 1.68, 0), 1.9, 0.5, 0.22, wood, thickness=0.05, density=1.0)
    # 絵馬（五角形の板）と草鞋
    for row, y in enumerate((1.36, 0.86)):
        for k in range(6):
            x = -0.62 + k * 0.25 + rng.uniform(-0.03, 0.03)
            if (k + row) % 2 == 0:
                s.box((x, y, 0.05), (0.18, 0.12, 0.015), m["tex_sotoba"], rot=(0.1, 0, rng.uniform(-0.2, 0.2)), density=5.0)
                s.box((x, y + 0.07, 0.05), (0.13, 0.13, 0.015), m["tex_sotoba"], rot=(0.1, 0, math.pi / 4), density=5.0)
            else:
                s.box((x, y - 0.06, 0.05), (0.1, 0.26, 0.02), m["tex_straw"], rot=(0.15, 0, rng.uniform(-0.25, 0.25)), density=4.0)
                s.box((x, y - 0.06, 0.08), (0.11, 0.27, 0.02), m["tex_straw"], rot=(0.25, 0.1, rng.uniform(-0.25, 0.25)), density=4.0)
            s.cylinder((x, y + 0.08, 0.04), 0.12, 0.004, 0.004, m["tex_rope"], sides=3)
    for x in (-0.5, 0.5):
        s.card((x, 1.5, 0.06), 0.09, -0.22, m["leaf_paper"], (0, 0, 1))
    return s.finish()


def build_ice_wall(rng, m):
    """凍った滝：崖に張りついた氷の幕。太さのちがう氷の柱が何本も流れ落ちたまま凍りつき、ふくらんだりくびれたりする。
    上のふちは張り出し、下の端からは大小のつららが垂れる（原点が崖の表面、+Z が外、上が +Y。大きさ およそ 3.6×5.5 m）"""
    s = mk.Model("prop_ice_wall", rng)
    iceb = m["ice_body"]
    width, top, bottom = 3.6, 3.0, -2.6
    x = -width / 2
    while x < width / 2:
        r = rng.uniform(0.22, 0.5)
        cx = x + r
        pts = []
        radii = []
        y = top + rng.uniform(-0.3, 0.2)
        end = bottom + rng.uniform(-0.2, 0.6)
        k = 0
        while y > end:
            bulge = 1.0 + 0.35 * math.sin(k * 1.7 + rng.uniform(0, 3))
            pts.append((cx + rng.uniform(-0.05, 0.05), y, 0.18 + r * 0.55 * bulge))
            radii.append(r * bulge)
            y -= rng.uniform(0.4, 0.7)
            k += 1
        pts.append((cx, end - r * 0.8, 0.2))
        radii.append(0.02)
        s.tube(pts, radii, iceb, sides=7, density=0.35, wobble=0.12)
        # 柱の下から垂れる、つらら
        for _ in range(rng.randint(1, 3)):
            length = rng.uniform(0.4, 1.3)
            tx = cx + rng.uniform(-r, r) * 0.7
            s.tube([(tx, end, 0.25), (tx + rng.uniform(-0.03, 0.03), end - length, 0.25)], [rng.uniform(0.05, 0.11), 0.0], iceb, sides=5, density=0.6)
        x += r * rng.uniform(1.3, 1.8)
    # 上のふちの張り出し（雪と氷のひさし）
    s.tube([(-width / 2 - 0.2, top + 0.2, 0.2), (0, top + 0.35, 0.45), (width / 2 + 0.2, top + 0.15, 0.2)], [0.35, 0.45, 0.35], iceb, sides=8, density=0.4, wobble=0.15)
    for _ in range(9):
        tx = rng.uniform(-width / 2, width / 2)
        length = rng.uniform(0.3, 0.9)
        s.tube([(tx, top, 0.55), (tx, top - length, 0.5)], [rng.uniform(0.04, 0.09), 0.0], iceb, sides=5, density=0.6)
    # 崖に接する裏の板（すき間から岩が見えないように）
    s.box((0, (top + bottom) / 2, 0.05), (width + 0.2, top - bottom, 0.1), iceb, density=0.35)
    return s.finish()


def build_ice_pillars(rng, m):
    """氷の柱：雪原に立つ、凍りついた滝の名残りのような青い氷の柱の群れ。ねじれてふくらみ、根元は氷の塊に埋まる"""
    s = mk.Model("prop_ice_pillars", rng)
    iceb = m["ice_body"]
    for k in range(rng.randint(5, 7)):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 3.5) if k else 0.0
        base = Vector((math.cos(a) * d, -0.3, math.sin(a) * d))
        height = rng.uniform(3.0, 8.5) * (1.2 if k == 0 else 1.0)
        r = rng.uniform(0.45, 1.0)
        lean = Vector((rng.uniform(-0.12, 0.12), 1.0, rng.uniform(-0.12, 0.12))).normalized()
        pts, radii = [], []
        n = 7
        for j in range(n + 1):
            t = j / n
            p = base + lean * height * t + Vector((math.sin(t * 5 + k) * 0.15, 0, math.cos(t * 4 + k) * 0.15))
            pts.append(tuple(p))
            radii.append(r * (1.0 - t * 0.75) * (1.0 + 0.25 * math.sin(t * 9 + k)) + 0.02)
        radii[-1] = 0.03
        s.tube(pts, radii, iceb, sides=8, density=0.3, wobble=0.1)
        for _ in range(3):  # 柱の途中から出た、小さなつらら
            t = rng.uniform(0.3, 0.8)
            p = base + lean * height * t
            side = Vector((rng.uniform(-1, 1), 0, rng.uniform(-1, 1))).normalized() * radii[int(t * n)]
            s.tube([tuple(p + side), tuple(p + side * 1.1 - Vector((0, rng.uniform(0.4, 0.9), 0)))], [0.08, 0.0], iceb, sides=5, density=0.6)
    for _ in range(6):  # 根元の氷の塊
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.5, 3.8)
        size = rng.uniform(0.6, 1.4)
        s.box((math.cos(a) * d, size * 0.2, math.sin(a) * d), (size, size * 0.8, size * 0.9), iceb,
              rot=(rng.uniform(0, 0.4), rng.uniform(0, 3), rng.uniform(0, 0.4)), density=0.5, jitter=0.1)
    return s.finish()


BUILDERS = {
    "hut": build_hut, "shinboku": build_shinboku,
    "ruins_a": lambda rng, m: build_ruins(rng, m, "prop_ruins_a"),
    "ruins_b": lambda rng, m: build_ruins(rng, m, "prop_ruins_b"),
    "ruins_c": lambda rng, m: build_ruins(rng, m, "prop_ruins_c"),
    "jizo": build_jizo, "lantern": build_lantern, "hokora": build_hokora, "torii": build_torii,
    "sotoba": build_sotoba, "backpack": build_backpack, "tent": build_tent,
    "memorial": build_memorial, "buddha": build_buddha, "remains": build_remains, "signpost": build_signpost,
    "bivouac": build_bivouac, "chain": build_chain, "carving": build_carving, "mine": build_mine,
    "ladder": build_ladder, "talisman": build_talisman, "bridge": build_bridge, "ema": build_ema,
    "ice_wall": build_ice_wall, "ice_pillars": build_ice_pillars,
}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [a for a in args if not a.startswith("--")] or list(BUILDERS)
    mk.lib.reset()
    rng = random.Random(4242)
    images = {
        "tex_planks": planks(rng), "tex_tin": tin_roof(rng), "tex_stone_blocks": stone_blocks(rng),
        "tex_stone_mossy": stone_blocks(rng, "tex_stone_mossy", True), "tex_stone": stone_plain(rng),
        "tex_stone_statue": stone_plain(rng, "tex_stone_statue", (0.6, 0.59, 0.55)), "tex_rope": rope(rng),
        "leaf_paper": paper(rng), "tex_lacquer": lacquer(rng), "tex_dark_wood": dark_wood(rng), "tex_red_cloth": red_cloth(rng),
        "leaf_tent": tent_cloth(rng), "tex_pack": pack_cloth(rng), "tex_sotoba": sotoba_wood(rng),
    }
    extra_rng = random.Random(777)  # 前からある模様を変えないように、新しい模様は別の乱数で描く
    images.update({
        "tex_engraved": engraved(extra_rng), "tex_bone": bone(extra_rng), "tex_jacket": jacket(extra_rng), "tex_rust": rust(extra_rng),
        "tex_signboard": signboard(extra_rng), "leaf_tape": tape(extra_rng), "tex_ofuda": ofuda(extra_rng), "tex_charcoal": charcoal(extra_rng),
        "tex_void": void(extra_rng), "leaf_flowers": dry_flowers(extra_rng), "tex_straw": straw(extra_rng),
        "ice_body": ice(extra_rng),
    })
    images["tex_helmet"] = images["tex_jacket"]
    images["tent_cloth_solid"] = images["leaf_tent"]
    for name in ("bark_cedar", "leaf_cedar", "wood_cut", "bark_bamboo"):
        images[name] = mk.load_image(os.path.join(mk.FLORA_OUT, name + ".png"), name)
    images["leaf_ivy"] = mk.load_image(os.path.join(mk.FLORA_OUT, "leaf_moss.png"), "leaf_ivy")
    images["tex_log_end"] = images["wood_cut"]
    materials = {name: mk.material(name, image, name.startswith("leaf_")) for name, image in images.items()}
    for index, name in enumerate(names):
        obj = BUILDERS[name](random.Random(500 + index * 31 + len(name)), materials)
        mk.export(obj)
        if "--preview" in sys.argv:
            mk.preview(obj)
        bpy.data.objects.remove(obj, do_unlink=True)
        bpy.context.view_layer.update()


main()
