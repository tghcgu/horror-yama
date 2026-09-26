"""崖の岩肌から生えてきて、登っている人の足をつかむ「壁の手」のモデルを作る。

骨ばった青白い腕。爪は黒く割れ、指は人より長い。
原点が岩肌（腕の付け根）。腕は +Y（壁の外）へ伸び、手のひらは下（-Z）を向いて開いている。
実行: blender -b --factory-startup --python tools/creatures/build_wall_hand.py
"""
import os
import sys

sys.path.append(os.path.dirname(__file__))
import creature_lib as lib  # noqa: E402
from mathutils import Vector  # noqa: E402

WRIST = Vector((0, 0.5, 0.02))
FINGERS = (-0.045, -0.015, 0.015, 0.045)


def finger_points(dx, length):
    base = WRIST + Vector((dx, 0.1, 0.0))
    return [base, base + Vector((dx * 0.3, length * 0.4, -0.01)), base + Vector((dx * 0.5, length * 0.72, -0.03)),
            base + Vector((dx * 0.6, length, -0.06))]


lib.reset()
body = lib.Meta("wall_hand_body", resolution=0.007)

# 岩から出ている腕（付け根は岩の中に埋まるので太め）
body.limb([(0, -0.08, 0), (0, 0.2, 0.01), WRIST], [0.06, 0.042, 0.032])
body.ball((0, 0.22, -0.02), 0.035)  # 骨の出っ張り
# 手の甲と、長い指・親指
body.ellipsoid(WRIST + Vector((0, 0.06, 0)), 0.055, (1.15, 1.0, 0.4))
for dx, length in zip(FINGERS, (0.2, 0.26, 0.27, 0.22)):
    points = finger_points(dx, length)
    body.limb(points, [0.013, 0.012, 0.01, 0.008])
    for p in points[1:3]:
        body.ball(p, 0.013)
body.limb([WRIST + Vector((0.05, 0.03, -0.01)), WRIST + Vector((0.1, 0.08, -0.03)), WRIST + Vector((0.12, 0.14, -0.05))],
          [0.016, 0.013, 0.01])

skin = body.to_mesh()
skin.name = "WallHand"
lib.add_surface_detail(skin, 0.002, 0.03, 'VORONOI')
lib.smooth(skin, iterations=1, factor=0.4)
lib.reduce_to(skin, 2500)
print("TRIANGLES", sum(len(p.vertices) - 2 for p in skin.data.polygons))


def dead_skin(nodes, links):
    coord = nodes.new('ShaderNodeTexCoord')
    noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=12.0, Detail=5.0)
    links.new(coord.outputs['Object'], noise.inputs['Vector'])
    color = lib.ramp(nodes, links, noise.outputs['Fac'],
                     [(0.35, (0.5, 0.52, 0.52)), (0.6, (0.62, 0.6, 0.57)), (0.8, (0.66, 0.6, 0.58))])
    # 岩の中から出てきたので、付け根ほど土と岩の粉で汚れている
    separate = nodes.new('ShaderNodeSeparateXYZ')
    links.new(coord.outputs['Object'], separate.inputs['Vector'])
    dirt = lib.ramp(nodes, links, separate.outputs['Y'], [(0.0, (1.0, 1.0, 1.0)), (0.3, (0.0, 0.0, 0.0))])
    color = lib.mix(nodes, links, color, (0.18, 0.15, 0.12), dirt)
    veins = lib.node(nodes, 'ShaderNodeTexVoronoi', feature='DISTANCE_TO_EDGE', Scale=18.0)
    links.new(coord.outputs['Object'], veins.inputs['Vector'])
    vein_mask = lib.ramp(nodes, links, veins.outputs['Distance'], [(0.0, (0.6, 0.6, 0.6)), (0.02, (0.0, 0.0, 0.0))])
    color = lib.mix(nodes, links, color, (0.3, 0.32, 0.42), vein_mask)
    occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.03)
    shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.2, 0.2, 0.2)), (1.0, (1.0, 1.0, 1.0))])
    return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')


lib.bpy.context.scene.cycles.samples = 48
lib.unwrap(skin)
lib.bake_color(skin, "wall_hand_skin", dead_skin, size=256, final_size=128)

nail = lib.flat_material("Claw", (0.05, 0.04, 0.04))
parts = []
for dx, length in zip(FINGERS, (0.2, 0.26, 0.27, 0.22)):
    tip = finger_points(dx, length)[-1]
    c = lib.cone_between(tip, tip + Vector((0, 0.035, -0.02)), 0.009, nail, vertices=5)
    lib.bind_whole(c, "fingers")
    parts.append(c)

bones = [
    lib.Bone("arm", (0, -0.08, 0), WRIST, None, 0.05),
    lib.Bone("hand", WRIST, WRIST + Vector((0, 0.1, 0)), "arm", 0.06, allow=lambda co: co.y > 0.45),
    lib.Bone("fingers", WRIST + Vector((0, 0.1, 0)), WRIST + Vector((0, 0.38, -0.06)), "hand", 0.05,
             allow=lambda co: co.y > 0.58),
]
lib.skin_to_bones(skin, bones)
skin = lib.join(skin, parts)
rig = lib.build_armature("WallHandRig", bones)
lib.attach_to_armature(skin, rig)

lib.render_preview("wall_hand", (0, 0.4, 0), 1.4, views=((40, 40), (90, 10), (0, 60)))
lib.export_glb("wall_hand")
