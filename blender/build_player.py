"""Build Path of Destiny player armor model and export GLB."""
import bpy
import math
import os

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "models")
OUTPUT_PATH = os.path.abspath(os.path.join(OUTPUT_DIR, "player.glb"))

# Colors from reference: white armor, dark gray undersuit, red accents, cyan visor
WHITE = (0.92, 0.93, 0.95, 1.0)
DARK = (0.12, 0.13, 0.15, 1.0)
RED = (0.75, 0.08, 0.08, 1.0)
CYAN = (0.1, 0.85, 0.95, 1.0)
EMISSIVE_STRENGTH = 3.0

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def make_mat(name, color, metallic=0.6, roughness=0.35, emission=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = EMISSIVE_STRENGTH
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

def add_cylinder(name, loc, radius, depth, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(location=loc, radius=radius, depth=depth, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    assign_mat(obj, mat)
    return obj

def add_sphere(name, loc, radius, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(location=loc, radius=radius)
    obj = bpy.context.active_object
    obj.name = name
    assign_mat(obj, mat)
    return obj

def build_player():
    clear_scene()
    white = make_mat("ArmorWhite", WHITE, metallic=0.7, roughness=0.25)
    dark = make_mat("Undersuit", DARK, metallic=0.2, roughness=0.6)
    red = make_mat("AccentRed", RED, metallic=0.5, roughness=0.3)
    visor = make_mat("Visor", CYAN, metallic=0.9, roughness=0.1, emission=CYAN)

    # Root empty for export
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
    root = bpy.context.active_object
    root.name = "PlayerRoot"

    # Torso (Blender Z-up: loc = X, Y, Z_height)
    torso = add_cube("Torso", (0, 0, 1.15), (0.35, 0.22, 0.42), white)
    chest_plate = add_cube("ChestPlate", (0, -0.12, 1.25), (0.38, 0.08, 0.35), white)
    chest_red = add_cube("ChestChevron", (0, -0.18, 1.22), (0.12, 0.02, 0.18), red)

    # Back reactor
    back_plate = add_cube("BackPlate", (0, 0.14, 1.2), (0.32, 0.06, 0.38), white)
    reactor = add_cylinder("Reactor", (0, 0.2, 1.25), 0.08, 0.04, red, rot=(math.pi/2, 0, 0))
    reactor_mat = make_mat("ReactorGlow", RED, emission=RED)
    assign_mat(reactor, reactor_mat)

    # Head / Helmet
    head = add_sphere("Helmet", (0, 0, 1.75), 0.22, white)
    visor_strip = add_cube("Visor", (0, -0.19, 1.76), (0.18, 0.02, 0.04), visor)
    jaw = add_cube("JawGuard", (0, -0.15, 1.62), (0.14, 0.06, 0.1), dark)

    # Shoulders
    l_shoulder = add_cube("ShoulderL", (-0.42, 0, 1.45), (0.18, 0.18, 0.14), white)
    r_shoulder = add_cube("ShoulderR", (0.42, 0, 1.45), (0.18, 0.18, 0.14), white)
    l_stripe = add_cube("StripeL", (-0.42, -0.1, 1.45), (0.14, 0.02, 0.04), red)
    r_stripe = add_cube("StripeR", (0.42, -0.1, 1.45), (0.14, 0.02, 0.04), red)

    # Arms
    l_upper = add_cylinder("ArmUpperL", (-0.42, 0, 1.05), 0.09, 0.35, dark)
    r_upper = add_cylinder("ArmUpperR", (0.42, 0, 1.05), 0.09, 0.35, dark)
    l_fore = add_cube("ForearmL", (-0.42, 0, 0.72), (0.1, 0.1, 0.28), white)
    r_fore = add_cube("ForearmR", (0.42, 0, 0.72), (0.1, 0.1, 0.28), white)
    l_glove = add_cube("GloveL", (-0.42, 0, 0.48), (0.09, 0.09, 0.1), dark)
    r_glove = add_cube("GloveR", (0.42, 0, 0.48), (0.09, 0.09, 0.1), dark)

    # Waist / belt
    belt = add_cube("Belt", (0, 0, 0.88), (0.38, 0.2, 0.12), dark)
    pouch_l = add_cube("PouchL", (-0.15, 0.12, 0.88), (0.08, 0.06, 0.08), dark)
    pouch_r = add_cube("PouchR", (0.15, 0.12, 0.88), (0.08, 0.06, 0.08), dark)

    # Legs
    l_thigh = add_cube("ThighL", (-0.16, 0, 0.55), (0.14, 0.14, 0.38), white)
    r_thigh = add_cube("ThighR", (0.16, 0, 0.55), (0.14, 0.14, 0.38), white)
    l_knee = add_sphere("KneeL", (-0.16, 0.02, 0.32), 0.08, dark)
    r_knee = add_sphere("KneeR", (0.16, 0.02, 0.32), 0.08, dark)
    l_shin = add_cube("ShinL", (-0.16, 0, 0.15), (0.12, 0.12, 0.32), white)
    r_shin = add_cube("ShinR", (0.16, 0, 0.15), (0.12, 0.12, 0.32), white)
    l_boot = add_cube("BootL", (-0.16, 0.04, -0.05), (0.13, 0.22, 0.1), dark)
    r_boot = add_cube("BootR", (0.16, 0.04, -0.05), (0.13, 0.22, 0.1), dark)

    parts = [torso, chest_plate, chest_red, back_plate, reactor, head, visor_strip, jaw,
             l_shoulder, r_shoulder, l_stripe, r_stripe, l_upper, r_upper, l_fore, r_fore,
             l_glove, r_glove, belt, pouch_l, pouch_r, l_thigh, r_thigh, l_knee, r_knee,
             l_shin, r_shin, l_boot, r_boot]

    bpy.ops.object.select_all(action='DESELECT')
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = torso
    bpy.ops.object.join()
    player_mesh = bpy.context.active_object
    player_mesh.name = "PathOfDestinyPlayer"
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    min_z = min(v.co.z for v in player_mesh.data.vertices)
    player_mesh.location.z = -min_z
    return player_mesh

def build_environment_props():
    """Build sci-fi environment pieces for Outriders-style world."""
    props = []
    rust = make_mat("RustMetal", (0.35, 0.18, 0.08, 1.0), metallic=0.8, roughness=0.5)
    steel = make_mat("Steel", (0.25, 0.27, 0.3, 1.0), metallic=0.9, roughness=0.4)
    glow_orange = make_mat("LavaGlow", (1.0, 0.4, 0.05, 1.0), emission=(1.0, 0.4, 0.05, 1.0))

    # Ruined pillar
    bpy.ops.mesh.primitive_cylinder_add(location=(5, 5, 2), radius=0.8, depth=4)
    pillar = bpy.context.active_object
    pillar.name = "RuinPillar"
    assign_mat(pillar, rust)
    props.append(pillar)

    # Broken platform
    platform = add_cube("Platform", (0, 0, -0.05), (20, 20, 0.1), steel)
    props.append(platform)

    # Glowing fissure
    fissure = add_cube("Fissure", (3, -2, 0.01), (4, 0.3, 0.02), glow_orange)
    props.append(fissure)

    # Alien spire
    spire = add_cylinder("Spire", (-8, 6, 3), 0.5, 6, rust)
    spire.scale = (1, 1, 1.5)
    props.append(spire)

    # Cargo container
    container = add_cube("Container", (-4, -6, 1), (1.5, 3, 2), steel)
    props.append(container)

    return props

def export_glb(filepath, objects):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        use_selection=True,
        export_format='GLB',
        export_apply=True,
    )
    print(f"Exported: {filepath}")

def main():
    player_mesh = build_player()
    export_glb(OUTPUT_PATH, [player_mesh])
    print("Player model complete.")

if __name__ == "__main__":
    main()
