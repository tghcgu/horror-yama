"""夜の“何か”（Stalker）のモデルを作る。

やせこけて背骨の曲がった、手足の長い人影。
後ろに長く伸びた頭、落ちくぼんだ眼窩の奥で光る小さな目、耳の近くまで裂けた口と尖った歯。
実行: blender -b --factory-startup --python tools/creatures/build_stalker.py
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
import creature_lib as lib  # noqa: E402
from mathutils import Vector  # noqa: E402

SIDES = (1, -1)  # +X が体の左（Blender の .L）
MOUTH_Z = 1.925  # 口の裂け目の高さ。これより上は頭、下はあごの骨に付く


def mouth_curve(t):
    """口の裂け目に沿った点。t = -1（右の口角）〜 1（左の口角）。口角は顔の横まで回り込み、少し吊り上がる"""
    return Vector((0.1 * t, 0.56 - 0.1 * t * t, MOUTH_Z + 0.022 * t * t))


# --- 体 ---
lib.reset()
body = lib.Meta("stalker_body", resolution=0.011)

# 骨盤と、細くくびれた腰
body.ellipsoid((0, 0.0, 1.0), 0.12, (1.25, 0.85, 0.75))
body.limb([(0, 0.0, 1.02), (0, 0.05, 1.28), (0, 0.12, 1.45)], [0.085, 0.068, 0.09])
body.ball((0, 0.14, 1.3), 0.045, negative=True)  # へこんだ腹

# 前に傾いた胸郭と、皮膚に浮き出たあばら骨
chest_center = Vector((0, 0.14, 1.56))
chest_r, chest_size = 0.15, (1.2, 0.8, 1.05)
chest_tilt = Vector((0, 0, 1)).rotation_difference(Vector((0, 0.35, 1)).normalized())
body.ellipsoid(chest_center, chest_r, chest_size, axis=(0, 0.35, 1))
semi = Vector((chest_r * chest_size[0], chest_r * chest_size[1], chest_r * chest_size[2]))


def chest_surface(angle_deg, height, lift=1.03):
    """胸郭の表面の点。angle は +X（体の横）から前(+Y)へ回る角度、height は胸郭の中心からの高さ"""
    ring = math.sqrt(max(0.0, 1.0 - (height / semi.z) ** 2))
    a = math.radians(angle_deg)
    local = Vector((semi.x * math.cos(a) * ring, semi.y * math.sin(a) * ring, height)) * lift
    return chest_center + chest_tilt @ local


for rib in range(5):
    height = -0.1 + rib * 0.04
    for side in SIDES:
        points = [chest_surface(angle, height - abs(angle) * 0.0004) for angle in range(-70, 80, 20)]
        points = [Vector((p.x * side, p.y, p.z)) for p in points]
        for a, b in zip(points, points[1:]):
            body.capsule(a, b, 0.011)

# 背中に浮き出た背骨の節と、突き出た肩甲骨
for i in range(11):
    t = i / 10
    if t < 0.45:
        p = Vector((0, -0.075, 1.05)).lerp(Vector((0, -0.02, 1.4)), t / 0.45)
    else:
        p = chest_surface(-90, -0.12 + (t - 0.45) / 0.55 * 0.24, lift=1.0)
    body.ball(p, 0.022)
for side in SIDES:
    body.ellipsoid((0.1 * side, 0.03, 1.62), 0.05, (1.0, 0.45, 1.3))

# 肩（鎖骨と、骨ばった肩）
for side in SIDES:
    body.capsule((0.04 * side, 0.21, 1.69), (0.23 * side, 0.17, 1.71), 0.028)
    body.ball((0.24 * side, 0.16, 1.71), 0.052)

# 細長い首と、浮き出た筋
body.limb([(0, 0.2, 1.7), (0, 0.28, 1.82), (0, 0.33, 1.9)], [0.05, 0.04, 0.045])
for side in SIDES:
    body.capsule((0.035 * side, 0.36, 1.92), (0.02 * side, 0.24, 1.7), 0.011)

# 頭：後ろ上へ長く伸びた頭蓋、前に突き出た顔、張り出した頬骨と眉の骨
body.ellipsoid((0, 0.37, 2.01), 0.12, (0.8, 1.0, 1.3), axis=(0, -0.75, 0.66))
body.ellipsoid((0, 0.47, 1.935), 0.078, (0.78, 1.15, 1.05), axis=(0, 0.5, 1))
body.capsule((-0.05, 0.495, 2.035), (0.05, 0.495, 2.035), 0.019)
for side in SIDES:
    body.ball((0.07 * side, 0.475, 1.99), 0.032)
    body.ball((0.088 * side, 0.42, 2.05), 0.032, negative=True)   # こけたこめかみ
    body.ball((0.072 * side, 0.495, 1.945), 0.022, negative=True)  # こけた頬
    body.ball((0.046 * side, 0.54, 2.0), 0.036, negative=True)    # 深い眼窩
    body.ball((0.046 * side, 0.52, 2.0), 0.03, negative=True)
body.ball((0, 0.565, 1.968), 0.014, negative=True)  # 骸骨のような鼻の穴
# 顔の横まで裂けた口
curve = [mouth_curve(t / 6) for t in range(-6, 7)]
for a, b in zip(curve, curve[1:]):
    body.capsule(a, b, 0.016, negative=True)

# 長い腕、ごつごつした関節、4 本の長い指
for side in SIDES:
    shoulder = Vector((0.24 * side, 0.16, 1.71))
    elbow = Vector((0.3 * side, 0.21, 1.02))
    wrist = Vector((0.32 * side, 0.28, 0.35))
    body.limb([shoulder, elbow, wrist], [0.042, 0.035, 0.026])
    body.ball(elbow, 0.042)
    body.ball(wrist, 0.03)
    body.ellipsoid((0.325 * side, 0.3, 0.27), 0.05, (0.5, 0.9, 1.3))
    for dx in (-0.035, -0.012, 0.012, 0.035):
        base = Vector((0.325 * side + dx * side, 0.31, 0.21))
        mid = Vector((base.x + dx * 0.3 * side, 0.34, 0.1))
        tip = Vector((base.x + dx * 0.5 * side, 0.4, 0.0))
        body.limb([base, mid, tip], [0.013, 0.011, 0.008])
        body.ball(mid, 0.014)

# 脚と、鉤爪のある足
for side in SIDES:
    hip = Vector((0.1 * side, 0.0, 0.97))
    knee = Vector((0.15 * side, 0.12, 0.55))
    ankle = Vector((0.13 * side, -0.02, 0.12))
    body.limb([hip, knee, ankle], [0.055, 0.04, 0.028])
    body.ball(knee, 0.05)
    body.limb([ankle, (0.14 * side, 0.12, 0.035)], [0.03, 0.03])
    body.ball((0.13 * side, -0.04, 0.05), 0.03)
    for dx in (-0.03, 0.0, 0.03):
        body.capsule((0.14 * side + dx, 0.12, 0.035), (0.14 * side + dx * 1.5, 0.22, 0.01), 0.011)

skin = body.to_mesh()
skin.name = "Stalker"
lib.add_surface_detail(skin, 0.006, 0.035, 'VORONOI')  # しわ
lib.add_surface_detail(skin, 0.004, 0.12, 'CLOUDS')    # こぶ
lib.smooth(skin, iterations=1, factor=0.4)
lib.reduce_to(skin, 7000)
print("TRIANGLES", sum(len(p.vertices) - 2 for p in skin.data.polygons))


# --- 肌の色の焼き込み ---
def stalker_skin(nodes, links):
    coord = nodes.new('ShaderNodeTexCoord')
    # 打ち身のような紫がかった斑
    noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=6.0, Detail=6.0)
    links.new(coord.outputs['Object'], noise.inputs['Vector'])
    color = lib.ramp(nodes, links, noise.outputs['Fac'],
                     [(0.3, (0.04, 0.04, 0.045)), (0.55, (0.075, 0.068, 0.075)), (0.8, (0.14, 0.085, 0.115))])
    # 皮膚の下の血管
    veins = lib.node(nodes, 'ShaderNodeTexVoronoi', feature='DISTANCE_TO_EDGE', Scale=9.0)
    links.new(coord.outputs['Object'], veins.inputs['Vector'])
    vein_mask = lib.ramp(nodes, links, veins.outputs['Distance'], [(0.0, (0.8, 0.8, 0.8)), (0.025, (0.0, 0.0, 0.0))])
    color = lib.mix(nodes, links, color, (0.03, 0.035, 0.08), vein_mask)
    # 骨の出っ張り（あばら・背骨・関節）は白っぽく
    geometry = nodes.new('ShaderNodeNewGeometry')
    ridges = lib.ramp(nodes, links, geometry.outputs['Pointiness'], [(0.5, (0.0, 0.0, 0.0)), (0.58, (0.7, 0.7, 0.7))])
    color = lib.mix(nodes, links, color, (0.3, 0.28, 0.25), ridges)
    # 細かい汚れ
    grime = lib.node(nodes, 'ShaderNodeTexNoise', Scale=40.0, Detail=2.0)
    links.new(coord.outputs['Object'], grime.inputs['Vector'])
    grime_shade = lib.ramp(nodes, links, grime.outputs['Fac'], [(0.4, (0.7, 0.7, 0.7)), (0.6, (1.0, 1.0, 1.0))])
    color = lib.mix(nodes, links, color, grime_shade, 1.0, blend='MULTIPLY')
    # くぼみは暗く
    occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.08)
    shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.2, 0.2, 0.2)), (1.0, (1.0, 1.0, 1.0))])
    return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')


bpy = lib.bpy
bpy.context.scene.cycles.samples = 64
lib.unwrap(skin)
lib.bake_color(skin, "stalker_skin", stalker_skin)

# --- 目・歯・爪 ---
eye = lib.flat_material("Eye", (1.0, 0.92, 0.75), emission=(1.0, 0.9, 0.7), strength=8.0)
tooth = lib.flat_material("Teeth", (0.72, 0.68, 0.58))
claw = lib.flat_material("Claw", (0.07, 0.06, 0.05))

parts = []
# 目は眼窩の奥にしまい、光る点だけが見えるようにする（左右で少し大きさが違う）
for side, radius in ((1, 0.0075), (-1, 0.006)):
    e = lib.primitive('uv_sphere', (0.046 * side, 0.522, 2.0), material=eye, radius=radius, segments=8, ring_count=6)
    lib.bind_whole(e, "head")
    parts.append(e)

# 細く不ぞろいな歯を、びっしり並べる（上下は半本ずらして、かみ合うように）
random = lib.random_generator(7)
TEETH = 15
for i in range(TEETH):
    for row in ("upper", "lower"):
        t = (i + (0.0 if row == "upper" else 0.5)) / (TEETH - 0.5) * 1.6 - 0.8
        edge = mouth_curve(t)
        inward = Vector((0, -0.006, 0))
        length = (0.026 if row == "upper" else 0.02) * (1.0 - abs(t) * 0.45) * random.uniform(0.7, 1.15)
        lean = Vector((random.uniform(-0.004, 0.004), random.uniform(0.0, 0.005), 0))
        if row == "upper":
            base = edge + inward + Vector((0, 0, 0.013))
            tip = base + lean + Vector((0, 0, -length))
            bone = "head"
        else:
            base = edge + inward + Vector((0, 0, -0.013))
            tip = base + lean + Vector((0, 0, length))
            bone = "jaw"
        tooth_mesh = lib.cone_between(base, tip, random.uniform(0.0035, 0.005), tooth, vertices=5)
        lib.bind_whole(tooth_mesh, bone)
        parts.append(tooth_mesh)

for side in SIDES:
    for dx in (-0.035, -0.012, 0.012, 0.035):
        tip = Vector((0.325 * side + dx * side * 1.5, 0.4, 0.0))
        c = lib.cone_between(tip, tip + Vector((0, 0.05, -0.035)), 0.008, claw)
        lib.bind_whole(c, "fingers." + ("L" if side > 0 else "R"))
        parts.append(c)
    for dx in (-0.03, 0.0, 0.03):
        tip = Vector((0.14 * side + dx * 1.5, 0.22, 0.01))
        c = lib.cone_between(tip, tip + Vector((0, 0.04, -0.012)), 0.008, claw)
        lib.bind_whole(c, "foot." + ("L" if side > 0 else "R"))
        parts.append(c)

# --- 骨 ---
def below_mouth(co):
    """口の裂け目より下の、あごの部分か"""
    return co.y > 0.4 and co.z < MOUTH_Z + 0.022 * min((co.x / 0.1) ** 2, 1.0)


bones = [
    lib.Bone("hips", (0, 0, 0.9), (0, 0.02, 1.1), None, 0.14),
    lib.Bone("spine", (0, 0.02, 1.1), (0, 0.1, 1.42), "hips", 0.1),
    lib.Bone("chest", (0, 0.1, 1.42), (0, 0.2, 1.72), "spine", 0.18),
    lib.Bone("neck", (0, 0.2, 1.72), (0, 0.33, 1.9), "chest", 0.05),
    lib.Bone("head", (0, 0.33, 1.9), (0, 0.5, 2.08), "neck", 0.14, allow=lambda co: not below_mouth(co)),
    lib.Bone("jaw", (0, 0.38, 1.9), (0, 0.56, 1.9), "head", 0.07, allow=below_mouth),
]
for side in SIDES:
    s = "L" if side > 0 else "R"
    bones += [
        lib.Bone("clavicle." + s, (0.04 * side, 0.2, 1.7), (0.24 * side, 0.16, 1.71), "chest", 0.05),
        lib.Bone("upperarm." + s, (0.24 * side, 0.16, 1.71), (0.3 * side, 0.21, 1.02), "clavicle." + s, 0.045),
        lib.Bone("forearm." + s, (0.3 * side, 0.21, 1.02), (0.32 * side, 0.28, 0.35), "upperarm." + s, 0.035),
        lib.Bone("hand." + s, (0.32 * side, 0.28, 0.35), (0.325 * side, 0.31, 0.2), "forearm." + s, 0.05),
        lib.Bone("fingers." + s, (0.325 * side, 0.31, 0.2), (0.33 * side, 0.38, 0.0), "hand." + s, 0.03),
        lib.Bone("thigh." + s, (0.1 * side, 0.0, 0.95), (0.15 * side, 0.12, 0.55), "hips", 0.06),
        lib.Bone("shin." + s, (0.15 * side, 0.12, 0.55), (0.13 * side, -0.02, 0.12), "thigh." + s, 0.045),
        lib.Bone("foot." + s, (0.13 * side, -0.02, 0.12), (0.14 * side, 0.2, 0.02), "shin." + s, 0.04),
    ]

lib.skin_to_bones(skin, bones)
skin = lib.join(skin, parts)
rig = lib.build_armature("StalkerRig", bones)
lib.attach_to_armature(skin, rig)

lib.render_preview("stalker", (0, 0.25, 1.15), 3.4)
lib.render_preview("stalker_face", (0, 0.47, 1.97), 0.75, views=((0, 5), (35, 10), (80, 0)))
lib.export_glb("stalker")
