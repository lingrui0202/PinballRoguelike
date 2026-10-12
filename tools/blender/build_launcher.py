"""
发射器 Launcher（弹射台）——第 3 周作业 3D 资源。

用 Blender 的 Python API（bpy）建模，全程脚本化、可复现：
    blender --background --python tools/blender/build_launcher.py

产出：
    assets3d/launcher.blend          可继续编辑的源文件
    assets3d/launcher.glb            可导入 Godot 的交换格式
    <作业目录>/{front,side,iso}.png   正视图 / 侧视图 / 斜视图三张模型截图

结构（三个命名部件，原点在底座底面中心，Y 轴向上，Blender Z-up 导出时转 Y-up）：
    Base        底座圆盘 + 两片侧向支撑（金属灰）
    Barrel      炮管（深灰），向前倾斜 25°
    EnergyRing  能量环（发光青），套在炮管中段
"""

import bpy
import math
import os
from mathutils import Vector

# ---------------------------------------------------------------- 输出路径
HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_BLEND = os.path.join(r"E:\Dev\Homework\第3周\学号_姓名_第3周作业", "launcher.blend")
OUT_GLB = os.path.join(PROJ, "assets3d", "launcher.glb")
SHOT_DIR = r"E:\Dev\Homework\第3周\学号_姓名_第3周作业"

LEAN = math.radians(25.0)  # 炮管前倾角度
BARREL_LEN = 1.0
BARREL_R = 0.18
BASE_R = 0.45
BASE_H = 0.16


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_material(name: str, color, metallic: float, roughness: float, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def add_cylinder(name, radius, depth, location, rotation, mat):
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius, depth=depth, vertices=48,
        location=location, rotation=rotation,
    )
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(mat)
    return ob


def build_base(mat) -> None:
    """底座：圆盘 + 两片侧向斜撑（作为炮架，要厚实、剪影清楚）"""
    add_cylinder("Base", BASE_R, BASE_H, (0.0, 0.0, BASE_H / 2.0), (0.0, 0.0, 0.0), mat)
    for sign in (-1.0, 1.0):
        bpy.ops.mesh.primitive_cube_add(
            size=1.0, location=(sign * 0.26, 0.0, 0.26),
        )
        ob = bpy.context.active_object
        ob.scale = (0.05, 0.20, 0.30)
        ob.rotation_euler = (LEAN, 0.0, 0.0)
        ob.data.materials.append(mat)
        ob.name = "Base_Support"
    # 底座边缘加一圈倒角，避免圆盘像一块饼干
    bpy.context.view_layer.objects.active = bpy.data.objects.get("Base")
    mod = bpy.data.objects["Base"].modifiers.new("Bevel", "BEVEL")
    mod.width = 0.02
    mod.segments = 3
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # 把两片支撑并到底座里（保持"三个部件"的分件约定）
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.objects:
        if ob.name in ("Base", "Base_Support"):
            ob.select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects.get("Base")
    bpy.ops.object.join()


def build_barrel(mat):
    """炮管：沿 Z 轴的圆柱，绕 X 前倾 25° 后指向斜上方"""
    axis = Vector((0.0, -math.sin(LEAN), math.cos(LEAN)))
    bottom = Vector((0.0, -0.01, BASE_H))
    center = bottom + axis * (BARREL_LEN / 2.0)
    ob = add_cylinder("Barrel", BARREL_R, BARREL_LEN, tuple(center), (LEAN, 0.0, 0.0), mat)
    return ob, axis, bottom


def build_ring(mat, axis, bottom):
    """能量环：套在炮管 60% 高度处的圆环，轴向与炮管一致"""
    pos = bottom + axis * (BARREL_LEN * 0.58)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=BARREL_R + 0.055,
        minor_radius=0.055,
        major_segments=48, minor_segments=16,
        location=tuple(pos), rotation=(LEAN, 0.0, 0.0),
    )
    ob = bpy.context.active_object
    ob.name = "EnergyRing"
    ob.data.materials.append(mat)
    return ob


def ensure_normals() -> None:
    """重算法线朝外，避免导出后内壁翻面"""
    for ob in bpy.data.objects:
        if ob.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        ob.select_set(False)


def parent_to_root() -> None:
    """挂到一个位于世界原点的空物体下，保证原点 = 底座底面中心"""
    root = bpy.data.objects.new("Launcher", None)
    bpy.context.scene.collection.objects.link(root)
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.parent is None:
            ob.parent = root


def report() -> None:
    tris = 0
    zmin, zmax = 1e9, -1e9
    for ob in bpy.data.objects:
        if ob.type != "MESH":
            continue
        me = ob.data
        me.calc_loop_triangles()
        tris += len(me.loop_triangles)
        for v in me.vertices:
            co = ob.matrix_world @ v.co
            zmin = min(zmin, co.z)
            zmax = max(zmax, co.z)
    print("REPORT tris=%d height=%.3f zmin=%.3f zmax=%.3f" % (tris, zmax - zmin, zmin, zmax))


def setup_render() -> None:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 96
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1200
    scene.render.film_transparent = True

    world = bpy.data.worlds.new("StudioWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.55, 0.58, 0.63, 1.0)
    bg.inputs[1].default_value = 0.6
    scene.world = world

    # 三点布光：key 强一点，让金属块面拉开明暗
    bpy.ops.object.light_add(type="SUN", location=(3.0, -4.0, 6.0))
    key = bpy.context.active_object
    key.data.energy = 6.0
    bpy.ops.object.light_add(type="AREA", location=(-3.5, 2.0, 3.0))
    fill = bpy.context.active_object
    fill.data.energy = 200.0
    fill.data.size = 4.0
    bpy.ops.object.light_add(type="AREA", location=(0.0, 4.0, 1.5))
    rim = bpy.context.active_object
    rim.data.energy = 260.0
    rim.data.size = 3.0


def shoot(name: str, cam_loc, target=(0.0, 0.0, 0.5)) -> None:
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("Cam_%s" % name)
    cam = bpy.data.objects.new("Cam_%s" % name, cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = cam_loc
    direction = Vector(target) - Vector(cam_loc)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    os.makedirs(SHOT_DIR, exist_ok=True)
    out = os.path.join(SHOT_DIR, "%s.png" % name)
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("SHOT " + out)


def main() -> None:
    reset_scene()

    mat_base = make_material("Mat_Base", (0.62, 0.64, 0.68, 1.0), 0.9, 0.3)
    mat_barrel = make_material("Mat_Barrel", (0.13, 0.15, 0.18, 1.0), 0.65, 0.35)
    # 发光强度别拉太高：>2 导出到 glTF 后会被引擎压成纯白，反而丢掉青色
    mat_ring = make_material("Mat_Ring", (0.05, 0.95, 0.85, 1.0), 0.0, 0.2, emission=1.6)

    build_base(mat_base)
    barrel, axis, bottom = build_barrel(mat_barrel)
    build_ring(mat_ring, axis, bottom)

    ensure_normals()
    parent_to_root()
    report()

    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print("SAVED " + OUT_BLEND)

    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_yup=True)
    print("EXPORTED " + OUT_GLB)

    setup_render()
    shoot("front", (0.0, -3.2, 0.8))    # 正视图（从炮口朝向的一侧看）
    shoot("side", (3.2, 0.0, 0.8))      # 侧视图
    shoot("iso", (2.4, -2.4, 1.8))      # 斜视图


if __name__ == "__main__":
    main()
