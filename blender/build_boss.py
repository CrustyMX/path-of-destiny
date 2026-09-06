"""Build boss enemy model - corrupted war machine."""
import bpy
import os
import math

OUTPUT_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "models", "boss.glb"))

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def make_mat(name, color, metallic=0.6, roughness=0.4, emission=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = 4.0
    return mat

def assign_mat(obj, mat):
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)

def add_cube(name, loc, scale, mat):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    assign_mat(obj, mat)
    return obj

def add_cylinder(name, loc, radius, depth, mat):
    bpy.ops.mesh.primitive_cylinder_add(location=loc, radius=radius, depth=depth)
    obj = bpy.context.active_object
    obj.name = name
    assign_mat(obj, mat)
    return obj

def build():
    clear_scene()
    dark = make_mat("BossDark", (0.08, 0.08, 0.1, 1.0), metallic=0.9, roughness=0.3)
    red = make_mat("BossRed", (0.9, 0.1, 0.05, 1.0), emission=(0.9, 0.1, 0.05, 1.0))
    steel = make_mat("BossSteel", (0.3, 0.32, 0.35, 1.0), metallic=0.85, roughness=0.4)

    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    root = bpy.context.active_object
    root.name = "BossRoot"
    parts = []

    # Massive torso
    torso = add_cube("BossTorso", (0, 0, 2.5), (1.2, 0.8, 1.8), dark)
    torso.parent = root
    parts.append(torso)

    # Core reactor (weak point)
    core = add_cylinder("BossCore", (0, -0.85, 2.5), 0.35, 0.3, red)
    core.rotation_euler = (math.pi/2, 0, 0)
    core.parent = root
    parts.append(core)

    # Head sensor array
    head = add_cube("BossHead", (0, 0, 4.2), (0.6, 0.5, 0.5), steel)
    head.parent = root
    parts.append(head)
    eye = add_cube("BossEye", (0, -0.3, 4.3), (0.5, 0.05, 0.08), red)
    eye.parent = root
    parts.append(eye)

    # Arms with weapon mounts
    for side, x in [("L", -1.5), ("R", 1.5)]:
        arm = add_cube(f"Arm_{side}", (x, 0, 2.8), (0.4, 0.4, 1.2), dark)
        arm.parent = root
        parts.append(arm)
        cannon = add_cylinder(f"Cannon_{side}", (x, -0.6, 1.8), 0.2, 1.5, steel)
        cannon.rotation_euler = (math.pi/2, 0, 0)
        cannon.parent = root
        parts.append(cannon)

    # Legs — feet on z=0
    for side, x in [("L", -0.6), ("R", 0.6)]:
        leg = add_cube(f"Leg_{side}", (x, 0, 1.6), (0.5, 0.5, 1.6), dark)
        leg.parent = root
        parts.append(leg)
        foot = add_cube(f"Foot_{side}", (x, 0.3, 0.15), (0.6, 0.8, 0.15), steel)
        foot.parent = root
        parts.append(foot)

    # Spikes around upper torso
    for i, angle in enumerate(range(0, 360, 60)):
        rad = math.radians(angle)
        sx = math.cos(rad) * 1.0
        sy = math.sin(rad) * 1.0
        spike = add_cube(f"Spike_{i}", (sx, sy, 3.5), (0.15, 0.15, 0.6), steel)
        spike.parent = root
        parts.append(spike)

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for p in parts:
        p.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=OUTPUT_PATH,
        use_selection=True,
        export_format='GLB',
        export_apply=True,
    )
    print(f"Exported: {OUTPUT_PATH}")

if __name__ == "__main__":
    build()
