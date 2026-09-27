"""プレイヤー（登山者）のモデルを作る。ロビーの鏡に映る姿で、あとで友達と遊ぶときの見た目にもなる。

大きな丸い頭のちびキャラ。身長 1.65 m。着せ替えができるように、部分ごとに別の形として作り、
ゲームの中で表示を切り替える（名前の頭で種類がわかる）:
    Hat_*（帽子）、Hair_*（髪）、Top_*（上着）、Neck_*（首まわり）、Face_*（表情）
帽子・上着・首まわり・髪・肌の模様は灰色で焼き込み、色はゲームの中で塗る（鏡の前で選べる）。
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
FACE_Y = 0.225  # 顔の表面（頭の中心から前へ）
HIP = {s: Vector((0.09 * s, 0.0, 0.52)) for s in SIDES}
KNEE = {s: Vector((0.1 * s, 0.02, 0.3)) for s in SIDES}
ANKLE = {s: Vector((0.1 * s, 0.0, 0.1)) for s in SIDES}
SHOULDER = {s: Vector((0.2 * s, 0.0, 0.98)) for s in SIDES}
ELBOW = {s: Vector((0.29 * s, 0.03, 0.8)) for s in SIDES}
WRIST = {s: Vector((0.32 * s, 0.07, 0.64)) for s in SIDES}
GREY = ((0.55, 0.55, 0.55), (0.66, 0.66, 0.66))  # 色を塗る部分の、焼き込みの明るさ

lib.reset()


def fabric(dark, light, scale, quilt=0.0):
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


def hair_strands(nodes, links):
    """髪の焼き込み：毛の流れの筋と、くぼみの陰（灰色。色はゲームの中で塗る）"""
    coord = nodes.new('ShaderNodeTexCoord')
    wave = lib.node(nodes, 'ShaderNodeTexWave', wave_type='BANDS', bands_direction='Z', Scale=38.0, Distortion=4.0)
    links.new(coord.outputs['Object'], wave.inputs['Vector'])
    color = lib.ramp(nodes, links, wave.outputs['Fac'], [(0.0, (0.5, 0.5, 0.5)), (0.5, (0.7, 0.7, 0.7)), (1.0, (0.6, 0.6, 0.6))])
    occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.04)
    shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.4, 0.4, 0.4)), (1.0, (1.0, 1.0, 1.0))])
    return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')


def finish(meta, name, triangles, detail=0.0):
    mesh = meta.to_mesh()
    mesh.name = name
    if detail > 0.0:
        lib.add_surface_detail(mesh, detail, 0.08, 'CLOUDS')
    lib.smooth(mesh, iterations=2, factor=0.5)
    lib.reduce_to(mesh, triangles)
    return mesh


def join_parts(mesh, parts):
    """メタボールの形に、とがった部分（円すいなど）をくっつけてひとつにする"""
    return lib.join(mesh, parts) if parts else mesh


def face_opening(meta):
    """帽子や髪の、顔を出す穴"""
    meta.ellipsoid(HEAD + Vector((0, 0.19, -0.06)), 0.2, (1.1, 0.5, 0.6), negative=True)


# ============================== 帽子 ==============================
hats = {}

m = lib.Meta("hat_beanie", resolution=0.01)  # ニット帽（ぽんぽん付き）
m.ellipsoid(HEAD + Vector((0, -0.02, 0.07)), HEAD_R * 1.06, (1.05, 0.98, 0.8))
m.ellipsoid(HEAD + Vector((0, -0.01, 0.2)), 0.2, (1.0, 1.0, 0.7))
m.ball(HEAD + Vector((0, -0.03, 0.38)), 0.09)
m.ellipsoid(HEAD + Vector((0, -0.005, 0.02)), HEAD_R * 1.1, (1.05, 0.98, 0.22))
face_opening(m)
hats["beanie"] = (finish(m, "Hat_beanie", 1400), 60.0)

m = lib.Meta("hat_cap", resolution=0.01)  # キャップ（つば付き）
m.ellipsoid(HEAD + Vector((0, -0.02, 0.08)), HEAD_R * 1.05, (1.04, 1.0, 0.72))
m.ball(HEAD + Vector((0, -0.02, 0.27)), 0.03)
face_opening(m)
cap = finish(m, "Hat_cap", 1000)
brim = lib.primitive('cylinder', HEAD + Vector((0, 0.2, 0.08)), scale=(0.2, 0.17, 0.018), vertices=16, radius=1.0, depth=1.0)
hats["cap"] = (join_parts(cap, [brim]), 30.0)

m = lib.Meta("hat_earflap", resolution=0.01)  # 耳あて帽（もこもこのふち）
m.ellipsoid(HEAD + Vector((0, -0.02, 0.07)), HEAD_R * 1.07, (1.05, 0.98, 0.82))
for side in SIDES:
    m.limb([HEAD + Vector((0.24 * side, 0.0, 0.0)), HEAD + Vector((0.25 * side, 0.03, -0.17))], [0.07, 0.06])
m.ellipsoid(HEAD + Vector((0, 0.14, 0.12)), 0.12, (1.4, 0.45, 0.6))  # 額の折り返し
face_opening(m)
hats["earflap"] = (finish(m, "Hat_earflap", 1400), 90.0)

m = lib.Meta("hat_helmet", resolution=0.01)  # 登山用ヘルメット
m.ellipsoid(HEAD + Vector((0, -0.01, 0.09)), HEAD_R * 1.1, (1.03, 1.05, 0.78))
for dx in (-0.08, 0.0, 0.08):
    m.capsule(HEAD + Vector((dx, 0.12, 0.22)), HEAD + Vector((dx, -0.16, 0.24)), 0.018)  # 盛り上がった筋
face_opening(m)
helmet = finish(m, "Hat_helmet", 1200)
straps = [lib.primitive('cylinder', HEAD + Vector((0.2 * s, 0.1, -0.12)), rotation=(0.2, 0, 0), scale=(0.012, 0.012, 0.16),
                        vertices=6, radius=1.0, depth=1.0) for s in SIDES]
hats["helmet"] = (join_parts(helmet, straps), 12.0)

m = lib.Meta("hat_catears", resolution=0.01)  # ねこみみのニット帽
m.ellipsoid(HEAD + Vector((0, -0.02, 0.07)), HEAD_R * 1.06, (1.05, 0.98, 0.8))
m.ellipsoid(HEAD + Vector((0, -0.005, 0.02)), HEAD_R * 1.1, (1.05, 0.98, 0.22))
face_opening(m)
catears = finish(m, "Hat_catears", 1200)
ears = []
for side in SIDES:
    base = HEAD + Vector((0.14 * side, -0.01, 0.2))
    ears.append(lib.cone_between(base, base + Vector((0.05 * side, 0.0, 0.16)), 0.075, None, vertices=5))
hats["catears"] = (join_parts(catears, ears), 60.0)

m = lib.Meta("hat_bucket", resolution=0.01)  # バケットハット（下向きの広いつば）
m.ellipsoid(HEAD + Vector((0, -0.02, 0.1)), HEAD_R * 1.04, (1.04, 1.02, 0.72))
face_opening(m)
bucket = finish(m, "Hat_bucket", 1000)
bucket_brim = lib.primitive('cone', HEAD + Vector((0, 0.0, 0.08)), vertices=18, radius1=0.4, radius2=0.26, depth=0.09)
hats["bucket"] = (join_parts(bucket, [bucket_brim]), 50.0)

# ============================== 髪 ==============================
hairs = {}


def hair_base(meta):
    meta.ellipsoid(HEAD + Vector((0, -0.03, 0.05)), HEAD_R * 1.03, (1.04, 1.0, 0.9))
    for dx in (-0.1, -0.03, 0.04, 0.11):  # 前髪
        meta.ellipsoid(HEAD + Vector((dx, 0.19, 0.1)), 0.06, (0.9, 0.5, 1.2), axis=(0, 0.4, 1))
    face_opening(meta)


m = lib.Meta("hair_short", resolution=0.009)
hair_base(m)
hairs["short"] = finish(m, "Hair_short", 1200)

m = lib.Meta("hair_bob", resolution=0.009)
hair_base(m)
for side in SIDES:
    m.ellipsoid(HEAD + Vector((0.2 * side, -0.02, -0.08)), 0.1, (0.7, 1.0, 1.4))
m.ellipsoid(HEAD + Vector((0, -0.15, -0.07)), 0.2, (1.2, 0.6, 1.0))
hairs["bob"] = finish(m, "Hair_bob", 1400)

m = lib.Meta("hair_long", resolution=0.009)
hair_base(m)
for side in SIDES:
    m.ellipsoid(HEAD + Vector((0.2 * side, -0.04, -0.14)), 0.1, (0.7, 1.0, 2.0))
m.ellipsoid(HEAD + Vector((0, -0.17, -0.2)), 0.22, (1.15, 0.55, 1.9))
hairs["long"] = finish(m, "Hair_long", 1600)

m = lib.Meta("hair_pigtails", resolution=0.009)
hair_base(m)
for side in SIDES:
    root = HEAD + Vector((0.2 * side, -0.1, 0.02))
    m.limb([root, root + Vector((0.1 * side, -0.05, -0.15)), root + Vector((0.12 * side, -0.02, -0.34))], [0.06, 0.055, 0.035])
hairs["pigtails"] = finish(m, "Hair_pigtails", 1400)

# ============================== 上着 ==============================
tops = {}


def sleeves(meta, r=1.0):
    for side in SIDES:
        meta.ball(SHOULDER[side], 0.1 * r)
        meta.limb([SHOULDER[side], ELBOW[side], WRIST[side]], [0.085 * r, 0.08 * r, 0.075 * r])
        meta.ball(ELBOW[side], 0.082 * r)
        meta.ball(WRIST[side], 0.078 * r)


m = lib.Meta("top_down", resolution=0.012)  # もこもこのダウンジャケット
m.ellipsoid((0, 0.0, 0.8), 0.24, (1.0, 0.85, 1.05))
for z in (0.62, 0.77, 0.92):
    m.ellipsoid((0, 0.01, z), 0.22, (1.08, 0.92, 0.35))
m.ellipsoid((0, 0.0, 1.06), 0.17, (1.2, 0.95, 0.5))
sleeves(m)
tops["down"] = (finish(m, "Top_down", 2400), 5.0, 42.0)

m = lib.Meta("top_hoodie", resolution=0.012)  # パーカー（背中にフード、前にポケット）
m.ellipsoid((0, 0.0, 0.79), 0.23, (1.0, 0.82, 1.1))
m.ellipsoid((0, -0.12, 1.05), 0.13, (1.4, 0.8, 0.7))  # 背中に下ろしたフード
m.ellipsoid((0, 0.18, 0.66), 0.09, (1.6, 0.35, 0.7))  # 前のポケット
sleeves(m, 0.95)
hoodie = finish(m, "Top_hoodie", 2200)
cords = [lib.primitive('cylinder', (0.05 * s, 0.2, 0.95), scale=(0.008, 0.008, 0.08), vertices=5, radius=1.0, depth=1.0)
         for s in SIDES]
tops["hoodie"] = (join_parts(hoodie, cords), 6.0, 0.0)

m = lib.Meta("top_coat", resolution=0.012)  # ひざまでのコート
m.ellipsoid((0, 0.0, 0.8), 0.23, (1.0, 0.85, 1.1))
m.ellipsoid((0, 0.0, 0.45), 0.24, (1.05, 0.9, 1.1))  # すそ
m.ellipsoid((0, 0.02, 1.07), 0.16, (1.25, 1.0, 0.45))  # 立てた襟
for z in (0.9, 0.78, 0.66):
    m.ball((0.0, 0.21, z), 0.018)  # ボタン
sleeves(m, 0.95)
tops["coat"] = (finish(m, "Top_coat", 2400), 7.0, 0.0)

m = lib.Meta("top_poncho", resolution=0.012)  # 雨よけのポンチョ
m.ellipsoid((0, 0.0, 0.84), 0.3, (1.25, 0.95, 0.95))
m.ellipsoid((0, 0.0, 0.7), 0.3, (1.3, 1.0, 0.55))
m.ellipsoid((0, -0.03, 1.07), 0.15, (1.3, 1.1, 0.5))
sleeves(m, 0.85)
tops["poncho"] = (finish(m, "Top_poncho", 2200), 4.0, 0.0)

# ============================== 首まわり ==============================
necks = {}
m = lib.Meta("neck_scarf", resolution=0.01)
for i in range(12):
    a = i / 12 * math.tau
    m.ball((math.cos(a) * 0.13, 0.02 + math.sin(a) * 0.11, 1.1), 0.065)
m.limb([(0.08, 0.12, 1.06), (0.12, 0.2, 0.92), (0.1, 0.22, 0.8)], [0.05, 0.045, 0.042])
necks["scarf"] = (finish(m, "Neck_scarf", 1000), 70.0)

m = lib.Meta("neck_bandana", resolution=0.01)
for i in range(12):
    a = i / 12 * math.tau
    m.ball((math.cos(a) * 0.12, 0.02 + math.sin(a) * 0.1, 1.1), 0.035)
m.ellipsoid((0, 0.17, 1.0), 0.09, (1.2, 0.3, 1.0))  # 胸に垂れた三角
necks["bandana"] = (finish(m, "Neck_bandana", 800), 40.0)

# ============================== いつも着ているもの ==============================
m = lib.Meta("climber_head", resolution=0.01)
m.ellipsoid(HEAD, HEAD_R, (1.05, 0.95, 0.95))
for side in SIDES:
    m.ellipsoid(HEAD + Vector((0.12 * side, 0.17, -0.09)), 0.07, (1.0, 0.6, 0.8))  # ぷっくりしたほっぺ
    m.ball(HEAD + Vector((0.255 * side, 0.0, -0.02)), 0.05)  # 耳
head_mesh = finish(m, "Head", 1400)

m = lib.Meta("climber_pants", resolution=0.012)
m.ellipsoid((0, 0.0, 0.54), 0.17, (1.1, 0.85, 0.55))
for side in SIDES:
    m.limb([HIP[side], KNEE[side], ANKLE[side] + Vector((0, 0, 0.04))], [0.09, 0.08, 0.075])
pants_mesh = finish(m, "Pants", 1200)

m = lib.Meta("climber_boots", resolution=0.01)
for side in SIDES:
    m.ellipsoid((0.1 * side, 0.04, 0.07), 0.1, (0.85, 1.25, 0.75))
    m.ellipsoid((0.1 * side, 0.05, 0.025), 0.1, (0.95, 1.35, 0.3))
boots_mesh = finish(m, "Boots", 800)

m = lib.Meta("climber_mittens", resolution=0.008)
for side in SIDES:
    hand = WRIST[side] + Vector((0.01 * side, 0.03, -0.08))
    m.ellipsoid(hand, 0.065, (0.85, 0.95, 1.05))
    m.ball(hand + Vector((-0.045 * side, 0.04, 0.02)), 0.03)
mittens_mesh = finish(m, "Mittens", 700)

m = lib.Meta("climber_pack", resolution=0.012)
m.ellipsoid((0, -0.25, 0.8), 0.2, (1.0, 0.7, 1.15))
m.ellipsoid((0, -0.3, 0.72), 0.1, (1.2, 0.6, 0.7))
for side in SIDES:
    m.limb([(0.12 * side, -0.14, 1.02), (0.15 * side, 0.08, 1.02), (0.14 * side, 0.2, 0.8)], [0.022, 0.022, 0.02])
pack_mesh = finish(m, "Pack", 1000)
roll = lib.primitive('cylinder', (0, -0.26, 1.07), rotation=(0, 1.5708, 0), vertices=12, radius=0.075, depth=0.42)
roll.name = "Roll"

# ============================== 焼き込み ==============================
lib.bpy.context.scene.cycles.samples = 24
bakes = []
for key, (mesh, scale) in hats.items():
    mesh.name = "Hat_" + key
    bakes.append((mesh, "hat_%s_tint" % key, fabric(GREY[0], GREY[1], scale)))
for key, mesh in hairs.items():
    bakes.append((mesh, "hair_%s_hair" % key, hair_strands))
for key, (mesh, scale, quilt) in tops.items():
    mesh.name = "Top_" + key
    bakes.append((mesh, "top_%s_tint" % key, fabric(GREY[0], GREY[1], scale, quilt)))
for key, (mesh, scale) in necks.items():
    bakes.append((mesh, "neck_%s_tint" % key, fabric(GREY[0], GREY[1], scale)))
bakes += [
    (mittens_mesh, "mittens_tint", fabric(GREY[0], GREY[1], 40.0)),
    (pants_mesh, "climber_pants_tex", fabric((0.07, 0.08, 0.12), (0.09, 0.1, 0.15), 8.0)),
    (boots_mesh, "climber_boots_tex", fabric((0.16, 0.09, 0.05), (0.22, 0.13, 0.07), 10.0)),
    (pack_mesh, "climber_pack_tex", fabric((0.2, 0.13, 0.07), (0.26, 0.17, 0.09), 8.0)),
    (head_mesh, "skin_tint", fabric((0.86, 0.84, 0.82), (0.9, 0.88, 0.86), 6.0)),  # 肌も灰色寄りに焼き、色はゲームで塗る
]
for mesh, name, build in bakes:
    lib.unwrap(mesh)
    lib.bake_color(mesh, name, build, size=256, final_size=128)
roll.data.materials.append(lib.flat_material("Roll", (0.1, 0.3, 0.45)))

# ============================== 表情 ==============================
eye = lib.flat_material("EyeBlack", (0.02, 0.015, 0.02))
shine = lib.flat_material("EyeShine", (1.0, 1.0, 1.0), emission=(1.0, 1.0, 1.0), strength=1.0)
blush = lib.flat_material("Blush", (0.95, 0.38, 0.38))
mouth_mat = lib.flat_material("Mouth", (0.3, 0.1, 0.08))
brow = lib.flat_material("Brow", (0.12, 0.08, 0.06))


def on_face(x, z, forward=0.0):
    """顔の表面の点（x は左右、z は頭の中心からの高さ）"""
    return HEAD + Vector((x, FACE_Y + forward, z))


def eyes_round(parts, size=1.0, shine_on=True):
    for side in SIDES:
        c = on_face(0.085 * side, -0.02)
        parts.append(lib.primitive('uv_sphere', c, scale=(0.75 * size, 0.45, 1.0 * size), material=eye, radius=0.05,
                                   segments=12, ring_count=8))
        if shine_on:
            parts.append(lib.primitive('uv_sphere', c + Vector((0.014 * side, 0.024, 0.018)), material=shine, radius=0.014,
                                       segments=8, ring_count=6))


def cheeks(parts):
    for side in SIDES:
        parts.append(lib.primitive('uv_sphere', on_face(0.14 * side, -0.085, -0.025), scale=(1.0, 0.35, 0.65), material=blush,
                                   radius=0.035, segments=10, ring_count=6))


def stroke(parts, a, b, radius, material):
    """顔に描いた線（まゆ・閉じた目・口の線）"""
    a, b = Vector(a), Vector(b)
    direction = b - a
    rotation = Vector((0, 0, 1)).rotation_difference(direction.normalized()).to_euler()
    parts.append(lib.primitive('cylinder', (a + b) / 2, rotation=rotation, scale=(radius, radius, direction.length),
                               material=material, vertices=6, radius=1.0, depth=1.0))


faces = {}
parts = []  # にこにこ（いつもの顔）
eyes_round(parts)
cheeks(parts)
parts.append(lib.primitive('uv_sphere', on_face(0, -0.1, 0.015), scale=(1.0, 0.4, 0.55), material=mouth_mat, radius=0.025,
                           segments=10, ring_count=6))
faces["smile"] = parts

parts = []  # きりっ（まゆを上げて、口はまっすぐ）
eyes_round(parts)
for side in SIDES:
    stroke(parts, on_face(0.05 * side, 0.055, 0.01), on_face(0.13 * side, 0.075, -0.01), 0.009, brow)
stroke(parts, on_face(-0.03, -0.1, 0.012), on_face(0.03, -0.1, 0.012), 0.008, mouth_mat)
faces["determined"] = parts

parts = []  # ねむそう（半分閉じた目、たれたまゆ）
for side in SIDES:
    stroke(parts, on_face(0.05 * side, -0.03, 0.01), on_face(0.12 * side, -0.035, 0.0), 0.011, eye)
    stroke(parts, on_face(0.05 * side, 0.04, 0.01), on_face(0.12 * side, 0.03, -0.005), 0.007, brow)
cheeks(parts)
parts.append(lib.primitive('uv_sphere', on_face(0, -0.1, 0.015), scale=(0.7, 0.4, 0.7), material=mouth_mat, radius=0.02,
                           segments=10, ring_count=6))
faces["sleepy"] = parts

parts = []  # びっくり（小さな丸い目と、丸くあいた口）
for side in SIDES:
    parts.append(lib.primitive('uv_sphere', on_face(0.085 * side, -0.01), scale=(0.7, 0.4, 0.7), material=eye, radius=0.04,
                               segments=12, ring_count=8))
    stroke(parts, on_face(0.05 * side, 0.07, 0.005), on_face(0.12 * side, 0.08, -0.01), 0.007, brow)
parts.append(lib.primitive('uv_sphere', on_face(0, -0.11, 0.012), scale=(0.9, 0.4, 1.2), material=mouth_mat, radius=0.03,
                           segments=10, ring_count=6))
faces["surprised"] = parts

parts = []  # ねこ口（にっこり閉じた目 ^ ^ と ω の口）
for side in SIDES:
    c = on_face(0.085 * side, -0.02, 0.005)
    stroke(parts, c + Vector((-0.035, 0, -0.012)), c + Vector((0.0, 0, 0.018)), 0.01, eye)
    stroke(parts, c + Vector((0.0, 0, 0.018)), c + Vector((0.035, 0, -0.012)), 0.01, eye)
cheeks(parts)
for side in SIDES:
    c = on_face(0.018 * side, -0.1, 0.012)
    stroke(parts, c + Vector((-0.016, 0, 0.006)), c + Vector((0.0, 0, -0.008)), 0.006, mouth_mat)
    stroke(parts, c + Vector((0.0, 0, -0.008)), c + Vector((0.016, 0, 0.006)), 0.006, mouth_mat)
faces["cat"] = parts

parts = []  # むすっ（困りまゆと、への字口）
eyes_round(parts, 0.85)
for side in SIDES:
    stroke(parts, on_face(0.05 * side, 0.075, 0.005), on_face(0.13 * side, 0.05, -0.01), 0.008, brow)
stroke(parts, on_face(-0.03, -0.105, 0.012), on_face(0.0, -0.095, 0.014), 0.007, mouth_mat)
stroke(parts, on_face(0.0, -0.095, 0.014), on_face(0.03, -0.105, 0.012), 0.007, mouth_mat)
faces["pout"] = parts

face_meshes = {}
for key, pieces in faces.items():
    first = pieces[0]
    face_meshes[key] = lib.join(first, pieces[1:]) if len(pieces) > 1 else first
    face_meshes[key].name = "Face_" + key

# ============================== 骨 ==============================
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
rig = lib.build_armature("ClimberRig", bones)

skinned = [pants_mesh, boots_mesh, mittens_mesh] + [t[0] for t in tops.values()] + [n[0] for n in necks.values()]
on_head = [head_mesh] + [h[0] for h in hats.values()] + list(hairs.values()) + list(face_meshes.values())
for mesh in skinned:
    lib.skin_to_bones(mesh, bones)
for mesh in on_head:
    lib.bind_whole(mesh, "head")
for mesh in (pack_mesh, roll):
    lib.bind_whole(mesh, "chest")
for mesh in skinned + on_head + [pack_mesh, roll]:
    lib.attach_to_armature(mesh, rig)


# ============================== 確認用の画像と書き出し ==============================
def dress(hat="beanie", hair="short", top="down", neck="scarf", face="smile"):
    """選んだ組み合わせだけを表示する（確認用の画像のため）"""
    chosen = {"Hat_" + hat, "Hair_" + hair, "Top_" + top, "Neck_" + neck, "Face_" + face}
    for obj in lib.bpy.context.scene.objects:
        if obj.type == 'MESH' and obj.name.split("_")[0] in ("Hat", "Hair", "Top", "Neck", "Face"):
            obj.hide_render = obj.name not in chosen


dress()
lib.render_preview("climber", (0, 0.0, 0.85), 3.0, views=((0, 5), (40, 10), (160, 10)))
for i, (hat, hair, top, neck, face) in enumerate([
        ("cap", "bob", "hoodie", "bandana", "determined"), ("earflap", "long", "coat", "scarf", "sleepy"),
        ("helmet", "pigtails", "poncho", "none", "surprised"), ("catears", "short", "down", "none", "cat"),
        ("bucket", "long", "hoodie", "scarf", "pout"), ("none", "pigtails", "coat", "bandana", "smile")]):
    dress(hat, hair, top, neck, face)
    lib.render_preview("climber_style%d" % i, (0, 0.0, 1.1), 1.9, views=((20, 5),))
dress()
for obj in lib.bpy.context.scene.objects:
    obj.hide_render = False
lib.export_glb("climber")
