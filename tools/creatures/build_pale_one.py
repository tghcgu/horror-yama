"""雪原に立つ「白い人」のモデルを作る。

背の高い日本の幽霊。足元の見えない白い着物（ぼろぼろの裾、しわ、長い袖）、青白い手と長い爪、
顔の前まで垂れた長い黒髪。髪のすき間から、片目だけがこちらを見ている。高さ 2.9 m ほど。
実行: blender -b --factory-startup --python tools/creatures/build_pale_one.py
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
import creature_lib as lib  # noqa: E402
from mathutils import Vector  # noqa: E402

SIDES = (1, -1)
HEAD = Vector((0, 0.06, 2.66))
EYE = Vector((-0.036, 0.155, 2.685))  # 髪のすき間から見える、片方の目

lib.reset()
random = lib.random_generator(11)

# --- 着物 ---
robe = lib.Meta("pale_robe", resolution=0.018)
for z, r, size in ((0.15, 0.42, (1.0, 0.85, 0.5)), (0.6, 0.34, (1.0, 0.8, 0.9)), (1.1, 0.26, (1.0, 0.8, 1.0)),
                   (1.6, 0.22, (1.05, 0.75, 1.0)), (2.05, 0.2, (1.1, 0.75, 0.9)), (2.25, 0.17, (1.5, 0.8, 0.6))):
    robe.ellipsoid((0, 0, z), r, size)
robe.ellipsoid((0, 0, 1.45), 0.24, (1.0, 0.82, 0.25))  # 帯
for i in range(12):  # 裾へ流れるしわ
    a = i / 12 * math.tau + random.uniform(-0.1, 0.1)
    top = Vector((math.cos(a) * 0.22, math.sin(a) * 0.17, 1.35))
    bottom = Vector((math.cos(a) * 0.4, math.sin(a) * 0.33, 0.12))
    robe.capsule(top, bottom, random.uniform(0.03, 0.05))
for i in range(22):  # ぼろぼろの裾
    a = i / 22 * math.tau
    robe.ball((math.cos(a) * 0.4, math.sin(a) * 0.32, random.uniform(0.0, 0.08)), random.uniform(0.05, 0.09))
for side in SIDES:  # 前で重なる襟と、長く垂れた袖
    robe.capsule((0.13 * side, 0.12, 2.32), (-0.05 * side, 0.17, 1.88), 0.025)
    robe.ellipsoid((0.3 * side, 0.06, 1.65), 0.14, (0.6, 1.1, 1.9))
    robe.capsule((0.2 * side, 0.0, 2.2), (0.3 * side, 0.06, 1.8), 0.1)
robe_mesh = robe.to_mesh()
robe_mesh.name = "PaleOne"
lib.add_surface_detail(robe_mesh, 0.008, 0.1, 'CLOUDS')
lib.smooth(robe_mesh, iterations=2, factor=0.5)
lib.reduce_to(robe_mesh, 3500)

# --- 肌（首・顔・手） ---
skin = lib.Meta("pale_skin", resolution=0.008)
skin.limb([(0, 0.02, 2.28), (0, 0.05, 2.52)], [0.05, 0.048])
skin.ellipsoid(HEAD, 0.12, (0.85, 0.95, 1.25))
skin.ball(EYE + Vector((0, 0.01, 0)), 0.022, negative=True)
for side in SIDES:
    wrist = Vector((0.27 * side, 0.14, 0.93))
    skin.limb([(0.29 * side, 0.1, 1.25), wrist], [0.035, 0.028])
    skin.ellipsoid((0.265 * side, 0.155, 0.86), 0.04, (0.45, 0.9, 1.3))
    for dx in (-0.025, -0.008, 0.008, 0.025):
        x = 0.265 * side + dx
        skin.limb([(x, 0.16, 0.81), (x + dx * 0.3, 0.17, 0.7), (x + dx * 0.4, 0.16, 0.6)], [0.009, 0.008, 0.006])
skin_mesh = skin.to_mesh()
skin_mesh.name = "PaleSkin"
lib.add_surface_detail(skin_mesh, 0.002, 0.04, 'VORONOI')
lib.reduce_to(skin_mesh, 2500)

# --- 長い黒髪 ---
# 後ろ髪：頭の後ろ半分を覆い、背中まで重く垂れる
hair = lib.Meta("pale_hair", resolution=0.012)
hair.ellipsoid(HEAD + Vector((0, -0.06, 0.05)), 0.13, (0.95, 0.9, 1.1))
for i in range(22):
    a = math.pi * 1.5 + (i / 21 - 0.5) * math.pi * 1.25  # 頭の後ろ側（-Y）を中心に回る
    out = Vector((math.cos(a), math.sin(a), 0))
    root = HEAD + out * 0.11 + Vector((0, -0.02, 0.1))
    length = random.uniform(0.8, 1.1)
    mid = HEAD + out * 0.15 + Vector((random.uniform(-0.02, 0.02), -0.03, -length * 0.45))
    tip = HEAD + out * 0.19 + Vector((random.uniform(-0.04, 0.04), -0.05, -length))
    hair.limb([root, mid, tip], [0.024, 0.022, 0.014])
# 前髪：顔の前にすだれのように垂れる。片目のところだけすき間があく
for x in (-0.108, -0.087, -0.066, -0.004, 0.018, 0.04, 0.062, 0.084, 0.106):
    bow = 0.13 - abs(x) * 0.45  # 顔の丸みに沿って、真ん中ほど前に出る
    root = HEAD + Vector((x * 0.9, bow - 0.03, 0.14))
    mid = HEAD + Vector((x, bow + 0.012, -0.02))
    length = random.uniform(0.5, 0.7)
    tip = HEAD + Vector((x * 1.1 + random.uniform(-0.015, 0.015), bow + 0.03, -length))
    hair.limb([root, mid, tip], [0.011, 0.011, 0.007])
hair_mesh = hair.to_mesh()
hair_mesh.name = "PaleHair"
lib.add_surface_detail(hair_mesh, 0.004, 0.02, 'CLOUDS')
lib.reduce_to(hair_mesh, 3000)
print("TRIANGLES", sum(sum(len(p.vertices) - 2 for p in m.data.polygons) for m in (robe_mesh, skin_mesh, hair_mesh)))


def stained_robe(nodes, links):
    coord = nodes.new('ShaderNodeTexCoord')
    noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=3.0, Detail=6.0)
    links.new(coord.outputs['Object'], noise.inputs['Vector'])
    color = lib.ramp(nodes, links, noise.outputs['Fac'], [(0.3, (0.72, 0.7, 0.66)), (0.7, (0.84, 0.83, 0.8))])
    # 裾ほど濃い、泥と古いしみ
    stains = lib.node(nodes, 'ShaderNodeTexNoise', Scale=7.0, Detail=5.0)
    links.new(coord.outputs['Object'], stains.inputs['Vector'])
    stain_mask = lib.ramp(nodes, links, stains.outputs['Fac'], [(0.58, (0.0, 0.0, 0.0)), (0.68, (0.8, 0.8, 0.8))])
    color = lib.mix(nodes, links, color, (0.42, 0.36, 0.28), stain_mask)
    separate = nodes.new('ShaderNodeSeparateXYZ')
    links.new(coord.outputs['Object'], separate.inputs['Vector'])
    hem = lib.ramp(nodes, links, separate.outputs['Z'], [(0.0, (0.7, 0.7, 0.7)), (0.5, (0.0, 0.0, 0.0))])
    color = lib.mix(nodes, links, color, (0.3, 0.27, 0.22), hem)
    occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.12)
    shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.35, 0.35, 0.37)), (1.0, (1.0, 1.0, 1.0))])
    return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')


def dead_skin(nodes, links):
    coord = nodes.new('ShaderNodeTexCoord')
    noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=9.0, Detail=4.0)
    links.new(coord.outputs['Object'], noise.inputs['Vector'])
    color = lib.ramp(nodes, links, noise.outputs['Fac'], [(0.35, (0.55, 0.58, 0.62)), (0.7, (0.7, 0.71, 0.74))])
    veins = lib.node(nodes, 'ShaderNodeTexVoronoi', feature='DISTANCE_TO_EDGE', Scale=12.0)
    links.new(coord.outputs['Object'], veins.inputs['Vector'])
    vein_mask = lib.ramp(nodes, links, veins.outputs['Distance'], [(0.0, (0.6, 0.6, 0.6)), (0.02, (0.0, 0.0, 0.0))])
    color = lib.mix(nodes, links, color, (0.32, 0.36, 0.5), vein_mask)
    occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.04)
    shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.3, 0.3, 0.32)), (1.0, (1.0, 1.0, 1.0))])
    return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')


lib.bpy.context.scene.cycles.samples = 48
lib.unwrap(robe_mesh)
lib.bake_color(robe_mesh, "pale_robe_skin", stained_robe)
lib.unwrap(skin_mesh)
lib.bake_color(skin_mesh, "pale_body_skin", dead_skin, size=256, final_size=128)
hair_mesh.data.materials.append(lib.flat_material("Hair", (0.012, 0.012, 0.014)))

# --- 片目と長い爪 ---
eye_white = lib.flat_material("EyeWhite", (0.75, 0.72, 0.68))
pupil = lib.flat_material("EyeBlack", (0.0, 0.0, 0.0))
nail = lib.flat_material("Claw", (0.35, 0.33, 0.3))
parts = []
eyeball = lib.primitive('uv_sphere', EYE, material=eye_white, radius=0.016, segments=10, ring_count=6)
dot = lib.primitive('uv_sphere', EYE + Vector((0.002, 0.014, 0.0)), material=pupil, radius=0.005, segments=6, ring_count=4)
for part in (eyeball, dot):
    lib.bind_whole(part, "head")
    parts.append(part)
for side in SIDES:
    for dx in (-0.025, -0.008, 0.008, 0.025):
        x = 0.265 * side + dx
        tip = Vector((x + dx * 0.4, 0.16, 0.6))
        c = lib.cone_between(tip, tip + Vector((0, 0.01, -0.06)), 0.006, nail, vertices=4)
        lib.bind_whole(c, "hand." + ("L" if side > 0 else "R"))
        parts.append(c)

# --- 骨 ---
bones = [
    lib.Bone("hips", (0, 0, 0.3), (0, 0, 1.5), None, 0.4),
    lib.Bone("chest", (0, 0, 1.5), (0, 0.02, 2.25), "hips", 0.25),
    lib.Bone("neck", (0, 0.02, 2.25), (0, 0.05, 2.52), "chest", 0.06),
    lib.Bone("head", (0, 0.05, 2.52), (0, 0.08, 2.85), "neck", 0.15),
]
for side in SIDES:
    s = "L" if side > 0 else "R"
    bones += [
        lib.Bone("upperarm." + s, (0.2 * side, 0.0, 2.2), (0.3 * side, 0.08, 1.55), "chest", 0.12),
        lib.Bone("forearm." + s, (0.3 * side, 0.08, 1.55), (0.27 * side, 0.15, 0.9), "upperarm." + s, 0.08),
        lib.Bone("hand." + s, (0.27 * side, 0.15, 0.9), (0.26 * side, 0.17, 0.6), "forearm." + s, 0.05),
    ]
lib.skin_to_bones(robe_mesh, bones)
lib.skin_to_bones(skin_mesh, bones)
# 髪は根元だけ頭に付けて、毛先は胸の骨に付ける（首をかしげても、髪は下へ垂れたまま）
head_group = hair_mesh.vertex_groups.new(name="head")
chest_group = hair_mesh.vertex_groups.new(name="chest")
for vertex in hair_mesh.data.vertices:
    t = min(max((vertex.co.z - (HEAD.z - 0.25)) / 0.3, 0.0), 1.0)
    head_group.add([vertex.index], t, 'REPLACE')
    chest_group.add([vertex.index], 1.0 - t, 'REPLACE')
model = lib.join(robe_mesh, [skin_mesh, hair_mesh] + parts)
rig = lib.build_armature("PaleOneRig", bones)
lib.attach_to_armature(model, rig)

lib.render_preview("pale_one", (0, 0.0, 1.5), 5.0, views=((20, 8), (90, 5), (180, 5)))
lib.render_preview("pale_one_face", (0, 0.1, 2.6), 1.0, views=((0, 0), (30, 5)))
lib.export_glb("pale_one")
