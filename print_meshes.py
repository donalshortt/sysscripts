import bpy

# Create or replace a text block called "gltf_indices"
if "gltf_indices" in bpy.data.texts:
    txt = bpy.data.texts["gltf_indices"]
    txt.clear()
else:
    txt = bpy.data.texts.new("gltf_indices")

# Dump mesh & primitive info
txt.write("glTF mesh indices and primitives:\n\n")
for mi, mesh in enumerate(bpy.data.meshes):
    txt.write(f"Mesh{mi}: {mesh.name}\n")
    # Each material slot is one primitive
    for pi, mat in enumerate(mesh.materials):
        matname = mat.name if mat else "<no material>"
        txt.write(f"  Primitive{pi}: material slot #{pi} → {matname}\n")
    txt.write("\n")

# Finally, switch the Text Editor to show our new block
for area in bpy.context.screen.areas:
    if area.type == 'TEXT_EDITOR':
        area.spaces.active.text = txt
        break
