"""Blender で草木（と、山に転がっている物）のモデルを作る。

使い方（Blender 4.5 で実行する）:
    blender -b --factory-startup --python tools/flora/build_flora.py [-- 名前 名前 ...]

どれも、幹や枝は輪切りをつないだ筒（樹皮の模様を UV で巻く）、葉は葉の絵を描いた薄い板（カード）で作る。
葉の絵と樹皮の模様は、ここで 1 画素ずつ描いて、PS1 らしい小さな画像（128 画素）にする。
1 つのモデルは 1 つのメッシュで、素材は「樹皮」（bark_*）と「葉」（leaf_*）の 2 つ。
Godot 側（Flora）は、素材の名前が leaf_ で始まる面を、裏からも見えて透ける葉の素材で描く。

座標は Blender の向き（Z が上）。原点は根元。書き出すと Godot では Y が上になる。
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "creatures"))
import creature_lib as lib  # noqa: E402

OUT = os.path.join(lib.PROJECT, "tools", "flora", "out")
TEX = 128


# --- 画像を描く ---

class Canvas:
    """RGBA の小さな画像。左右（と上下）はつながっていて、端を越えた所は反対側に描く"""

    def __init__(self, size=TEX, color=(0.0, 0.0, 0.0, 0.0)):
        self.size = size
        self.px = list(color) * (size * size)

    def blend(self, x, y, color, alpha=1.0):
        s = self.size
        i = ((y % s) * s + (x % s)) * 4
        a = alpha * (color[3] if len(color) > 3 else 1.0)
        old_a = self.px[i + 3]
        for k in range(3):
            self.px[i + k] = self.px[i + k] * (1.0 - a) + color[k] * a if old_a > 0.0 else color[k]
        self.px[i + 3] = max(old_a, a)

    def ellipse(self, cx, cy, rx, ry, angle, color, alpha=1.0):
        """傾いた楕円を塗る"""
        c, s = math.cos(angle), math.sin(angle)
        reach = int(max(rx, ry)) + 1
        for dy in range(-reach, reach + 1):
            for dx in range(-reach, reach + 1):
                u = (dx * c + dy * s) / max(rx, 0.5)
                v = (-dx * s + dy * c) / max(ry, 0.5)
                if u * u + v * v <= 1.0:
                    self.blend(int(cx) + dx, int(cy) + dy, color, alpha)

    def line(self, x0, y0, x1, y1, width, color, alpha=1.0):
        steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for k in range(steps + 1):
            t = k / steps
            self.ellipse(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, width, width, 0.0, color, alpha)

    def save(self, name):
        image = bpy.data.images.new(name, self.size, self.size, alpha=True)
        image.pixels = self.px
        image.filepath_raw = os.path.join(OUT, name + ".png")
        os.makedirs(OUT, exist_ok=True)
        image.file_format = 'PNG'
        image.save()
        image.pack()
        return image


def jitter(color, rng, amount=0.12):
    f = rng.uniform(1.0 - amount, 1.0 + amount)
    return (min(color[0] * f, 1.0), min(color[1] * f, 1.0), min(color[2] * f, 1.0), 1.0)


def voronoi_plates(canvas, rng, base, crack, count=18):
    """ひび割れた樹皮の板（ボロノイ模様。端はつながる）"""
    s = canvas.size
    points = [(rng.uniform(0, s), rng.uniform(0, s), rng.uniform(0.8, 1.15)) for _ in range(count)]
    for y in range(s):
        for x in range(s):
            best, second, shade = 1e9, 1e9, 1.0
            for px, py, f in points:
                dx = min(abs(x - px), s - abs(x - px))
                dy = min(abs(y - py), s - abs(y - py)) * 0.55  # 縦長の板
                d = dx * dx + dy * dy
                if d < best:
                    second, best, shade = best, d, f
                elif d < second:
                    second = d
            edge = math.sqrt(second) - math.sqrt(best)
            color = crack if edge < 1.6 else tuple(min(c * shade, 1.0) for c in base)
            i = (y * s + x) * 4
            canvas.px[i:i + 4] = [color[0], color[1], color[2], 1.0]


# --- 樹皮と葉の絵 ---

def bark_cedar(rng):
    """杉：赤茶色の、縦に裂けた繊維"""
    c = Canvas(color=(0.34, 0.2, 0.13, 1.0))
    for _ in range(90):
        x = rng.uniform(0, TEX)
        shade = rng.choice([(0.26, 0.15, 0.1), (0.45, 0.28, 0.18), (0.4, 0.24, 0.16), (0.22, 0.13, 0.09)])
        width = rng.uniform(0.6, 1.8)
        y = rng.uniform(0, TEX)
        length = rng.uniform(20, 70)
        c.line(x, y, x + rng.uniform(-3, 3), y + length, width, shade, 0.8)
    return c.save("bark_cedar")


def bark_pine(rng):
    """松：黒ずんだ、亀の甲のような板状の樹皮"""
    c = Canvas()
    voronoi_plates(c, rng, (0.32, 0.26, 0.22), (0.1, 0.08, 0.07), 22)
    return c.save("bark_pine")


def bark_birch(rng):
    """白樺：白い樹皮に、横向きの黒い皮目と黒い傷"""
    c = Canvas(color=(0.86, 0.85, 0.8, 1.0))
    for _ in range(40):
        c.ellipse(rng.uniform(0, TEX), rng.uniform(0, TEX), rng.uniform(4, 12), rng.uniform(0.6, 1.4), 0.0, (0.1, 0.1, 0.1), 0.9)
    for _ in range(8):
        c.ellipse(rng.uniform(0, TEX), rng.uniform(0, TEX), rng.uniform(6, 14), rng.uniform(3, 7), rng.uniform(-0.3, 0.3), (0.2, 0.19, 0.17), 0.8)
    for _ in range(30):
        c.ellipse(rng.uniform(0, TEX), rng.uniform(0, TEX), rng.uniform(2, 6), rng.uniform(1, 3), 0.0, (0.75, 0.74, 0.7), 0.6)
    return c.save("bark_birch")


def bark_bamboo(rng):
    """竹：つやのある緑に、細い縦すじ"""
    c = Canvas(color=(0.42, 0.55, 0.22, 1.0))
    for _ in range(30):
        x = rng.uniform(0, TEX)
        c.line(x, 0, x, TEX, 0.5, rng.choice([(0.36, 0.48, 0.18), (0.5, 0.62, 0.3)]), 0.6)
    return c.save("bark_bamboo")


def bark_dead(rng):
    """枯れ木：灰色にさらされ、縦に裂けた樹皮"""
    c = Canvas(color=(0.5, 0.48, 0.45, 1.0))
    for _ in range(70):
        x = rng.uniform(0, TEX)
        y = rng.uniform(0, TEX)
        c.line(x, y, x + rng.uniform(-2, 2), y + rng.uniform(15, 60), rng.uniform(0.5, 1.4),
               rng.choice([(0.35, 0.33, 0.3), (0.62, 0.6, 0.56), (0.28, 0.26, 0.24)]), 0.8)
    return c.save("bark_dead")


def wood_cut(rng):
    """切り口：年輪"""
    c = Canvas(color=(0.62, 0.48, 0.32, 1.0))
    center = TEX / 2
    for r in range(3, 64, 4):
        wobble = rng.uniform(0.9, 1.1)
        for k in range(120):
            a = k / 120 * math.tau
            c.blend(int(center + math.cos(a) * r * wobble), int(center + math.sin(a) * r), (0.45, 0.32, 0.2), 0.8)
    for y in range(TEX):
        for x in range(TEX):
            if (x - center) ** 2 + (y - center) ** 2 > 62 ** 2:
                i = (y * TEX + x) * 4
                c.px[i:i + 4] = [0.34, 0.2, 0.13, 1.0]
    return c.save("wood_cut")


def leaf_cedar(rng):
    """杉の葉：下から扇のように伸びる小枝に、とがった葉がびっしり付く"""
    c = Canvas()
    darks = [(0.1, 0.2, 0.09), (0.14, 0.26, 0.11), (0.18, 0.31, 0.12)]
    for _ in range(9):
        x0 = TEX / 2 + rng.uniform(-10, 10)
        angle = rng.uniform(-1.0, 1.0)
        length = rng.uniform(55, 110)
        steps = int(length / 3)
        for k in range(steps):
            t = k / steps
            x = x0 + math.sin(angle) * length * t
            y = 4 + math.cos(angle) * length * t
            width = (1.0 - t) * 11 + 3
            for side in (-1, 1):
                c.ellipse(x + side * width * 0.5, y, width * 0.5, 1.6, side * 0.5 + angle, jitter(rng.choice(darks), rng), 1.0)
    return c.save("leaf_cedar")


def leaf_pine(rng):
    """松の葉：細い針が放射状に集まった房"""
    c = Canvas()
    for _ in range(20):
        cx, cy = rng.uniform(18, TEX - 18), rng.uniform(18, TEX - 18)
        for _ in range(36):
            a = rng.uniform(0, math.tau)
            length = rng.uniform(10, 22)
            color = jitter(rng.choice([(0.12, 0.24, 0.12), (0.18, 0.32, 0.15), (0.1, 0.19, 0.1)]), rng)
            c.line(cx, cy, cx + math.cos(a) * length, cy + math.sin(a) * length, 0.7, color)
    return c.save("leaf_pine")


def leaf_broad(rng, name="leaf_broad", colors=((0.36, 0.5, 0.2), (0.45, 0.6, 0.25), (0.28, 0.42, 0.16))):
    """広葉樹の葉：小さな楕円の葉が、丸い房になって重なる"""
    c = Canvas()
    for _ in range(7):
        cx, cy, r = rng.uniform(28, TEX - 28), rng.uniform(28, TEX - 28), rng.uniform(16, 26)
        for _ in range(40):
            a = rng.uniform(0, math.tau)
            d = r * math.sqrt(rng.uniform(0, 1))
            c.ellipse(cx + math.cos(a) * d, cy + math.sin(a) * d, rng.uniform(3, 5), rng.uniform(1.8, 2.8), rng.uniform(0, math.tau),
                      jitter(rng.choice(colors), rng), 1.0)
    return c.save(name)


def leaf_bamboo(rng):
    """竹の葉：細長い葉が、垂れ下がるように何枚も並ぶ"""
    c = Canvas()
    for k in range(7):
        x = 12 + k * 17 + rng.uniform(-4, 4)
        length = rng.uniform(70, 110)
        angle = rng.uniform(-0.25, 0.25)
        steps = 30
        for i in range(steps):
            t = i / steps
            width = math.sin(t * math.pi) * 6 + 0.8
            c.ellipse(x + math.sin(angle) * length * t, 4 + math.cos(angle) * length * t, width, 2.2, angle,
                      jitter((0.36, 0.52, 0.2), rng, 0.08))
    return c.save("leaf_bamboo")


def leaf_fern(rng):
    """シダの葉：まん中の軸の左右に、小葉が並び、先ほど小さくなる（下から上へ伸びる 1 枚）"""
    c = Canvas()
    steps = 22
    for i in range(steps):
        t = i / steps
        y = 3 + t * (TEX - 8)
        length = (1.0 - t) * 52 + 6
        for side in (-1, 1):
            for k in range(6):
                u = k / 6
                c.ellipse(TEX / 2 + side * (3 + u * length), y + u * length * 0.35, 3.2 * (1 - u * 0.6), 2.2, side * 0.35,
                          jitter((0.3, 0.48, 0.18), rng, 0.1))
    c.line(TEX / 2, 2, TEX / 2, TEX - 4, 0.9, (0.3, 0.36, 0.14))
    return c.save("leaf_fern")


def leaf_sasa(rng):
    """笹の葉：幅の広い、先のとがった葉が 5 枚、扇のように開く"""
    c = Canvas()
    for k in range(5):
        angle = -0.9 + k * 0.45 + rng.uniform(-0.1, 0.1)
        length = rng.uniform(80, 115)
        steps = 34
        for i in range(steps):
            t = i / steps
            width = math.sin(min(t * 1.25, 1.0) * math.pi) * 9 + 0.6
            c.ellipse(TEX / 2 + math.sin(angle) * length * t, 4 + math.cos(angle) * length * t, width, 2.4, angle,
                      jitter((0.28, 0.44, 0.17) if k % 2 else (0.34, 0.5, 0.2), rng, 0.06))
    return c.save("leaf_sasa")


def leaf_burr(rng):
    """栗の毬：黄緑の玉に、細いとげが四方へ"""
    c = Canvas()
    center = TEX / 2
    for _ in range(90):
        ang = rng.uniform(0, math.tau)
        length = rng.uniform(40, 60)
        c.line(center, center, center + math.cos(ang) * length, center + math.sin(ang) * length, 0.8, jitter((0.62, 0.7, 0.25), rng))
    c.ellipse(center, center, 34, 34, 0.0, (0.55, 0.64, 0.22))
    return c.save("leaf_burr")


def leaf_moss(rng):
    """苔とこけの生えた小枝"""
    return leaf_broad(rng, "leaf_moss", ((0.3, 0.42, 0.16), (0.36, 0.48, 0.18), (0.24, 0.34, 0.12)))


# --- 形を組む ---

class Plant:
    """1 つのメッシュに、筒（樹皮の素材）と葉のカード（葉の素材）を足していく"""

    def __init__(self, name, rng):
        self.name = name
        self.rng = rng
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.materials = []

    def material_index(self, material):
        if material not in self.materials:
            self.materials.append(material)
        return self.materials.index(material)

    def tube(self, points, radii, material, sides=7, v_scale=0.5, cap=False, wobble=0.0):
        """points をつなぐ筒。radii は各点の半径。樹皮の模様は、1 周で横 1 枚、縦は v_scale 枚/m"""
        index = self.material_index(material)
        rings = []
        length = 0.0
        side = None
        for k, (point, radius) in enumerate(zip(points, radii)):
            point = Vector(point)
            before = Vector(points[max(k - 1, 0)])
            after = Vector(points[min(k + 1, len(points) - 1)])
            axis = (after - before).normalized()
            # 輪の向きは、前の輪から少しずつ回して引き継ぐ（筒がねじれないように）
            if side is None:
                reference = Vector((0.0, 0.0, 1.0)) if abs(axis.z) < 0.9 else Vector((1.0, 0.0, 0.0))
                side = axis.cross(reference).normalized()
            else:
                side = (side - axis * side.dot(axis)).normalized()
            up = axis.cross(side).normalized()
            if k > 0:
                length += (point - Vector(points[k - 1])).length
            ring = []
            for s in range(sides + 1):
                a = s / sides * math.tau
                r = radius * (1.0 + (self.rng.uniform(-wobble, wobble) if s < sides else 0.0))
                ring.append((self.bm.verts.new(point + (side * math.cos(a) + up * math.sin(a)) * r), s / sides, length * v_scale))
            rings.append(ring)
        for k in range(len(rings) - 1):
            for s in range(sides):
                quad = [rings[k][s], rings[k][s + 1], rings[k + 1][s + 1], rings[k + 1][s]]
                face = self.bm.faces.new([q[0] for q in quad])
                face.material_index = index
                face.smooth = True
                for loop, q in zip(face.loops, quad):
                    loop[self.uv].uv = (q[1], q[2])
        if cap:
            last = rings[-1][:sides]
            face = self.bm.faces.new([q[0] for q in last])
            face.material_index = index
            for loop, q in zip(face.loops, last):
                loop[self.uv].uv = (0.5 + (q[0].co - Vector(points[-1])).x, 0.5)

    def card(self, center, width, height, material, facing, up=Vector((0.0, 0.0, 1.0)), bend=0.0, uv=(0.0, 0.0, 1.0, 1.0)):
        """葉のカード：center を下辺の中央に、up の向きへ height、横へ width の板。bend で先を facing のほうへ曲げる"""
        index = self.material_index(material)
        center, facing, up = Vector(center), Vector(facing).normalized(), Vector(up).normalized()
        side = up.cross(facing)
        if side.length < 1e-4:
            side = Vector((1.0, 0.0, 0.0))
        side.normalize()
        rows = 3 if bend != 0.0 else 1
        verts = []
        for r in range(rows + 1):
            t = r / rows
            lift = up * height * t + facing * bend * t * t * height
            verts.append([
                (self.bm.verts.new(center + lift - side * width * 0.5), uv[0], uv[1] + (uv[3] - uv[1]) * t),
                (self.bm.verts.new(center + lift + side * width * 0.5), uv[2], uv[1] + (uv[3] - uv[1]) * t),
            ])
        for r in range(rows):
            quad = [verts[r][0], verts[r][1], verts[r + 1][1], verts[r + 1][0]]
            face = self.bm.faces.new([q[0] for q in quad])
            face.material_index = index
            for loop, q in zip(face.loops, quad):
                loop[self.uv].uv = (q[1], q[2])

    def cluster(self, center, radius, count, size, material, droop=0.0):
        """葉のカードを、球の中にばらばらの向きで散らした房"""
        for _ in range(count):
            direction = Vector((self.rng.uniform(-1, 1), self.rng.uniform(-1, 1), self.rng.uniform(-0.6, 1))).normalized()
            base = Vector(center) + direction * radius * self.rng.uniform(0.2, 0.8)
            facing = Vector((self.rng.uniform(-1, 1), self.rng.uniform(-1, 1), self.rng.uniform(-0.3, 0.3))).normalized()
            up = (direction + Vector((0.0, 0.0, 0.6 - droop))).normalized()
            s = size * self.rng.uniform(0.8, 1.2)
            self.card(base - up * s * 0.4, s, s, material, facing, up)

    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for material in self.materials:
            mesh.materials.append(material)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
        print("BUILT", self.name, tris, "triangles")
        return obj


def material(name, image, leaf):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes['Principled BSDF']
    texture = nodes.new('ShaderNodeTexImage')
    texture.image = image
    texture.interpolation = 'Closest'
    links.new(texture.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.9
    if leaf:
        round_node = nodes.new('ShaderNodeMath')
        round_node.operation = 'ROUND'
        links.new(texture.outputs['Alpha'], round_node.inputs[0])
        links.new(round_node.outputs[0], bsdf.inputs['Alpha'])
        m.use_backface_culling = False
    return m


def bent_path(rng, start, direction, length, segments, curl=0.25, droop=0.0):
    """start から direction へ伸びる、少しずつ曲がる道すじ"""
    points = [Vector(start)]
    d = Vector(direction).normalized()
    step = length / segments
    for _ in range(segments):
        d = (d + Vector((rng.uniform(-curl, curl), rng.uniform(-curl, curl), rng.uniform(-curl, curl) * 0.5 - droop))).normalized()
        points.append(points[-1] + d * step)
    return points


# --- 草木 ---

def build_cedar(rng, m):
    """杉：まっすぐ高い幹に、下向きに垂れた枝が何段も重なり、細長い円すいの樹形になる"""
    p = Plant("flora_cedar", rng)
    height = 13.0
    trunk = [Vector((rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), z)) for z in (0.0, 0.5, 2.0, 4.5, 7.0, 9.5, 11.5, height)]
    p.tube(trunk, [0.46, 0.34, 0.3, 0.26, 0.2, 0.14, 0.08, 0.03], m["bark_cedar"], sides=8, v_scale=0.35, wobble=0.04)
    golden = 2.39996
    angle = rng.uniform(0, math.tau)
    z = 3.2
    while z < height - 0.6:
        t = (z - 3.2) / (height - 3.2)
        reach = 2.3 * (1.0 - t) ** 0.85 + 0.35
        for _ in range(4):
            angle += golden
            out = Vector((math.cos(angle), math.sin(angle), 0.0))
            axis = trunk[0].lerp(trunk[-1], z / height)
            tip = axis + out * reach + Vector((0.0, 0.0, -0.35 * reach))
            p.tube([axis, axis + out * reach * 0.5 + Vector((0, 0, -0.08 * reach)), tip], [0.07 * (1 - t) + 0.02, 0.035, 0.012], m["bark_cedar"], sides=4)
            for k, along in enumerate((0.45, 0.8)):
                base = axis.lerp(tip, along)
                size = reach * (0.75 if k else 0.9)
                p.card(base - Vector((0, 0, size * 0.25)), size * 1.1, size, m["leaf_cedar"], out, Vector((0, 0, 1)) + out * 0.4)
                side = out.cross(Vector((0, 0, 1)))
                p.card(base - Vector((0, 0, size * 0.2)), size, size * 0.9, m["leaf_cedar"], side, Vector((0, 0, 1)) + out * 0.8)
        z += 0.62
    # てっぺんの、とがった穂先
    top = trunk[-1]
    for k in range(4):
        a = k * math.pi / 2
        p.card(top - Vector((0, 0, 1.2)), 0.9, 1.8, m["leaf_cedar"], Vector((math.cos(a), math.sin(a), 0)))
    return p.finish()


def build_pine(rng, m):
    """松：くねって傾いた幹から枝が横へ張り出し、先に平たい雲のような葉の塊がのる"""
    p = Plant("flora_pine", rng)
    trunk = bent_path(rng, (0, 0, 0), (0.25, 0.1, 1.0), 5.2, 6, curl=0.35)
    radii = [0.3 - k * 0.035 for k in range(len(trunk))]
    p.tube(trunk, radii, m["bark_pine"], sides=7, v_scale=0.4, wobble=0.06)
    pads = [trunk[-1] + Vector((0, 0, 0.3))]
    for k in range(8):
        start = trunk[2 + k % 4]
        a = rng.uniform(0, math.tau)
        branch = bent_path(rng, start, (math.cos(a), math.sin(a), 0.25), rng.uniform(1.4, 2.4), 3, curl=0.3)
        p.tube(branch, [0.1, 0.07, 0.05, 0.03], m["bark_pine"], sides=5)
        pads.append(branch[-1])
    for pad in pads:
        radius = rng.uniform(1.0, 1.5)
        for _ in range(16):
            a = rng.uniform(0, math.tau)
            d = radius * math.sqrt(rng.uniform(0, 1))
            base = pad + Vector((math.cos(a) * d, math.sin(a) * d, rng.uniform(-0.1, 0.25)))
            facing = Vector((0, 0, 1)).lerp(Vector((math.cos(a), math.sin(a), 0)), 0.3)
            p.card(base - Vector((math.cos(a + 1.5), math.sin(a + 1.5), 0)) * 0.7, 1.5, 1.4, m["leaf_pine"], Vector((0, 0, 1)),
                   Vector((math.cos(a + 1.5), math.sin(a + 1.5), rng.uniform(-0.15, 0.25))))
        for k in range(6):
            a = k * math.tau / 6 + rng.uniform(-0.3, 0.3)
            p.card(pad + Vector((math.cos(a), math.sin(a), 0)) * radius * 0.7 - Vector((0, 0, 0.3)), 1.5, 0.8,
                   m["leaf_pine"], Vector((math.cos(a), math.sin(a), 0)))
    return p.finish()


def build_birch(rng, m):
    """白樺：細く白い幹が上で枝分かれし、明るい緑の葉の房がふんわり付く"""
    p = Plant("flora_birch", rng)
    trunk = bent_path(rng, (0, 0, 0), (0.05, 0.0, 1.0), 8.5, 7, curl=0.08)
    p.tube(trunk, [0.18, 0.15, 0.14, 0.12, 0.1, 0.08, 0.06, 0.03], m["bark_birch"], sides=7, v_scale=0.3)
    tips = [trunk[-1]]
    for k in range(5):
        start = trunk[3 + k % 4]
        a = rng.uniform(0, math.tau)
        branch = bent_path(rng, start, (math.cos(a), math.sin(a), 1.2), rng.uniform(1.5, 2.6), 3, curl=0.2)
        p.tube(branch, [0.06, 0.045, 0.03, 0.015], m["bark_birch"], sides=5)
        tips.append(branch[-1])
    for tip in tips:
        p.cluster(tip, rng.uniform(1.0, 1.4), 12, 1.1, m["leaf_broad"], droop=0.3)
    return p.finish()


def build_bamboo(rng, m):
    """竹やぶ：節のある細い竹が十数本、少しずつ傾いて立ち、上のほうで細い葉が垂れる"""
    p = Plant("flora_bamboo", rng)
    for _ in range(13):
        base = Vector((rng.uniform(-1.6, 1.6), rng.uniform(-1.6, 1.6), 0.0))
        height = rng.uniform(7.5, 10.5)
        lean = Vector((rng.uniform(-0.08, 0.08), rng.uniform(-0.08, 0.08), 1.0)).normalized()
        nodes = int(height / 1.1)
        points, radii = [], []
        for k in range(nodes + 1):
            points.append(base + lean * (k * height / nodes) + Vector((0, 0, 0)) * 0)
            radii.append(0.065 - k * 0.002)
        p.tube(points, radii, m["bark_bamboo"], sides=6, v_scale=0.9)
        for k in range(nodes // 2, nodes + 1):
            point = base + lean * (k * height / nodes)
            for _ in range(2):
                a = rng.uniform(0, math.tau)
                facing = Vector((math.cos(a), math.sin(a), 0))
                p.card(point, 1.0, 1.4, m["leaf_bamboo"], facing, Vector((math.cos(a), math.sin(a), 0.5)), bend=-0.5)
    return p.finish()


def build_sasa(rng, m):
    """笹やぶ：ひざの高さほどの細い茎の先に、幅の広い葉が開く"""
    p = Plant("flora_sasa", rng)
    for _ in range(14):
        base = Vector((rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7), 0))
        height = rng.uniform(0.2, 0.45)
        top = base + Vector((rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), height))
        p.tube([base, top], [0.012, 0.008], m["bark_bamboo"], sides=3)
        a = rng.uniform(0, math.tau)
        for k in range(3):
            facing = Vector((math.cos(a + k * 2.1), math.sin(a + k * 2.1), 0))
            p.card(top - Vector((0, 0, 0.12)), 0.6, 0.55, m["leaf_sasa"], facing, (Vector((0, 0, 1)) + facing * 0.5).normalized(), bend=0.45)
    return p.finish()


def build_fern(rng, m):
    """シダ：根元から羽のような葉が、外へ弧を描いて垂れる"""
    p = Plant("flora_fern", rng)
    for k in range(9):
        a = k / 9 * math.tau + rng.uniform(-0.2, 0.2)
        out = Vector((math.cos(a), math.sin(a), 0))
        length = rng.uniform(0.7, 1.0)
        p.card(out * 0.05, 0.42, length, m["leaf_fern"], out, (Vector((0, 0, 1)) + out * 0.7).normalized(), bend=0.55)
    return p.finish()


def build_bush(rng, m):
    """低木：細い枝が何本も伸び、葉の房がこんもり重なる"""
    p = Plant("flora_bush", rng)
    for _ in range(6):
        a = rng.uniform(0, math.tau)
        branch = bent_path(rng, (0, 0, 0), (math.cos(a) * 0.6, math.sin(a) * 0.6, 1.0), rng.uniform(0.8, 1.3), 2, curl=0.3)
        p.tube(branch, [0.04, 0.025, 0.01], m["bark_pine"], sides=4)
        p.cluster(branch[-1], 0.55, 6, 0.8, m["leaf_broad"])
    p.cluster((0, 0, 0.6), 0.6, 8, 0.9, m["leaf_broad"])
    return p.finish()


def build_stump(rng, m):
    """切り株：年輪の見える切り口、地面をつかむ太い根、苔"""
    p = Plant("flora_stump", rng)
    p.tube([(0, 0, 0), (0, 0, 0.35), (0, 0, 0.65)], [0.5, 0.42, 0.4], m["bark_cedar"], sides=10, v_scale=0.5, wobble=0.05)
    center = Vector((0, 0, 0.66))
    index = p.material_index(m["wood_cut"])
    ring = [p.bm.verts.new(center + Vector((math.cos(k / 10 * math.tau) * 0.4, math.sin(k / 10 * math.tau) * 0.4, rng.uniform(-0.04, 0.04)))) for k in range(10)]
    face = p.bm.faces.new(ring)
    face.material_index = index
    for loop, k in zip(face.loops, range(10)):
        loop[p.uv].uv = (0.5 + math.cos(k / 10 * math.tau) * 0.48, 0.5 + math.sin(k / 10 * math.tau) * 0.48)
    for k in range(5):
        a = k / 5 * math.tau + rng.uniform(-0.3, 0.3)
        out = Vector((math.cos(a), math.sin(a), 0))
        p.tube([out * 0.3 + Vector((0, 0, 0.3)), out * 0.6 + Vector((0, 0, 0.1)), out * 0.95 + Vector((0, 0, -0.1))], [0.12, 0.08, 0.03], m["bark_cedar"], sides=5)
    p.cluster((0.15, 0.2, 0.55), 0.3, 4, 0.4, m["leaf_moss"])
    return p.finish()


def build_log(rng, m):
    """倒木：苔むした太い幹が横たわり、根元は折れてささくれ、枝の折れ残りが突き出る（長さ 5 m、x 方向）"""
    p = Plant("flora_log", rng)
    points = [Vector((x, rng.uniform(-0.05, 0.05), 0.33)) for x in (-2.5, -1.2, 0.0, 1.2, 2.5)]
    p.tube(points, [0.3, 0.33, 0.35, 0.37, 0.39], m["bark_cedar"], sides=9, v_scale=0.4, wobble=0.05)
    # 折れた根元のささくれ
    for k in range(7):
        a = k / 7 * math.tau
        base = Vector((2.5, math.cos(a) * 0.3, 0.33 + math.sin(a) * 0.3))
        p.tube([base, base + Vector((rng.uniform(0.2, 0.5), math.cos(a) * 0.05, math.sin(a) * 0.05))], [0.07, 0.0], m["bark_cedar"], sides=3)
    for _ in range(3):
        x = rng.uniform(-2.0, 1.8)
        a = rng.uniform(-1.2, 1.2)
        start = Vector((x, 0, 0.6))
        p.tube([start, start + Vector((rng.uniform(-0.2, 0.2), math.sin(a) * 0.9, math.cos(a) * 0.9))], [0.07, 0.02], m["bark_cedar"], sides=4)
    for _ in range(5):
        p.cluster((rng.uniform(-2.2, 2.2), rng.uniform(-0.1, 0.1), 0.62), 0.25, 3, 0.45, m["leaf_moss"])
    p.card((-1.0, 0.3, 0.1), 0.45, 0.8, m["leaf_fern"], Vector((0, 1, 0)), Vector((0, 0.6, 1)), bend=0.4)
    return p.finish()


def build_dead(rng, m):
    """枯れ木：葉のない灰色の幹が裂けてねじれ、折れた枝が空をつかむように伸びる"""
    p = Plant("flora_dead", rng)
    trunk = bent_path(rng, (0, 0, 0), (0.1, 0.05, 1.0), 7.0, 6, curl=0.22)
    p.tube(trunk, [0.26, 0.2, 0.17, 0.14, 0.1, 0.07, 0.03], m["bark_dead"], sides=7, v_scale=0.4, wobble=0.08)
    for k in range(9):
        start = trunk[1 + k % 5]
        a = rng.uniform(0, math.tau)
        branch = bent_path(rng, start, (math.cos(a), math.sin(a), rng.uniform(0.2, 1.0)), rng.uniform(1.2, 2.6), 3, curl=0.45)
        p.tube(branch, [0.07, 0.05, 0.03, 0.008], m["bark_dead"], sides=4)
        for twig in range(2):
            b = rng.uniform(0, math.tau)
            p.tube([branch[2], branch[2] + Vector((math.cos(b) * 0.6, math.sin(b) * 0.6, rng.uniform(0.1, 0.6)))], [0.02, 0.004], m["bark_dead"], sides=3)
    return p.finish()


def build_chestnut(rng, m):
    """栗の木：太くごつごつした幹が低く枝分かれし、濃い緑の葉の広い樹冠に、とげとげの毬（いが）がなる"""
    p = Plant("flora_chestnut", rng)
    trunk = bent_path(rng, (0, 0, 0), (0.1, 0.0, 1.0), 3.2, 3, curl=0.15)
    p.tube(trunk, [0.32, 0.26, 0.22, 0.18], m["bark_pine"], sides=8, v_scale=0.4, wobble=0.06)
    tips = []
    for k in range(6):
        a = k / 6 * math.tau + rng.uniform(-0.3, 0.3)
        branch = bent_path(rng, trunk[-1], (math.cos(a), math.sin(a), 0.7), rng.uniform(2.0, 3.0), 3, curl=0.25)
        p.tube(branch, [0.14, 0.1, 0.07, 0.03], m["bark_pine"], sides=5)
        tips.append(branch[-1])
    for tip in tips:
        p.cluster(tip, 1.3, 14, 1.3, m["leaf_chestnut"], droop=0.2)
        # 毬：黄緑のとげとげの玉（葉の絵のカードを十字に組む）
        for _ in range(4):
            burr = Vector(tip) + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.8, 0.3)))
            for axis in ((1, 0, 0), (0, 1, 0)):
                p.card(burr - Vector((0, 0, 0.12)), 0.26, 0.26, m["leaf_burr"], Vector(axis))
    p.cluster(trunk[-1] + Vector((0, 0, 1.2)), 1.6, 18, 1.4, m["leaf_chestnut"])
    return p.finish()


BUILDERS = {
    "cedar": build_cedar, "pine": build_pine, "birch": build_birch, "bamboo": build_bamboo,
    "sasa": build_sasa, "fern": build_fern, "bush": build_bush, "stump": build_stump, "log": build_log,
    "dead": build_dead, "chestnut": build_chestnut,
}


IMPOSTORS = ("cedar", "pine", "birch", "bamboo", "dead", "chestnut")


def render_impostor(obj, short):
    """遠くで使う「一枚絵」：木を真横から、背景を透かして撮る（128×256 画素）。
    絵の高さは max(木の高さ, 木の幅×2)、絵の縦のまん中が、木の高さの半分に来る"""
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.eevee.taa_render_samples = 16
    scene.render.film_transparent = True
    scene.render.resolution_x = 128
    scene.render.resolution_y = 256
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    world = bpy.data.worlds.new("impostor")
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.55, 0.55, 0.55, 1.0)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0
    scene.world = world
    if "impostor_sun" not in bpy.data.objects:
        sun = bpy.data.objects.new("impostor_sun", bpy.data.lights.new("impostor_sun", 'SUN'))
        sun.data.energy = 2.0
        sun.rotation_euler = (math.radians(55), 0, math.radians(35))
        scene.collection.objects.link(sun)
    dims = obj.dimensions
    height = dims.z
    width = max(dims.x, dims.y)
    size = max(height, width * 2.0)
    camera_data = bpy.data.cameras.new("impostor")
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = size
    camera = bpy.data.objects.new("impostor", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (0.0, -60.0, height / 2)
    camera.rotation_euler = (math.radians(90), 0, 0)
    scene.camera = camera
    path = os.path.join(lib.PROJECT, "assets", "textures", "impostor_%s.png" % short)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)
    print("IMPOSTOR", path, "size", size)


def export(obj):
    for other in bpy.data.objects:
        if other.name in bpy.context.view_layer.objects:
            other.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = os.path.join(lib.PROJECT, "assets", "models", obj.name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_yup=True, export_apply=True,
                              export_materials='EXPORT', use_selection=True, export_skins=False, export_animations=False)
    print("EXPORTED", path)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [a for a in args if not a.startswith("--")] or list(BUILDERS)
    lib.reset()
    rng = random.Random(20260927)
    textures = {
        "bark_cedar": (bark_cedar(rng), False), "bark_pine": (bark_pine(rng), False), "bark_birch": (bark_birch(rng), False),
        "bark_bamboo": (bark_bamboo(rng), False), "wood_cut": (wood_cut(rng), False),
        "bark_dead": (bark_dead(rng), False),
        "leaf_cedar": (leaf_cedar(rng), True), "leaf_pine": (leaf_pine(rng), True), "leaf_broad": (leaf_broad(rng), True),
        "leaf_bamboo": (leaf_bamboo(rng), True), "leaf_fern": (leaf_fern(rng), True), "leaf_sasa": (leaf_sasa(rng), True),
        "leaf_moss": (leaf_moss(rng), True),
    }
    textures["leaf_chestnut"] = (leaf_broad(rng, "leaf_chestnut", ((0.2, 0.34, 0.12), (0.26, 0.4, 0.14), (0.16, 0.28, 0.1))), True)
    textures["leaf_burr"] = (leaf_burr(rng), True)
    materials = {name: material(name, image, leaf) for name, (image, leaf) in textures.items()}
    for index, name in enumerate(names):
        obj = BUILDERS[name](random.Random(1000 + index * 17 + len(name)), materials)
        export(obj)
        if name in IMPOSTORS:
            render_impostor(obj, name)
        if "--preview" in sys.argv:
            size = max(obj.dimensions)
            lib.render_preview(obj.name, (0, 0, obj.dimensions.z * 0.45), size * 1.6, views=((30, 12), (150, 25)))
        bpy.data.objects.remove(obj, do_unlink=True)
        bpy.context.view_layer.update()


main()
