# 03d_apply_old_texture.py - puts the OLD good texture on "Kazuma_game" and prints how the
# earlier face projection ("FaceProject") was set up. Nothing is deleted. No previews here.
import bpy, traceback

def dump_material(mat):
    out = ["MATERIAL " + mat.name]
    nt = mat.node_tree
    if not nt:
        return out
    for n in nt.nodes:
        s = "- %s '%s'" % (n.type, n.name)
        if n.type == "TEX_IMAGE":
            s += " image=%s ext=%s interp=%s" % (n.image.name if n.image else None, n.extension, n.interpolation)
        if n.type == "MAPPING":
            s += " vector_type=%s" % n.vector_type
            for i in n.inputs:
                if hasattr(i, "default_value") and i.name in ("Location", "Rotation", "Scale"):
                    s += " %s=%s" % (i.name, tuple(round(v, 5) for v in i.default_value))
        if n.type == "TEX_COORD":
            s += " object=%s" % (n.object.name if n.object else None)
        if n.type == "UVMAP":
            s += " uv_map=%s" % n.uv_map
        out.append(s)
    for l in nt.links:
        out.append("   %s.%s -> %s.%s" % (l.from_node.name, l.from_socket.name, l.to_node.name, l.to_socket.name))
    return out

msg = []
try:
    game = bpy.data.objects["Kazuma_game"]
    img_c = bpy.data.images["Kazuma_color"]
    img_n = bpy.data.images["Kazuma_normal"]
    mat = bpy.data.materials.get("Kazuma_game_mat_old") or bpy.data.materials.new("Kazuma_game_mat_old")
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tc = nt.nodes.new("ShaderNodeTexImage"); tc.image = img_c
    tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = img_n
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tc.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = 0.85
    game.data.materials.clear()
    game.data.materials.append(mat)
    game.hide_set(False)
    game.hide_viewport = False
    msg.append("Old texture applied on Kazuma_game.")

    msg.append("")
    msg.append("== HOW THE FACE PROJECTION WAS SET UP ==")
    for name in ("FaceProject",):
        m = bpy.data.materials.get(name)
        if m:
            msg += dump_material(m)
    cam = bpy.data.objects.get("Camera")
    if cam:
        msg.append("Camera: loc=%s rot_deg=%s type=%s ortho=%.4f lens=%.2f shift=(%.3f,%.3f) sensor=%.1f" % (
            tuple(round(v, 4) for v in cam.location),
            tuple(round(v * 57.29578, 2) for v in cam.rotation_euler),
            cam.data.type, cam.data.ortho_scale, cam.data.lens, cam.data.shift_x, cam.data.shift_y, cam.data.sensor_width))
    for o in bpy.data.objects:
        if o.type == "EMPTY":
            msg.append("Empty: %s loc=%s" % (o.name, tuple(round(v, 4) for v in o.location)))
    scene = bpy.context.scene
    msg.append("Render size: %dx%d" % (scene.render.resolution_x, scene.render.resolution_y))
except Exception:
    msg.append("ERROR:\n" + traceback.format_exc())


text = "\n".join(msg)
print(text)
try:
    bpy.context.window_manager.clipboard = text
except Exception:
    pass
