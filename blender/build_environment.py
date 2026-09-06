"""Build Outriders-style environment props and export GLB.

Blender uses Z-up: X/Y = ground plane, Z = vertical height.
glTF export converts this to Godot's Y-up automatically.
"""
import bpy
import os
import math

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "models")
OUTPUT_PATH = os.path.abspath(os.path.join(OUTPUT_DIR, "environment.glb"))

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
        bsdf.inputs["Emission Strength"].default_value = 2.5
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
    rust = make_mat("RustMetal", (0.35, 0.18, 0.08, 1.0), metallic=0.8, roughness=0.55)
    steel = make_mat("Steel", (0.22, 0.24, 0.28, 1.0), metallic=0.85, roughness=0.45)
    rock = make_mat("AlienRock", (0.15, 0.12, 0.1, 1.0), metallic=0.1, roughness=0.85)
    glow = make_mat("LavaGlow", (1.0, 0.35, 0.05, 1.0), emission=(1.0, 0.35, 0.05, 1.0))
    cyan_glow = make_mat("TechGlow", (0.1, 0.7, 0.9, 1.0), emission=(0.1, 0.7, 0.9, 1.0))

    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    root = bpy.context.active_object
    root.name = "EnvironmentRoot"
    parts = []

    # Ground terrain chunks — flat on X-Y plane, thin in Z
    for i, (x, y, sx, sy) in enumerate([
        (0, 0, 25, 25), (30, 0, 15, 20), (-25, 15, 18, 18), (10, -30, 20, 15)
    ]):
        ground = add_cube(f"Ground_{i}", (x, y, 0.075), (sx, sy, 0.075), rock)
        ground.parent = root
        parts.append(ground)

    # Ruined industrial pillars — cylinders along Z (vertical)
    for i, (x, y, h) in enumerate([(8, 8, 5), (-12, -8, 7), (20, -10, 4), (-20, 20, 6)]):
        pillar = add_cylinder(f"Pillar_{i}", (x, y, h / 2), 0.6 + i * 0.1, h, rust)
        pillar.parent = root
        parts.append(pillar)
        debris = add_cube(f"Debris_{i}", (x + 1.5, y + 0.8, h * 0.3), (1.2, 0.8, 0.4), rust)
        debris.parent = root
        parts.append(debris)

    # Cargo containers — height along Z, rotate around Z on ground
    for i, (x, y, rot) in enumerate([(5, -8, 15), (-6, 12, -20), (15, 5, 45)]):
        container = add_cube(f"Container_{i}", (x, y, 2.0), (1.8, 2.4, 2.0), steel)
        container.rotation_euler = (0, 0, math.radians(rot))
        container.parent = root
        parts.append(container)

    # Lava fissures — flat on ground (thin Z), long along X
    for i, (x, y, length) in enumerate([(0, 0, 8), (12, -5, 5), (-8, 10, 6)]):
        fissure = add_cube(f"Fissure_{i}", (x, y, 0.02), (length / 2, 0.2, 0.01), glow)
        fissure.parent = root
        parts.append(fissure)

    # Alien spires — vertical cylinders on Z
    for i, (x, y, h) in enumerate([(-15, -15, 8), (25, 15, 10), (-30, 0, 6)]):
        spire = add_cylinder(f"Spire_{i}", (x, y, h / 2), 0.4, h, rock)
        spire.parent = root
        parts.append(spire)
        tip = add_cube(f"SpireTip_{i}", (x, y, h + 0.5), (0.3, 0.3, 0.5), cyan_glow)
        tip.parent = root
        parts.append(tip)

    # Boss arena ring — vertical wall segments standing on ground
    for i in range(12):
        angle = i * (math.pi * 2 / 12)
        rx = math.cos(angle) * 15
        ry = math.sin(angle) * 15
        segment = add_cube(f"ArenaWall_{i}", (rx, ry, 1.5), (2.0, 0.25, 1.5), steel)
        segment.rotation_euler = (0, 0, angle + math.pi / 2)
        segment.parent = root
        parts.append(segment)

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
