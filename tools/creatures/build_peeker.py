"""崖の上から覗く「のぞき」のモデルを作る。

崖の上に腹ばいになった、青白くやせた人。大きな髪のない頭、真っ黒な大きい目と小さく光る瞳、
頬まで広がるにやけた口。崖のふちをつかんだ手から、長い指が崖の下へ垂れ下がる。
原点が崖のふち。-Y 側が崖の上（足場）、+Y 側が崖の外（プレイヤーのいる側）。
実行: blender -b --factory-startup --python tools/creatures/build_peeker.py
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
import creature_lib as lib  # noqa: E402
from mathutils import Vector  # noqa: E402

SIDES = (1, -1)
HEAD = Vector((0, 0.08, 0.42))
FINGERS = (-0.045, -0.015, 0.015, 0.045)


def grin(t):
    """にやけた口の線。t = -1〜1。口角は上へつり上がる"""
    return Vector((0.11 * t, 0.232 - 0.085 * t * t, 0.315 + 0.035 * t * t))


def finger_points(side, dx):
    x = 0.3 * side + dx
    return [Vector((x, 0.06, 0.02)), Vector((x + dx * 0.3, 0.13, -0.03)),
            Vector((x + dx * 0.5, 0.145, -0.2)), Vector((x + dx * 0.6, 0.12, -0.36))]


lib.reset()
body = lib.Meta("peeker_body", resolution=0.011)

# 腹ばいの胴と、浮き出た背骨・肩甲骨
body.ellipsoid((0, -0.45, 0.16), 0.17, (1.15, 1.3, 0.75))
body.limb([(0, -0.6, 0.13), (0, -1.05, 0.11)], [0.11, 0.1])
body.ellipsoid((0, -1.15, 0.12), 0.14, (1.2, 0.9, 0.7))
for side in SIDES:
    body.ellipsoid((0.12 * side, -0.45, 0.27), 0.05, (1.0, 1.2, 0.5))
    body.limb([(0.1 * side, -1.25, 0.1), (0.12 * side, -1.8, 0.08), (0.12 * side, -2.3, 0.07)], [0.07, 0.05, 0.045])
for i in range(9):
    t = i / 8
    body.ball(Vector((0, -0.3, 0.27)).lerp(Vector((0, -1.05, 0.2)), t), 0.02)

# 崖のふちへ伸びる腕と、ふちをつかむ手、崖の下へ垂れる長い指
for side in SIDES:
    shoulder = Vector((0.2 * side, -0.35, 0.2))
    elbow = Vector((0.36 * side, -0.25, 0.34))
    wrist = Vector((0.3 * side, -0.03, 0.05))
    body.limb([shoulder, elbow, wrist], [0.05, 0.04, 0.032])
    body.ball(elbow, 0.045)
    body.ellipsoid((0.3 * side, 0.02, 0.025), 0.05, (1.1, 1.0, 0.45))
    for dx in FINGERS:
        points = finger_points(side, dx * side)
        body.limb(points, [0.013, 0.012, 0.011, 0.008])
        for p in points[1:3]:
            body.ball(p, 0.014)

# 長い首と、大きな頭
body.limb([(0, -0.3, 0.22), (0, -0.12, 0.32), (0, 0.02, 0.36)], [0.055, 0.05, 0.052])
body.ellipsoid(HEAD, 0.16, (0.85, 1.0, 1.3), axis=(0, -0.3, 1))
body.ellipsoid((0, 0.14, 0.27), 0.055, (0.9, 0.85, 0.9))  # あご
for side in SIDES:
    body.ball((0.058 * side, 0.205, 0.42), 0.05, negative=True)  # 深く大きな目のくぼみ
    body.ball((0.012 * side, 0.24, 0.35), 0.008, negative=True)  # 鼻の穴
curve = [grin(t / 5) for t in range(-5, 6)]
for a, b in zip(curve, curve[1:]):
    body.capsule(a, b, 0.014, negative=True)

skin = body.to_mesh()
skin.name = "Peeker"
lib.add_surface_detail(skin, 0.004, 0.04, 'VORONOI')
lib.add_surface_detail(skin, 0.003, 0.12, 'CLOUDS')
lib.smooth(skin, iterations=1, factor=0.4)
lib.reduce_to(skin, 6500)
print("TRIANGLES", sum(len(p.vertices) - 2 for p in skin.data.polygons))


def pale_skin(nodes, links):
    coord = nodes.new('ShaderNodeTexCoord')
    noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=5.0, Detail=5.0)
    links.new(coord.outputs['Object'], noise.inputs['Vector'])
    color = lib.ramp(nodes, links, noise.outputs['Fac'],
                     [(0.35, (0.55, 0.57, 0.6)), (0.55, (0.64, 0.61, 0.58)), (0.75, (0.68, 0.58, 0.57))])
    # 透けて見える青い血管
    veins = lib.node(nodes, 'ShaderNodeTexVoronoi', feature='DISTANCE_TO_EDGE', Scale=7.0)
    links.new(coord.outputs['Object'], veins.inputs['Vector'])
    vein_mask = lib.ramp(nodes, links, veins.outputs['Distance'], [(0.0, (0.7, 0.7, 0.7)), (0.02, (0.0, 0.0, 0.0))])
    color = lib.mix(nodes, links, color, (0.33, 0.36, 0.5), vein_mask)
    # 汚れ
    dirt = lib.node(nodes, 'ShaderNodeTexNoise', Scale=18.0, Detail=3.0)
    links.new(coord.outputs['Object'], dirt.inputs['Vector'])
    dirt_mask = lib.ramp(nodes, links, dirt.outputs['Fac'], [(0.6, (0.0, 0.0, 0.0)), (0.72, (0.7, 0.7, 0.7))])
    color = lib.mix(nodes, links, color, (0.28, 0.24, 0.2), dirt_mask)
    occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.06)
    shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.25, 0.22, 0.22)), (1.0, (1.0, 1.0, 1.0))])
    return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')


lib.bpy.context.scene.cycles.samples = 64
lib.unwrap(skin)
lib.bake_color(skin, "peeker_skin", pale_skin)

# --- 目・歯・爪 ---
black = lib.flat_material("EyeBlack", (0.005, 0.005, 0.005))
pupil = lib.flat_material("Eye", (1.0, 1.0, 0.95), emission=(1.0, 1.0, 0.9), strength=3.0)
tooth = lib.flat_material("Teeth", (0.7, 0.66, 0.52))
nail = lib.flat_material("Claw", (0.3, 0.26, 0.22))
parts = []
for side in SIDES:
    # 目はくぼみの奥の黒い玉。瞳だけが小さく光る
    eyeball = lib.primitive('uv_sphere', (0.058 * side, 0.18, 0.42), material=black, radius=0.036, segments=12, ring_count=8)
    dot = lib.primitive('uv_sphere', (0.058 * side - 0.006 * side, 0.214, 0.416), material=pupil, radius=0.005, segments=6, ring_count=4)
    lib.bind_whole(eyeball, "head")
    lib.bind_whole(dot, "head")
    parts += [eyeball, dot]
for i in range(15):
    for row in (1, -1):
        t = (i + (0.0 if row > 0 else 0.5)) / 14.5 * 1.6 - 0.8
        base = grin(t) + Vector((0, -0.004, 0.009 * row))
        tooth_mesh = lib.cone_between(base, base + Vector((0, 0.003, -0.015 * row)), 0.0045, tooth, vertices=4)
        lib.bind_whole(tooth_mesh, "head")
        parts.append(tooth_mesh)
for side in SIDES:
    for dx in FINGERS:
        tip = finger_points(side, dx * side)[-1]
        c = lib.cone_between(tip, tip + Vector((0, -0.02, -0.03)), 0.008, nail, vertices=5)
        lib.bind_whole(c, "fingers." + ("L" if side > 0 else "R"))
        parts.append(c)

# --- 骨 ---
bones = [
    lib.Bone("chest", (0, -0.8, 0.15), (0, -0.3, 0.2), None, 0.2),
    lib.Bone("legs", (0, -1.1, 0.12), (0, -2.3, 0.07), "chest", 0.15),
    lib.Bone("neck", (0, -0.3, 0.22), (0, 0.02, 0.36), "chest", 0.06),
    lib.Bone("head", (0, 0.02, 0.36), (0, 0.1, 0.58), "neck", 0.17),
]
for side in SIDES:
    s = "L" if side > 0 else "R"
    bones += [
        lib.Bone("upperarm." + s, (0.2 * side, -0.35, 0.2), (0.36 * side, -0.25, 0.34), "chest", 0.05),
        lib.Bone("forearm." + s, (0.36 * side, -0.25, 0.34), (0.3 * side, -0.03, 0.05), "upperarm." + s, 0.04),
        lib.Bone("hand." + s, (0.3 * side, -0.03, 0.05), (0.3 * side, 0.08, 0.02), "forearm." + s, 0.05),
        lib.Bone("fingers." + s, (0.3 * side, 0.08, 0.02), (0.3 * side, 0.14, -0.34), "hand." + s, 0.03),
    ]

lib.skin_to_bones(skin, bones)
skin = lib.join(skin, parts)
rig = lib.build_armature("PeekerRig", bones)
lib.attach_to_armature(skin, rig)

lib.render_preview("peeker", (0, -0.2, 0.2), 2.6, views=((30, 25), (90, 10), (0, -15)))
lib.render_preview("peeker_face", (0, 0.15, 0.38), 0.8, views=((0, -20), (35, -10)))
lib.export_glb("peeker")
