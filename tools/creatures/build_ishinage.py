"""岩場の岩棚から石を投げてくる「石投げ」のモデルを作る。

人の背丈ほどの、ずんぐりとした猿のような体。ぼさぼさの毛に覆われ、顔は毛に隠れて
ひとつだけの大きな目が光る。地面につくほど長くて太い腕と、大きなこぶし。
原点が足元。正面は +Y。
実行: blender -b --factory-startup --python tools/creatures/build_ishinage.py
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
import creature_lib as lib  # noqa: E402
from mathutils import Vector  # noqa: E402

SIDES = (1, -1)
HEAD = Vector((0, 0.24, 1.0))


def arm_points(side):
    return (Vector((0.32 * side, 0.05, 0.98)), Vector((0.46 * side, 0.14, 0.6)), Vector((0.44 * side, 0.26, 0.24)))


def leg_points(side):
    return (Vector((0.15 * side, 0.0, 0.5)), Vector((0.21 * side, 0.14, 0.27)), Vector((0.18 * side, 0.0, 0.07)))


lib.reset()
random = lib.random_generator(5)
body = lib.Meta("ishinage_body", resolution=0.018)

# 前かがみの大きな胴と、盛り上がった肩
body.ellipsoid((0, 0.05, 0.82), 0.3, (1.15, 0.95, 1.0), axis=(0, 0.5, 1))
body.ellipsoid((0, 0.0, 0.56), 0.22, (1.1, 0.95, 0.9))
for side in SIDES:
    body.ball((0.28 * side, 0.04, 0.98), 0.15)
# ぼさぼさの毛のかたまり（背中・肩・頭）
for _ in range(60):
    u, v = random.uniform(0, math.tau), random.uniform(-0.2, 1.2)
    p = Vector((0.33 * math.cos(u) * math.cos(v), 0.28 * math.sin(u) * math.cos(v) - 0.02, 0.8 + 0.3 * math.sin(v)))
    if p.y < 0.2:
        body.ball(p, random.uniform(0.05, 0.09))
# 腕とこぶし
for side in SIDES:
    shoulder, elbow, wrist = arm_points(side)
    body.limb([shoulder, elbow, wrist], [0.1, 0.085, 0.075])
    body.ball(elbow, 0.09)
    body.ellipsoid(wrist + Vector((0, 0.02, -0.08)), 0.1, (1.0, 1.1, 1.0))
    for k in range(3):
        body.ball(elbow.lerp(shoulder, 0.3 + k * 0.25) + Vector((0.04 * side, -0.05, 0)), 0.06)
    hip, knee, ankle = leg_points(side)
    body.limb([hip, knee, ankle], [0.1, 0.08, 0.06])
    body.ellipsoid(ankle + Vector((0, 0.06, -0.03)), 0.07, (1.0, 1.6, 0.6))
# 頭（肩にうずもれている）と、毛に隠れた顔
body.ellipsoid(HEAD, 0.17, (1.0, 0.95, 0.9))
for _ in range(18):
    u = random.uniform(-2.6, 2.6)
    body.ball(HEAD + Vector((0.14 * math.sin(u), 0.1 * math.cos(u) - 0.05, random.uniform(0.02, 0.13))), random.uniform(0.05, 0.07))
body.ball(HEAD + Vector((0, 0.15, 0.0)), 0.055, negative=True)  # 目のくぼみ
body.capsule(HEAD + Vector((-0.07, 0.15, -0.1)), HEAD + Vector((0.07, 0.15, -0.1)), 0.025, negative=True)  # 口

skin = body.to_mesh()
skin.name = "Ishinage"
lib.add_surface_detail(skin, 0.012, 0.03, 'VORONOI')
lib.add_surface_detail(skin, 0.01, 0.1, 'CLOUDS')
lib.reduce_to(skin, 6500)
print("TRIANGLES", sum(len(p.vertices) - 2 for p in skin.data.polygons))


def matted_fur(nodes, links):
    coord = nodes.new('ShaderNodeTexCoord')
    noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=5.0, Detail=6.0)
    links.new(coord.outputs['Object'], noise.inputs['Vector'])
    color = lib.ramp(nodes, links, noise.outputs['Fac'],
                     [(0.35, (0.13, 0.1, 0.08)), (0.55, (0.22, 0.17, 0.12)), (0.75, (0.3, 0.25, 0.18))])
    # 毛の流れ（下向きの細い筋）
    wave = lib.node(nodes, 'ShaderNodeTexWave', wave_type='BANDS', bands_direction='X', Scale=40.0, Distortion=12.0,
                    Detail=4.0)
    links.new(coord.outputs['Object'], wave.inputs['Vector'])
    strands = lib.ramp(nodes, links, wave.outputs['Fac'], [(0.0, (0.6, 0.6, 0.6)), (0.4, (0.0, 0.0, 0.0))])
    color = lib.mix(nodes, links, color, (0.05, 0.04, 0.03), strands)
    # 岩の粉で白っぽく汚れている
    dust = lib.node(nodes, 'ShaderNodeTexNoise', Scale=14.0, Detail=3.0)
    links.new(coord.outputs['Object'], dust.inputs['Vector'])
    dust_mask = lib.ramp(nodes, links, dust.outputs['Fac'], [(0.6, (0.0, 0.0, 0.0)), (0.72, (0.5, 0.5, 0.5))])
    color = lib.mix(nodes, links, color, (0.5, 0.47, 0.42), dust_mask)
    occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.1)
    shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.1, 0.1, 0.1)), (1.0, (1.0, 1.0, 1.0))])
    return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')


lib.bpy.context.scene.cycles.samples = 48
lib.unwrap(skin)
lib.bake_color(skin, "ishinage_skin", matted_fur)

eye = lib.flat_material("Eye", (1.0, 0.75, 0.2), emission=(1.0, 0.7, 0.15), strength=6.0)
black = lib.flat_material("EyeBlack", (0.02, 0.01, 0.01))
tooth = lib.flat_material("Teeth", (0.62, 0.56, 0.4))
parts = []
ball = lib.primitive('uv_sphere', HEAD + Vector((0, 0.12, 0.0)), material=black, radius=0.05, segments=10, ring_count=8)
iris = lib.primitive('uv_sphere', HEAD + Vector((0, 0.165, 0.0)), material=eye, radius=0.018, segments=8, ring_count=6)
parts += [ball, iris]
for i in range(7):
    x = -0.06 + i * 0.02
    for row in (1, -1):
        base = HEAD + Vector((x, 0.14, -0.1 + 0.02 * row))
        t = lib.cone_between(base, base + Vector((0, 0.005, -0.03 * row)), 0.008, tooth, vertices=4)
        parts.append(t)
for p in parts:
    lib.bind_whole(p, "head")

bones = [
    lib.Bone("hips", (0, 0, 0.45), (0, 0.02, 0.7), None, 0.25),
    lib.Bone("chest", (0, 0.02, 0.7), (0, 0.12, 1.02), "hips", 0.3),
    lib.Bone("head", (0, 0.14, 0.9), HEAD + Vector((0, 0.1, 0.15)), "chest", 0.2, allow=lambda co: co.z > 0.85 and abs(co.x) < 0.2),
]
for side in SIDES:
    s = "L" if side > 0 else "R"
    shoulder, elbow, wrist = arm_points(side)
    hip, knee, ankle = leg_points(side)
    bones += [
        lib.Bone("upperarm." + s, shoulder, elbow, "chest", 0.1, allow=lambda co, side=side: co.x * side > 0.25),
        lib.Bone("forearm." + s, elbow, wrist, "upperarm." + s, 0.09, allow=lambda co, side=side: co.x * side > 0.25),
        lib.Bone("hand." + s, wrist, wrist + Vector((0, 0.03, -0.2)), "forearm." + s, 0.1, allow=lambda co, side=side: co.x * side > 0.25),
        lib.Bone("thigh." + s, hip, knee, "hips", 0.1, allow=lambda co, side=side: co.x * side > 0.02 and co.z < 0.55),
        lib.Bone("shin." + s, knee, ankle + Vector((0, 0.1, -0.05)), "thigh." + s, 0.08,
                 allow=lambda co, side=side: co.x * side > 0.02 and co.z < 0.4),
    ]
lib.skin_to_bones(skin, bones)
skin = lib.join(skin, parts)
rig = lib.build_armature("IshinageRig", bones)
lib.attach_to_armature(skin, rig)

lib.render_preview("ishinage", (0, 0.1, 0.6), 3.2, views=((25, 10), (90, 5), (180, 10)))
lib.render_preview("ishinage_face", HEAD, 1.0, views=((0, -5), (35, 0)))
lib.export_glb("ishinage")
