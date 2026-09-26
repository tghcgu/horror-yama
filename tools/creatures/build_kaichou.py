"""崖のまわりを旋回し、登っている人に襲いかかる「怪鳥（けちょう）」のモデルを作る。

翼を広げると 3 m ほどの大きな黒い鳥。首の先には、青白い人の顔がついている。
羽は黒く、ところどころ抜け落ちて地肌がのぞく。脚には大きな鉤爪。
原点が胴の真ん中。正面は +Y、翼は左右（±X）へ水平に広げた姿勢で作る。
実行: blender -b --factory-startup --python tools/creatures/build_kaichou.py
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
import creature_lib as lib  # noqa: E402
from mathutils import Vector  # noqa: E402

SIDES = (1, -1)
HEAD = Vector((0, 0.72, 0.1))


def wing_points(side):
    return (Vector((0.16 * side, 0.12, 0.06)), Vector((0.7 * side, 0.12, 0.14)), Vector((1.45 * side, -0.02, 0.1)))


lib.reset()
random = lib.random_generator(7)
body = lib.Meta("kaichou_body", resolution=0.014)

# 胴（前後に長い）と尾羽
body.ellipsoid((0, 0.0, 0.0), 0.2, (1.0, 1.9, 0.85))
body.ellipsoid((0, 0.22, 0.04), 0.17, (1.1, 1.0, 1.0))
for i in range(7):
    angle = (i - 3) * 0.2
    root = Vector((0, -0.35, 0.02))
    body.ellipsoid(root + Vector((math.sin(angle) * 0.25, -0.3 * math.cos(angle), 0)), 0.08, (1.1, 3.2, 0.25),
                   axis=(0, 0, 1))
# 翼：骨に沿って、後ろへ流れる羽のかたまりを並べる
for side in SIDES:
    shoulder, elbow, tip = wing_points(side)
    body.limb([shoulder, elbow, tip], [0.06, 0.045, 0.025])
    for k in range(16):
        t = k / 15
        p = shoulder.lerp(elbow, t * 2) if t < 0.5 else elbow.lerp(tip, t * 2 - 1)
        length = 0.55 - 0.25 * abs(t - 0.45)
        body.ellipsoid(p + Vector((0, -length * 0.55, -0.01)), 0.075, (1.3, length / 0.075 * 0.9, 0.22))
# 細い首
body.limb([(0, 0.3, 0.06), (0, 0.5, 0.1), (0, 0.62, 0.1)], [0.07, 0.055, 0.055])
# 人の顔
body.ellipsoid(HEAD, 0.11, (0.85, 0.95, 1.15))
for side in SIDES:
    body.ball(HEAD + Vector((0.038 * side, 0.08, 0.03)), 0.025, negative=True)
    body.ball(HEAD + Vector((0.07 * side, 0.02, 0.0)), 0.03)  # 頬骨
body.ellipsoid(HEAD + Vector((0, 0.1, -0.005)), 0.018, (0.8, 1.0, 1.5))  # 鼻
body.capsule(HEAD + Vector((-0.04, 0.085, -0.06)), HEAD + Vector((0.04, 0.085, -0.06)), 0.014, negative=True)  # 口
# 脚
for side in SIDES:
    body.limb([(0.08 * side, -0.05, -0.1), (0.1 * side, -0.02, -0.3), (0.1 * side, 0.02, -0.45)], [0.04, 0.03, 0.022])

skin = body.to_mesh()
skin.name = "Kaichou"
lib.add_surface_detail(skin, 0.006, 0.04, 'VORONOI')
lib.reduce_to(skin, 6500)
print("TRIANGLES", sum(len(p.vertices) - 2 for p in skin.data.polygons))


def feathers(nodes, links):
    coord = nodes.new('ShaderNodeTexCoord')
    separate = nodes.new('ShaderNodeSeparateXYZ')
    links.new(coord.outputs['Object'], separate.inputs['Vector'])
    noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=6.0, Detail=5.0)
    links.new(coord.outputs['Object'], noise.inputs['Vector'])
    color = lib.ramp(nodes, links, noise.outputs['Fac'],
                     [(0.35, (0.02, 0.02, 0.025)), (0.6, (0.06, 0.06, 0.08)), (0.8, (0.1, 0.1, 0.13))])
    # 羽の筋
    wave = lib.node(nodes, 'ShaderNodeTexWave', wave_type='BANDS', bands_direction='X', Scale=30.0, Distortion=3.0)
    links.new(coord.outputs['Object'], wave.inputs['Vector'])
    barbs = lib.ramp(nodes, links, wave.outputs['Fac'], [(0.0, (0.5, 0.5, 0.5)), (0.25, (0.0, 0.0, 0.0))])
    color = lib.mix(nodes, links, color, (0.16, 0.17, 0.22), barbs)
    # 羽の抜けた地肌
    bald = lib.node(nodes, 'ShaderNodeTexNoise', Scale=9.0, Detail=2.0)
    links.new(coord.outputs['Object'], bald.inputs['Vector'])
    bald_mask = lib.ramp(nodes, links, bald.outputs['Fac'], [(0.66, (0.0, 0.0, 0.0)), (0.7, (0.9, 0.9, 0.9))])
    color = lib.mix(nodes, links, color, (0.4, 0.3, 0.3), bald_mask)
    # 首から先（y > 0.6）は青白い人の肌
    face_mask = lib.ramp(nodes, links, separate.outputs['Y'], [(0.6, (0.0, 0.0, 0.0)), (0.64, (1.0, 1.0, 1.0))])
    skin_noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=20.0, Detail=4.0)
    links.new(coord.outputs['Object'], skin_noise.inputs['Vector'])
    skin_color = lib.ramp(nodes, links, skin_noise.outputs['Fac'], [(0.4, (0.62, 0.62, 0.6)), (0.7, (0.72, 0.66, 0.64))])
    color = lib.mix(nodes, links, color, skin_color, face_mask)
    occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.05)
    shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.2, 0.2, 0.2)), (1.0, (1.0, 1.0, 1.0))])
    return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')


lib.bpy.context.scene.cycles.samples = 48
lib.unwrap(skin)
lib.bake_color(skin, "kaichou_skin", feathers)

eye = lib.flat_material("Eye", (1.0, 0.15, 0.1), emission=(1.0, 0.1, 0.05), strength=5.0)
black = lib.flat_material("EyeBlack", (0.01, 0.0, 0.0))
claw = lib.flat_material("Claw", (0.08, 0.07, 0.06))
tooth = lib.flat_material("Teeth", (0.7, 0.66, 0.55))
parts = []
for side in SIDES:
    ball = lib.primitive('uv_sphere', HEAD + Vector((0.038 * side, 0.065, 0.03)), material=black, radius=0.022, segments=8, ring_count=6)
    dot = lib.primitive('uv_sphere', HEAD + Vector((0.038 * side, 0.085, 0.03)), material=eye, radius=0.007, segments=6, ring_count=4)
    lib.bind_whole(ball, "head")
    lib.bind_whole(dot, "head")
    parts += [ball, dot]
    s = "L" if side > 0 else "R"
    foot = Vector((0.1 * side, 0.02, -0.45))
    for angle in (-0.5, 0.0, 0.5, math.pi):
        direction = Vector((math.sin(angle) * 0.08, math.cos(angle) * 0.08, -0.05))
        c = lib.cone_between(foot, foot + direction, 0.012, claw, vertices=5)
        lib.bind_whole(c, "legs")
        parts.append(c)
for i in range(6):
    base = HEAD + Vector((-0.03 + i * 0.012, 0.09, -0.052))
    t = lib.cone_between(base, base + Vector((0, 0.002, -0.014)), 0.004, tooth, vertices=4)
    lib.bind_whole(t, "head")
    parts.append(t)

bones = [
    lib.Bone("body", (0, -0.3, 0), (0, 0.3, 0.04), None, 0.25, allow=lambda co: abs(co.x) < 0.35),
    lib.Bone("tail", (0, -0.3, 0.01), (0, -0.85, 0.02), "body", 0.2, allow=lambda co: abs(co.x) < 0.35 and co.y < -0.2),
    lib.Bone("neck", (0, 0.3, 0.06), (0, 0.62, 0.1), "body", 0.08, allow=lambda co: abs(co.x) < 0.2),
    lib.Bone("head", (0, 0.62, 0.1), HEAD + Vector((0, 0.12, 0.08)), "neck", 0.14, allow=lambda co: co.y > 0.55),
    lib.Bone("legs", (0, -0.05, -0.1), (0, 0.02, -0.45), "body", 0.08, allow=lambda co: co.z < -0.08 and abs(co.x) < 0.2),
]
for side in SIDES:
    s = "L" if side > 0 else "R"
    shoulder, elbow, tip = wing_points(side)
    bones += [
        lib.Bone("wing1." + s, shoulder, elbow, "body", 0.3, allow=lambda co, side=side: co.x * side > 0.12),
        lib.Bone("wing2." + s, elbow, tip, "wing1." + s, 0.3, allow=lambda co, side=side: co.x * side > 0.5),
    ]
lib.skin_to_bones(skin, bones)
skin = lib.join(skin, parts)
rig = lib.build_armature("KaichouRig", bones)
lib.attach_to_armature(skin, rig)

lib.render_preview("kaichou", (0, 0.0, 0.0), 5.0, views=((20, 40), (90, 10), (0, 5)))
lib.render_preview("kaichou_face", HEAD, 0.7, views=((0, 0), (40, 10)))
lib.export_glb("kaichou")
