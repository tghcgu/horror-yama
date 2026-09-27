"""山の動物のモデルをまとめて作る。

四つ足（シカ・カモシカ・タヌキ・キツネ・ウサギ・ユキウサギ・サル・イノシシ・野犬）と、鳥（カラス・タカ・ライチョウ）。
四つ足は、本物の体のつくりにそって組む：深い胸、肩甲骨と腰のふくらみ、ひじ・手首のある前脚、ひざと後ろへ突き出た
かかと（飛節）のある後ろ脚、額・眉・頬・鼻づら・あごのある頭、くぼみのある耳、割れたひづめや指のある足。
種ごとに、体つき・耳・しっぽ・角・たてがみ・模様（シカの白い尻、タヌキの目のまわりの黒、キツネの朱の尾先、
サルの赤い顔など）を変える。assets/models/animal_<名前>.glb に書き出す。原点が足元、正面は +Y。
骨の名前（body, neck, head, tail, legFLa/legFLb …）は、ゲームの動かし方（critter.gd）に合わせてある。
実行: blender -b --factory-startup --python tools/creatures/build_animals.py [-- animal_deer ...]
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
import creature_lib as lib  # noqa: E402
from mathutils import Vector  # noqa: E402

SIDES = (1, -1)


# --- 毛皮の焼き込み ---

def coat(base, belly, belly_height, spots=None, marks=(), tip=None, legs_dark=0.6, legs_height=0.2, streak=0.22, back_dark=0.8):
    """毛皮：体の向きに流れる毛並みの筋、色むら、背中の濃い色、腹側の明るい色、斑点、
    marks = [(中心, 半径, 色), ...] の模様（顔のくま・白い尻・赤い顔など）、しっぽの先の色、黒っぽい脚先"""
    def build(nodes, links):
        coord = nodes.new('ShaderNodeTexCoord')
        separate = nodes.new('ShaderNodeSeparateXYZ')
        links.new(coord.outputs['Object'], separate.inputs['Vector'])
        noise = lib.node(nodes, 'ShaderNodeTexNoise', Scale=9.0, Detail=5.0)
        links.new(coord.outputs['Object'], noise.inputs['Vector'])
        dark = tuple(c * 0.72 for c in base)
        color = lib.ramp(nodes, links, noise.outputs['Fac'], [(0.3, dark), (0.7, base)])
        # 毛並み：体の前後に流れる、細かい筋（毛の房）
        stretch = lib.node(nodes, 'ShaderNodeMapping')
        stretch.inputs['Scale'].default_value = (80.0, 8.0, 80.0)
        links.new(coord.outputs['Object'], stretch.inputs['Vector'])
        fur = lib.node(nodes, 'ShaderNodeTexNoise', Scale=1.0, Detail=3.0)
        links.new(stretch.outputs['Vector'], fur.inputs['Vector'])
        strands = lib.ramp(nodes, links, fur.outputs['Fac'], [(0.35, (1.0 - streak,) * 3), (0.65, (1.0, 1.0, 1.0))])
        color = lib.mix(nodes, links, color, strands, 1.0, blend='MULTIPLY')
        # 背中の毛は濃く、腹は明るく
        back = lib.ramp(nodes, links, separate.outputs['Z'], [(belly_height + 0.1, (1.0, 1.0, 1.0)), (belly_height + 0.4, (back_dark,) * 3)])
        color = lib.mix(nodes, links, color, back, 1.0, blend='MULTIPLY')
        feet = lib.ramp(nodes, links, separate.outputs['Z'], [(legs_height * 0.5, (legs_dark,) * 3), (legs_height, (1.0, 1.0, 1.0))])
        color = lib.mix(nodes, links, color, feet, 1.0, blend='MULTIPLY')
        under = lib.ramp(nodes, links, separate.outputs['Z'], [(belly_height - 0.04, (1.0, 1.0, 1.0)), (belly_height + 0.04, (0.0, 0.0, 0.0))])
        color = lib.mix(nodes, links, color, belly, under)
        if spots is not None:
            voronoi = lib.node(nodes, 'ShaderNodeTexVoronoi', Scale=spots[1])
            links.new(coord.outputs['Object'], voronoi.inputs['Vector'])
            spot_mask = lib.ramp(nodes, links, voronoi.outputs['Distance'], [(0.0, (1.0, 1.0, 1.0)), (0.12, (0.0, 0.0, 0.0))])
            high = lib.ramp(nodes, links, separate.outputs['Z'], [(belly_height + 0.05, (0.0, 0.0, 0.0)), (belly_height + 0.12, (1.0, 1.0, 1.0))])
            color = lib.mix(nodes, links, color, spots[0], lib.mix(nodes, links, spot_mask, high, 1.0, blend='MULTIPLY'))
        for center, radius, mark_color in marks:
            dist = lib.node(nodes, 'ShaderNodeVectorMath', operation='DISTANCE')
            links.new(coord.outputs['Object'], dist.inputs[0])
            dist.inputs[1].default_value = center
            m = lib.ramp(nodes, links, dist.outputs['Value'], [(radius * 0.65, (1.0, 1.0, 1.0)), (radius, (0.0, 0.0, 0.0))])
            color = lib.mix(nodes, links, color, mark_color, m)
        if tip is not None:
            back_y, tip_color = tip
            t = lib.ramp(nodes, links, separate.outputs['Y'], [(back_y - 0.03, (1.0, 1.0, 1.0)), (back_y + 0.03, (0.0, 0.0, 0.0))])
            color = lib.mix(nodes, links, color, tip_color, t)
        occlusion = lib.node(nodes, 'ShaderNodeAmbientOcclusion', Distance=0.05)
        shade = lib.ramp(nodes, links, occlusion.outputs['AO'], [(0.0, (0.3, 0.3, 0.3)), (1.0, (1.0, 1.0, 1.0))])
        return lib.mix(nodes, links, color, shade, 1.0, blend='MULTIPLY')
    return build


# --- 四つ足 ---

def quadruped(name, s):
    """四つ足の動物。s の数値で体つきを変える（長さはすべて m）"""
    lib.reset()
    H = s["height"]            # 肩の高さ
    L = s["length"]            # 胴の長さ（胸から尻まで）
    g = s.get("girth", 1.0)    # 胴の太さの倍率
    leg = s["leg"]             # 脚の太さ
    crouch = s.get("crouch", 0.0)  # 後ろ脚をたたんで、尻を落とす（ウサギ）
    body = lib.Meta(name, resolution=s.get("resolution", 0.012))
    body_z = H * s.get("body_z", 0.72)
    chest = Vector((0, L * 0.45, body_z))
    rump = Vector((0, -L * 0.45, body_z + H * s.get("rump_rise", 0.02) - H * crouch * 0.25))
    # 胴：深い胸、ふくらんだ腹、腰と尻、肩の上のき甲
    body.ellipsoid(chest, H * 0.23 * g, (0.8, 1.15, 1.08))
    body.ellipsoid(chest.lerp(rump, 0.5) + Vector((0, 0, -H * 0.03 * s.get("belly", 1.0))), H * 0.2 * g * s.get("belly", 1.0), (0.88, 1.2, 0.95))
    body.ellipsoid(rump, H * 0.21 * g, (0.92, 1.1, 1.0))
    body.capsule(chest, rump, H * 0.17 * g)
    body.ellipsoid(chest + Vector((0, -0.03 * H, H * 0.19 * g)), H * 0.09, (0.6, 1.4, 0.8))  # き甲
    for side in SIDES:
        body.ellipsoid(chest + Vector((H * 0.13 * side * g, 0.02 * H, H * 0.06)), H * 0.11, (0.45, 1.1, 1.35), axis=(0, 0.35, 1))  # 肩甲骨
        body.ellipsoid(rump + Vector((H * 0.12 * side * g, -0.02 * H, -H * 0.03)), H * 0.14 * s.get("haunch", 1.0), (0.55, 1.1, 1.25))  # もも
    if s.get("ribs"):
        for k in range(4):  # やせて浮いたあばら（野犬）：わき腹に、うすく浮き出る
            for side in SIDES:
                p = chest.lerp(rump, 0.18 + k * 0.09) + Vector((H * 0.145 * side * g, 0, -H * 0.02))
                body.capsule(p + Vector((0, 0, H * 0.06)), p + Vector((0, 0.01, -H * 0.07)), H * 0.013)
    if s.get("mane"):
        for k in range(9):  # 背のたてがみ（毛の尾根）：肩でいちばん高く、尻へ低くなる。背にぴったりつく
            t = k / 8
            base = (chest + Vector((0, L * 0.12, 0))).lerp(rump, t * 0.85)
            top = base.z + H * (0.19 - 0.03 * t) * g
            spine = Vector((0, base.y, top + H * s["mane"] * (1.0 - t) * 0.45))
            body.ellipsoid(spine, H * (0.075 + s["mane"] * 0.25 * (1.0 - t)), (0.42, 1.5, 1.0))
    # 首と頭
    neck_base = chest + Vector((0, L * 0.12, H * 0.1))
    neck_top = neck_base + Vector((0, H * s["neck"][0], H * s["neck"][1]))
    body.limb([neck_base, neck_base.lerp(neck_top, 0.5) + Vector((0, 0, H * 0.02)), neck_top],
              [H * 0.12 * s.get("neck_thick", 1.0), H * 0.1 * s.get("neck_thick", 1.0), H * 0.085 * s.get("neck_thick", 1.0)])
    hs = H * s["head"]  # 頭の大きさ
    head = neck_top + Vector((0, hs * 0.55, hs * 0.35))
    body.ellipsoid(head, hs, (0.82, 1.0, 0.86))  # 頭蓋
    body.ellipsoid(head + Vector((0, hs * 0.35, hs * 0.35)), hs * 0.6, (0.9, 0.9, 0.6))  # 額
    muzzle_len = hs * s["muzzle"]
    muzzle_tip = head + Vector((0, hs * 0.6 + muzzle_len, -hs * 0.3 * s.get("muzzle_drop", 1.0)))
    body.limb([head + Vector((0, hs * 0.4, -hs * 0.1)), muzzle_tip], [hs * 0.55 * s.get("muzzle_thick", 1.0), hs * 0.33 * s.get("muzzle_thick", 1.0)])
    body.limb([head + Vector((0, hs * 0.3, -hs * 0.45)), muzzle_tip + Vector((0, -hs * 0.2, -hs * 0.22))], [hs * 0.3, hs * 0.18])  # 下あご
    for side in SIDES:
        body.ellipsoid(head + Vector((hs * 0.55 * side, hs * 0.2, -hs * 0.2)), hs * 0.35, (0.6, 1.0, 0.8))  # 頬
        body.capsule(head + Vector((hs * 0.55 * side, hs * 0.5, hs * 0.35)), head + Vector((hs * 0.2 * side, hs * 0.7, hs * 0.42)), hs * 0.14)  # 眉の骨
        body.ball(head + Vector((hs * 0.52 * side, hs * 0.62, hs * 0.2)), hs * 0.17, negative=True)  # 目のくぼみ
    if s.get("disc"):
        body.ellipsoid(muzzle_tip + Vector((0, hs * 0.05, 0)), hs * 0.26, (1.0, 0.35, 0.9))  # イノシシの鼻の円盤
    # 耳
    ear = s["ear"]
    ear_size = hs * s.get("ear_size", 1.0)
    for side in SIDES:
        base = head + Vector((hs * 0.55 * side, -hs * 0.2, hs * 0.65))
        if ear == "long":  # ウサギ：長い耳を、背中のほうへ寝かせる
            tip = base + Vector((0.03 * side, -ear_size * 1.4, ear_size * 1.6))
            body.limb([base, base.lerp(tip, 0.5) + Vector((0.01 * side, 0, 0)), tip], [ear_size * 0.2, ear_size * 0.28, ear_size * 0.14])
            body.capsule(base.lerp(tip, 0.25) + Vector((0, ear_size * 0.12, 0)), base.lerp(tip, 0.85) + Vector((0, ear_size * 0.1, 0)), ear_size * 0.12, negative=True)
        elif ear == "round":  # タヌキ・サル：小さな丸い耳
            body.ellipsoid(base, ear_size * 0.33, (1.0, 0.5, 0.9))
            body.ball(base + Vector((0, ear_size * 0.15, 0)), ear_size * 0.2, negative=True)
        else:  # とがった耳：付け根は太く、先は細く、前はくぼむ
            tip = base + Vector((hs * 0.2 * side, -hs * 0.05, ear_size * 0.95))
            body.limb([base, base.lerp(tip, 0.5), tip], [ear_size * 0.3, ear_size * 0.22, ear_size * 0.05])
            body.capsule(base.lerp(tip, 0.2) + Vector((0, ear_size * 0.15, 0)), base.lerp(tip, 0.75) + Vector((0, ear_size * 0.1, 0)), ear_size * 0.13, negative=True)
    # 脚：前はひじ・手首、後ろはひざ（前へ）とかかと（後ろへ高く）
    legs = {}
    front_len = s.get("front_len", 1.0)
    for front in (True, False):
        for side in SIDES:
            x = H * 0.14 * side * g
            if front:
                top = chest + Vector((x, 0.02 * H, -H * 0.08))
                elbow = top + Vector((0, -0.05 * H, -(top.z * 0.45) * front_len))
                wrist = Vector((x * 0.95, elbow.y + 0.04 * H, max(H * 0.14 * front_len, 0.03)))
                foot = Vector((x * 0.95, wrist.y + 0.02 * H, 0.03 * H))
                body.limb([top, elbow, wrist, foot], [leg * 1.5, leg * 1.05, leg * 0.8, leg * 0.75])
                body.ball(elbow, leg * 1.15)
                body.ball(wrist, leg * 0.9)
                legs[("F" if front else "B") + ("L" if side > 0 else "R")] = (top, elbow, foot)
            else:
                top = rump + Vector((x, -0.02 * H, -H * 0.05))
                if crouch > 0.0:  # たたんだ後ろ脚：ひざを前、かかとを後ろ、長い足を地面に寝かせる
                    knee = top + Vector((0, 0.12 * H, -top.z * 0.45))
                    hock = Vector((x, top.y - 0.12 * H, H * 0.08))
                    foot = Vector((x, hock.y + 0.35 * H, 0.03 * H))
                else:
                    knee = top + Vector((0, 0.1 * H, -top.z * 0.38))
                    hock = Vector((x, knee.y - 0.16 * H, top.z * s.get("hock", 0.33)))
                    foot = Vector((x, hock.y + 0.04 * H, 0.03 * H))
                body.limb([top, knee, hock, foot], [leg * 1.9 * s.get("haunch", 1.0), leg * 1.1, leg * 0.8, leg * 0.75])
                body.ball(hock, leg * 0.95)
                legs[("F" if front else "B") + ("L" if side > 0 else "R")] = (top, knee, foot)
    # しっぽ
    tail_kind = s.get("tail", "short")
    tail_root = rump + Vector((0, -H * 0.24 * g, H * 0.08))
    tail_len = H * s.get("tail_len", 0.3)
    tail_thick = H * s.get("tail_thick", 0.05)
    if tail_kind == "bushy":  # キツネ・タヌキ：ふさふさ
        tip = tail_root + Vector((0, -tail_len, -tail_len * 0.35))
        body.limb([tail_root, tail_root.lerp(tip, 0.5) + Vector((0, 0, -tail_len * 0.05)), tip], [tail_thick * 0.6, tail_thick * 1.25, tail_thick * 0.5])
    elif tail_kind == "curl":  # 犬：背中へ巻き上がる
        tip = tail_root + Vector((0, -tail_len * 0.4, tail_len * 0.8))
        body.limb([tail_root, tail_root + Vector((0, -tail_len * 0.5, tail_len * 0.4)), tip], [tail_thick, tail_thick * 1.1, tail_thick * 0.7])
    elif tail_kind == "tuft":  # イノシシ：細いしっぽの先に毛の房
        tip = tail_root + Vector((0, -tail_len * 0.3, -tail_len))
        body.limb([tail_root, tip], [tail_thick * 0.5, tail_thick * 0.4])
        body.ellipsoid(tip, tail_thick * 1.2, (0.8, 0.8, 1.6))
    elif tail_kind == "puff":  # ウサギ：丸い綿毛
        tip = tail_root + Vector((0, -tail_len * 0.2, 0))
        body.ball(tip, tail_thick * 1.6)
    else:
        tip = tail_root + Vector((0, -tail_len, -tail_len * 0.4))
        body.limb([tail_root, tip], [tail_thick, tail_thick * 0.6])
    tail_tip = tip
    mesh = body.to_mesh()
    mesh.name = name
    lib.add_surface_detail(mesh, H * 0.006, 0.04, 'CLOUDS')   # 毛の房のでこぼこ
    lib.add_surface_detail(mesh, H * 0.003, 0.015, 'VORONOI')
    lib.smooth(mesh, iterations=1, factor=0.35)
    lib.reduce_to(mesh, s.get("triangles", 3600))
    lib.bpy.context.scene.cycles.samples = 24
    lib.unwrap(mesh)
    lib.bake_color(mesh, name + "_skin", s["coat"](head, muzzle_tip, rump, tail_tip), size=512, final_size=256)

    parts = []
    eye = lib.flat_material("EyeBlack", (0.02, 0.02, 0.02))
    shine = lib.flat_material("EyeShine", (1.0, 1.0, 1.0), emission=(1.0, 1.0, 1.0), strength=1.0)
    for side in SIDES:
        e = head + Vector((hs * 0.5 * side, hs * 0.66, hs * 0.2))
        parts.append(lib.primitive('uv_sphere', e, material=eye, radius=hs * 0.14, segments=10, ring_count=6, scale=(0.8, 1.0, 0.9)))
        parts.append(lib.primitive('uv_sphere', e + Vector((0.004 * side * H, hs * 0.11, hs * 0.06)), material=shine,
                                   radius=hs * 0.045, segments=6, ring_count=4))
    nose_color = s.get("nose", (0.05, 0.04, 0.04))
    nose = lib.flat_material("Nose", nose_color)
    nose_at = muzzle_tip + Vector((0, hs * 0.3, hs * 0.08))
    parts.append(lib.primitive('uv_sphere', nose_at, material=nose, radius=hs * 0.14, segments=8, ring_count=6, scale=(1.1, 0.7, 0.8)))
    for side in SIDES:  # 鼻の穴
        parts.append(lib.primitive('uv_sphere', nose_at + Vector((hs * 0.06 * side, hs * 0.08, -hs * 0.01)), material=eye,
                                   radius=hs * 0.045, segments=6, ring_count=4))
    parts.append(lib.primitive('cube', muzzle_tip + Vector((0, hs * 0.05, -hs * 0.2)), material=eye,
                               scale=(hs * 0.3, muzzle_len * 0.5, hs * 0.012)))  # 口のすじ
    if s.get("whiskers"):
        whisker = lib.flat_material("Whisker", (0.85, 0.85, 0.8))
        for side in SIDES:
            for k in range(3):
                root = muzzle_tip + Vector((hs * 0.2 * side, hs * 0.1, -hs * 0.05 + k * hs * 0.05))
                parts.append(lib.cone_between(root, root + Vector((hs * 0.9 * side, -hs * 0.1, (k - 1) * hs * 0.12)), hs * 0.012, whisker, vertices=3))
    inner = lib.flat_material("EarInner", s.get("ear_inner", (0.3, 0.22, 0.2)))
    if ear != "long":
        for side in SIDES:
            base = head + Vector((hs * 0.55 * side, -hs * 0.1, hs * 0.75))
            parts.append(lib.primitive('uv_sphere', base + Vector((hs * 0.05 * side, hs * 0.1, ear_size * (0.3 if ear == "pointed" else 0.0))),
                                       material=inner, radius=ear_size * 0.16, scale=(0.9, 0.3, 1.5 if ear == "pointed" else 1.0),
                                       segments=6, ring_count=4))
    # 足：割れたひづめか、指のある足
    hoof = lib.flat_material("Hoof", s.get("hoof", (0.08, 0.07, 0.06)))
    claw = lib.flat_material("Claw", (0.15, 0.13, 0.11))
    feet_parts = []
    for key, (top, mid, foot) in legs.items():
        if s.get("hooves"):
            for side in SIDES:  # 二つに割れたひづめ
                h = lib.cone_between(foot + Vector((leg * 0.35 * side, -leg * 0.3, leg * 0.9)), foot + Vector((leg * 0.4 * side, leg * 0.7, -0.01 * H)),
                                     leg * 0.55, hoof, vertices=5)
                lib.bind_whole(h, "leg%sb" % key)
                feet_parts.append(h)
        else:
            paw = lib.primitive('uv_sphere', foot + Vector((0, leg * 0.5, -0.005 * H)), material=hoof, radius=leg * 1.05,
                                scale=(1.0, 1.35 if not (crouch and key[0] == "B") else 2.4, 0.5), segments=8, ring_count=4)
            lib.bind_whole(paw, "leg%sb" % key)
            feet_parts.append(paw)
            for k in (-1.5, -0.5, 0.5, 1.5):  # 指と爪
                c = lib.cone_between(foot + Vector((leg * 0.32 * k, leg * 1.3, 0.0)), foot + Vector((leg * 0.36 * k, leg * 1.9, -0.005 * H)),
                                     leg * 0.13, claw, vertices=4)
                lib.bind_whole(c, "leg%sb" % key)
                feet_parts.append(c)
    horn = lib.flat_material("Horn", s.get("horn_color", (0.35, 0.28, 0.2)))
    if s.get("tusks"):
        tusk = lib.flat_material("Tusk", (0.92, 0.9, 0.8))
        for side in SIDES:
            root = muzzle_tip + Vector((hs * 0.3 * side, -hs * 0.15, -hs * 0.18))
            mid = root + Vector((hs * 0.35 * side, hs * 0.2, hs * 0.28))
            parts.append(lib.cone_between(root, mid, hs * 0.1, tusk, vertices=6))
            parts.append(lib.cone_between(mid, mid + Vector((hs * 0.06 * side, -hs * 0.12, hs * 0.3)), hs * 0.08, tusk, vertices=6))
    if s.get("antlers"):  # シカ：三つに枝分かれした角
        for side in SIDES:
            root = head + Vector((hs * 0.35 * side, -hs * 0.05, hs * 0.85))
            beam1 = root + Vector((0.07 * side, -0.05, 0.16))
            beam2 = beam1 + Vector((0.05 * side, -0.07, 0.17))
            parts.append(lib.cone_between(root, beam1, 0.024, horn, vertices=6))
            parts.append(lib.cone_between(beam1, beam2, 0.019, horn, vertices=6))
            parts.append(lib.cone_between(beam2, beam2 + Vector((0.02 * side, -0.02, 0.12)), 0.013, horn, vertices=5))
            parts.append(lib.cone_between(beam1, beam1 + Vector((0.02 * side, 0.11, 0.08)), 0.013, horn, vertices=5))  # 前へ出た枝
            parts.append(lib.cone_between(beam2, beam2 + Vector((0.06 * side, 0.04, 0.06)), 0.011, horn, vertices=5))
            parts.append(lib.primitive('uv_sphere', root, material=horn, radius=0.03, segments=6, ring_count=4))  # 角の付け根のこぶ
    if s.get("horns"):  # カモシカ：後ろへ反った短い角
        for side in SIDES:
            root = head + Vector((hs * 0.3 * side, -hs * 0.05, hs * 0.8))
            mid = root + Vector((0.01 * side, -0.03, 0.08))
            parts.append(lib.cone_between(root, mid, 0.02, horn, vertices=6))
            parts.append(lib.cone_between(mid, mid + Vector((0.005 * side, -0.05, 0.03)), 0.015, horn, vertices=5))
    for p in parts:
        lib.bind_whole(p, "head")
    parts += feet_parts
    if s.get("tail_tip_color"):
        ball = lib.primitive('uv_sphere', tail_tip, material=lib.flat_material("TailTip", s["tail_tip_color"]),
                             radius=tail_thick * 0.75, segments=10, ring_count=6)
        lib.bind_whole(ball, "tail")
        parts.append(ball)
    bones = [
        lib.Bone("body", rump, chest, None, H * 0.35),
        lib.Bone("neck", neck_base, neck_top, "body", H * 0.15),
        lib.Bone("head", neck_top, muzzle_tip + Vector((0, hs * 0.3, 0)), "neck", hs * 1.3,
                 allow=lambda co, top=neck_top.z - hs * 0.4, fy=neck_top.y - hs * 0.2: co.z > top and co.y > fy),
        lib.Bone("tail", tail_root, tail_tip, "body", tail_thick * 2.0 + H * 0.05),
    ]
    for key, (top, mid, foot) in legs.items():
        side = 1 if key[1] == "L" else -1
        bones += [
            lib.Bone("leg%sa" % key, top, mid, "body", leg * 1.9, allow=lambda co, sd=side, h=top.z: co.x * sd > 0.0 and co.z < h + 0.02 * H),
            lib.Bone("leg%sb" % key, mid, foot, "leg%sa" % key, leg * 1.6, allow=lambda co, sd=side, k=mid.z: co.x * sd > 0.0 and co.z < k + 0.05 * H),
        ]
    lib.skin_to_bones(mesh, bones)
    mesh = lib.join(mesh, parts)
    rig = lib.build_armature(name + "Rig", bones)
    lib.attach_to_armature(mesh, rig)
    lib.render_preview(name, (0, 0, H * 0.55), max(L, H) * 3.0, views=((50, 12), (120, 8)), size=360)
    lib.export_glb(name)


# --- 鳥 ---

def bird(name, spec):
    """鳥。翼を広げた形で作り、ゲームの中で羽ばたかせる。翼の先は、指のように分かれた風切羽"""
    lib.reset()
    s = spec["size"]
    body = lib.Meta(name, resolution=spec.get("resolution", 0.007))
    center = Vector((0, 0, s * 0.55))
    body.ellipsoid(center, s * 0.28, (0.85, 1.45, 0.85))
    body.ellipsoid(center + Vector((0, s * 0.18, -s * 0.05)), s * 0.22, (0.9, 1.0, 0.9))  # 胸
    head = center + Vector((0, s * 0.42, s * 0.22))
    body.limb([center + Vector((0, s * 0.2, s * 0.1)), head], [s * 0.16, s * 0.13])
    body.ellipsoid(head, s * 0.16, (0.9, 1.05, 0.95))
    for side in SIDES:
        body.capsule(head + Vector((s * 0.1 * side, s * 0.06, s * 0.08)), head + Vector((s * 0.05 * side, s * 0.12, s * 0.09)), s * 0.03)  # 眉
    for side in SIDES:  # 翼：付け根から先へ細くなり、先は指のように分かれる
        root = center + Vector((s * 0.2 * side, s * 0.05, s * 0.08))
        tip = root + Vector((s * spec["wing"] * side, -s * 0.12, 0.0))
        for k in range(6):
            t = k / 5
            p = root.lerp(tip, t * 0.8)
            body.ellipsoid(p + Vector((0, -s * 0.1, 0)), s * 0.1, (1.6, 2.3 - t * 1.2, 0.28))
        for f in range(4):  # 風切羽
            base = root.lerp(tip, 0.8)
            end = tip + Vector((0, -s * (0.06 + f * 0.08), 0))
            body.capsule(base + Vector((0, -s * 0.05 * f, 0)), end, s * 0.028)
    for k in range(3):  # 尾羽
        body.ellipsoid(center + Vector((s * (k - 1) * 0.06, -s * 0.5, -s * 0.02)), s * 0.1, (0.6, 2.4, 0.2))
    for side in SIDES:
        body.limb([center + Vector((s * 0.08 * side, 0, -s * 0.15)), Vector((s * 0.08 * side, s * 0.02, 0.01))], [s * 0.04, s * 0.025])
    mesh = body.to_mesh()
    mesh.name = name
    lib.add_surface_detail(mesh, s * 0.004, 0.02, 'VORONOI')
    lib.smooth(mesh, iterations=1, factor=0.4)
    lib.reduce_to(mesh, spec.get("triangles", 1600))
    lib.bpy.context.scene.cycles.samples = 20
    lib.unwrap(mesh)
    lib.bake_color(mesh, name + "_skin", spec["coat"], size=256, final_size=128)
    eye = lib.flat_material("EyeBlack", spec.get("eye", (0.02, 0.02, 0.02)))
    beak = lib.flat_material("Beak", spec["beak"])
    parts = []
    for side in SIDES:
        parts.append(lib.primitive('uv_sphere', head + Vector((s * 0.1 * side, s * 0.09, s * 0.04)), material=eye, radius=s * 0.032,
                                   segments=8, ring_count=4))
    beak_root = head + Vector((0, s * 0.13, 0))
    beak_tip = head + Vector((0, s * 0.13 + s * spec["beak_length"], -s * 0.03))
    parts.append(lib.cone_between(beak_root, beak_tip, s * 0.05, beak, vertices=6))
    if spec.get("hooked"):
        parts.append(lib.cone_between(beak_tip, beak_tip + Vector((0, s * 0.02, -s * 0.05)), s * 0.02, beak, vertices=5))
    talon = lib.flat_material("Claw", (0.2, 0.18, 0.15))
    for side in SIDES:
        for k in (-1, 0, 1):
            foot = Vector((s * 0.08 * side, s * 0.02, 0.01))
            parts.append(lib.cone_between(foot, foot + Vector((s * 0.03 * k, s * 0.07, -0.005)), s * 0.012, talon, vertices=4))
    for p in parts:
        lib.bind_whole(p, "head")
    bones = [
        lib.Bone("body", center + Vector((0, -s * 0.3, 0)), center + Vector((0, s * 0.25, s * 0.05)), None, s * 0.35,
                 allow=lambda co, w=s * 0.3: abs(co.x) < w),
        lib.Bone("head", center + Vector((0, s * 0.25, s * 0.1)), head + Vector((0, s * 0.2, 0)), "body", s * 0.2,
                 allow=lambda co, y=s * 0.2: co.y > y),
    ]
    for side in SIDES:
        root = center + Vector((s * 0.2 * side, s * 0.05, s * 0.08))
        tip = root + Vector((s * spec["wing"] * side, -s * 0.15, 0.0))
        k = "L" if side > 0 else "R"
        bones.append(lib.Bone("wing." + k, root, tip, "body", s * 0.3, allow=lambda co, sd=side, w=s * 0.2: co.x * sd > w))
    lib.skin_to_bones(mesh, bones)
    mesh = lib.join(mesh, parts)
    rig = lib.build_armature(name + "Rig", bones)
    lib.attach_to_armature(mesh, rig)
    lib.render_preview(name, center, s * 4.0, views=((30, 35),), size=360)
    lib.export_glb(name)


# --- 種ごとの体つきと模様 ---
# coat はどれも (頭, 鼻先, 尻, 尾の先) を受け取り、模様の位置を決める

QUADRUPEDS = {
    # ニホンジカ：すらりと長い脚、高い飛節、三つ叉の角、夏毛の白い斑点、白い尻
    "animal_deer": dict(height=1.0, length=0.8, girth=0.85, leg=0.03, neck=(0.12, 0.34), neck_thick=0.85, head=0.1, muzzle=0.95,
                        ear="pointed", ear_size=0.13, tail="short", tail_len=0.12, tail_thick=0.035, antlers=True, hooves=True,
                        hock=0.36, horn_color=(0.42, 0.34, 0.24),
                        coat=lambda head, nose, rump, tail: coat((0.55, 0.34, 0.18), (0.88, 0.82, 0.7), 0.55,
                                                                   spots=((0.9, 0.86, 0.76), 18.0),
                                                                   marks=[(rump + Vector((0, -0.2, 0.02)), 0.14, (0.95, 0.93, 0.88)),
                                                                          (nose, 0.05, (0.2, 0.16, 0.12))])),
    # ニホンカモシカ：がっしりした体、首のたてがみ、後ろへ反った黒い角、白っぽい顔とのど
    "animal_serow": dict(height=0.8, length=0.62, girth=1.1, leg=0.038, neck=(0.12, 0.2), neck_thick=1.25, head=0.15, muzzle=0.75,
                         ear="pointed", ear_size=0.12, tail="short", tail_len=0.08, tail_thick=0.04, horns=True, hooves=True,
                         horn_color=(0.08, 0.08, 0.08), mane=0.12,
                         coat=lambda head, nose, rump, tail: coat((0.24, 0.23, 0.22), (0.5, 0.48, 0.45), 0.42, streak=0.3,
                                                                   marks=[(head + Vector((0, 0.08, -0.06)), 0.11, (0.8, 0.78, 0.74)),
                                                                          (nose, 0.05, (0.12, 0.1, 0.1))])),
    # タヌキ：丸くふくれた毛の体、短く黒い脚、目のまわりの黒いくま、白っぽい頬、ふさふさの尾
    "animal_tanuki": dict(height=0.36, length=0.34, girth=1.35, belly=1.2, leg=0.028, body_z=0.62, neck=(0.12, 0.12), neck_thick=1.4, head=0.28,
                          muzzle=0.55, ear="round", ear_size=0.9, tail="bushy", tail_len=0.42, tail_thick=0.12, whiskers=True,
                          resolution=0.007, front_len=0.85, ear_inner=(0.12, 0.1, 0.08),
                          coat=lambda head, nose, rump, tail: coat((0.46, 0.38, 0.28), (0.3, 0.26, 0.2), 0.2, legs_dark=0.25, legs_height=0.14,
                                                                    tip=(tail.y + 0.08, (0.12, 0.1, 0.08)),
                                                                    marks=[(head + Vector((0.05, 0.06, 0.0)), 0.045, (0.08, 0.07, 0.06)),
                                                                           (head + Vector((-0.05, 0.06, 0.0)), 0.045, (0.08, 0.07, 0.06)),
                                                                           (nose, 0.035, (0.85, 0.8, 0.72))])),
    # 霊峰の白ぎつね：細い体、大きなとがった耳、長い鼻、朱の先のふさふさの尾
    "animal_fox": dict(height=0.4, length=0.42, girth=0.8, leg=0.022, neck=(0.12, 0.2), head=0.2, muzzle=1.15,
                       ear="pointed", ear_size=1.25, tail="bushy", tail_len=0.55, tail_thick=0.13, whiskers=True, resolution=0.007,
                       tail_tip_color=(0.95, 0.3, 0.15), ear_inner=(0.95, 0.75, 0.7), nose=(0.2, 0.08, 0.08),
                       coat=lambda head, nose, rump, tail: coat((0.95, 0.94, 0.9), (1.0, 1.0, 1.0), 0.22, legs_dark=0.95, streak=0.12)),
    # ノウサギ：丸めた背中、たたんだ長い後ろ脚と大きな足、寝かせた長い耳、白い綿毛の尾
    "animal_rabbit": dict(height=0.26, length=0.22, girth=1.2, leg=0.018, crouch=1.0, body_z=0.7, rump_rise=0.15, neck=(0.08, 0.1),
                          neck_thick=1.4, head=0.34, muzzle=0.45, ear="long", ear_size=0.9, tail="puff", tail_len=0.1, tail_thick=0.08,
                          whiskers=True, resolution=0.005, triangles=2400, front_len=0.8, haunch=1.3,
                          coat=lambda head, nose, rump, tail: coat((0.5, 0.39, 0.27), (0.85, 0.8, 0.72), 0.12,
                                                                    marks=[(tail, 0.05, (0.95, 0.95, 0.92))])),
    "animal_snowhare": dict(height=0.28, length=0.24, girth=1.2, leg=0.019, crouch=1.0, body_z=0.7, rump_rise=0.15, neck=(0.08, 0.1),
                            neck_thick=1.4, head=0.34, muzzle=0.45, ear="long", ear_size=0.95, tail="puff", tail_len=0.1, tail_thick=0.08,
                            whiskers=True, resolution=0.005, triangles=2400, front_len=0.8, haunch=1.3,
                            coat=lambda head, nose, rump, tail: coat((0.95, 0.95, 0.97), (1.0, 1.0, 1.0), 0.12, streak=0.08,
                                                                      marks=[(head + Vector((0, -0.12, 0.24)), 0.05, (0.1, 0.1, 0.1))])),
    # イノシシ：くさび形の体、大きな頭と長い鼻づら（先は円盤）、背のたてがみ、細い脚、牙、房の尾
    "animal_boar": dict(height=0.7, length=0.72, girth=1.3, leg=0.035, body_z=0.66, neck=(0.1, 0.02), neck_thick=1.7, head=0.2, muzzle=1.3,
                        muzzle_drop=1.5, muzzle_thick=1.15, disc=True, ear="pointed", ear_size=0.75, tail="tuft", tail_len=0.22,
                        tail_thick=0.03, tusks=True, mane=0.18, hooves=True, triangles=3800, resolution=0.011, ear_inner=(0.2, 0.15, 0.12),
                        nose=(0.25, 0.18, 0.16),
                        coat=lambda head, nose, rump, tail: coat((0.19, 0.14, 0.1), (0.26, 0.2, 0.15), 0.15, legs_dark=0.55, streak=0.4,
                                                                  marks=[(nose, 0.07, (0.35, 0.28, 0.24))])),
    # 野犬：やせてあばらの浮いた体、とがった耳、長い鼻、巻き上がった尾、黒っぽい背と口のまわり
    "animal_dog": dict(height=0.55, length=0.52, girth=0.78, leg=0.026, neck=(0.12, 0.2), head=0.16, muzzle=1.15, ear="pointed",
                       ear_size=0.95, tail="curl", tail_len=0.3, tail_thick=0.05, ribs=True, resolution=0.008, ear_inner=(0.35, 0.25, 0.22),
                       whiskers=True, belly=0.8,
                       coat=lambda head, nose, rump, tail: coat((0.5, 0.42, 0.32), (0.7, 0.64, 0.52), 0.3, legs_dark=0.8, back_dark=0.6, streak=0.3,
                                                                 marks=[(nose, 0.07, (0.12, 0.1, 0.08))])),
    # ニホンザル：がっしりした四つ足、丸い頭に平たい赤い顔、短い尾、厚い灰色がかった毛
    "animal_monkey": dict(height=0.5, length=0.4, girth=1.05, leg=0.034, neck=(0.06, 0.16), neck_thick=1.3, head=0.24, muzzle=0.25,
                          muzzle_thick=0.9, ear="round", ear_size=0.6, tail="short", tail_len=0.1, tail_thick=0.04, resolution=0.008,
                          front_len=1.05, ear_inner=(0.8, 0.45, 0.45), nose=(0.55, 0.25, 0.25), hock=0.3,
                          coat=lambda head, nose, rump, tail: coat((0.52, 0.47, 0.41), (0.62, 0.57, 0.5), 0.25, streak=0.3, legs_dark=0.85,
                                                                    marks=[(head + Vector((0, 0.13, -0.01)), 0.1, (0.82, 0.32, 0.32)),
                                                                           (rump + Vector((0, -0.13, -0.05)), 0.07, (0.8, 0.35, 0.35))])),
}
BIRDS = {
    "animal_crow": dict(size=0.45, wing=1.0, beak=(0.05, 0.05, 0.06), beak_length=0.3,
                        coat=coat((0.05, 0.05, 0.07), (0.07, 0.07, 0.09), 0.0, streak=0.15)),
    "animal_hawk": dict(size=0.55, wing=1.35, beak=(0.2, 0.18, 0.16), beak_length=0.18, hooked=True, eye=(0.8, 0.6, 0.1),
                        coat=coat((0.4, 0.28, 0.18), (0.88, 0.84, 0.74), 0.27, spots=((0.3, 0.2, 0.12), 25.0))),
    "animal_ptarmigan": dict(size=0.36, wing=0.8, beak=(0.1, 0.1, 0.1), beak_length=0.12,
                             coat=coat((0.95, 0.95, 0.97), (1.0, 1.0, 1.0), 0.15, streak=0.08)),
}

# 実行するときに -- のあとへ名前を並べると、その動物だけを作り直す
ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for animal_name, animal_spec in QUADRUPEDS.items():
    if not ONLY or animal_name in ONLY:
        quadruped(animal_name, animal_spec)
for animal_name, animal_spec in BIRDS.items():
    if not ONLY or animal_name in ONLY:
        bird(animal_name, animal_spec)
