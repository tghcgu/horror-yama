"""岩場の崖にはりつく「岩グモ」のモデルを作る。

岩のようにごつごつした甲羅（割れ目と苔）、前に集まった 8 つの赤い目、大きな牙、
ひざが高く突き出した 8 本の節のある脚と、脚に生えたトゲ。脚を広げると 1.4 m ほど。
実行: blender -b --factory-startup --python tools/creatures/build_spider.py
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
import creature_lib as lib  # noqa: E402
from mathutils import Vector  # noqa: E402

SIDES = (1, -1)
THORAX = Vector((0, 0.1, 0.13))
ABDOMEN = Vector((0, -0.28, 0.2))
LEG_ANGLES = (0.55, 1.15, 1.85, 2.45)  # 正面(+Y)から横へ回る角度（前脚 → 後ろ脚）


def leg_points(index, side):
    """脚の付け根・ひざ・足首・つま先"""
    a = LEG_ANGLES[index]
    out = Vector((side * math.sin(a), math.cos(a), 0))
    root = THORAX + out * 0.11 + Vector((0, 0, -0.01))
    knee = root + out * 0.33 + Vector((0, 0, 0.3))
    ankle = root + out * 0.7 + Vector((0, 0, 0.12))
    foot = root + out * 0.86 + Vector((0, 0, -0.13))
    return root, knee, ankle, foot


lib.reset()
random = lib.random_generator(3)
body = lib.Meta("spider_body", resolution=0.01)

# 頭胸部と、岩のこぶに覆われた大きな腹
body.ellipsoid(THORAX, 0.14, (1.0, 1.2, 0.68))
body.ellipsoid(ABDOMEN, 0.22, (1.0, 1.35, 0.85))
body.capsule(THORAX, ABDOMEN, 0.07)
for _ in range(28):
    u, v = random.uniform(0, math.tau), random.uniform(-0.3, 1.0)
    surface = Vector((0.22 * math.cos(u) * math.cos(v), 0.3 * math.sin(u) * math.cos(v), 0.19 * math.sin(v)))
    if surface.z > -0.05:
        body.ball(ABDOMEN + surface, random.uniform(0.03, 0.06))
for _ in range(10):
    u = random.uniform(0, math.tau)
    body.ball(THORAX + Vector((0.12 * math.cos(u), 0.15 * math.sin(u), 0.07)), random.uniform(0.02, 0.035))

# 太い牙の付け根と、前脚の手前の触肢
for side in SIDES:
    body.limb([THORAX + Vector((0.04 * side, 0.15, -0.02)), THORAX + Vector((0.05 * side, 0.22, -0.1))], [0.035, 0.028])
    body.limb([THORAX + Vector((0.07 * side, 0.14, 0.0)), THORAX + Vector((0.13 * side, 0.3, 0.06)),
               THORAX + Vector((0.12 * side, 0.36, -0.1))], [0.022, 0.018, 0.012])

# 8 本の脚
for index in range(4):
    for side in SIDES:
        root, knee, ankle, foot = leg_points(index, side)
        body.limb([root, knee, ankle, foot], [0.032, 0.026, 0.018, 0.008])
        body.ball(knee, 0.034)
        body.ball(ankle, 0.022)

shell = body.to_mesh()
shell.name = "Spider"
lib.add_surface_detail(shell, 0.01, 0.05, 'VORONOI')
lib.add_surface_detail(shell, 0.006, 0.15, 'CLOUDS')
lib.reduce_to(shell, 6000)
print("TRIANGLES", sum(len(p.vertices) - 2 for p in shell.data.polygons))


def rock_shell(nodes, links):
    coord = nodes.new('ShaderNodeTexCoord')
    noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=5.0, Detail=8.0)
    links.new(coord.outputs['Object'], noise.inputs['Vector'])
    color = lib.ramp(nodes, links, noise.outputs['Fac'],
                     [(0.35, (0.1, 0.09, 0.08)), (0.55, (0.2, 0.18, 0.16)), (0.75, (0.3, 0.27, 0.23))])
    # 岩の割れ目
    cracks = lib.node(nodes, 'ShaderNodeTexVoronoi', feature='DISTANCE_TO_EDGE', Scale=14.0)
    links.new(coord.outputs['Object'], cracks.inputs['Vector'])
    crack_mask = lib.ramp(nodes, links, cracks.outputs['Distance'], [(0.0, (1.0, 1.0, 1.0)), (0.04, (0.0, 0.0, 0.0))])
    color = lib.mix(nodes, links, color, (0.02, 0.018, 0.015), crack_mask)
    # 苔のまだら（上を向いた面だけ）
    moss = lib.node(nodes, 'ShaderNodeTexNoise', Scale=11.0, Detail=4.0)
    links.new(coord.outputs['Object'], moss.inputs['Vector'])
    moss_mask = lib.ramp(nodes, links, moss.outputs['Fac'], [(0.6, (0.0, 0.0, 0.0)), (0.7, (0.8, 0.8, 0.8))])
    geometry = nodes.new('ShaderNodeNewGeometry')
    separate = nodes.new('ShaderNodeSeparateXYZ')
    links.new(geometry.outputs['Normal'], separate.inputs['Vector'])
    up = lib.ramp(nodes, links, separate.outputs['Z'], [(0.3, (0.0, 0.0, 0.0)), (0.8, (1.0, 1.0, 1.0))])
    moss_on_top = lib.mix(nodes, links, moss_mask, up, 1.0, blend='MULTIPLY')
    color = lib.mix(nodes, links, color, (0.12, 0.16, 0.07), moss_on_top)
    # 出っ張りは明るく、くぼみは暗く
    ridges = lib.ramp(nodes, links, geometry.outputs['Pointiness'], [(0.5, (0.0, 0.0, 0.0)), (0.6, (0.6, 0.6, 0.6))])
    color = lib.mix(nodes, links, color, (0.42, 0.39, 0.34), ridges)
    occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.06)
    shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.15, 0.15, 0.15)), (1.0, (1.0, 1.0, 1.0))])
    return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')


lib.bpy.context.scene.cycles.samples = 64
lib.unwrap(shell)
lib.bake_color(shell, "spider_skin", rock_shell)

# --- 目・牙・トゲ ---
eye = lib.flat_material("Eye", (1.0, 0.12, 0.08), emission=(1.0, 0.1, 0.06), strength=6.0)
fang = lib.flat_material("Claw", (0.06, 0.05, 0.04))
parts = []
for i, (x, z, r) in enumerate([(0.03, 0.2, 0.018), (-0.03, 0.2, 0.018), (0.065, 0.18, 0.012), (-0.065, 0.18, 0.012),
                               (0.02, 0.235, 0.01), (-0.02, 0.235, 0.01), (0.075, 0.215, 0.008), (-0.075, 0.215, 0.008)]):
    e = lib.primitive('uv_sphere', THORAX + Vector((x, 0.155, z - 0.13)), material=eye, radius=r * 1.35, segments=8, ring_count=6)
    lib.bind_whole(e, "thorax")
    parts.append(e)
for side in SIDES:
    tip = THORAX + Vector((0.05 * side, 0.22, -0.1))
    f = lib.cone_between(tip, tip + Vector((-0.02 * side, 0.03, -0.09)), 0.016, fang)
    lib.bind_whole(f, "fangs")
    parts.append(f)
for index in range(4):
    for side in SIDES:
        root, knee, ankle, foot = leg_points(index, side)
        s = "L" if side > 0 else "R"
        for segment, (a, b) in enumerate(((root, knee), (knee, ankle))):
            for k in range(3):
                p = a.lerp(b, 0.25 + k * 0.25)
                outward = (Vector((p.x, p.y, 0)) - Vector((THORAX.x, THORAX.y, 0))).normalized()
                spike = lib.cone_between(p, p + outward * 0.05 + Vector((0, 0, 0.03)), 0.005, fang, vertices=4)
                lib.bind_whole(spike, "leg%d%s.%s" % (index, "ab"[segment], s))
                parts.append(spike)

# --- 骨 ---
bones = [
    lib.Bone("thorax", THORAX + Vector((0, -0.12, 0)), THORAX + Vector((0, 0.14, 0)), None, 0.14),
    lib.Bone("abdomen", THORAX + Vector((0, -0.12, 0.02)), ABDOMEN + Vector((0, -0.28, 0.05)), "thorax", 0.25),
    lib.Bone("fangs", THORAX + Vector((0, 0.14, -0.01)), THORAX + Vector((0, 0.25, -0.12)), "thorax", 0.05),
]
for index in range(4):
    for side in SIDES:
        root, knee, ankle, foot = leg_points(index, side)
        s = "L" if side > 0 else "R"
        bones += [
            lib.Bone("leg%da.%s" % (index, s), root, knee, "thorax", 0.035),
            lib.Bone("leg%db.%s" % (index, s), knee, ankle, "leg%da.%s" % (index, s), 0.028),
            lib.Bone("leg%dc.%s" % (index, s), ankle, foot, "leg%db.%s" % (index, s), 0.02),
        ]

lib.skin_to_bones(shell, bones)
shell = lib.join(shell, parts)
rig = lib.build_armature("SpiderRig", bones)
lib.attach_to_armature(shell, rig)

lib.render_preview("spider", (0, 0.0, 0.15), 2.2, views=((25, 35), (90, 15), (0, 10)))
lib.export_glb("spider")
