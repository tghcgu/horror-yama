"""人熊（ひとくま）のモデルを作る：後ろ足で立ち上がったまま歩く、背丈 3 m の巨大なツキノワグマ。

前かがみの樽のような胴、肩の上に盛り上がった筋肉のこぶ、ぼさぼさの長い毛のたてがみ。
膝まで届く太く長い腕に、鎌のような長い爪。大きく開いたあごに、黄ばんだ牙がびっしり。
小さく光る目。胸には白い月の輪。ところどころ毛が抜けて、傷だらけの皮膚がのぞき、口と爪は血で汚れている。
実行: blender -b --factory-startup --python tools/creatures/build_hitokuma.py
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
import creature_lib as lib  # noqa: E402
from mathutils import Vector  # noqa: E402

SIDES = (1, -1)  # +X が体の左（Blender の .L）
MOUTH_Z = 2.36   # 口の高さ。これより下の鼻先の部分は、あごの骨に付く

lib.reset()
body = lib.Meta("hitokuma_body", resolution=0.03)
random = lib.random_generator(31)

# 腰と、前かがみの樽のような胴
body.ellipsoid((0, 0.0, 1.2), 0.36, (1.3, 1.0, 0.95))
body.ellipsoid((0, 0.12, 1.62), 0.44, (1.2, 0.95, 1.2), axis=(0, 0.35, 1))
body.ellipsoid((0, 0.3, 2.02), 0.46, (1.3, 0.9, 1.0), axis=(0, 0.5, 1))
# 肩の上に盛り上がった筋肉のこぶ
body.ellipsoid((0, 0.08, 2.36), 0.34, (1.35, 1.0, 0.8))
# 太い首
body.limb([(0, 0.35, 2.3), (0, 0.55, 2.45), (0, 0.7, 2.52)], [0.3, 0.26, 0.24])

# 頭：丸い頭蓋、長い鼻づら、小さな丸い耳、張り出した眉
body.ellipsoid((0, 0.76, 2.58), 0.24, (1.1, 1.05, 0.95))
body.limb([(0, 0.92, 2.54), (0, 1.1, 2.5), (0, 1.22, 2.47)], [0.15, 0.12, 0.1])
body.ball((0, 1.27, 2.47), 0.07)  # 鼻先
for side in SIDES:
    body.ball((0.2 * side, 0.66, 2.8), 0.09)              # 耳
    body.ball((0.2 * side, 0.69, 2.8), 0.05, negative=True)  # 耳の穴
    body.capsule((0.16 * side, 0.9, 2.67), (0.04 * side, 0.95, 2.69), 0.05)  # 眉の骨
    body.ball((0.11 * side, 0.94, 2.62), 0.045, negative=True)  # 落ちくぼんだ目
    body.ball((0.035 * side, 1.3, 2.49), 0.02, negative=True)  # 鼻の穴
# 大きく開いた口と、下あご
body.capsule((0, 0.92, MOUTH_Z + 0.0), (0, 1.3, MOUTH_Z - 0.03), 0.085, negative=True)
body.limb([(0, 0.84, 2.26), (0, 1.0, 2.16), (0, 1.14, 2.08)], [0.12, 0.1, 0.075])  # 大きく開いた下あご

# ぼさぼさの毛のたてがみ（肩のこぶと背中、首のまわりに、毛の束が逆立つ）
for i in range(80):
    a = random.uniform(-2.4, 2.4)
    z = random.uniform(1.75, 2.6)
    r = 0.44 + 0.1 * math.cos(a)
    base = Vector((math.sin(a) * r * 1.1, -math.cos(a) * r * 0.5 + 0.12, z))
    out = Vector((math.sin(a), -math.cos(a) * 0.9, -0.6)).normalized()  # 毛の束は、外へ、下へ垂れる
    body.capsule(base, base + out * random.uniform(0.2, 0.32), random.uniform(0.026, 0.04))

# 毛の抜けた脇腹に、浮き出たあばら
for rib in range(4):
    z = 1.55 + rib * 0.11
    for side in SIDES:
        body.capsule((0.46 * side, 0.1, z), (0.42 * side, 0.34, z + 0.05), 0.035)

# 膝まで届く、太く長い腕。大きな手のひら
for side in SIDES:
    shoulder = Vector((0.58 * side, 0.22, 2.2))
    elbow = Vector((0.8 * side, 0.45, 1.5))
    wrist = Vector((0.74 * side, 0.78, 0.85))
    body.limb([shoulder, elbow, wrist], [0.25, 0.19, 0.14])
    body.ball(shoulder, 0.27)
    body.ball(elbow, 0.19)
    body.ellipsoid(wrist + Vector((0, 0.08, -0.12)), 0.17, (1.15, 1.2, 0.75))
    for i in range(10):  # 腕の毛の束
        t = random.uniform(0.1, 0.9)
        p = shoulder.lerp(elbow, t * 2) if t < 0.5 else elbow.lerp(wrist, t * 2 - 1)
        out = Vector((side, -0.4, -0.3)).normalized()
        body.capsule(p, p + out * random.uniform(0.1, 0.17), random.uniform(0.035, 0.06))

# 短く太い脚と、大きな足
for side in SIDES:
    hip = Vector((0.32 * side, 0.0, 1.12))
    knee = Vector((0.4 * side, 0.22, 0.62))
    ankle = Vector((0.36 * side, -0.02, 0.2))
    body.limb([hip, knee, ankle], [0.28, 0.21, 0.15])
    body.ball(knee, 0.21)
    body.ellipsoid((0.36 * side, 0.14, 0.09), 0.16, (1.05, 1.7, 0.6))

skin = body.to_mesh()
skin.name = "Hitokuma"
lib.add_surface_detail(skin, 0.02, 0.06, 'VORONOI')  # 毛の房のでこぼこ
lib.add_surface_detail(skin, 0.012, 0.2, 'CLOUDS')
lib.smooth(skin, iterations=1, factor=0.35)
lib.reduce_to(skin, 9000)
print("TRIANGLES", sum(len(p.vertices) - 2 for p in skin.data.polygons))


# --- 毛並みの焼き込み ---
def hitokuma_fur(nodes, links):
    coord = nodes.new('ShaderNodeTexCoord')
    obj = coord.outputs['Object']
    # 黒い毛に、茶色がかった毛先の筋（縦に流れる）
    strands = lib.node(nodes, 'ShaderNodeTexWave', wave_type='BANDS', bands_direction='Z', Scale=18.0, Distortion=9.0, Detail=6.0)
    links.new(obj, strands.inputs['Vector'])
    color = lib.ramp(nodes, links, strands.outputs['Fac'],
                     [(0.2, (0.018, 0.015, 0.014)), (0.6, (0.05, 0.04, 0.035)), (0.95, (0.13, 0.09, 0.06))])
    clumps = lib.node(nodes, 'ShaderNodeTexNoise', Scale=7.0, Detail=5.0)
    links.new(obj, clumps.inputs['Vector'])
    clump_shade = lib.ramp(nodes, links, clumps.outputs['Fac'], [(0.35, (0.55, 0.55, 0.55)), (0.65, (1.15, 1.15, 1.15))])
    color = lib.mix(nodes, links, color, clump_shade, 1.0, blend='MULTIPLY')
    # 胸の白い月の輪（前側の、鎖骨の下を横切る三日月）
    separate = nodes.new('ShaderNodeSeparateXYZ')
    links.new(obj, separate.inputs['Vector'])
    moon = nodes.new('ShaderNodeMath')
    moon.operation = 'MULTIPLY_ADD'  # z + x^2 * 0.9 （両はしが上へ反る三日月）
    square = nodes.new('ShaderNodeMath')
    square.operation = 'MULTIPLY'
    links.new(separate.outputs['X'], square.inputs[0])
    links.new(separate.outputs['X'], square.inputs[1])
    links.new(square.outputs['Value'], moon.inputs[0])
    moon.inputs[1].default_value = -0.9
    links.new(separate.outputs['Z'], moon.inputs[2])
    shifted = nodes.new('ShaderNodeMath')  # 色の段は 0〜1 なので、高さ 1.9 m を 0 にずらす
    shifted.operation = 'ADD'
    links.new(moon.outputs['Value'], shifted.inputs[0])
    shifted.inputs[1].default_value = -1.9
    band = lib.ramp(nodes, links, shifted.outputs['Value'], [(0.17, (0, 0, 0)), (0.2, (1, 1, 1)), (0.25, (1, 1, 1)), (0.28, (0, 0, 0))])
    front = lib.ramp(nodes, links, separate.outputs['Y'], [(0.45, (0, 0, 0)), (0.6, (1, 1, 1))])
    moon_mask = lib.mix(nodes, links, band, front, 1.0, blend='MULTIPLY')
    color = lib.mix(nodes, links, color, (0.72, 0.68, 0.6), moon_mask)
    # 毛が抜けて、傷だらけの皮膚がのぞく所
    mange = lib.node(nodes, 'ShaderNodeTexNoise', Scale=2.2, Detail=6.0, Roughness=0.7)
    links.new(obj, mange.inputs['Vector'])
    bald = lib.ramp(nodes, links, mange.outputs['Fac'], [(0.66, (0, 0, 0)), (0.7, (1, 1, 1))])  # ところどころの、大きな抜け跡
    scar_noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=30.0, Detail=3.0)
    links.new(obj, scar_noise.inputs['Vector'])
    skin_color = lib.ramp(nodes, links, scar_noise.outputs['Fac'], [(0.35, (0.32, 0.2, 0.2)), (0.6, (0.45, 0.33, 0.3)), (0.75, (0.2, 0.08, 0.07))])
    color = lib.mix(nodes, links, color, skin_color, bald)
    # 口のまわりと手の先の、黒ずんだ血
    for center, radius in (((0, 1.12, 2.3), 0.26), ((0.74, 0.9, 0.7), 0.24), ((-0.74, 0.9, 0.7), 0.24)):
        vec = nodes.new('ShaderNodeVectorMath')
        vec.operation = 'DISTANCE'
        links.new(obj, vec.inputs[0])
        vec.inputs[1].default_value = center
        blood = lib.ramp(nodes, links, vec.outputs['Value'], [(radius * 0.4, (1, 1, 1)), (radius, (0, 0, 0))])
        blood_noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=12.0, Detail=4.0)
        links.new(obj, blood_noise.inputs['Vector'])
        spots = lib.ramp(nodes, links, blood_noise.outputs['Fac'], [(0.5, (0, 0, 0)), (0.62, (1, 1, 1))])
        blood_mask = lib.mix(nodes, links, blood, spots, 1.0, blend='MULTIPLY')
        color = lib.mix(nodes, links, color, (0.09, 0.012, 0.01), blood_mask)  # 乾いて黒ずんだ血
    # くぼみは暗く
    occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.2)
    shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.15, 0.15, 0.15)), (1.0, (1.0, 1.0, 1.0))])
    return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')


bpy = lib.bpy
bpy.context.scene.cycles.samples = 48
lib.unwrap(skin)
lib.bake_color(skin, "hitokuma_fur", hitokuma_fur, size=1024, final_size=512)

# --- 目・牙・爪 ---
eye = lib.flat_material("Eye", (1.0, 0.6, 0.15), emission=(1.0, 0.4, 0.08), strength=10.0)
tooth = lib.flat_material("Teeth", (0.75, 0.68, 0.5))
claw = lib.flat_material("Claw", (0.06, 0.05, 0.045))
gum = lib.flat_material("Gum", (0.3, 0.05, 0.06))

parts = []
for side in SIDES:
    e = lib.primitive('uv_sphere', (0.11 * side, 0.95, 2.62), material=eye, radius=0.03, segments=8, ring_count=6)
    lib.bind_whole(e, "head")
    parts.append(e)

# 口の中（暗い赤）と、上下の牙
mouth = lib.primitive('uv_sphere', (0, 1.04, MOUTH_Z - 0.08), material=gum, radius=0.08, segments=8, ring_count=6, scale=(1.0, 2.4, 0.9))
lib.bind_whole(mouth, "jaw")
parts.append(mouth)
for i in range(9):
    t = i / 8
    for row in ("upper", "lower"):
        x = (t - 0.5) * 0.17
        y = 1.22 - abs(t - 0.5) * 0.3
        canine = i in (1, 7)
        length = (0.11 if canine else 0.05) * random.uniform(0.8, 1.15)
        if row == "upper":
            base = Vector((x, y, MOUTH_Z + 0.04))
            tip = base + Vector((random.uniform(-0.01, 0.01), 0.01, -length))
            bone = "head"
        else:
            base = Vector((x, y - 0.1, MOUTH_Z - 0.22))
            tip = base + Vector((random.uniform(-0.01, 0.01), 0.01, length * 0.9))
            bone = "jaw"
        t_mesh = lib.cone_between(base, tip, 0.018 if canine else 0.011, tooth, vertices=5)
        lib.bind_whole(t_mesh, bone)
        parts.append(t_mesh)

# 手の、鎌のような長い爪（5 本）と、足の爪
for side in SIDES:
    s = "L" if side > 0 else "R"
    for k in range(5):
        dx = (k - 2) * 0.055
        base = Vector((0.74 * side + dx * side, 0.95, 0.7))
        tip = base + Vector((dx * 0.4 * side, 0.12, -0.26))
        c = lib.cone_between(base, tip, 0.024, claw)
        lib.bind_whole(c, "fingers." + s)
        parts.append(c)
    for k in range(5):
        dx = (k - 2) * 0.05
        base = Vector((0.36 * side + dx, 0.38, 0.06))
        tip = base + Vector((dx * 0.3, 0.12, -0.05))
        c = lib.cone_between(base, tip, 0.02, claw)
        lib.bind_whole(c, "foot." + s)
        parts.append(c)


# --- 骨 ---
def jaw_part(co):
    return co.y > 0.85 and co.z < MOUTH_Z - 0.06


bones = [
    lib.Bone("hips", (0, 0, 1.05), (0, 0.05, 1.4), None, 0.35),
    lib.Bone("spine", (0, 0.05, 1.4), (0, 0.2, 1.85), "hips", 0.35),
    lib.Bone("chest", (0, 0.2, 1.85), (0, 0.32, 2.3), "spine", 0.4),
    lib.Bone("neck", (0, 0.32, 2.3), (0, 0.68, 2.5), "chest", 0.2),
    lib.Bone("head", (0, 0.68, 2.5), (0, 1.25, 2.55), "neck", 0.22, allow=lambda co: not jaw_part(co)),
    lib.Bone("jaw", (0, 0.8, 2.28), (0, 1.16, 2.08), "head", 0.09, allow=jaw_part),
]
for side in SIDES:
    s = "L" if side > 0 else "R"
    bones += [
        lib.Bone("clavicle." + s, (0.1 * side, 0.3, 2.28), (0.58 * side, 0.22, 2.2), "chest", 0.2),
        lib.Bone("upperarm." + s, (0.58 * side, 0.22, 2.2), (0.8 * side, 0.45, 1.5), "clavicle." + s, 0.2),
        lib.Bone("forearm." + s, (0.8 * side, 0.45, 1.5), (0.74 * side, 0.78, 0.85), "upperarm." + s, 0.16),
        lib.Bone("hand." + s, (0.74 * side, 0.78, 0.85), (0.74 * side, 0.88, 0.72), "forearm." + s, 0.16),
        lib.Bone("fingers." + s, (0.74 * side, 0.88, 0.72), (0.74 * side, 1.0, 0.5), "hand." + s, 0.1),
        lib.Bone("thigh." + s, (0.32 * side, 0.0, 1.12), (0.4 * side, 0.22, 0.62), "hips", 0.24),
        lib.Bone("shin." + s, (0.4 * side, 0.22, 0.62), (0.36 * side, -0.02, 0.2), "thigh." + s, 0.18),
        lib.Bone("foot." + s, (0.36 * side, -0.02, 0.2), (0.36 * side, 0.36, 0.06), "shin." + s, 0.15),
    ]

lib.skin_to_bones(skin, bones)
skin = lib.join(skin, parts)
rig = lib.build_armature("HitokumaRig", bones)
lib.attach_to_armature(skin, rig)

lib.render_preview("hitokuma", (0, 0.4, 1.5), 6.0)
lib.render_preview("hitokuma_face", (0, 1.0, 2.5), 1.6, views=((0, 5), (35, 10), (80, 0)))
lib.export_glb("hitokuma")
