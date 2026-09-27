"""Blender でヘリコプターのモデルを作る：訓練場のヘリポートに止まっているヘリと、島の浜辺に墜落したヘリの残骸。

使い方（Blender 4.5 で実行する）:
    blender -b --factory-startup --python tools/props/build_heli.py [-- heli heli_wreck --preview]

座標は Godot の向き（Y が上）。機首は -Z（前）、乗り口の扉は +X（右）の側。原点は着陸用の脚の下（地面）の真ん中。
"""
import math
import os
import random
import sys

import bpy
from mathutils import Euler, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meshkit as mk  # noqa: E402
from meshkit import Canvas  # noqa: E402

T = mk.TEX


# --- 模様 ---

def paint_body(rng, scorched=False):
    """機体の塗装：白に赤い帯と紺の細い帯、機体番号。墜落したものは、すすと焦げ跡と、はがれた塗装"""
    c = Canvas(color=(0.9, 0.9, 0.88, 1.0))
    # 帯は、胴体の筒にそって前後に走るように、縦に描く（筒の横は、模様の左右のはし）
    for u0, u1, color in ((0.0, 0.06, (0.72, 0.1, 0.08)), (0.94, 1.0, (0.72, 0.1, 0.08)), (0.44, 0.56, (0.72, 0.1, 0.08)),
                          (0.07, 0.09, (0.1, 0.14, 0.32)), (0.41, 0.43, (0.1, 0.14, 0.32))):
        c.rect(T * u0, 0, T * u1, T, color)
    for y in range(10, T - 10, 16):  # 機体番号のつもりの字
        c.line(T * 0.2, y, T * 0.28, y + 8, 1.4, (0.12, 0.12, 0.14))
        c.line(T * 0.28, y, T * 0.21, y + 8, 1.4, (0.12, 0.12, 0.14))
    for _ in range(30):  # 継ぎ目とリベット
        x = rng.uniform(0, T)
        c.line(x, 0, x, T, 0.3, (0.6, 0.6, 0.6), 0.5)
    c.noise(rng, 0.04, 2)
    if scorched:
        for _ in range(26):
            c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(6, 22), rng.uniform(4, 14), rng.uniform(0, 3),
                      rng.choice([(0.08, 0.07, 0.07), (0.2, 0.17, 0.15), (0.35, 0.3, 0.26)]), rng.uniform(0.5, 0.9))
        for _ in range(12):  # はがれて見える地金
            c.ellipse(rng.uniform(0, T), rng.uniform(0, T), rng.uniform(2, 6), rng.uniform(2, 5), 0.0, (0.55, 0.56, 0.58), 0.8)
    return c.save("heli_body_wreck" if scorched else "heli_body")


def paint_glass(rng, broken=False):
    c = Canvas(color=(0.1, 0.16, 0.22, 1.0))
    for _ in range(6):
        x = rng.uniform(0, T)
        c.line(x, 0, x + 30, T, 3.0, (0.3, 0.4, 0.5), 0.5)  # 照り返し
    if broken:
        for _ in range(14):  # ひび
            x, y = rng.uniform(0, T), rng.uniform(0, T)
            for k in range(5):
                a = k / 5 * math.tau + rng.uniform(-0.3, 0.3)
                c.line(x, y, x + math.cos(a) * rng.uniform(8, 25), y + math.sin(a) * rng.uniform(8, 25), 0.5, (0.85, 0.9, 0.95), 0.8)
    return c.save("heli_glass_broken" if broken else "heli_glass")


def paint_metal(rng, name, base):
    c = Canvas(color=(*base, 1.0))
    for _ in range(50):
        x, y = rng.uniform(0, T), rng.uniform(0, T)
        c.line(x, y, x + rng.uniform(-12, 12), y + rng.uniform(-2, 2), 0.4, (base[0] * 1.3, base[1] * 1.3, base[2] * 1.3), 0.5)
    c.noise(rng, 0.06, 2)
    return c.save(name)


def paint_seat(rng):
    c = Canvas(color=(0.18, 0.2, 0.28, 1.0))
    for k in range(0, T, 10):
        c.line(0, k, T, k, 0.6, (0.12, 0.13, 0.18), 0.8)
    c.noise(rng, 0.06, 2)
    return c.save("heli_seat")


def paint_stain(rng):
    """地面にしみた燃料と、焦げ跡（透ける）"""
    c = Canvas()
    for _ in range(60):
        c.ellipse(T / 2 + rng.gauss(0, 18), T / 2 + rng.gauss(0, 18), rng.uniform(4, 14), rng.uniform(3, 10), rng.uniform(0, 3),
                  rng.choice([(0.05, 0.05, 0.05), (0.12, 0.1, 0.08)]), 0.9)
    return c.save("leaf_heli_stain")


def paint_paper(rng):
    c = Canvas()
    c.rect(20, 20, T - 20, T - 20, (0.9, 0.9, 0.86))
    for y in range(30, T - 30, 8):
        c.line(28, y, T - 28, y, 0.6, (0.3, 0.3, 0.32))
    return c.save("leaf_heli_paper")


# --- 形 ---

def fuselage(s, m, xf, crumpled=False):
    """胴体・操縦席の窓・扉・エンジンの覆い・脚・回転翼の軸。xf(点) で置き場所と傾きを変える"""
    body = m["heli_body_wreck"] if crumpled else m["heli_body"]
    glass = m["heli_glass_broken"] if crumpled else m["heli_glass"]
    nose = -2.2 if crumpled else -2.6
    pts = [(0, 1.35, 2.0), (0, 1.4, 1.2), (0, 1.45, 0.0), (0, 1.4, -1.2), (0, 1.3, -1.9), (0, 1.15, nose)]
    radii = [0.8, 1.05, 1.15, 1.12, 0.9, 0.35]
    s.tube([xf(p) for p in pts], radii, body, sides=12, density=0.35, cap=True, wobble=0.06 if crumpled else 0.0)
    # 操縦席の大きな窓（前と横）
    for k in range(5):
        a = -1.1 + k * 0.55
        center = Vector((math.sin(a) * 1.02, 1.75, -1.55 - math.cos(a) * 0.35))
        s.box(tuple(xf(center)), (0.55, 0.62, 0.05), glass, rot=_rot(xf, (0.3, a, 0.0)), density=1.2)
    for side in (-1, 1):
        s.box(tuple(xf(Vector((side * 1.13, 1.65, -0.5)))), (0.05, 0.55, 0.9), glass, rot=_rot(xf, (0, 0, 0)), density=1.2)
    # 右の、横に開く扉（少し開いている）
    s.box(tuple(xf(Vector((1.18, 1.3, 0.35)))), (0.06, 1.3, 1.2), body, rot=_rot(xf, (0, 0.12, 0)), density=0.6)
    # エンジンの覆いと、回転翼の軸
    s.box(tuple(xf(Vector((0, 2.5, 0.4)))), (1.0, 0.55, 1.9), body, rot=_rot(xf, (0, 0, 0)), density=0.6)
    s.cylinder(tuple(xf(Vector((0, 2.75, 0.0)))), 0.45, 0.12, 0.1, m["heli_metal"], sides=8, axis=tuple(_dir(xf, (0, 1, 0))))
    s.cylinder(tuple(xf(Vector((0, 3.18, 0.0)))), 0.14, 0.3, 0.3, m["heli_metal_dark"], sides=10, axis=tuple(_dir(xf, (0, 1, 0))))


def _dir(xf, v):
    return (xf(Vector(v)) - xf(Vector((0, 0, 0)))).normalized()


def _rot(xf, local_rot):
    """xf の傾きを、箱の回転に足す"""
    basis = _basis(xf) @ Euler(local_rot, 'XYZ').to_matrix()
    return basis.to_euler('XYZ')


def _basis(xf):
    o = xf(Vector((0, 0, 0)))
    from mathutils import Matrix
    return Matrix((xf(Vector((1, 0, 0))) - o, xf(Vector((0, 1, 0))) - o, xf(Vector((0, 0, 1))) - o)).transposed()


def tail(s, m, xf):
    """尾：細くなる尾の筒、縦の翼、横の小さな翼、後ろの回転翼"""
    s.tube([xf(Vector(p)) for p in [(0, 1.55, 1.8), (0, 1.75, 4.0), (0, 1.95, 6.3)]], [0.36, 0.24, 0.16], m["heli_body"], sides=8, density=0.4)
    s.box(tuple(xf(Vector((0, 2.5, 6.4)))), (0.08, 1.2, 0.7), m["heli_body"], rot=_rot(xf, (-0.3, 0, 0)), density=0.8)
    s.box(tuple(xf(Vector((0, 1.95, 5.6)))), (1.3, 0.06, 0.4), m["heli_body"], rot=_rot(xf, (0, 0, 0)), density=0.8)
    for a in (0.0, math.pi / 2):
        s.box(tuple(xf(Vector((0.14, 2.55, 6.55)))), (0.04, 1.1, 0.12), m["heli_metal_dark"], rot=_rot(xf, (a, 0, 0)), density=1.0)


def skids(s, m, xf, broken=False):
    for side in (-1, 1):
        if broken and side > 0:
            s.tube([xf(Vector(p)) for p in [(side * 0.95, 0.08, -1.6), (side * 1.0, 0.08, -0.2), (side * 1.4, 0.3, 0.3)]], [0.05] * 3, m["heli_metal_dark"], sides=6, density=1.0)
            continue
        s.tube([xf(Vector(p)) for p in [(side * 0.95, 0.35, -2.0), (side * 0.95, 0.08, -1.6), (side * 0.95, 0.08, 1.3)]], [0.05] * 3, m["heli_metal_dark"], sides=6, density=1.0)
        for z in (-1.0, 0.8):
            s.tube([xf(Vector((side * 0.95, 0.08, z))), xf(Vector((side * 0.7, 0.8, z)))], [0.045, 0.045], m["heli_metal_dark"], sides=6, density=1.0)


def build_heli(rng, m):
    """ヘリポートに止まっている、霊峰行きのヘリ"""
    s = mk.Model("prop_heli", rng)
    xf = lambda p: Vector(p)  # noqa: E731
    fuselage(s, m, xf)
    tail(s, m, xf)
    skids(s, m, xf)
    for k in range(4):  # 回転翼（4 枚）
        a = k * math.pi / 2 + 0.3
        d = Vector((math.cos(a), 0, math.sin(a)))
        s.box(tuple(Vector((0, 3.24, 0)) + d * 2.8), (5.2, 0.05, 0.32), m["heli_metal_dark"], rot=(0, -a, 0.02), density=0.6)
    return s.finish()


def build_heli_wreck(rng, m):
    """浜辺に墜落したヘリ：横倒しの胴体、ちぎれて転がった尾、折れ曲がった回転翼、割れた窓、すすと焦げ跡、散らばった物"""
    s = mk.Model("prop_heli_wreck", rng)
    roll = math.radians(72)
    tilt = Euler((math.radians(-8), math.radians(20), roll), 'XYZ').to_matrix()

    def xf(p):  # 右へ横倒しにして、砂にめりこませる
        return tilt @ Vector(p) + Vector((1.3, -0.35, 0))

    fuselage(s, m, xf, crumpled=True)
    skids(s, m, xf, broken=True)
    # ちぎれて転がった尾（少し離れた所に、斜めに）
    tail_tilt = Euler((math.radians(10), math.radians(-35), math.radians(15)), 'XYZ').to_matrix()

    def tail_xf(p):
        return tail_tilt @ (Vector(p) - Vector((0, 1.6, 1.6))) + Vector((-1.5, 0.35, 4.2))

    tail(s, m, tail_xf)
    s.tube([tail_xf(Vector((0, 1.55, 1.7))), tail_xf(Vector((0.1, 1.5, 1.4)))], [0.37, 0.3], m["heli_metal_dark"], sides=8, density=0.6)  # ちぎれ口
    # 折れ曲がった回転翼：1 枚は根もとから砂に突き刺さり、1 枚は途中で折れて垂れ、2 枚は遠くへ飛んだ
    hub = xf(Vector((0, 3.2, 0)))
    s.box(tuple(hub + Vector((-1.2, -0.6, -0.4))), (2.8, 0.05, 0.3), m["heli_metal_dark"], rot=(0.2, 0.4, 0.5), density=0.6)
    s.box(tuple(hub + Vector((-0.6, 0.3, 1.3))), (0.3, 0.05, 2.6), m["heli_metal_dark"], rot=(0.8, 0.2, 0.1), density=0.6)
    for pos, rot in (((-4.5, 0.08, -2.5), (0.05, 0.9, 0.02)), ((4.8, 0.1, 3.2), (0.1, -0.4, 0.05))):
        s.box(pos, (3.4, 0.05, 0.3), m["heli_metal_dark"], rot=rot, density=0.6)
    # 散らばった物：座席、スーツケース、救命胴衣、書類、燃料のしみ
    s.box((3.4, 0.35, -1.2), (0.55, 0.7, 0.55), m["heli_seat"], rot=(0.4, 0.8, 0.2), density=1.5)
    s.box((2.6, 0.22, 2.2), (0.7, 0.45, 0.25), m["heli_case"], rot=(0.0, 0.5, 0.1), density=1.5)
    s.box((-2.4, 0.08, -0.8), (0.45, 0.16, 0.55), m["heli_vest"], rot=(0.1, 0.3, 0.05), density=1.5)
    for k in range(6):
        s.card((rng.uniform(-3, 4), 0.03, rng.uniform(-3, 3)), 0.28, 0.35, m["leaf_heli_paper"], (0, 1, 0), (rng.uniform(-1, 1), 0.05, rng.uniform(-1, 1)))
    s.card((0.8, 0.02, 0.5), 5.5, 5.5, m["leaf_heli_stain"], (0, 1, 0), (0, 0, 1))
    return s.finish()


BUILDERS = {"heli": build_heli, "heli_wreck": build_heli_wreck}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [a for a in args if not a.startswith("--")] or list(BUILDERS)
    mk.lib.reset()
    rng = random.Random(5150)
    images = {
        "heli_body": paint_body(rng), "heli_body_wreck": paint_body(rng, True), "heli_glass": paint_glass(rng),
        "heli_glass_broken": paint_glass(rng, True), "heli_metal": paint_metal(rng, "heli_metal", (0.6, 0.62, 0.64)),
        "heli_metal_dark": paint_metal(rng, "heli_metal_dark", (0.2, 0.21, 0.23)), "heli_seat": paint_seat(rng),
        "heli_case": paint_metal(rng, "heli_case", (0.5, 0.18, 0.12)), "heli_vest": paint_metal(rng, "heli_vest", (0.95, 0.5, 0.08)),
        "leaf_heli_stain": paint_stain(rng), "leaf_heli_paper": paint_paper(rng),
    }
    materials = {name: mk.material(name, image, name.startswith("leaf_")) for name, image in images.items()}
    for index, name in enumerate(names):
        obj = BUILDERS[name](random.Random(77 + index), materials)
        mk.export(obj)
        if "--preview" in sys.argv:
            mk.preview(obj, 0.3)
        bpy.data.objects.remove(obj, do_unlink=True)
        bpy.context.view_layer.update()


main()
