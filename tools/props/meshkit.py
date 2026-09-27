"""Blender で建物や置き物を組むための道具（tools/props/build_props.py から使う）。

座標は Godot の向きで書く（Y が上、+Z が手前）。Blender に置くときに G() で変換する。
模様は、ここで 1 画素ずつ描いた小さな画像（PS1 らしい 128 画素）。UV は実際の大きさに合わせて貼るので、
大きな板にも小さな板にも、同じ密度で模様が並ぶ。
素材の名前が leaf_ で始まる面は、Godot 側で裏からも見えて透ける素材になる（葉・紙垂・布の切れ端など）。
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "creatures"))
import creature_lib as lib  # noqa: E402

OUT = os.path.join(lib.PROJECT, "tools", "props", "out")
FLORA_OUT = os.path.join(lib.PROJECT, "tools", "flora", "out")
TEX = 128


def G(x, y, z):
    """Godot の座標 (x, y, z) を Blender の座標へ"""
    return Vector((x, -z, y))


# --- 画像を描く ---

class Canvas:
    def __init__(self, size=TEX, color=(0.0, 0.0, 0.0, 0.0)):
        self.size = size
        self.px = list(color) * (size * size)

    def blend(self, x, y, color, alpha=1.0):
        s = self.size
        i = ((int(y) % s) * s + (int(x) % s)) * 4
        a = alpha * (color[3] if len(color) > 3 else 1.0)
        old_a = self.px[i + 3]
        for k in range(3):
            self.px[i + k] = self.px[i + k] * (1.0 - a) + color[k] * a if old_a > 0.0 else color[k]
        self.px[i + 3] = max(old_a, a)

    def rect(self, x0, y0, x1, y1, color, alpha=1.0):
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                self.blend(x, y, color, alpha)

    def ellipse(self, cx, cy, rx, ry, angle, color, alpha=1.0):
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

    def noise(self, rng, amount, grain=1):
        """色むら（grain 画素ごとの、明るさのばらつき）"""
        s = self.size
        for by in range(0, s, grain):
            for bx in range(0, s, grain):
                f = 1.0 + rng.uniform(-amount, amount)
                for y in range(by, min(by + grain, s)):
                    for x in range(bx, min(bx + grain, s)):
                        i = (y * s + x) * 4
                        for k in range(3):
                            self.px[i + k] = min(self.px[i + k] * f, 1.0)

    def save(self, name):
        image = bpy.data.images.new(name, self.size, self.size, alpha=True)
        image.pixels = self.px
        os.makedirs(OUT, exist_ok=True)
        image.filepath_raw = os.path.join(OUT, name + ".png")
        image.file_format = 'PNG'
        image.save()
        image.pack()
        return image


def load_image(path, name):
    image = bpy.data.images.load(path)
    image.name = name
    image.pack()
    return image


def material(name, image, see_through=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes['Principled BSDF']
    texture = nodes.new('ShaderNodeTexImage')
    texture.image = image
    texture.interpolation = 'Closest'
    links.new(texture.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.9
    if see_through:
        r = nodes.new('ShaderNodeMath')
        r.operation = 'ROUND'
        links.new(texture.outputs['Alpha'], r.inputs[0])
        links.new(r.outputs[0], bsdf.inputs['Alpha'])
        m.use_backface_culling = False
    return m


# --- 形を組む ---

class Model:
    """1 つのメッシュに、箱・円柱・筒・板を足していく（座標は Godot の向き）"""

    def __init__(self, name, rng):
        self.name = name
        self.rng = rng
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.materials = []

    def _index(self, mat):
        if mat not in self.materials:
            self.materials.append(mat)
        return self.materials.index(mat)

    def _face(self, verts, uvs, mat, smooth=False):
        face = self.bm.faces.new(verts)
        face.material_index = self._index(mat)
        face.smooth = smooth
        for loop, uv in zip(face.loops, uvs):
            loop[self.uv].uv = uv
        return face

    def box(self, center, size, mat, rot=(0.0, 0.0, 0.0), density=0.5, jitter=0.0):
        """箱。rot は Godot の向きの回転（ラジアン, XYZ）。模様は density 枚/m で貼る"""
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        basis = Euler(rot, 'XYZ').to_matrix()
        corners = {}
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    local = Vector((sx * hx, sy * hy, sz * hz))
                    if jitter:
                        local += Vector((self.rng.uniform(-jitter, jitter) for _ in range(3)))
                    p = Vector(center) + basis @ local
                    corners[(sx, sy, sz)] = self.bm.verts.new(G(p.x, p.y, p.z))
        faces = [
            ([(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)], size[0], size[1]),     # 手前 (+Z)
            ([(1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1)], size[0], size[1]),  # 奥
            ([(1, -1, 1), (1, -1, -1), (1, 1, -1), (1, 1, 1)], size[2], size[1]),      # 右
            ([(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)], size[2], size[1]),  # 左
            ([(-1, 1, 1), (1, 1, 1), (1, 1, -1), (-1, 1, -1)], size[0], size[2]),      # 上
            ([(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)], size[0], size[2]),  # 下
        ]
        offset = (self.rng.random(), self.rng.random())
        for keys, w, h in faces:
            verts = [corners[k] for k in keys]
            uvs = [(offset[0], offset[1]), (offset[0] + w * density, offset[1]),
                   (offset[0] + w * density, offset[1] + h * density), (offset[0], offset[1] + h * density)]
            self._face(verts, uvs, mat)  # G() はただの回転なので、面の向き（左回り＝外向き）はそのまま

    def tube(self, points, radii, mat, sides=8, density=0.5, cap=False, wobble=0.0, smooth=True):
        """points（Godot の座標）をつなぐ筒。模様は 1 周で横 1 枚、縦は density 枚/m"""
        rings = []
        length = 0.0
        side = None
        pts = [Vector(p) for p in points]
        for k, (point, radius) in enumerate(zip(pts, radii)):
            axis = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
            if side is None:
                reference = Vector((0.0, 1.0, 0.0)) if abs(axis.y) < 0.9 else Vector((1.0, 0.0, 0.0))
                side = axis.cross(reference).normalized()
            else:
                side = (side - axis * side.dot(axis)).normalized()
            up = side.cross(axis).normalized()
            if k > 0:
                length += (point - pts[k - 1]).length
            ring = []
            for s in range(sides + 1):
                a = s / sides * math.tau
                r = radius * (1.0 + (self.rng.uniform(-wobble, wobble) if s < sides else 0.0))
                p = point + (side * math.cos(a) + up * math.sin(a)) * r
                ring.append((self.bm.verts.new(G(p.x, p.y, p.z)), s / sides, length * density))
            if k > 0 and ring:
                ring[-1] = (ring[-1][0], 1.0, ring[-1][2])
            rings.append(ring)
        for k in range(len(rings) - 1):
            for s in range(sides):
                quad = [rings[k][s], rings[k + 1][s], rings[k + 1][s + 1], rings[k][s + 1]]
                self._face([q[0] for q in quad], [(q[1], q[2]) for q in quad], mat, smooth)
        if cap:
            last = rings[-1][:sides]
            self._face([q[0] for q in last], [(0.5 + 0.5 * math.cos(i / sides * math.tau), 0.5 + 0.5 * math.sin(i / sides * math.tau)) for i in range(sides)], mat)

    def cylinder(self, base, height, r0, r1, mat, sides=10, density=0.5, cap=True, axis=(0.0, 1.0, 0.0)):
        a = Vector(base)
        b = a + Vector(axis).normalized() * height
        self.tube([a, b], [r0, r1], mat, sides, density, cap)

    def card(self, base, width, height, mat, facing, up=(0.0, 1.0, 0.0), bend=0.0, uv=(0.0, 0.0, 1.0, 1.0)):
        """板（葉・紙・布）：base を下辺の中央に、up の向きへ height。bend で先を facing のほうへ曲げる"""
        base, facing, up = Vector(base), Vector(facing).normalized(), Vector(up).normalized()
        side = up.cross(facing)
        if side.length < 1e-4:
            side = Vector((1.0, 0.0, 0.0))
        side.normalize()
        rows = 3 if bend else 1
        verts = []
        for r in range(rows + 1):
            t = r / rows
            lift = up * height * t + facing * bend * t * t * height
            left = base + lift - side * width * 0.5
            right = base + lift + side * width * 0.5
            verts.append([(self.bm.verts.new(G(left.x, left.y, left.z)), uv[0], uv[1] + (uv[3] - uv[1]) * t),
                          (self.bm.verts.new(G(right.x, right.y, right.z)), uv[2], uv[1] + (uv[3] - uv[1]) * t)])
        for r in range(rows):
            quad = [verts[r][0], verts[r][1], verts[r + 1][1], verts[r + 1][0]]
            self._face([q[0] for q in quad], [(q[1], q[2]) for q in quad], mat)

    def roof(self, center, width, depth, rise, mat, thickness=0.12, density=0.5):
        """切妻屋根：棟が Z 方向に走る 2 枚の板（width は軒から軒まで）"""
        half = width / 2
        slope = math.atan2(rise, half)
        length = math.hypot(half, rise)
        for side in (-1, 1):
            c = Vector(center) + Vector((side * half / 2, rise / 2, 0.0))
            self.box(c, (length + 0.1, thickness, depth), mat, rot=(0.0, 0.0, -side * slope), density=density)

    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(mesh)
        self.bm.free()
        for m in self.materials:
            mesh.materials.append(m)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
        print("BUILT", self.name, tris, "triangles")
        return obj


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


def preview(obj, height_bias=0.45):
    size = max(obj.dimensions)
    lib.render_preview(obj.name, (0, 0, obj.dimensions.z * height_bias), size * 1.7, views=((35, 18), (200, 25)))
