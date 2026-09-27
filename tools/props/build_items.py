"""Blender でアイテムのモデルを作る（30 種類）。assets/models/item_<名前>.glb に書き出す。

使い方（Blender 4.5 で実行する）:
    blender -b --factory-startup --python tools/props/build_items.py [-- 名前 名前 ... --preview]

大きさは実物どおり（m）。座標は Godot の向き（Y が上）。原点は、だいたい物の真ん中。
ナタは刃を +Y（上）、柄を -Y（下）に向け、刃先を +X に向ける（手に持ったときの向き）。
素材の名前が glow_ で始まる面は、暗い所でも光って見える（お札の墨、キノコの斑点）。
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
D = 9.0  # 小さな物なので、模様は 1 m あたり 9 枚（11 cm で 1 枚）の密度で貼る


# --- 模様 ---

def paint_steel(rng, name, base=(0.58, 0.6, 0.63)):
    c = Canvas(color=(*base, 1.0))
    for _ in range(70):  # 細かなこすれ傷
        x, y = rng.uniform(0, T), rng.uniform(0, T)
        c.line(x, y, x + rng.uniform(-18, 18), y + rng.uniform(-3, 3), 0.4, (base[0] * 1.3, base[1] * 1.3, base[2] * 1.3), 0.5)
    for _ in range(12):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(2, 6), rng.uniform(1, 3), 0.0, (base[0] * 0.55, base[1] * 0.5, base[2] * 0.45), 0.5)
    c.noise(rng, 0.06, 2)
    return c.save(name)


def paint_wood(rng):
    c = Canvas(color=(0.42, 0.27, 0.15, 1.0))
    for _ in range(40):
        y = rng.uniform(0, T)
        c.line(0, y, T, y + rng.uniform(-3, 3), 0.6, (0.3, 0.19, 0.1), 0.7)
    c.noise(rng, 0.07, 2)
    return c.save("item_wood")


def paint_cord(rng, name, color, dark):
    """巻いた紐：ななめの縞"""
    c = Canvas(color=(*color, 1.0))
    for k in range(-T, T * 2, 7):
        c.line(k, 0, k + T * 0.35, T, 1.4, dark, 0.9)
    c.noise(rng, 0.08, 2)
    return c.save(name)


def paint_rope(rng):
    c = Canvas(color=(0.9, 0.45, 0.1, 1.0))
    for k in range(-T, T * 2, 6):
        c.line(k, 0, k + T * 0.5, T, 1.0, (0.65, 0.3, 0.06), 0.8)
    for _ in range(80):  # 黒い差し色の糸
        x, y = rng.uniform(0, T), rng.uniform(0, T)
        c.line(x, y, x + 3, y + 5, 0.5, (0.08, 0.08, 0.1), 0.9)
    return c.save("item_rope")


def paint_gauze(rng):
    c = Canvas(color=(0.93, 0.92, 0.88, 1.0))
    for k in range(0, T, 4):
        c.line(k, 0, k, T, 0.4, (0.8, 0.79, 0.75), 0.7)
        c.line(0, k, T, k, 0.4, (0.8, 0.79, 0.75), 0.7)
    c.noise(rng, 0.03, 1)
    return c.save("item_gauze")


def paint_rice(rng):
    c = Canvas(color=(0.94, 0.94, 0.9, 1.0))
    for _ in range(260):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), 2.2, 1.1, rng.uniform(0, 3), rng.choice([(1.0, 1.0, 0.98), (0.8, 0.8, 0.75)]), 0.9)
    return c.save("item_rice")


def paint_nori(rng):
    c = Canvas(color=(0.06, 0.1, 0.07, 1.0))
    c.noise(rng, 0.3, 2)
    for _ in range(40):
        x, y = rng.uniform(0, T), rng.uniform(0, T)
        c.line(x, y, x + rng.uniform(-10, 10), y + rng.uniform(-10, 10), 0.5, (0.12, 0.2, 0.12), 0.8)
    return c.save("item_nori")


def paint_ofuda(rng):
    c = Canvas(color=(0.88, 0.82, 0.64, 1.0))
    c.noise(rng, 0.05, 2)
    c.rect(4, 4, T - 4, 8, (0.62, 0.12, 0.08))
    c.rect(4, T - 8, T - 4, T - 4, (0.62, 0.12, 0.08))
    c.ellipse(T / 2, T * 0.2, 14, 14, 0.0, (0.72, 0.14, 0.1))
    return c.save("item_ofuda")


def paint_ofuda_ink(rng):
    """お札の呪文（暗い所で、うっすら赤く光る）"""
    c = Canvas()
    y = T * 0.34
    while y < T - 14:
        for _ in range(4):
            c.line(T / 2 + rng.uniform(-20, 20), y + rng.uniform(0, 8), T / 2 + rng.uniform(-20, 20), y + rng.uniform(0, 8), 1.6, (0.55, 0.03, 0.02))
        y += 12
    return c.save("glow_ofuda_ink")


def paint_flare(rng):
    c = Canvas(color=(0.78, 0.08, 0.05, 1.0))
    c.noise(rng, 0.06, 2)
    c.rect(0, T * 0.35, T, T * 0.62, (0.95, 0.93, 0.88))
    for x in range(10, T - 10, 12):  # 注意書きの字
        c.line(x, T * 0.42, x + 6, T * 0.55, 1.0, (0.1, 0.1, 0.1))
    c.rect(0, T * 0.35, T, T * 0.37, (0.1, 0.1, 0.1))
    c.rect(0, T * 0.6, T, T * 0.62, (0.1, 0.1, 0.1))
    return c.save("item_flare")


def paint_red_paper(rng):
    c = Canvas(color=(0.8, 0.08, 0.06, 1.0))
    for k in range(0, T, 16):
        c.rect(0, k, T, k + 2, (0.95, 0.75, 0.2))
    c.noise(rng, 0.08, 2)
    return c.save("item_red_paper")


def paint_brass(rng):
    c = Canvas(color=(0.82, 0.62, 0.24, 1.0))
    for _ in range(30):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(3, 9), rng.uniform(2, 5), 0.0,
                  rng.choice([(0.95, 0.8, 0.4), (0.5, 0.36, 0.14)]), 0.4)
    c.noise(rng, 0.05, 2)
    return c.save("item_brass")


def paint_warmer(rng):
    c = Canvas(color=(0.95, 0.94, 0.9, 1.0))
    c.rect(0, T * 0.25, T, T * 0.55, (0.95, 0.45, 0.1))
    c.ellipse(T * 0.3, T * 0.4, 10, 10, 0.0, (1.0, 0.8, 0.2))
    for x in range(T // 2, T - 10, 10):
        c.line(x, T * 0.33, x + 5, T * 0.47, 1.2, (0.98, 0.98, 0.95))
    for x in range(10, T - 10, 9):
        c.line(x, T * 0.7, x + 4, T * 0.76, 0.7, (0.3, 0.3, 0.3))
    return c.save("item_warmer")


def paint_choco(rng):
    c = Canvas(color=(0.3, 0.16, 0.08, 1.0))
    for k in range(0, T, 32):
        c.rect(k, 0, k + 2, T, (0.18, 0.09, 0.04))
        c.rect(0, k, T, k + 2, (0.18, 0.09, 0.04))
        c.rect(k + 3, 3, k + 5, T, (0.42, 0.24, 0.12))
    return c.save("item_choco")


def paint_wrapper(rng):
    c = Canvas(color=(0.72, 0.08, 0.1, 1.0))
    c.rect(0, T * 0.4, T, T * 0.6, (0.9, 0.75, 0.3))
    for x in range(8, T - 8, 14):
        c.line(x, T * 0.44, x + 8, T * 0.56, 1.3, (0.5, 0.05, 0.05))
    c.noise(rng, 0.06, 2)
    return c.save("item_wrapper")


def paint_can_label(rng):
    c = Canvas(color=(0.2, 0.42, 0.62, 1.0))
    c.rect(0, T * 0.15, T, T * 0.2, (0.95, 0.9, 0.3))
    c.rect(0, T * 0.8, T, T * 0.85, (0.95, 0.9, 0.3))
    # 魚の絵
    c.ellipse(T * 0.45, T * 0.5, 26, 12, 0.0, (0.8, 0.82, 0.86))
    c.ellipse(T * 0.72, T * 0.5, 8, 12, 0.0, (0.8, 0.82, 0.86))
    c.ellipse(T * 0.3, T * 0.47, 2, 2, 0.0, (0.1, 0.1, 0.1))
    for x in range(int(T * 0.35), int(T * 0.6), 6):
        c.line(x, T * 0.42, x + 2, T * 0.58, 0.5, (0.55, 0.58, 0.62))
    return c.save("item_can_label")


def paint_nylon(rng, name, color):
    c = Canvas(color=(*color, 1.0))
    for k in range(0, T, 3):
        c.line(0, k, T, k, 0.3, (color[0] * 0.8, color[1] * 0.8, color[2] * 0.8), 0.6)
    c.noise(rng, 0.05, 2)
    return c.save(name)


def paint_chalk_dust(rng):
    c = Canvas(color=(0.94, 0.94, 0.92, 1.0))
    c.noise(rng, 0.05, 1)
    return c.save("item_chalk")


def paint_first_aid(rng):
    c = Canvas(color=(0.82, 0.1, 0.1, 1.0))
    c.rect(T * 0.38, T * 0.2, T * 0.62, T * 0.8, (0.96, 0.96, 0.96))
    c.rect(T * 0.2, T * 0.38, T * 0.8, T * 0.62, (0.96, 0.96, 0.96))
    c.noise(rng, 0.04, 2)
    return c.save("item_first_aid")


def paint_brocade(rng):
    c = Canvas(color=(0.72, 0.08, 0.14, 1.0))
    for y in range(0, T, 16):
        for x in range(0, T, 16):
            off = 8 if (y // 16) % 2 else 0
            c.ellipse(x + off, y + 8, 4, 4, 0.0, (0.92, 0.72, 0.28))
            c.ellipse(x + off, y + 8, 2, 2, 0.0, (0.72, 0.08, 0.14))
    c.rect(T * 0.3, T * 0.35, T * 0.7, T * 0.65, (0.95, 0.85, 0.5))
    for k in range(3):  # 「御守」の字のつもりの筋
        c.line(T * 0.4 + k * 8, T * 0.4, T * 0.4 + k * 8, T * 0.6, 1.2, (0.3, 0.05, 0.05))
    return c.save("item_brocade")


def paint_mushroom_cap(rng):
    c = Canvas(color=(0.45, 0.1, 0.35, 1.0))
    c.noise(rng, 0.12, 3)
    for _ in range(40):
        c.line(rng.uniform(0, T), 0, rng.uniform(0, T), T, 0.5, (0.3, 0.05, 0.25), 0.5)
    return c.save("item_mushroom_cap")


def paint_glow_spots(rng):
    c = Canvas(color=(0.55, 0.95, 0.5, 1.0))
    c.noise(rng, 0.15, 3)
    return c.save("glow_spots")


def paint_plain(rng, name, color, amount=0.06):
    c = Canvas(color=(*color, 1.0))
    c.noise(rng, amount, 2)
    return c.save(name)


def paint_salt_paper(rng):
    c = Canvas(color=(0.95, 0.94, 0.9, 1.0))
    c.noise(rng, 0.03, 1)
    c.rect(T * 0.3, T * 0.3, T * 0.7, T * 0.7, (0.75, 0.1, 0.08))
    c.rect(T * 0.35, T * 0.35, T * 0.65, T * 0.65, (0.95, 0.94, 0.9))
    for k in range(3):
        c.line(T * 0.42, T * 0.42 + k * 7, T * 0.58, T * 0.42 + k * 7, 1.0, (0.75, 0.1, 0.08))
    return c.save("item_salt_paper")


def paint_salt(rng):
    c = Canvas(color=(0.95, 0.95, 0.94, 1.0))
    for _ in range(400):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), 0.8, 0.8, 0.0, rng.choice([(1.0, 1.0, 1.0), (0.82, 0.83, 0.86)]))
    return c.save("item_salt")


def paint_bottle(rng):
    c = Canvas(color=(0.32, 0.15, 0.04, 1.0))
    for x in range(0, T, 20):
        c.rect(x, 0, x + 3, T, (0.55, 0.3, 0.1))  # 光の照り返し
    return c.save("item_bottle")


def paint_energy_label(rng):
    c = Canvas(color=(0.98, 0.82, 0.1, 1.0))
    c.rect(0, T * 0.4, T, T * 0.6, (0.8, 0.1, 0.08))
    for x in range(10, T - 10, 11):
        c.line(x, T * 0.44, x + 5, T * 0.56, 1.3, (1.0, 1.0, 0.95))
    c.ellipse(T * 0.2, T * 0.25, 8, 8, 0.0, (0.1, 0.35, 0.8))
    return c.save("item_energy_label")


def paint_dial(rng):
    c = Canvas(color=(0.93, 0.91, 0.84, 1.0))
    cx = cy = T / 2
    for k in range(32):
        a = k / 32 * math.tau
        r0 = 50 if k % 8 == 0 else 56
        c.line(cx + math.cos(a) * r0, cy + math.sin(a) * r0, cx + math.cos(a) * 60, cy + math.sin(a) * 60, 0.8, (0.1, 0.1, 0.1))
    for k, a in enumerate([-math.pi / 2, 0.0, math.pi / 2, math.pi]):
        c.ellipse(cx + math.cos(a) * 42, cy + math.sin(a) * 42, 4, 4, 0.0, (0.75, 0.08, 0.06) if k == 0 else (0.1, 0.1, 0.1))
    return c.save("item_dial")


def paint_berry(rng):
    c = Canvas(color=(0.72, 0.06, 0.1, 1.0))
    for y in range(0, T, 10):
        for x in range(0, T, 10):
            c.ellipse(x + (5 if (y // 10) % 2 else 0), y, 4.5, 4.5, 0.0, (0.9, 0.18, 0.2))
            c.ellipse(x + (5 if (y // 10) % 2 else 0) - 1.5, y - 1.5, 1.2, 1.2, 0.0, (1.0, 0.7, 0.7))
    return c.save("item_berry")


def paint_leaf(rng):
    c = Canvas()
    c.ellipse(T / 2, T / 2, T * 0.46, T * 0.22, 0.0, (0.25, 0.5, 0.15))
    c.line(8, T / 2, T - 8, T / 2, 0.8, (0.16, 0.35, 0.08))
    for k in range(6):
        x = 20 + k * 16
        c.line(x, T / 2, x + 10, T / 2 - 18, 0.5, (0.16, 0.35, 0.08))
        c.line(x, T / 2, x + 10, T / 2 + 18, 0.5, (0.16, 0.35, 0.08))
    return c.save("leaf_item_leaf")


def paint_chestnut(rng):
    c = Canvas(color=(0.38, 0.18, 0.08, 1.0))
    for x in range(T):
        f = 0.85 + 0.3 * math.sin(x / T * math.tau * 3)
        for y in range(T):
            i = (y * T + x) * 4
            c.px[i:i + 3] = [0.38 * f, 0.18 * f, 0.08 * f]
    c.rect(0, T * 0.8, T, T, (0.75, 0.62, 0.45))  # 下の白っぽい所
    for _ in range(12):
        c.line(rng.uniform(0, T), 0, rng.uniform(0, T), T * 0.8, 0.5, (0.25, 0.1, 0.04), 0.7)
    return c.save("item_chestnut")


def paint_burr(rng):
    c = Canvas()
    for _ in range(260):  # とげ（透ける）
        x, y = rng.uniform(0, T), rng.uniform(0, T)
        a = rng.uniform(0, math.tau)
        c.line(x, y, x + math.cos(a) * 9, y + math.sin(a) * 9, 0.6, rng.choice([(0.45, 0.4, 0.15), (0.35, 0.3, 0.1)]))
    return c.save("leaf_item_burr")


def paint_meat(rng, cooked=False):
    base = (0.45, 0.22, 0.1) if cooked else (0.68, 0.1, 0.12)
    fat = (0.62, 0.42, 0.22) if cooked else (0.95, 0.86, 0.8)
    c = Canvas(color=(*base, 1.0))
    c.noise(rng, 0.1, 2)
    for _ in range(18):  # 脂の筋（さし）
        x, y = rng.uniform(0, T), rng.uniform(0, T)
        c.line(x, y, x + rng.uniform(-30, 30), y + rng.uniform(-12, 12), rng.uniform(0.5, 1.5), fat, 0.8)
    if cooked:
        for k in range(0, T, 18):  # 焼き目
            c.line(0, k, T, k + 18, 2.0, (0.12, 0.06, 0.03), 0.9)
    return c.save("item_meat_cooked" if cooked else "item_meat_raw")


def paint_toasted_rice(rng):
    """焼きおにぎり：醤油を塗って焼いた、こんがりきつね色のご飯。網の焼き目"""
    c = Canvas(color=(0.66, 0.42, 0.18, 1.0))
    for _ in range(240):
        tone = rng.uniform(0.75, 1.25)
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), 2.2, 1.1, rng.uniform(0, 3), (0.72 * tone, 0.48 * tone, 0.22 * tone), 0.8)
    for _ in range(14):  # 醤油がしみて焦げた所
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(3, 7), rng.uniform(2, 5), rng.uniform(0, 3), (0.3, 0.15, 0.05), 0.6)
    for k in range(8, T, 40):  # 網の焼き目（まばらに、少しかすれて）
        c.line(0, k, T, k + 6, 1.1, (0.2, 0.1, 0.04), 0.55)
    return c.save("item_rice_toasted")


def paint_grilled_cap(rng):
    """焼きキノコのかさ：火が通って黒ずんだ紫茶色。焦げと、しみ出た汁のつや"""
    c = Canvas(color=(0.3, 0.12, 0.14, 1.0))
    c.noise(rng, 0.15, 3)
    for _ in range(30):
        c.line(rng.uniform(0, T), 0, rng.uniform(0, T), T, 0.6, (0.12, 0.05, 0.05), 0.6)
    for _ in range(10):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(2, 5), rng.uniform(2, 4), 0.0, (0.05, 0.03, 0.03), 0.7)
    return c.save("item_cap_grilled")


def paint_roasted_chestnut(rng):
    """焼き栗の殻：焦げて黒ずんだ茶色"""
    c = Canvas(color=(0.24, 0.1, 0.04, 1.0))
    for x in range(T):
        f = 0.8 + 0.3 * math.sin(x / T * math.tau * 3)
        for y in range(T):
            i = (y * T + x) * 4
            c.px[i:i + 3] = [0.24 * f, 0.1 * f, 0.04 * f]
    for _ in range(18):
        c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(2, 6), rng.uniform(1, 3), rng.uniform(0, 3), (0.06, 0.03, 0.02), 0.7)
    for x in (T * 0.25, T * 0.75):  # 焼いて割れた殻から、黄色い実がのぞく
        c.line(x, T * 0.15, x + 2, T * 0.75, 3.2, (0.95, 0.78, 0.3), 1.0)
        c.line(x - 2.5, T * 0.15, x - 0.5, T * 0.75, 0.8, (0.05, 0.02, 0.01), 0.9)
        c.line(x + 4.5, T * 0.15, x + 4.0, T * 0.75, 0.8, (0.05, 0.02, 0.01), 0.9)
    return c.save("item_chestnut_roasted")


def paint_fur(rng):
    c = Canvas(color=(0.36, 0.25, 0.16, 1.0))
    for _ in range(700):
        x, y = rng.uniform(0, T), rng.uniform(0, T)
        tone = rng.uniform(0.6, 1.3)
        c.line(x, y, x + rng.uniform(-2, 2), y + rng.uniform(4, 9), 0.4, (0.36 * tone, 0.25 * tone, 0.16 * tone), 0.8)
    return c.save("item_fur")


# --- モデル ---

def item_piton(rng, m):
    """ハーケン：先の尖った平たい鋼の板と、上の穴に掛けたカラビナ"""
    s = mk.Model("item_piton", rng)
    s.box((0, 0.02, 0), (0.028, 0.16, 0.006), m["item_steel"], density=D)
    s.tube([(0, -0.06, 0), (0, -0.1, 0), (0, -0.13, 0)], [0.012, 0.006, 0.0], m["item_steel"], sides=4, density=D, smooth=False)
    s.box((0, 0.11, 0.012), (0.03, 0.035, 0.03), m["item_steel"], density=D)  # 頭（打つ所）
    ring = [(math.cos(a) * 0.028 + 0.0, 0.14 + math.sin(a) * 0.04, 0.0) for a in [k / 12 * math.tau for k in range(13)]]
    s.tube(ring, [0.004] * 13, m["item_steel_dark"], sides=5, density=D)  # カラビナ
    s.box((0.028, 0.14, 0), (0.006, 0.04, 0.006), m["item_brass"], density=D)  # 開閉口
    return s.finish()


def item_bandage(rng, m):
    """包帯：巻いたガーゼと、ほどけた端、赤い十字の留め紙"""
    s = mk.Model("item_bandage", rng)
    s.cylinder((-0.04, 0, 0), 0.08, 0.055, 0.055, m["item_gauze"], sides=12, axis=(1, 0, 0), density=D)
    s.cylinder((-0.041, 0, 0), 0.082, 0.02, 0.02, m["item_cardboard"], sides=8, axis=(1, 0, 0), density=D)
    s.box((0.0, -0.058, 0.07), (0.075, 0.004, 0.13), m["item_gauze"], rot=(0.15, 0, 0), density=D)
    s.box((0.0, 0.0, 0.056), (0.03, 0.03, 0.003), m["item_first_aid"], density=D * 3)
    return s.finish()


def rounded_prism(s, outline, depth, bulge, mat, density):
    """角の丸い板（outline は XY の輪郭）。前後の面は少しふくらませる"""
    rings = []
    for z, grow in ((-depth / 2, 0.0), (-depth / 2 + depth * 0.2, bulge), (depth / 2 - depth * 0.2, bulge), (depth / 2, 0.0)):
        ring = []
        for (x, y) in outline:
            p = Vector((x, y, 0.0))
            p = p + p.normalized() * grow if p.length > 1e-6 else p
            ring.append(s.bm.verts.new(mk.G(p.x, p.y, z)))
        rings.append(ring)
    n = len(outline)
    for r in range(3):
        for i in range(n):
            j = (i + 1) % n
            quad = [rings[r][i], rings[r][j], rings[r + 1][j], rings[r + 1][i]]
            s._face(quad, [(i / n, r / 3), ((i + 1) / n, r / 3), ((i + 1) / n, (r + 1) / 3), (i / n, (r + 1) / 3)], mat)
    for ring, flip in ((rings[0], True), (rings[3], False)):
        center = s.bm.verts.new(sum((v.co for v in ring), Vector()) / n)
        for i in range(n):
            j = (i + 1) % n
            tri = [center, ring[j], ring[i]] if flip else [center, ring[i], ring[j]]
            uvs = [(0.5, 0.5), (0.5 + outline[j][0] * density, 0.5 + outline[j][1] * density), (0.5 + outline[i][0] * density, 0.5 + outline[i][1] * density)]
            s._face(tri, uvs if not flip else [uvs[0], uvs[1], uvs[2]], mat)


def item_onigiri(rng, m):
    """おにぎり：角の丸い三角のご飯に、海苔の帯と、てっぺんの梅干し"""
    s = mk.Model("item_onigiri", rng)
    outline = []
    corners = [(0.0, 0.06), (-0.065, -0.05), (0.065, -0.05)]
    for k in range(3):  # 三角の角を丸める
        cx, cy = corners[k]
        start = math.atan2(cy, cx) - math.pi / 3
        for j in range(5):
            a = start + j / 4 * (2 * math.pi / 3)
            outline.append((cx * 0.72 + math.cos(a) * 0.022, cy * 0.72 + math.sin(a) * 0.022))
    rounded_prism(s, outline, 0.05, 0.004, m["item_rice"], D)
    s.box((0, -0.04, 0.0), (0.07, 0.045, 0.062), m["item_nori"], density=D)
    s.tube([(0, 0.075, 0.02), (0, 0.083, 0.022), (0, 0.088, 0.022)], [0.012, 0.011, 0.0], m["item_ume"], sides=6, density=D)
    return s.finish()


def item_ofuda(rng, m):
    """お札：少し反った細長い紙に、朱の印と墨の呪文（暗い所でうっすら光る）"""
    s = mk.Model("item_ofuda", rng)
    for k in range(4):
        y = -0.1 + k * 0.05
        bend = math.sin(k * 0.8) * 0.004
        s.box((0, y + 0.025, bend), (0.07, 0.05, 0.003), m["item_ofuda"], rot=(0.04 * (k - 1.5), 0, 0), density=7.0)
    s.card((0, -0.07, 0.003), 0.06, 0.15, m["glow_ofuda_ink"], (0, 0, 1))
    return s.finish()


def item_rope(rng, m):
    """ロープ：橙の登山ロープを輪にして何重にも巻き、真ん中を縛ってある"""
    s = mk.Model("item_rope", rng)
    for k in range(5):
        pts = []
        for j in range(17):
            a = j / 16 * math.tau
            pts.append((math.cos(a) * (0.075 + k * 0.004), math.sin(a) * (0.1 + k * 0.004), -0.02 + k * 0.01))
        s.tube(pts, [0.009] * 17, m["item_rope"], sides=5, density=D)
    s.cylinder((0, 0.085, -0.03), 0.06, 0.02, 0.02, m["item_rope"], sides=6, axis=(0, 0, 1), density=D)  # 縛った所
    s.tube([(0.01, -0.1, 0.0), (0.03, -0.13, 0.01), (0.02, -0.16, 0.0)], [0.009, 0.009, 0.008], m["item_rope"], sides=5, density=D)
    return s.finish()


def item_flare(rng, m):
    """発煙筒：赤い筒に白い注意書きの帯、黒いふたと、こすって火をつける白い頭"""
    s = mk.Model("item_flare", rng)
    s.cylinder((0, -0.11, 0), 0.2, 0.022, 0.022, m["item_flare"], sides=10, density=D)
    s.cylinder((0, 0.09, 0), 0.035, 0.024, 0.024, m["item_black"], sides=10, density=D)
    s.cylinder((0, 0.125, 0), 0.015, 0.02, 0.014, m["item_striker"], sides=10, density=D)
    s.cylinder((0, -0.12, 0), 0.012, 0.024, 0.024, m["item_black"], sides=10, density=D)
    return s.finish()


def item_firecracker(rng, m):
    """爆竹：赤い紙の筒の束を金の紙で巻き、編んだ導火線が長く出ている"""
    s = mk.Model("item_firecracker", rng)
    for k in range(7):
        a = k / 6 * math.tau if k else 0.0
        r = 0.0 if k == 0 else 0.026
        s.cylinder((math.cos(a) * r, -0.05, math.sin(a) * r), 0.1, 0.012, 0.012, m["item_red_paper"], sides=8, density=D)
    s.cylinder((0, -0.02, 0), 0.03, 0.041, 0.041, m["item_wrapper"], sides=12, density=D)
    fuse = [(0, 0.05, 0), (0.01, 0.08, 0.005), (0.03, 0.1, 0.0), (0.05, 0.105, -0.01)]
    s.tube(fuse, [0.003] * 4, m["item_fuse"], sides=4, density=D)
    return s.finish()


def item_bell(rng, m):
    """熊よけの鈴：真鍮の丸い鈴（割れ目と中の玉）を、赤い紐と木の留め具に下げる"""
    s = mk.Model("item_bell", rng)
    shell = [(0, -0.045, 0), (0, -0.04, 0), (0, -0.02, 0), (0, 0.01, 0), (0, 0.035, 0), (0, 0.045, 0)]
    s.tube(shell, [0.02, 0.038, 0.046, 0.044, 0.03, 0.0], m["item_brass"], sides=12, density=D)
    s.box((0, -0.03, 0.0), (0.08, 0.006, 0.012), m["item_black"], density=D)  # 割れ目
    ring = [(0.0, 0.055 + math.sin(a) * 0.01, math.cos(a) * 0.01) for a in [k / 8 * math.tau for k in range(9)]]
    s.tube(ring, [0.003] * 9, m["item_brass"], sides=4, density=D)
    s.tube([(0, 0.065, 0), (0.005, 0.12, 0), (0, 0.17, 0)], [0.004, 0.004, 0.004], m["item_cord_red"], sides=5, density=D)
    s.cylinder((0, 0.17, -0.02), 0.04, 0.008, 0.008, m["item_wood"], sides=6, axis=(0, 0, 1), density=D)
    return s.finish()


def item_hand_warmer(rng, m):
    """カイロ：ふっくらした白い袋に、橙の印刷"""
    s = mk.Model("item_hand_warmer", rng)
    s.box((0, 0, 0), (0.1, 0.13, 0.012), m["item_warmer"], density=7.5, jitter=0.002)
    s.box((0, 0, 0), (0.09, 0.12, 0.02), m["item_warmer"], density=7.5, jitter=0.003)
    s.box((0, 0.067, 0), (0.1, 0.006, 0.006), m["item_warmer"], density=D)  # 閉じ口
    return s.finish()


def item_thermos(rng, m):
    """水筒：へこみのある銀の魔法瓶に、赤いコップのふたと肩掛けの紐"""
    s = mk.Model("item_thermos", rng)
    body = [(0, -0.1, 0), (0, -0.095, 0), (0, 0.06, 0), (0, 0.08, 0), (0, 0.09, 0)]
    s.tube(body, [0.03, 0.036, 0.036, 0.03, 0.022], m["item_steel"], sides=12, density=D, wobble=0.02)
    s.cylinder((0, 0.085, 0), 0.05, 0.026, 0.03, m["item_red_plastic"], sides=12, density=D)
    s.tube([(0.035, 0.07, 0), (0.07, 0.0, 0), (0.035, -0.08, 0)], [0.004] * 3, m["item_strap"], sides=4, density=D)
    return s.finish()


def item_chocolate(rng, m):
    """チョコ：半分むいた板チョコ。赤と金の包み紙から、割れた茶色の板がのぞく"""
    s = mk.Model("item_chocolate", rng)
    s.box((0, -0.025, 0), (0.08, 0.1, 0.017), m["item_wrapper"], density=7.0)
    s.box((0, 0.045, 0), (0.078, 0.06, 0.013), m["item_choco"], density=8.0)
    s.box((0, 0.076, 0.0), (0.078, 0.012, 0.013), m["item_choco"], rot=(0, 0, 0.12), density=8.0, jitter=0.002)
    s.card((0, 0.025, 0.009), 0.082, 0.035, m["leaf_foil"], (0, 0, 1), (0, 1, 0.4), bend=0.3)
    return s.finish()


def item_canned(rng, m):
    """缶詰：魚の絵の紙が巻かれたブリキ缶。ふちと、開けるための輪"""
    s = mk.Model("item_canned", rng)
    s.cylinder((0, -0.035, 0), 0.07, 0.04, 0.04, m["item_steel"], sides=14, density=D)
    s.cylinder((0, -0.024, 0), 0.048, 0.0412, 0.0412, m["item_can_label"], sides=14, density=6.0, cap=False)
    for y in (-0.035, 0.033):
        s.cylinder((0, y, 0), 0.004, 0.042, 0.042, m["item_steel"], sides=14, density=D)
    ring = [(math.cos(a) * 0.012 + 0.018, 0.038, math.sin(a) * 0.008) for a in [k / 10 * math.tau for k in range(11)]]
    s.tube(ring, [0.002] * 11, m["item_steel"], sides=4, density=D)
    return s.finish()


def item_chalk(rng, m):
    """チョーク：青い筒形のチョーク袋。口から白い粉がのぞき、しぼり紐とベルト通しがつく"""
    s = mk.Model("item_chalk", rng)
    bag = [(0, -0.06, 0), (0, -0.055, 0), (0, 0.03, 0), (0, 0.05, 0)]
    s.tube(bag, [0.03, 0.05, 0.05, 0.046], m["item_nylon_blue"], sides=12, density=D, cap=False, wobble=0.04)
    s.cylinder((0, -0.06, 0), 0.004, 0.049, 0.049, m["item_nylon_blue"], sides=12, density=D)
    s.cylinder((0, 0.05, 0), 0.01, 0.052, 0.052, m["item_black"], sides=12, density=D)  # 口のふち
    s.cylinder((0, 0.035, 0), 0.02, 0.043, 0.04, m["item_chalk"], sides=10, density=D)  # 粉
    s.tube([(0.04, 0.05, 0.02), (0.06, 0.02, 0.03), (0.055, -0.01, 0.035)], [0.003] * 3, m["item_black"], sides=4, density=D)
    s.box((0, -0.01, -0.052), (0.05, 0.05, 0.008), m["item_strap"], density=D)
    return s.finish()


def item_crampons(rng, m):
    """アイゼン：靴底の形の鉄の枠に、下向きの爪が 10 本と、前へ突き出た 2 本の前爪。赤いベルト"""
    s = mk.Model("item_crampons", rng)
    steel = m["item_steel"]
    for x in (-0.035, 0.035):
        s.box((x, 0, 0), (0.008, 0.012, 0.21), steel, density=D)
    for z in (-0.08, 0.0, 0.08):
        s.box((0, 0, z), (0.078, 0.012, 0.008), steel, density=D)
    for x in (-0.035, 0.035):
        for z in (-0.09, -0.045, 0.0, 0.045, 0.09):
            s.tube([(x, -0.006, z), (x, -0.04, z + 0.004)], [0.005, 0.0], steel, sides=4, density=D, smooth=False)
    for x in (-0.02, 0.02):
        s.tube([(x, 0.0, 0.105), (x, -0.012, 0.14)], [0.005, 0.0], steel, sides=4, density=D, smooth=False)  # 前爪
    for z in (-0.06, 0.05):
        s.box((0, 0.02, z), (0.1, 0.006, 0.02), m["item_strap_red"], density=D)
        s.box((0.052, 0.0, z), (0.004, 0.04, 0.02), m["item_strap_red"], density=D)
        s.box((-0.052, 0.0, z), (0.004, 0.04, 0.02), m["item_strap_red"], density=D)
    s.box((0.058, 0.02, 0.05), (0.012, 0.014, 0.024), m["item_steel_dark"], density=D)  # 留め金
    return s.finish()


def item_first_aid(rng, m):
    """救急箱：白い十字の赤い箱。取っ手と留め金"""
    s = mk.Model("item_first_aid", rng)
    s.box((0, 0, 0), (0.16, 0.11, 0.06), m["item_first_aid"], density=6.2)
    s.box((0, 0.0, 0), (0.162, 0.006, 0.062), m["item_black"], density=D)  # ふたの合わせ目
    s.tube([(-0.035, 0.055, 0), (-0.03, 0.075, 0), (0.03, 0.075, 0), (0.035, 0.055, 0)], [0.006] * 4, m["item_black"], sides=5, density=D)
    for x in (-0.05, 0.05):
        s.box((x, 0.0, 0.031), (0.016, 0.014, 0.004), m["item_steel"], density=D)
    return s.finish()


def item_omamori(rng, m):
    """お守り：金の刺繍の錦の袋。上で結んだ紐の輪"""
    s = mk.Model("item_omamori", rng)
    s.box((0, 0, 0), (0.05, 0.075, 0.012), m["item_brocade"], density=D * 2, jitter=0.001)
    s.box((0, 0.037, 0), (0.052, 0.008, 0.014), m["item_brocade"], rot=(0, 0, 0.1), density=D * 2)
    knot = [(math.cos(a) * 0.012, 0.055 + math.sin(a) * 0.014, 0) for a in [k / 10 * math.tau for k in range(11)]]
    s.tube(knot, [0.0025] * 11, m["item_cord_gold"], sides=4, density=D)
    for side in (-1, 1):
        s.tube([(side * 0.005, 0.045, 0.004), (side * 0.012, 0.03, 0.009), (side * 0.014, 0.02, 0.01)], [0.0022] * 3, m["item_cord_gold"], sides=4, density=D)
    return s.finish()


def item_mushroom(rng, m):
    """謎のキノコ：紫のかさに、青白く光る斑点の、細いキノコの群れ"""
    s = mk.Model("item_mushroom", rng)
    for k, (x, z, h, r) in enumerate([(0, 0, 0.08, 0.045), (0.035, 0.02, 0.055, 0.03), (-0.03, 0.018, 0.045, 0.024)]):
        lean = 0.01 * (k - 1)
        s.tube([(x, -0.04, z), (x + lean, -0.04 + h * 0.6, z), (x + lean * 2, -0.04 + h, z)], [0.008, 0.007, 0.006], m["item_stem"], sides=6, density=D)
        top = -0.04 + h
        cap = [(x + lean * 2, top - 0.004, z), (x + lean * 2, top + 0.006, z), (x + lean * 2, top + r * 0.55, z), (x + lean * 2, top + r * 0.7, z)]
        s.tube(cap, [0.0, r, r * 0.7, 0.0], m["item_mushroom_cap"], sides=10, density=D)
        for j in range(5):
            a = j / 5 * math.tau + k
            s.box((x + lean * 2 + math.cos(a) * r * 0.55, top + r * 0.4, z + math.sin(a) * r * 0.55), (0.007, 0.004, 0.007), m["glow_spots"], rot=(0.4, a, 0))
    return s.finish()


def item_salt(rng, m):
    """清めの塩：朱の印を押した白い紙の包みと、小皿に盛った塩"""
    s = mk.Model("item_salt", rng)
    s.cylinder((0, -0.035, 0), 0.012, 0.05, 0.04, m["item_clay"], sides=12, density=D)
    s.tube([(0, -0.024, 0), (0, -0.01, 0), (0, 0.02, 0), (0, 0.035, 0)], [0.04, 0.035, 0.015, 0.0], m["item_salt"], sides=10, density=D)
    s.box((0.02, -0.02, 0.05), (0.06, 0.012, 0.045), m["item_salt_paper"], rot=(0, 0.4, 0.05), density=D * 1.2)
    return s.finish()


def item_energy(rng, m):
    """栄養ドリンク：茶色い小瓶に、黄色と赤の帯、金のふた"""
    s = mk.Model("item_energy", rng)
    bottle = [(0, -0.05, 0), (0, -0.048, 0), (0, 0.025, 0), (0, 0.04, 0), (0, 0.05, 0)]
    s.tube(bottle, [0.02, 0.024, 0.024, 0.014, 0.012], m["item_bottle"], sides=12, density=D)
    s.cylinder((0, -0.03, 0), 0.045, 0.0245, 0.0245, m["item_energy_label"], sides=12, density=6.5, cap=False)
    s.cylinder((0, 0.048, 0), 0.016, 0.013, 0.013, m["item_brass"], sides=10, density=D)
    return s.finish()


def item_compass(rng, m):
    """方位磁石：真鍮のふちの丸い磁石。白い文字盤に赤と白の針、ひもを通す輪"""
    s = mk.Model("item_compass", rng)
    s.cylinder((0, -0.01, 0), 0.02, 0.046, 0.046, m["item_brass"], sides=16, density=D)
    s.cylinder((0, 0.009, 0), 0.003, 0.04, 0.04, m["item_dial"], sides=16, density=10.0)
    s.box((0, 0.012, 0.014), (0.006, 0.003, 0.028), m["item_red_plastic"], density=D)
    s.box((0, 0.012, -0.014), (0.006, 0.003, 0.028), m["item_white"], density=D)
    s.cylinder((0, 0.012, 0), 0.004, 0.005, 0.005, m["item_brass"], sides=6, density=D)
    ring = [(0.0, 0.0 + math.sin(a) * 0.008, 0.052 + math.cos(a) * 0.008) for a in [k / 8 * math.tau for k in range(9)]]
    s.tube(ring, [0.0025] * 9, m["item_brass"], sides=4, density=D)
    return s.finish()


def item_nata(rng, m):
    """ナタ：四角い先の、厚い鋼の刃（刃先は白く研がれている）。木の柄に赤い紐を巻き、金具の口金"""
    s = mk.Model("item_nata", rng)
    s.box((0, 0.15, 0), (0.055, 0.25, 0.008), m["item_steel_dark"], density=D)
    s.box((0.03, 0.15, 0), (0.008, 0.25, 0.005), m["item_edge"], density=D)  # 研いだ刃先
    s.box((0.005, 0.28, 0), (0.06, 0.012, 0.007), m["item_edge"], rot=(0, 0, 0.08), density=D)  # 四角い先
    s.box((-0.024, 0.15, 0), (0.008, 0.25, 0.012), m["item_steel_dark"], density=D)  # 背の厚み
    s.box((0, 0.018, 0), (0.05, 0.02, 0.022), m["item_brass"], density=D)  # 口金
    s.cylinder((0, -0.13, 0), 0.14, 0.017, 0.019, m["item_wood"], sides=8, density=D)
    s.cylinder((0, -0.1, 0), 0.08, 0.0195, 0.0195, m["item_cord_red"], sides=8, density=D, cap=False)
    s.cylinder((0, -0.14, 0), 0.012, 0.02, 0.02, m["item_steel"], sides=8, density=D)  # 柄じり
    return s.finish()


def item_berries(rng, m):
    """木の実：木いちごの赤い実をひとつかみ。葉を 2 枚そえて"""
    s = mk.Model("item_berries", rng)
    for k in range(9):
        a = k * 2.4
        r = 0.012 + (k % 3) * 0.012
        c = (math.cos(a) * r, -0.01 + (k % 4) * 0.009, math.sin(a) * r)
        s.tube([(c[0], c[1] - 0.012, c[2]), (c[0], c[1], c[2]), (c[0], c[1] + 0.012, c[2])], [0.009, 0.014, 0.004], m["item_berry"], sides=8, density=D)
    s.card((0.0, 0.0, 0.0), 0.04, 0.07, m["leaf_item_leaf"], (0.3, 1, 0.2), (1, 0.2, 0.3))
    s.card((0.0, 0.0, 0.0), 0.035, 0.06, m["leaf_item_leaf"], (-0.3, 1, 0.2), (-1, 0.3, -0.4))
    return s.finish()


def item_chestnut(rng, m):
    """栗：つやのある栗が 3 つと、割れて口を開けたとげとげの毬"""
    s = mk.Model("item_chestnut", rng)
    for k in range(3):
        a = k / 3 * math.tau
        c = Vector((math.cos(a) * 0.028, -0.01, math.sin(a) * 0.028))
        s.tube([tuple(c + Vector((0, -0.022, 0))), tuple(c + Vector((0, -0.01, 0))), tuple(c + Vector((0, 0.012, 0))), tuple(c + Vector((0, 0.028, 0)))],
               [0.02, 0.025, 0.02, 0.0], m["item_chestnut"], sides=10, density=D)
    burr = Vector((0.05, 0.0, -0.05))
    s.tube([tuple(burr + Vector((0, -0.03, 0))), tuple(burr + Vector((0, 0.0, 0))), tuple(burr + Vector((0, 0.02, 0)))], [0.03, 0.035, 0.02], m["item_burr_body"], sides=8, density=D, cap=True)
    for k in range(10):
        a = k / 10 * math.tau
        s.card(tuple(burr + Vector((math.cos(a) * 0.03, -0.01, math.sin(a) * 0.03))), 0.035, 0.03, m["leaf_item_burr"], (math.cos(a), 0, math.sin(a)), (math.cos(a) * 0.6, 0.8, math.sin(a) * 0.6))
    return s.finish()


def item_raw_meat(rng, m):
    """生肉：さしの入った赤い肉の塊。白い脂の縁と、切り口からのぞく骨"""
    s = mk.Model("item_raw_meat", rng)
    s.box((0, 0, 0), (0.14, 0.045, 0.1), m["item_meat_raw"], rot=(0, 0.3, 0), density=D, jitter=0.006)
    s.box((0.01, 0.018, 0.035), (0.14, 0.014, 0.03), m["item_fat"], rot=(0, 0.3, 0), density=D, jitter=0.004)
    s.cylinder((-0.07, 0.0, -0.02), 0.06, 0.012, 0.012, m["item_bone"], sides=8, axis=(-1, 0, -0.3), density=D)
    s.tube([(-0.13, 0.0, -0.04), (-0.135, 0.0, -0.04), (-0.14, 0.0, -0.04)], [0.016, 0.018, 0.0], m["item_bone"], sides=8, density=D)
    return s.finish()


def item_cooked_meat(rng, m):
    """焼いた肉：こんがり焼き目のついた肉を、串に刺して"""
    s = mk.Model("item_cooked_meat", rng)
    for k in range(3):
        s.box((-0.03 + k * 0.045, 0, 0), (0.04, 0.045, 0.06), m["item_meat_cooked"], rot=(k * 0.4, 0.2, 0), density=D, jitter=0.006)
    s.cylinder((-0.1, 0, 0), 0.24, 0.004, 0.003, m["item_wood"], sides=5, axis=(1, 0, 0), density=D)
    return s.finish()


def item_pelt(rng, m):
    """毛皮：たたんだ獣の毛皮を、紐で縛ってある"""
    s = mk.Model("item_pelt", rng)
    s.box((0, 0, 0), (0.18, 0.05, 0.14), m["item_fur"], density=7.0, jitter=0.008)
    s.box((0, 0.028, -0.02), (0.17, 0.02, 0.1), m["item_fur"], rot=(0.1, 0, 0), density=7.0, jitter=0.006)
    s.box((0.0, -0.028, 0.0), (0.17, 0.008, 0.13), m["item_hide"], density=7.0)  # 裏の皮
    for x in (-0.05, 0.05):
        s.box((x, 0.0, 0.0), (0.012, 0.064, 0.145), m["item_cord_brown"], density=D)
    return s.finish()


def item_kumanoi(rng, m):
    """熊の胆：黒く干からびた、しわだらけの袋を、麻紐で縛って和紙の札をつけたもの"""
    s = mk.Model("item_kumanoi", rng)
    pouch = [(0, -0.05, 0), (0, -0.04, 0), (0, -0.01, 0), (0.005, 0.02, 0), (0.0, 0.04, 0), (0, 0.055, 0)]
    s.tube(pouch, [0.012, 0.03, 0.036, 0.03, 0.016, 0.0], m["item_bile"], sides=9, density=D, wobble=0.18)
    s.cylinder((0, 0.035, 0), 0.008, 0.018, 0.018, m["item_cord_brown"], sides=6, density=D)
    s.tube([(0.0, 0.043, 0.0), (0.02, 0.06, 0.01), (0.035, 0.05, 0.015)], [0.0025] * 3, m["item_cord_brown"], sides=4, density=D)
    s.box((0.045, 0.035, 0.015), (0.018, 0.045, 0.003), m["item_ofuda"], rot=(0, 0.3, 0.2), density=D * 1.5)
    return s.finish()


def item_yaki_onigiri(rng, m):
    """焼きおにぎり：醤油を塗って網で焼いた三角のおにぎりを、竹串に刺して"""
    s = mk.Model("item_yaki_onigiri", rng)
    outline = []
    corners = [(0.0, 0.06), (-0.065, -0.05), (0.065, -0.05)]
    for k in range(3):
        cx, cy = corners[k]
        start = math.atan2(cy, cx) - math.pi / 3
        for j in range(5):
            a = start + j / 4 * (2 * math.pi / 3)
            outline.append((cx * 0.72 + math.cos(a) * 0.022, cy * 0.72 + math.sin(a) * 0.022))
    rounded_prism(s, outline, 0.05, 0.004, m["item_rice_toasted"], D)
    s.cylinder((0, -0.13, 0), 0.16, 0.004, 0.003, m["item_wood"], sides=5, density=D)
    return s.finish()


def item_grilled_mushroom(rng, m):
    """焼きキノコ：軸を取ったかさを 3 枚、真ん中を竹串で刺してあぶったもの（もう光らない）"""
    s = mk.Model("item_grilled_mushroom", rng)
    for k, (y, r) in enumerate([(0.055, 0.03), (0.0, 0.034), (-0.055, 0.029)]):
        tilt = 0.12 * (k - 1)
        # かさ：裏（ひだの面）を後ろへ、丸い表を前へ向けたドーム
        cap = [(0.0, y, -0.006), (0.0, y + tilt * 0.01, -0.002), (0.0, y, r * 0.45), (0.0, y, r * 0.62)]
        s.tube(cap, [r * 0.9, r, r * 0.72, 0.0], m["item_cap_grilled"], sides=12, density=D)
        s.tube([(0.0, y, -0.0065), (0.0, y, -0.006)], [0.0, r * 0.88], m["item_stem_grilled"], sides=12, density=D)  # ひだの面
    s.cylinder((0.0, -0.12, 0.0), 0.22, 0.004, 0.003, m["item_wood"], sides=5, density=D)
    return s.finish()


def item_roasted_chestnut(rng, m):
    """焼き栗：割れ目から黄色い実がのぞく、焦げた栗を 4 つ、茶色い紙の上に"""
    s = mk.Model("item_roasted_chestnut", rng)
    s.box((0, -0.036, 0), (0.12, 0.004, 0.11), m["item_cardboard"], rot=(0, 0.3, 0.02), density=D)
    for k in range(4):
        a = k / 4 * math.tau + 0.4
        c = Vector((math.cos(a) * 0.03, -0.01, math.sin(a) * 0.03))
        s.tube([tuple(c + Vector((0, -0.022, 0))), tuple(c + Vector((0, -0.01, 0))), tuple(c + Vector((0, 0.012, 0))), tuple(c + Vector((0, 0.028, 0)))],
               [0.02, 0.025, 0.02, 0.0], m["item_chestnut_roasted"], sides=10, density=D)
    return s.finish()


BUILDERS = {
    "piton": item_piton, "bandage": item_bandage, "onigiri": item_onigiri, "ofuda": item_ofuda, "rope": item_rope,
    "flare": item_flare, "firecracker": item_firecracker, "bell": item_bell, "hand_warmer": item_hand_warmer, "thermos": item_thermos,
    "chocolate": item_chocolate, "canned": item_canned, "chalk": item_chalk, "crampons": item_crampons, "first_aid": item_first_aid,
    "omamori": item_omamori, "mushroom": item_mushroom, "salt": item_salt, "energy": item_energy, "compass": item_compass,
    "nata": item_nata, "berries": item_berries, "chestnut": item_chestnut, "raw_meat": item_raw_meat, "cooked_meat": item_cooked_meat,
    "pelt": item_pelt, "kumanoi": item_kumanoi, "yaki_onigiri": item_yaki_onigiri, "grilled_mushroom": item_grilled_mushroom,
    "roasted_chestnut": item_roasted_chestnut,
}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [a for a in args if not a.startswith("--")] or list(BUILDERS)
    mk.lib.reset()
    rng = random.Random(9090)
    images = {
        "item_steel": paint_steel(rng, "item_steel"), "item_steel_dark": paint_steel(rng, "item_steel_dark", (0.32, 0.33, 0.35)),
        "item_edge": paint_steel(rng, "item_edge", (0.85, 0.87, 0.9)), "item_wood": paint_wood(rng),
        "item_cord_red": paint_cord(rng, "item_cord_red", (0.72, 0.1, 0.08), (0.45, 0.05, 0.04)),
        "item_cord_gold": paint_cord(rng, "item_cord_gold", (0.92, 0.72, 0.28), (0.6, 0.42, 0.12)),
        "item_cord_brown": paint_cord(rng, "item_cord_brown", (0.55, 0.42, 0.25), (0.35, 0.25, 0.14)),
        "item_fuse": paint_cord(rng, "item_fuse", (0.35, 0.3, 0.22), (0.15, 0.12, 0.08)),
        "item_rope": paint_rope(rng), "item_gauze": paint_gauze(rng), "item_rice": paint_rice(rng), "item_nori": paint_nori(rng),
        "item_ume": paint_plain(rng, "item_ume", (0.75, 0.1, 0.12), 0.15), "item_ofuda": paint_ofuda(rng), "glow_ofuda_ink": paint_ofuda_ink(rng),
        "item_flare": paint_flare(rng), "item_black": paint_plain(rng, "item_black", (0.08, 0.08, 0.09)),
        "item_striker": paint_plain(rng, "item_striker", (0.9, 0.88, 0.8), 0.15), "item_red_paper": paint_red_paper(rng),
        "item_wrapper": paint_wrapper(rng), "item_brass": paint_brass(rng), "item_warmer": paint_warmer(rng),
        "item_red_plastic": paint_plain(rng, "item_red_plastic", (0.78, 0.12, 0.1), 0.04),
        "item_strap": paint_nylon(rng, "item_strap", (0.12, 0.12, 0.14)), "item_strap_red": paint_nylon(rng, "item_strap_red", (0.75, 0.12, 0.08)),
        "item_choco": paint_choco(rng), "leaf_foil": paint_plain(rng, "leaf_foil", (0.8, 0.8, 0.82), 0.2),
        "item_can_label": paint_can_label(rng), "item_nylon_blue": paint_nylon(rng, "item_nylon_blue", (0.15, 0.3, 0.62)),
        "item_chalk": paint_chalk_dust(rng), "item_first_aid": paint_first_aid(rng), "item_brocade": paint_brocade(rng),
        "item_mushroom_cap": paint_mushroom_cap(rng), "glow_spots": paint_glow_spots(rng),
        "item_stem": paint_plain(rng, "item_stem", (0.85, 0.82, 0.74)), "item_clay": paint_plain(rng, "item_clay", (0.35, 0.25, 0.18), 0.1),
        "item_salt": paint_salt(rng), "item_salt_paper": paint_salt_paper(rng), "item_bottle": paint_bottle(rng),
        "item_energy_label": paint_energy_label(rng), "item_dial": paint_dial(rng), "item_white": paint_plain(rng, "item_white", (0.95, 0.95, 0.95)),
        "item_berry": paint_berry(rng), "leaf_item_leaf": paint_leaf(rng), "item_chestnut": paint_chestnut(rng),
        "leaf_item_burr": paint_burr(rng), "item_burr_body": paint_plain(rng, "item_burr_body", (0.4, 0.34, 0.14), 0.2),
        "item_meat_raw": paint_meat(rng), "item_meat_cooked": paint_meat(rng, True), "item_fat": paint_plain(rng, "item_fat", (0.95, 0.88, 0.82)),
        "item_bone": paint_plain(rng, "item_bone", (0.88, 0.84, 0.74)), "item_fur": paint_fur(rng),
        "item_hide": paint_plain(rng, "item_hide", (0.72, 0.58, 0.42), 0.1), "item_cardboard": paint_plain(rng, "item_cardboard", (0.6, 0.48, 0.32)),
        "item_bile": paint_plain(rng, "item_bile", (0.14, 0.09, 0.05), 0.35),
        "item_rice_toasted": paint_toasted_rice(rng), "item_cap_grilled": paint_grilled_cap(rng),
        "item_stem_grilled": paint_plain(rng, "item_stem_grilled", (0.62, 0.48, 0.32), 0.15),
        "item_chestnut_roasted": paint_roasted_chestnut(rng),
    }
    materials = {name: mk.material(name, image, name.startswith("leaf_")) for name, image in images.items()}
    for index, name in enumerate(names):
        obj = BUILDERS[name](random.Random(900 + index * 17), materials)
        mk.export(obj)
        if "--preview" in sys.argv:
            mk.preview(obj, 0.5)
        bpy.data.objects.remove(obj, do_unlink=True)
        bpy.context.view_layer.update()


main()
