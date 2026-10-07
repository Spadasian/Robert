# 03d_old_texture.py - puts the OLD good texture on "Kazuma_game", renders previews,
# and prints how the earlier face projection ("FaceProject") was set up. Nothing is deleted.
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

# ---------- preview helper: renders front/left/back/right/face and joins them in one picture ----------
def make_previews(names, tag=""):
    import bpy, os, math
    scene = bpy.context.scene
    out_dir = os.path.join(os.path.dirname(bpy.data.filepath) or os.path.expanduser("~"), "previews")
    os.makedirs(out_dir, exist_ok=True)
    saved = {
        "engine": scene.render.engine, "camera": scene.camera,
        "rx": scene.render.resolution_x, "ry": scene.render.resolution_y,
        "pct": scene.render.resolution_percentage, "path": scene.render.filepath,
        "light": scene.display.shading.light, "color": scene.display.shading.color_type,
        "view": scene.view_settings.view_transform,
        "hide": {o.name: o.hide_render for o in bpy.data.objects},
    }
    world_color = scene.world.color[:] if scene.world else None
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "TEXTURE"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_percentage = 100
    if scene.world:
        scene.world.color = (0.12, 0.12, 0.14)

    info = []
    for obj_name in names:
        obj = bpy.data.objects.get(obj_name)
        if not obj:
            continue
        for slot in obj.material_slots:
            mat = slot.material
            if not (mat and mat.node_tree):
                continue
            for node in mat.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image:
                    for link in node.outputs[0].links:
                        if link.to_socket.name == "Base Color":
                            mat.node_tree.nodes.active = node
                            info.append("%s: Base Color = %s" % (obj_name, node.image.name))

    cam_data = bpy.data.cameras.new("TMP_CAM")
    cam_data.type = "ORTHO"
    cam_data.clip_end = 50
    cam = bpy.data.objects.new("TMP_CAM", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    views = [("front", (0, -6, 0.85), (90, 0, 0)), ("left", (-6, 0, 0.85), (90, 0, -90)),
             ("back", (0, 6, 0.85), (90, 0, 180)), ("right", (6, 0, 0.85), (90, 0, 90))]

    def shoot(path, pos, rot, scale, w, h):
        cam.location = pos
        cam.rotation_euler = [math.radians(a) for a in rot]
        cam_data.ortho_scale = scale
        scene.render.resolution_x, scene.render.resolution_y = w, h
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)

    results = []
    try:
        for obj_name in names:
            obj = bpy.data.objects.get(obj_name)
            if not obj:
                continue
            for o in bpy.data.objects:
                if o.type == "MESH":
                    o.hide_render = (o.name != obj_name)
            parts = []
            for vname, pos, rot in views:
                p = os.path.join(out_dir, "%s%s_%s.png" % (obj_name, tag, vname))
                shoot(p, pos, rot, 2.2, 450, 600)
                parts.append(p)
            p = os.path.join(out_dir, "%s%s_face.png" % (obj_name, tag))
            shoot(p, (0, -6, 1.55), (90, 0, 0), 0.5, 600, 600)
            parts.append(p)
            final = os.path.join(out_dir, "PREVIEW_%s%s.png" % (obj_name, tag))
            try:
                import numpy as np
                arrs = []
                for pp in parts:
                    img = bpy.data.images.load(pp, check_existing=False)
                    w, h = img.size
                    a = np.empty(w * h * 4, dtype=np.float32)
                    img.pixels.foreach_get(a)
                    arrs.append(a.reshape(h, w, 4))
                    bpy.data.images.remove(img)
                big = np.concatenate(arrs, axis=1)
                out = bpy.data.images.new("PREVIEW_TMP", big.shape[1], big.shape[0])
                out.pixels.foreach_set(big.ravel())
                out.filepath_raw = final
                out.file_format = "PNG"
                out.save()
                bpy.data.images.remove(out)
                results.append(final)
            except Exception as e:
                results.append("(could not join images: %s) single images are in the folder %s" % (e, out_dir))
    finally:
        for o in bpy.data.objects:
            if o.name in saved["hide"]:
                o.hide_render = saved["hide"][o.name]
        scene.camera = saved["camera"]
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
        scene.render.engine = saved["engine"]
        scene.render.resolution_x, scene.render.resolution_y = saved["rx"], saved["ry"]
        scene.render.resolution_percentage = saved["pct"]
        scene.render.filepath = saved["path"]
        scene.display.shading.light = saved["light"]
        scene.display.shading.color_type = saved["color"]
        scene.view_settings.view_transform = saved["view"]
        if scene.world and world_color:
            scene.world.color = world_color
    return results, info


try:
    results, info = make_previews(["Kazuma_game"], tag="_oldtex")
    msg.append("")
    msg.append("DONE. Attach this image in the chat:")
    msg += results
except Exception:
    msg.append("ERROR in previews:\n" + traceback.format_exc())
text = "\n".join(msg)
print(text)
try:
    bpy.context.window_manager.clipboard = text
except Exception:
    pass
