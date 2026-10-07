# 01_inspect_scene.py - ONLY READS the scene, changes nothing.
# Writes a report, copies it to the clipboard and saves it as a Text block called "REPORT".
import bpy, os
from mathutils import Vector

L = []
L.append("Blender " + bpy.app.version_string)
L.append("File: " + (bpy.data.filepath or "(not saved)"))
L.append("")
L.append("== OBJECTS ==")
for o in sorted(bpy.data.objects, key=lambda x: x.name):
    row = "%s | %s" % (o.name, o.type)
    try:
        row += " | hidden=%s" % (o.hide_get() or o.hide_viewport)
    except Exception:
        pass
    row += " | collections=%s" % [c.name for c in o.users_collection]
    if o.parent:
        row += " | parent=" + o.parent.name
    if o.type == "MESH":
        me = o.data
        zs = [(o.matrix_world @ Vector(c)).z for c in o.bound_box]
        row += " | verts=%d faces=%d" % (len(me.vertices), len(me.polygons))
        row += " | size=(%.2f, %.2f, %.2f)" % tuple(o.dimensions)
        row += " | z=%.2f..%.2f" % (min(zs), max(zs))
        row += " | uv_maps=%d" % len(me.uv_layers)
        row += " | attributes=%s" % [a.name for a in me.attributes if not a.name.startswith(".")]
        row += " | materials=%s" % [m.name for m in me.materials if m]
        row += " | modifiers=%s" % [m.type for m in o.modifiers]
        row += " | vertex_groups=%d" % len(o.vertex_groups)
    elif o.type == "ARMATURE":
        row += " | bones=%d" % len(o.data.bones)
    L.append(row)

L.append("")
L.append("== MATERIALS / TEXTURES ==")
for m in bpy.data.materials:
    tex = []
    if m.use_nodes and m.node_tree:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                tex.append("%s %dx%d" % (n.image.name, n.image.size[0], n.image.size[1]))
    L.append("%s | users=%d | textures=%s" % (m.name, m.users, tex))

L.append("")
L.append("== IMAGES ==")
for im in bpy.data.images:
    L.append("%s | %dx%d | source=%s | packed=%s | path=%s" % (
        im.name, im.size[0], im.size[1], im.source, im.packed_file is not None, im.filepath))

report = "\n".join(L)
print(report)
txt = bpy.data.texts.get("REPORT") or bpy.data.texts.new("REPORT")
txt.clear()
txt.write(report)
try:
    bpy.context.window_manager.clipboard = report
except Exception:
    pass
try:
    with open(os.path.join(os.path.expanduser("~"), "blender_report.txt"), "w", encoding="utf-8") as f:
        f.write(report)
except Exception:
    pass
print("\nREPORT READY - paste it in the chat (Ctrl+V).")
