"""プレイヤー（登山者）のモデルを作る。ロビーの鏡に映る姿で、あとで友達と遊ぶときの見た目にもなる。

大きな丸い頭のちびキャラ。キラッとした大きな目、赤いほっぺ、小さな口。
ぽんぽん付きのニット帽、もこもこの上着、ミトン、丸い登山靴、小さなザックと丸めたマット。身長 1.65 m。
帽子・上着・マフラーの模様は灰色で焼き込み、色はゲームの中で塗る（鏡の前で選べる）。
実行: blender -b --factory-startup --python tools/creatures/build_climber.py
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
import creature_lib as lib  # noqa: E402
from mathutils import Vector  # noqa: E402

SIDES = (1, -1)
HEAD = Vector((0, 0.0, 1.36))
HEAD_R = 0.26
EYE_Z = HEAD.z - 0.02
HIP = {s: Vector((0.09 * s, 0.0, 0.52)) for s in SIDES}
KNEE = {s: Vector((0.1 * s, 0.02, 0.3)) for s in SIDES}
ANKLE = {s: Vector((0.1 * s, 0.0, 0.1)) for s in SIDES}
SHOULDER = {s: Vector((0.2 * s, 0.0, 0.98)) for s in SIDES}
ELBOW = {s: Vector((0.29 * s, 0.03, 0.8)) for s in SIDES}
WRIST = {s: Vector((0.32 * s, 0.07, 0.64)) for s in SIDES}

lib.reset()


def fabric(dark, light, scale, quilt=0.0, dirt=(0.1, 0.08, 0.06)):
    """布地の焼き込み：やわらかい色むら、キルトの縫い目（quilt > 0 のとき）、くぼみの陰"""
    def build(nodes, links):
        coord = nodes.new('ShaderNodeTexCoord')
        weave = lib.node(nodes, 'ShaderNodeTexNoise', Scale=scale, Detail=2.0)
        links.new(coord.outputs['Object'], weave.inputs['Vector'])
        color = lib.ramp(nodes, links, weave.outputs['Fac'], [(0.25, dark), (0.75, light)])
        if quilt > 0.0:
            separate = nodes.new('ShaderNodeSeparateXYZ')
            links.new(coord.outputs['Object'], separate.inputs['Vector'])
            wave = lib.node(nodes, 'ShaderNodeMath', operation='SINE')
            scaled = lib.node(nodes, 'ShaderNodeMath', operation='MULTIPLY')
            scaled.inputs[1].default_value = quilt
            links.new(separate.outputs['Z'], scaled.inputs[0])
            links.new(scaled.outputs['Value'], wave.inputs[0])
            seams = lib.ramp(nodes, links, wave.outputs['Value'], [(0.0, (0.72, 0.72, 0.72)), (0.12, (1.0, 1.0, 1.0))])
            color = lib.mix(nodes, links, color, seams, 1.0, blend='MULTIPLY')
        occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.05)
        shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.45, 0.45, 0.45)), (1.0, (1.0, 1.0, 1.0))])
        return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')
    return build


def finish(meta, name, triangles, detail=0.0):
    mesh = meta.to_mesh()
    mesh.name = name
    if detail > 0.0:
        lib.add_surface_detail(mesh, detail, 0.08, 'CLOUDS')
    lib.smooth(mesh, iterations=2, factor=0.5)
    lib.reduce_to(mesh, triangles)
    return mesh


GREY = ((0.55, 0.55, 0.55), (0.66, 0.66, 0.66))  # 色を塗る部分の、焼き込みの明るさ

# --- 頭（顔） ---
head = lib.Meta("climber_head", resolution=0.01)
head.ellipsoid(HEAD, HEAD_R, (1.05, 0.95, 0.95))
for side in SIDES:
    head.ellipsoid(HEAD + Vector((0.12 * side, 0.17, -0.09)), 0.07, (1.0, 0.6, 0.8))  # ぷっくりしたほっぺ
    head.ball(HEAD + Vector((0.255 * side, 0.0, -0.02)), 0.05)  # 耳
head_mesh = finish(head, "Head", 1400)

# --- ニット帽（折り返しと、ぽんぽん） ---
hat = lib.Meta("climber_hat", resolution=0.01)
hat.ellipsoid(HEAD + Vector((0, -0.02, 0.07)), HEAD_R * 1.06, (1.05, 0.98, 0.8))
hat.ellipsoid(HEAD + Vector((0, -0.01, 0.2)), 0.2, (1.0, 1.0, 0.7))
hat.ball(HEAD + Vector((0, -0.03, 0.38)), 0.09)  # ぽんぽん
hat.ellipsoid(HEAD + Vector((0, -0.005, 0.02)), HEAD_R * 1.1, (1.05, 0.98, 0.22))  # 折り返し
hat.ellipsoid(HEAD + Vector((0, 0.19, -0.06)), 0.2, (1.1, 0.5, 0.6), negative=True)  # 顔を出す
hat_mesh = finish(hat, "Hat", 1400)

# --- もこもこの上着 ---
jacket = lib.Meta("climber_jacket", resolution=0.012)
jacket.ellipsoid((0, 0.0, 0.8), 0.24, (1.0, 0.85, 1.05))
for z in (0.62, 0.77, 0.92):
    jacket.ellipsoid((0, 0.01, z), 0.22, (1.08, 0.92, 0.35))  # 綿入りのふくらみ
jacket.ellipsoid((0, 0.0, 1.06), 0.17, (1.2, 0.95, 0.5))  # 襟
for side in SIDES:
    jacket.ball(SHOULDER[side], 0.1)
    jacket.limb([SHOULDER[side], ELBOW[side], WRIST[side]], [0.085, 0.08, 0.075])
    jacket.ball(ELBOW[side], 0.082)
    jacket.ball(WRIST[side], 0.078)  # 袖口
jacket_mesh = finish(jacket, "Jacket", 2400)

# --- マフラー ---
scarf = lib.Meta("climber_scarf", resolution=0.01)
for i in range(12):
    a = i / 12 * math.tau
    scarf.ball((math.cos(a) * 0.13, 0.02 + math.sin(a) * 0.11, 1.1), 0.065)
scarf.limb([(0.08, 0.12, 1.06), (0.12, 0.2, 0.92), (0.1, 0.22, 0.8)], [0.05, 0.045, 0.042])  # 垂れた端
scarf_mesh = finish(scarf, "Scarf", 1000)

# --- ズボン・靴・ミトン ---
pants = lib.Meta("climber_pants", resolution=0.012)
pants.ellipsoid((0, 0.0, 0.54), 0.17, (1.1, 0.85, 0.55))
for side in SIDES:
    pants.limb([HIP[side], KNEE[side], ANKLE[side] + Vector((0, 0, 0.04))], [0.09, 0.08, 0.075])
pants_mesh = finish(pants, "Pants", 1200)

boots = lib.Meta("climber_boots", resolution=0.01)
for side in SIDES:
    boots.ellipsoid((0.1 * side, 0.04, 0.07), 0.1, (0.85, 1.25, 0.75))
    boots.ellipsoid((0.1 * side, 0.05, 0.025), 0.1, (0.95, 1.35, 0.3))  # 厚い靴底
boots_mesh = finish(boots, "Boots", 800)

mittens = lib.Meta("climber_mittens", resolution=0.008)
for side in SIDES:
    hand = WRIST[side] + Vector((0.01 * side, 0.03, -0.08))
    mittens.ellipsoid(hand, 0.065, (0.85, 0.95, 1.05))
    mittens.ball(hand + Vector((-0.045 * side, 0.04, 0.02)), 0.03)  # 親指
mittens_mesh = finish(mittens, "Mittens", 700)

# --- ザックとマット ---
pack = lib.Meta("climber_pack", resolution=0.012)
pack.ellipsoid((0, -0.25, 0.8), 0.2, (1.0, 0.7, 1.15))
pack.ellipsoid((0, -0.3, 0.72), 0.1, (1.2, 0.6, 0.7))  # 前ポケット
for side in SIDES:
    pack.limb([(0.12 * side, -0.14, 1.02), (0.15 * side, 0.08, 1.02), (0.14 * side, 0.2, 0.8)], [0.022, 0.022, 0.02])  # 肩ベルト
pack_mesh = finish(pack, "Pack", 1000)
roll = lib.primitive('cylinder', (0, -0.26, 1.07), rotation=(0, 1.5708, 0), vertices=12, radius=0.075, depth=0.42)
roll.name = "Roll"

print("TRIANGLES", sum(sum(len(p.vertices) - 2 for p in m.data.polygons)
                       for m in (head_mesh, hat_mesh, jacket_mesh, scarf_mesh, pants_mesh, boots_mesh, mittens_mesh, pack_mesh)))

# --- 焼き込み。色を塗る部分（帽子・上着・マフラー・ミトン）は灰色で、色はゲームの中で塗る ---
lib.bpy.context.scene.cycles.samples = 32
for mesh, name, colors, scale, quilt in (
        (hat_mesh, "climber_hat_tint", GREY, 60.0, 0.0),
        (jacket_mesh, "climber_jacket_tint", GREY, 5.0, 42.0),
        (scarf_mesh, "climber_scarf_tint", GREY, 70.0, 0.0),
        (mittens_mesh, "climber_mittens_tint", GREY, 40.0, 0.0),
        (pants_mesh, "climber_pants_tex", ((0.07, 0.08, 0.12), (0.09, 0.1, 0.15)), 8.0, 0.0),
        (boots_mesh, "climber_boots_tex", ((0.16, 0.09, 0.05), (0.22, 0.13, 0.07)), 10.0, 0.0),
        (pack_mesh, "climber_pack_tex", ((0.2, 0.13, 0.07), (0.26, 0.17, 0.09)), 8.0, 0.0),
        (head_mesh, "climber_face_tex", ((0.72, 0.52, 0.42), (0.78, 0.58, 0.47)), 6.0, 0.0)):
    lib.unwrap(mesh)
    lib.bake_color(mesh, name, fabric(colors[0], colors[1], scale, quilt), size=256, final_size=128)
roll.data.materials.append(lib.flat_material("Roll", (0.1, 0.3, 0.45)))

# --- 顔：大きな目（キラッとした光つき）、赤いほっぺ、小さな口 ---
parts = []
eye = lib.flat_material("EyeBlack", (0.02, 0.015, 0.02))
shine = lib.flat_material("EyeShine", (1.0, 1.0, 1.0), emission=(1.0, 1.0, 1.0), strength=1.0)
blush = lib.flat_material("Blush", (0.95, 0.38, 0.38))
mouth = lib.flat_material("Mouth", (0.3, 0.1, 0.08))
for side in SIDES:
    center = HEAD + Vector((0.085 * side, 0.225, EYE_Z - HEAD.z))
    e = lib.primitive('uv_sphere', center, scale=(0.75, 0.45, 1.0), material=eye, radius=0.05, segments=12, ring_count=8)
    s = lib.primitive('uv_sphere', center + Vector((0.014 * side, 0.024, 0.018)), material=shine, radius=0.014, segments=8, ring_count=6)
    b = lib.primitive('uv_sphere', HEAD + Vector((0.14 * side, 0.2, -0.085)), scale=(1.0, 0.35, 0.65), material=blush,
                      radius=0.035, segments=10, ring_count=6)
    for part in (e, s, b):
        lib.bind_whole(part, "head")
        parts.append(part)
m = lib.primitive('uv_sphere', HEAD + Vector((0, 0.24, -0.1)), scale=(1.0, 0.4, 0.55), material=mouth, radius=0.025,
                  segments=10, ring_count=6)
lib.bind_whole(m, "head")
parts.append(m)

# --- 骨 ---
bones = [
    lib.Bone("hips", (0, 0, 0.45), (0, 0, 0.66), None, 0.2),
    lib.Bone("spine", (0, 0, 0.66), (0, 0, 0.86), "hips", 0.24),
    lib.Bone("chest", (0, 0, 0.86), (0, 0, 1.04), "spine", 0.24),
    lib.Bone("neck", (0, 0, 1.04), (0, 0, 1.12), "chest", 0.1),
    lib.Bone("head", (0, 0, 1.12), (0, 0, 1.62), "neck", 0.3),
]
for side in SIDES:
    s = "L" if side > 0 else "R"
    bones += [
        lib.Bone("upperarm." + s, SHOULDER[side], ELBOW[side], "chest", 0.09),
        lib.Bone("forearm." + s, ELBOW[side], WRIST[side], "upperarm." + s, 0.085),
        lib.Bone("hand." + s, WRIST[side], WRIST[side] + Vector((0.01 * side, 0.04, -0.15)), "forearm." + s, 0.07),
        lib.Bone("thigh." + s, HIP[side], KNEE[side], "hips", 0.1),
        lib.Bone("shin." + s, KNEE[side], ANKLE[side], "thigh." + s, 0.09),
        lib.Bone("foot." + s, ANKLE[side], ANKLE[side] + Vector((0, 0.14, -0.06)), "shin." + s, 0.09),
    ]
for mesh in (jacket_mesh, pants_mesh, boots_mesh, mittens_mesh, scarf_mesh):
    lib.skin_to_bones(mesh, bones)
for mesh in (head_mesh, hat_mesh):
    lib.bind_whole(mesh, "head")
lib.bind_whole(pack_mesh, "chest")
lib.bind_whole(roll, "chest")
model = lib.join(jacket_mesh, [head_mesh, hat_mesh, scarf_mesh, pants_mesh, boots_mesh, mittens_mesh, pack_mesh, roll] + parts)
rig = lib.build_armature("ClimberRig", bones)
lib.attach_to_armature(model, rig)

lib.render_preview("climber", (0, 0.0, 0.85), 3.0, views=((0, 5), (40, 10), (160, 10)))
lib.render_preview("climber_face", HEAD, 0.9, views=((0, 0), (30, 5)))
lib.export_glb("climber")
