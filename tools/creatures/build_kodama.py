"""樹海にいる「木霊（こだま）」のモデルを作る。

ひざくらいの背丈の、白くてぷにっとした小さな人形。体に比べて大きな丸い頭に、
穴があいただけの 2 つの目と口。細い手足。かわいいのに、どこか気味が悪い。
原点が足元。正面は +Y。
実行: blender -b --factory-startup --python tools/creatures/build_kodama.py
"""
import os
import sys

sys.path.append(os.path.dirname(__file__))
import creature_lib as lib  # noqa: E402
from mathutils import Vector  # noqa: E402

SIDES = (1, -1)
HEAD = Vector((0, 0, 0.44))

lib.reset()
body = lib.Meta("kodama_body", resolution=0.006)

# 小さな胴（下へ向かって少しふくらむ）
body.ellipsoid((0, 0, 0.19), 0.075, (1.0, 0.85, 1.45))
body.ellipsoid((0, 0, 0.13), 0.08, (1.05, 0.9, 0.9))
# 細い手足
for side in SIDES:
    body.limb([(0.07 * side, 0, 0.26), (0.11 * side, 0.01, 0.17), (0.12 * side, 0.03, 0.09)], [0.022, 0.018, 0.016])
    body.ball((0.12 * side, 0.035, 0.08), 0.022)
    body.limb([(0.04 * side, 0, 0.1), (0.045 * side, 0.01, 0.02)], [0.028, 0.024])
    body.ellipsoid((0.045 * side, 0.02, 0.012), 0.025, (1.0, 1.4, 0.55))
# 大きな丸い頭と、ぽっかりあいた目と口
body.limb([(0, 0, 0.26), (0, 0, 0.32)], [0.04, 0.05])
body.ellipsoid(HEAD, 0.15, (1.0, 0.92, 0.95))
for side in SIDES:
    body.ball(HEAD + Vector((0.052 * side, 0.12, 0.02)), 0.03, negative=True)
body.ellipsoid(HEAD + Vector((0, 0.13, -0.065)), 0.026, (1.25, 1.0, 0.85), negative=True)

skin = body.to_mesh()
skin.name = "Kodama"
lib.add_surface_detail(skin, 0.002, 0.06, 'CLOUDS')
lib.smooth(skin, iterations=2, factor=0.5)
lib.reduce_to(skin, 2500)
print("TRIANGLES", sum(len(p.vertices) - 2 for p in skin.data.polygons))


def pale_body(nodes, links):
    coord = nodes.new('ShaderNodeTexCoord')
    noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=7.0, Detail=4.0)
    links.new(coord.outputs['Object'], noise.inputs['Vector'])
    color = lib.ramp(nodes, links, noise.outputs['Fac'],
                     [(0.35, (0.78, 0.82, 0.76)), (0.6, (0.88, 0.9, 0.85)), (0.8, (0.92, 0.93, 0.9))])
    occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.05)
    shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.12, 0.16, 0.14)), (1.0, (1.0, 1.0, 1.0))])
    return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')


lib.bpy.context.scene.cycles.samples = 48
lib.unwrap(skin)
lib.bake_color(skin, "kodama_skin", pale_body, size=256, final_size=128)

# 目と口の穴の奥は真っ黒
black = lib.flat_material("EyeBlack", (0.0, 0.0, 0.0))
parts = []
for side in SIDES:
    hole = lib.primitive('uv_sphere', HEAD + Vector((0.052 * side, 0.1, 0.02)), material=black, radius=0.027, segments=8, ring_count=6)
    lib.bind_whole(hole, "head")
    parts.append(hole)
mouth = lib.primitive('uv_sphere', HEAD + Vector((0, 0.11, -0.065)), scale=(1.2, 1.0, 0.8), material=black, radius=0.024, segments=8, ring_count=6)
lib.bind_whole(mouth, "head")
parts.append(mouth)

bones = [
    lib.Bone("body", (0, 0, 0.04), (0, 0, 0.28), None, 0.09),
    lib.Bone("head", (0, 0, 0.28), (0, 0, 0.6), "body", 0.16, allow=lambda co: co.z > 0.25),
]
for side in SIDES:
    s = "L" if side > 0 else "R"
    bones += [
        lib.Bone("arm." + s, (0.07 * side, 0, 0.26), (0.12 * side, 0.03, 0.08), "body", 0.03,
                 allow=lambda co, side=side: co.x * side > 0.06 and co.z < 0.3),
        lib.Bone("leg." + s, (0.04 * side, 0, 0.1), (0.045 * side, 0.02, 0.0), "body", 0.035,
                 allow=lambda co, side=side: co.x * side > 0.005 and co.z < 0.1),
    ]
lib.skin_to_bones(skin, bones)
skin = lib.join(skin, parts)
rig = lib.build_armature("KodamaRig", bones)
lib.attach_to_armature(skin, rig)

lib.render_preview("kodama", (0, 0, 0.3), 1.3, views=((20, 10), (70, 5), (0, 0)))
lib.export_glb("kodama")
