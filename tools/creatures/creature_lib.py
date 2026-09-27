"""Blender で化け物のモデルを作るための共通部品。

使い方（Blender 4.5 で実行する）:
    blender -b --factory-startup --python tools/creatures/<作るもの>.py

流れ:
    1. メタボール（くっつき合う粘土の玉）で体を組む → つなぎ目のない一体の体になる
    2. メッシュに変えて、表面にしわ・こぶを付け、PS1 らしい面数まで減らす
    3. 肌の色をテクスチャに焼き込む（くぼみの陰、骨の出っ張り、まだら）
    4. 目・歯・爪などの小物をくっつける
    5. 骨を入れて、各頂点がどの骨に付いて動くかを決める
    6. .glb で書き出す（Godot がそのまま読める）

座標は Blender の向き（Z が上、+Y が正面）。書き出すと Godot では -Z が正面になる。
"""
import math
import os

import bpy
from mathutils import Vector

# stiffness 2・threshold 0.6 のメタボールは、影響半径の 0.575 倍の大きさに見える（実測）
VISIBLE = 0.575
PROJECT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def random_generator(seed):
    """毎回同じ形になるように、種を決めた乱数"""
    import random
    return random.Random(seed)


def select_only(obj):
    for other in bpy.context.view_layer.objects:
        other.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


# --- 1. メタボールで体を組む ---

class Meta:
    """メタボールの集まり。r はすべて「見た目の半径」で指定する"""

    def __init__(self, name, resolution=0.012):
        self.data = bpy.data.metaballs.new(name)
        self.data.resolution = resolution
        self.data.render_resolution = resolution
        self.data.threshold = 0.6
        self.obj = bpy.data.objects.new(name, self.data)
        bpy.context.scene.collection.objects.link(self.obj)

    def _element(self, kind, co, r, negative):
        e = self.data.elements.new(type=kind)
        e.co = Vector(co)
        e.radius = r / VISIBLE
        e.stiffness = 2.0
        e.use_negative = negative
        return e

    def ball(self, co, r, negative=False):
        return self._element('BALL', co, r, negative)

    def capsule(self, a, b, r, negative=False):
        """a から b まで伸びる、太さ r の棒（両端は丸い）"""
        a, b = Vector(a), Vector(b)
        e = self._element('CAPSULE', (a + b) / 2, r, negative)
        e.size_x = (b - a).length / 2
        e.rotation = Vector((1, 0, 0)).rotation_difference((b - a).normalized())
        return e

    def limb(self, points, radii):
        """いくつかの点を順につなぐ手足。点ごとの太さを少しずつ変えて、細くなっていく形にする"""
        for i in range(len(points) - 1):
            steps = 3
            for s in range(steps):
                t0, t1 = s / steps, (s + 1) / steps
                a = Vector(points[i]).lerp(Vector(points[i + 1]), t0)
                b = Vector(points[i]).lerp(Vector(points[i + 1]), t1)
                r = radii[i] + (radii[i + 1] - radii[i]) * (t0 + t1) / 2
                self.capsule(a, b, r)

    def ellipsoid(self, co, r, size, axis=None, negative=False):
        """size は (横, 前後, 縦) の倍率。axis を渡すと、縦（Z）をその向きに傾ける"""
        e = self._element('ELLIPSOID', co, r, negative)
        e.size_x, e.size_y, e.size_z = size
        if axis is not None:
            e.rotation = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized())
        return e

    def to_mesh(self):
        select_only(self.obj)
        bpy.ops.object.convert(target='MESH')
        return bpy.context.view_layer.objects.active


# --- 2. 表面の仕上げ ---

def apply_modifier(obj, modifier):
    select_only(obj)
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def add_surface_detail(obj, strength, scale, kind='VORONOI'):
    """ボロノイ模様で表面をわずかに凹凸させて、しわ・こぶ・血管の盛り上がりを出す"""
    texture = bpy.data.textures.new(obj.name + "_detail_" + kind, type=kind)
    texture.noise_scale = scale
    if kind == 'VORONOI':
        texture.distance_metric = 'DISTANCE'
    modifier = obj.modifiers.new("detail", 'DISPLACE')
    modifier.texture = texture
    modifier.texture_coords = 'OBJECT'
    modifier.strength = strength
    modifier.mid_level = 0.5
    apply_modifier(obj, modifier)


def smooth(obj, iterations=2, factor=0.5):
    modifier = obj.modifiers.new("smooth", 'SMOOTH')
    modifier.iterations = iterations
    modifier.factor = factor
    apply_modifier(obj, modifier)


def reduce_to(obj, triangles):
    """面の数を減らす（PS1 らしい粗さに）"""
    current = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if current > triangles:
        modifier = obj.modifiers.new("decimate", 'DECIMATE')
        modifier.ratio = triangles / current
        apply_modifier(obj, modifier)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True


# --- 3. テクスチャの焼き込み ---

def unwrap(obj):
    select_only(obj)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
    bpy.ops.object.mode_set(mode='OBJECT')


def bake_color(obj, name, build, size=512, final_size=256):
    """build(nodes, links) が返す色を、Cycles でテクスチャ画像に焼き込む。
    焼いたあとは、その画像を貼っただけのシンプルな素材に差し替える"""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 32

    material = bpy.data.materials.new(name + "_bake")
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    output = nodes.new('ShaderNodeOutputMaterial')
    emission = nodes.new('ShaderNodeEmission')
    links.new(build(nodes, links), emission.inputs['Color'])
    links.new(emission.outputs['Emission'], output.inputs['Surface'])
    image = bpy.data.images.new(name, size, size)
    target = nodes.new('ShaderNodeTexImage')
    target.image = image
    nodes.active = target

    obj.data.materials.clear()
    obj.data.materials.append(material)
    select_only(obj)
    bpy.ops.object.bake(type='EMIT', margin=6, use_clear=True)
    if final_size != size:
        image.scale(final_size, final_size)
    image.filepath_raw = os.path.join(PROJECT, "tools", "creatures", "out", name + ".png")
    os.makedirs(os.path.dirname(image.filepath_raw), exist_ok=True)
    image.file_format = 'PNG'
    image.save()

    obj.data.materials.clear()
    obj.data.materials.append(textured_material(name, image))
    return image


def textured_material(name, image):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes['Principled BSDF']
    texture = nodes.new('ShaderNodeTexImage')
    texture.image = image
    texture.interpolation = 'Closest'
    links.new(texture.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.55
    return material


def flat_material(name, color, emission=None, strength=1.0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (*color, 1.0)
    bsdf.inputs['Roughness'].default_value = 0.4
    if emission is not None:
        bsdf.inputs['Emission Color'].default_value = (*emission, 1.0)
        bsdf.inputs['Emission Strength'].default_value = strength
    return material


# 焼き込みで使う、よく使うノードの組み合わせ

def node(nodes, kind, **inputs):
    n = nodes.new(kind)
    for key, value in inputs.items():
        if key in n.inputs:
            n.inputs[key].default_value = value
        else:
            setattr(n, key, value)
    return n


def _socket(sockets, identifier):
    return next(s for s in sockets if s.identifier == identifier)


def feed(links, socket, value):
    """ソケットに、別のノードの出力か、固定の値（数値・色）をつなぐ"""
    if isinstance(value, bpy.types.NodeSocket):
        links.new(value, socket)
    elif isinstance(value, (int, float)):
        socket.default_value = value
    else:
        socket.default_value = (*value, 1.0) if len(value) == 3 else value


def mix(nodes, links, a, b, factor, blend='MIX'):
    """色 a と色 b を factor の割合で混ぜる（blend='MULTIPLY' などで掛け合わせ）"""
    m = nodes.new('ShaderNodeMix')
    m.data_type = 'RGBA'
    m.blend_type = blend
    feed(links, _socket(m.inputs, 'Factor_Float'), factor)
    feed(links, _socket(m.inputs, 'A_Color'), a)
    feed(links, _socket(m.inputs, 'B_Color'), b)
    return _socket(m.outputs, 'Result_Color')


def ramp(nodes, links, source, stops):
    """source（0〜1 の値）を、stops = [(位置, (r, g, b)), ...] の色に変える"""
    r = nodes.new('ShaderNodeValToRGB')
    elements = r.color_ramp.elements
    while len(elements) > 1:
        elements.remove(elements[-1])
    elements[0].position, elements[0].color = stops[0][0], (*stops[0][1], 1.0)
    for position, color in stops[1:]:
        e = elements.new(position)
        e.color = (*color, 1.0)
    links.new(source, r.inputs['Fac'])
    return r.outputs['Color']


# --- 4. 小物 ---

def primitive(kind, location, scale=(1, 1, 1), rotation=(0, 0, 0), material=None, **kwargs):
    """小物（目・歯・爪など）を作る。kind は 'uv_sphere' / 'cone' など"""
    getattr(bpy.ops.mesh, "primitive_" + kind + "_add")(location=location, rotation=rotation, **kwargs)
    obj = bpy.context.view_layer.objects.active
    obj.scale = scale
    select_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if material is not None:
        obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def cone_between(base, tip, radius, material, vertices=6):
    """base から tip に向かってとがる円すい（歯・爪・とげ）"""
    base, tip = Vector(base), Vector(tip)
    direction = tip - base
    rotation = Vector((0, 0, 1)).rotation_difference(direction.normalized()).to_euler()
    obj = primitive('cone', (base + tip) / 2, rotation=rotation, material=material,
                    vertices=vertices, radius1=radius, radius2=0.0, depth=direction.length)
    return obj


def bind_whole(obj, bone):
    """小物全体を、1 本の骨にしっかり付ける"""
    group = obj.vertex_groups.new(name=bone)
    group.add([v.index for v in obj.data.vertices], 1.0, 'REPLACE')


def join(target, parts):
    select_only(target)  # ほかに選ばれたままの物を、まちがってくっつけないように
    for part in parts:
        part.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return target


# --- 5. 骨を入れる ---

class Bone:
    def __init__(self, name, head, tail, parent=None, radius=0.05, allow=None):
        self.name = name
        self.head = Vector(head)
        self.tail = Vector(tail)
        self.parent = parent
        self.radius = radius  # この骨のまわりの肉の厚み（頂点との距離を測るときの目安）
        self.allow = allow    # allow(co) が False の頂点は、この骨に付けない


def build_armature(name, bones):
    data = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    select_only(obj)
    bpy.ops.object.mode_set(mode='EDIT')
    for bone in bones:
        edit = data.edit_bones.new(bone.name)
        edit.head, edit.tail = bone.head, bone.tail
        edit.roll = 0.0
        if bone.parent:
            edit.parent = data.edit_bones[bone.parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    return obj


def _segment_distance(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def skin_to_bones(obj, bones, influences=3, falloff=4.0):
    """各頂点を、近い骨（肉の厚みで割った距離が小さい骨）ほど強く付ける"""
    groups = {bone.name: obj.vertex_groups.new(name=bone.name) for bone in bones}
    for vertex in obj.data.vertices:
        co = vertex.co
        candidates = []
        for bone in bones:
            if bone.allow is not None and not bone.allow(co):
                continue
            candidates.append((_segment_distance(co, bone.head, bone.tail) / bone.radius, bone.name))
        candidates.sort()
        chosen = candidates[:influences]
        weights = [1.0 / (d + 0.05) ** falloff for d, _ in chosen]
        total = sum(weights)
        for (d, name), w in zip(chosen, weights):
            if w / total > 0.02:
                groups[name].add([vertex.index], w / total, 'REPLACE')


def attach_to_armature(obj, armature):
    obj.parent = armature
    modifier = obj.modifiers.new("Armature", 'ARMATURE')
    modifier.object = armature


# --- 6. 書き出しと確認用の画像 ---

def export_glb(name):
    path = os.path.join(PROJECT, "assets", "models", name + ".glb")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_yup=True, export_apply=False,
                              export_skins=True, export_animations=False, export_materials='EXPORT',
                              use_selection=False)
    print("EXPORTED", path)
    return path


def render_preview(name, target, distance, views=((20, 15), (90, 10), (160, 20)), size=480):
    """いくつかの角度から見た画像を並べて保存する（形の確認用）"""
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.eevee.taa_render_samples = 16
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    world = bpy.data.worlds.new("preview")
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.35, 0.36, 0.4, 1.0)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.2
    scene.world = world
    if "preview_key" not in bpy.data.objects:
        key = bpy.data.objects.new("preview_key", bpy.data.lights.new("preview_key", 'SUN'))
        key.data.energy = 3.0
        key.rotation_euler = (math.radians(50), 0, math.radians(30))
        scene.collection.objects.link(key)
    camera_data = bpy.data.cameras.new("preview")
    camera_data.lens = 50
    camera = bpy.data.objects.new("preview", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    target = Vector(target)
    paths = []
    for i, (yaw, pitch) in enumerate(views):
        yaw_r, pitch_r = math.radians(yaw), math.radians(pitch)
        offset = Vector((math.sin(yaw_r) * math.cos(pitch_r), math.cos(yaw_r) * math.cos(pitch_r), math.sin(pitch_r)))
        camera.location = target + offset * distance
        camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
        path = os.path.join(PROJECT, "tools", "creatures", "out", "%s_view%d.png" % (name, i))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    print("PREVIEWS", paths)
    return paths
