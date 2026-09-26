"""樹海の木の上にひそむ「手長」のモデルを作る。

木の枝の上にうずくまった、骨と皮ばかりの小さな体。うつむいた頭には長い黒髪、
体の何倍もある長い腕を真下へ垂らし、地面近くで長い指がゆっくりと開いたり閉じたりする。
原点が枝の上（体の足元）。腕は下（-Z）へ 2.6 m ほど伸びる。正面は +Y。
実行: blender -b --factory-startup --python tools/creatures/build_tenaga.py
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
import creature_lib as lib  # noqa: E402
from mathutils import Vector  # noqa: E402

SIDES = (1, -1)
HEAD = Vector((0, 0.2, 0.42))
FINGERS = (-0.05, -0.017, 0.017, 0.05)


def arm_points(side):
    shoulder = Vector((0.16 * side, 0.08, 0.42))
    elbow = Vector((0.3 * side, 0.3, -0.75))
    wrist = Vector((0.24 * side, 0.34, -2.15))
    return shoulder, elbow, wrist


def finger_points(side, dx):
    wrist = arm_points(side)[2]
    base = wrist + Vector((dx, 0.02, -0.12))
    return [base, base + Vector((dx * 0.4, 0.05, -0.18)), base + Vector((dx * 0.6, 0.08, -0.36)), base + Vector((dx * 0.6, 0.12, -0.52))]


lib.reset()
random = lib.random_generator(11)
body = lib.Meta("tenaga_body", resolution=0.012)

# うずくまった胴。背骨とあばらが浮き出ている
body.ellipsoid((0, 0.05, 0.3), 0.14, (1.1, 0.9, 1.3), axis=(0, 0.4, 1))
body.ellipsoid((0, -0.02, 0.12), 0.11, (1.1, 1.0, 0.8))
for i in range(8):
    body.ball(Vector((0, -0.08, 0.1)).lerp(Vector((0, -0.04, 0.45)), i / 7), 0.022)
for side in SIDES:
    for i in range(4):
        z = 0.2 + i * 0.06
        body.capsule((0.05 * side, 0.12, z), (0.13 * side, 0.02, z + 0.02), 0.012)
# 折りたたんだ脚（ひざを胸の横まで引き上げて、枝にしゃがむ）
for side in SIDES:
    hip = Vector((0.09 * side, -0.02, 0.08))
    knee = Vector((0.17 * side, 0.2, 0.28))
    ankle = Vector((0.13 * side, -0.02, 0.02))
    body.limb([hip, knee, ankle], [0.055, 0.035, 0.03])
    body.ball(knee, 0.04)
    body.limb([ankle, ankle + Vector((0, 0.16, -0.02))], [0.03, 0.02])

# 体の何倍もある腕と、長い指
for side in SIDES:
    shoulder, elbow, wrist = arm_points(side)
    body.limb([shoulder, elbow, wrist], [0.045, 0.034, 0.028])
    body.ball(elbow, 0.042)
    body.ball(shoulder, 0.05)
    body.ellipsoid(wrist + Vector((0, 0.01, -0.07)), 0.05, (1.1, 0.55, 1.2))
    for dx in FINGERS:
        points = finger_points(side, dx * side)
        body.limb(points, [0.014, 0.012, 0.01, 0.007])
        for p in points[1:3]:
            body.ball(p, 0.014)

# うつむいた頭
body.limb([(0, 0.02, 0.45), (0, 0.12, 0.47)], [0.045, 0.045])
body.ellipsoid(HEAD, 0.12, (0.85, 1.0, 1.1), axis=(0, 0.7, 1))
for side in SIDES:
    body.ball(HEAD + Vector((0.04 * side, 0.1, -0.03)), 0.03, negative=True)
body.capsule(HEAD + Vector((-0.035, 0.11, -0.09)), HEAD + Vector((0.035, 0.11, -0.09)), 0.012, negative=True)

skin = body.to_mesh()
skin.name = "Tenaga"
lib.add_surface_detail(skin, 0.004, 0.04, 'VORONOI')
lib.add_surface_detail(skin, 0.003, 0.12, 'CLOUDS')
lib.smooth(skin, iterations=1, factor=0.4)
lib.reduce_to(skin, 6000)
print("TRIANGLES", sum(len(p.vertices) - 2 for p in skin.data.polygons))


def withered_skin(nodes, links):
    coord = nodes.new('ShaderNodeTexCoord')
    noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=6.0, Detail=6.0)
    links.new(coord.outputs['Object'], noise.inputs['Vector'])
    color = lib.ramp(nodes, links, noise.outputs['Fac'],
                     [(0.35, (0.28, 0.25, 0.2)), (0.55, (0.4, 0.36, 0.3)), (0.75, (0.46, 0.42, 0.36))])
    # 木の皮のような、縦に走るしわ
    wave = lib.node(nodes, 'ShaderNodeTexWave', wave_type='BANDS', bands_direction='Z', Scale=14.0, Distortion=6.0)
    links.new(coord.outputs['Object'], wave.inputs['Vector'])
    wrinkles = lib.ramp(nodes, links, wave.outputs['Fac'], [(0.0, (0.5, 0.5, 0.5)), (0.3, (0.0, 0.0, 0.0))])
    color = lib.mix(nodes, links, color, (0.12, 0.1, 0.08), wrinkles)
    moss = lib.node(nodes, 'ShaderNodeTexNoise', Scale=12.0, Detail=3.0)
    links.new(coord.outputs['Object'], moss.inputs['Vector'])
    moss_mask = lib.ramp(nodes, links, moss.outputs['Fac'], [(0.62, (0.0, 0.0, 0.0)), (0.72, (0.6, 0.6, 0.6))])
    color = lib.mix(nodes, links, color, (0.16, 0.2, 0.09), moss_mask)
    occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.06)
    shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.2, 0.18, 0.16)), (1.0, (1.0, 1.0, 1.0))])
    return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')


lib.bpy.context.scene.cycles.samples = 48
lib.unwrap(skin)
lib.bake_color(skin, "tenaga_skin", withered_skin)

# --- 長い黒髪・目・爪 ---
hair = lib.flat_material("Hair", (0.02, 0.018, 0.02))
eye = lib.flat_material("Eye", (1.0, 0.9, 0.6), emission=(1.0, 0.85, 0.5), strength=4.0)
nail = lib.flat_material("Claw", (0.12, 0.1, 0.08))
parts = []
for i in range(26):
    angle = random.uniform(-2.4, 2.4)
    root = HEAD + Vector((0.1 * math.sin(angle), -0.02 + 0.06 * math.cos(angle), 0.07))
    tip = root + Vector((random.uniform(-0.04, 0.04), random.uniform(0.05, 0.14), -random.uniform(0.3, 0.55)))
    strand = lib.cone_between(root, tip, 0.018, hair, vertices=4)
    lib.bind_whole(strand, "head")
    parts.append(strand)
for side in SIDES:
    e = lib.primitive('uv_sphere', HEAD + Vector((0.04 * side, 0.085, -0.03)), material=eye, radius=0.012, segments=8, ring_count=6)
    lib.bind_whole(e, "head")
    parts.append(e)
    s = "L" if side > 0 else "R"
    for dx in FINGERS:
        tip = finger_points(side, dx * side)[-1]
        c = lib.cone_between(tip, tip + Vector((0, 0.03, -0.07)), 0.009, nail, vertices=5)
        lib.bind_whole(c, "fingers." + s)
        parts.append(c)

# --- 骨 ---
bones = [
    lib.Bone("body", (0, -0.02, 0.05), (0, 0.02, 0.45), None, 0.16),
    lib.Bone("head", (0, 0.05, 0.45), HEAD + Vector((0, 0.1, -0.08)), "body", 0.14,
             allow=lambda co: co.z > 0.35),
]
for side in SIDES:
    s = "L" if side > 0 else "R"
    shoulder, elbow, wrist = arm_points(side)
    bones += [
        lib.Bone("upperarm." + s, shoulder, elbow, "body", 0.05, allow=lambda co, side=side: co.x * side > 0.06),
        lib.Bone("forearm." + s, elbow, wrist, "upperarm." + s, 0.04, allow=lambda co, side=side: co.x * side > 0.06),
        lib.Bone("hand." + s, wrist, wrist + Vector((0, 0.03, -0.14)), "forearm." + s, 0.06,
                 allow=lambda co, side=side: co.x * side > 0.06),
        lib.Bone("fingers." + s, wrist + Vector((0, 0.03, -0.14)), wrist + Vector((0, 0.12, -0.66)), "hand." + s, 0.05,
                 allow=lambda co, side=side: co.x * side > 0.06),
    ]

lib.skin_to_bones(skin, bones)
skin = lib.join(skin, parts)
rig = lib.build_armature("TenagaRig", bones)
lib.attach_to_armature(skin, rig)

lib.render_preview("tenaga", (0, 0.2, -0.9), 5.0, views=((30, 10), (90, 5), (0, -10)))
lib.render_preview("tenaga_face", HEAD, 0.9, views=((0, -25), (40, -10)))
lib.export_glb("tenaga")
