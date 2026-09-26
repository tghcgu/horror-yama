"""雪の下を泳ぎ、足元から飛び出してくる「雪潜り」のモデルを作る。

太いミミズのような、節のある青白い体。先端はヤツメウナギのような丸い口になっていて、
内側へ向かって何重にも歯が並ぶ。原点が雪の表面。体は下（-Z）から上へ、少し前（+Y）へ反って伸びる。
実行: blender -b --factory-startup --python tools/creatures/build_yukimoguri.py
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
import creature_lib as lib  # noqa: E402
from mathutils import Vector  # noqa: E402

SPINE = [Vector((0, -0.25, -1.3)), Vector((0, -0.2, -0.7)), Vector((0, -0.05, -0.1)), Vector((0, 0.15, 0.45)),
         Vector((0, 0.4, 0.85))]
MOUTH = Vector((0, 0.52, 1.0))
MOUTH_AXIS = Vector((0, 0.6, 0.8)).normalized()

lib.reset()
body = lib.Meta("yukimoguri_body", resolution=0.016)

# 節のある胴：節ごとに少しふくらむ
for i in range(len(SPINE) - 1):
    for k in range(4):
        t = (k + 0.5) / 4
        p = SPINE[i].lerp(SPINE[i + 1], t)
        r = 0.3 - 0.02 * (i + t)
        body.ellipsoid(p, r, (1.0, 1.0, 0.55), axis=SPINE[i + 1] - SPINE[i])
    body.capsule(SPINE[i], SPINE[i + 1], 0.24 - 0.02 * i)
# 先端の丸い口（穴をあける）
body.ellipsoid(MOUTH - MOUTH_AXIS * 0.12, 0.28, (1.0, 1.0, 0.7), axis=MOUTH_AXIS)
body.ellipsoid(MOUTH, 0.2, (1.0, 1.0, 0.8), axis=MOUTH_AXIS, negative=True)

skin = body.to_mesh()
skin.name = "Yukimoguri"
lib.add_surface_detail(skin, 0.01, 0.04, 'VORONOI')
lib.smooth(skin, iterations=1, factor=0.4)
lib.reduce_to(skin, 5000)
print("TRIANGLES", sum(len(p.vertices) - 2 for p in skin.data.polygons))


def worm_skin(nodes, links):
    coord = nodes.new('ShaderNodeTexCoord')
    noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=5.0, Detail=5.0)
    links.new(coord.outputs['Object'], noise.inputs['Vector'])
    color = lib.ramp(nodes, links, noise.outputs['Fac'],
                     [(0.35, (0.62, 0.6, 0.64)), (0.6, (0.72, 0.66, 0.68)), (0.8, (0.78, 0.72, 0.72))])
    # 節の境目の暗い溝
    wave = lib.node(nodes, 'ShaderNodeTexWave', wave_type='BANDS', bands_direction='Z', Scale=4.5, Distortion=1.0)
    links.new(coord.outputs['Object'], wave.inputs['Vector'])
    grooves = lib.ramp(nodes, links, wave.outputs['Fac'], [(0.0, (0.8, 0.8, 0.8)), (0.12, (0.0, 0.0, 0.0))])
    color = lib.mix(nodes, links, color, (0.25, 0.18, 0.2), grooves)
    # 口のまわりは赤黒い
    separate = nodes.new('ShaderNodeSeparateXYZ')
    links.new(coord.outputs['Object'], separate.inputs['Vector'])
    lip = lib.ramp(nodes, links, separate.outputs['Z'], [(0.78, (0.0, 0.0, 0.0)), (0.95, (1.0, 1.0, 1.0))])
    color = lib.mix(nodes, links, color, (0.35, 0.08, 0.08), lip)
    occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.12)
    shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.05, 0.02, 0.02)), (1.0, (1.0, 1.0, 1.0))])
    return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')


lib.bpy.context.scene.cycles.samples = 48
lib.unwrap(skin)
lib.bake_color(skin, "yukimoguri_skin", worm_skin)

# 口の内側へ向かって、何重にも並ぶ歯
tooth = lib.flat_material("Teeth", (0.75, 0.72, 0.6))
throat = lib.flat_material("EyeBlack", (0.05, 0.0, 0.0))
parts = []
side_a = MOUTH_AXIS.orthogonal().normalized()
side_b = MOUTH_AXIS.cross(side_a).normalized()
for ring, (radius, depth, count) in enumerate(((0.17, 0.0, 14), (0.13, -0.06, 11), (0.09, -0.12, 8))):
    for i in range(count):
        angle = i / count * math.tau + ring * 0.3
        rim = MOUTH + MOUTH_AXIS * depth + (side_a * math.cos(angle) + side_b * math.sin(angle)) * radius
        inward = (MOUTH + MOUTH_AXIS * (depth - 0.05) - rim).normalized()
        t = lib.cone_between(rim, rim + inward * 0.07, 0.016, tooth, vertices=4)
        lib.bind_whole(t, "head")
        parts.append(t)
gullet = lib.primitive('uv_sphere', MOUTH - MOUTH_AXIS * 0.18, material=throat, radius=0.12, segments=10, ring_count=6)
lib.bind_whole(gullet, "head")
parts.append(gullet)

bones = [lib.Bone("seg0", SPINE[0], SPINE[1], None, 0.3)]
for i in range(1, len(SPINE) - 1):
    bones.append(lib.Bone("seg%d" % i, SPINE[i], SPINE[i + 1], "seg%d" % (i - 1), 0.3))
bones.append(lib.Bone("head", SPINE[-1], MOUTH + MOUTH_AXIS * 0.1, "seg%d" % (len(SPINE) - 2), 0.3))
lib.skin_to_bones(skin, bones)
skin = lib.join(skin, parts)
rig = lib.build_armature("YukimoguriRig", bones)
lib.attach_to_armature(skin, rig)

lib.render_preview("yukimoguri", (0, 0.1, 0.2), 4.0, views=((30, 10), (90, 5), (10, 40)))
lib.export_glb("yukimoguri")
