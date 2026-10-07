# 03_rebuild_and_bake.py
# Makes a NEW object "Kazuma_game" from "Kazuma_low": closes holes, bakes clean colors + normals
# from "Kazuma_high", then renders previews. Your other objects are not changed.
import bpy, bmesh, os, time, traceback

def step03():
    t0 = time.time()
    log = []
    scene = bpy.context.scene
    view_layer = bpy.context.view_layer
    high = bpy.data.objects["Kazuma_high"]
    low = bpy.data.objects["Kazuma_low"]
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")

    # ---- 1. new object from Kazuma_low
    old = bpy.data.objects.get("Kazuma_game")
    if old:
        old_mesh = old.data
        bpy.data.objects.remove(old, do_unlink=True)
        bpy.data.meshes.remove(old_mesh)
    game = low.copy()
    game.data = low.data.copy()
    game.name = "Kazuma_game"
    game.data.name = "Kazuma_game"
    scene.collection.objects.link(game)

    # ---- 2. close the holes (keeping the existing UV layout)
    me = game.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.00001)
    boundary = [e for e in bm.edges if e.is_boundary]
    log.append("Open edges before: %d" % len(boundary))
    faces_before = set(bm.faces)
    if boundary:
        bmesh.ops.holes_fill(bm, edges=boundary, sides=200)
        new_faces = [f for f in bm.faces if f not in faces_before]
        if new_faces:
            res = bmesh.ops.triangulate(bm, faces=new_faces, quad_method="BEAUTY", ngon_method="BEAUTY")
            new_faces = list(res["faces"])
        new_set = set(new_faces)
        uv_layer = bm.loops.layers.uv.active
        if uv_layer is None:
            uv_layer = bm.loops.layers.uv.new("UVMap")
        for f in new_faces:
            ref_uv = None
            for e in f.edges:
                for lf in e.link_faces:
                    if lf not in new_set:
                        pts = [l[uv_layer].uv for l in lf.loops]
                        ref_uv = sum((p for p in pts), pts[0] * 0) / len(pts)
                        break
                if ref_uv is not None:
                    break
            for loop in f.loops:
                cands = [l[uv_layer].uv.copy() for l in loop.vert.link_loops if l.face not in new_set]
                if not cands:
                    continue
                if ref_uv is not None:
                    cands.sort(key=lambda uv: (uv - ref_uv).length)
                loop[uv_layer].uv = cands[0]
        log.append("Hole faces added: %d" % len(new_faces))
    boundary_after = [e for e in bm.edges if e.is_boundary]
    log.append("Open edges after: %d (big holes that stay open, if any)" % len(boundary_after))
    bm.to_mesh(me)
    bm.free()
    me.update()
    log.append("Kazuma_game: %d verts, %d faces" % (len(me.vertices), len(me.polygons)))

    # ---- 3. materials and empty textures
    mat_hp = bpy.data.materials.new("HP_color_bake")
    try:
        mat_hp.use_nodes = True
    except Exception:
        pass
    nt = mat_hp.node_tree
    nt.nodes.clear()
    n_attr = nt.nodes.new("ShaderNodeAttribute")
    n_attr.attribute_name = "kazuma_color"
    n_emit = nt.nodes.new("ShaderNodeEmission")
    n_out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(n_attr.outputs["Color"], n_emit.inputs["Color"])
    nt.links.new(n_emit.outputs["Emission"], n_out.inputs["Surface"])

    for name in ("Kazuma_color_v3", "Kazuma_normal_v3"):
        if name in bpy.data.images:
            bpy.data.images.remove(bpy.data.images[name])
    img_c = bpy.data.images.new("Kazuma_color_v3", 4096, 4096, alpha=False)
    img_n = bpy.data.images.new("Kazuma_normal_v3", 4096, 4096, alpha=False)
    img_n.colorspace_settings.name = "Non-Color"

    mat_g = bpy.data.materials.get("Kazuma_game_mat") or bpy.data.materials.new("Kazuma_game_mat")
    try:
        mat_g.use_nodes = True
    except Exception:
        pass
    gt = mat_g.node_tree
    gt.nodes.clear()
    g_out = gt.nodes.new("ShaderNodeOutputMaterial")
    g_bsdf = gt.nodes.new("ShaderNodeBsdfPrincipled")
    g_tc = gt.nodes.new("ShaderNodeTexImage")
    g_tc.image = img_c
    g_tn = gt.nodes.new("ShaderNodeTexImage")
    g_tn.image = img_n
    g_nm = gt.nodes.new("ShaderNodeNormalMap")
    gt.links.new(g_tc.outputs["Color"], g_bsdf.inputs["Base Color"])
    gt.links.new(g_tn.outputs["Color"], g_nm.inputs["Color"])
    gt.links.new(g_nm.outputs["Normal"], g_bsdf.inputs["Normal"])
    gt.links.new(g_bsdf.outputs["BSDF"], g_out.inputs["Surface"])
    g_bsdf.inputs["Roughness"].default_value = 0.85
    game.data.materials.clear()
    game.data.materials.append(mat_g)

    # ---- 4. bake from Kazuma_high
    saved_hide = {o.name: (o.hide_get(), o.hide_viewport) for o in (high, low, game)}
    saved_engine = scene.render.engine
    high_mats = list(high.data.materials)
    try:
        for o in (high, game):
            o.hide_viewport = False
            o.hide_set(False)
        high.data.materials.clear()
        high.data.materials.append(mat_hp)

        scene.render.engine = "CYCLES"
        try:
            scene.cycles.device = "GPU"
        except Exception:
            pass
        scene.cycles.samples = 8
        try:
            scene.cycles.use_denoising = False
        except Exception:
            pass
        b = scene.render.bake
        b.use_selected_to_active = True
        b.use_cage = False
        b.cage_extrusion = 0.01
        b.max_ray_distance = 0.03
        b.margin = 16
        b.margin_type = "EXTEND"
        b.target = "IMAGE_TEXTURES"
        b.normal_space = "TANGENT"

        bpy.ops.object.select_all(action="DESELECT")
        high.select_set(True)
        game.select_set(True)
        view_layer.objects.active = game

        gt.nodes.active = g_tc
        bpy.ops.object.bake(type="EMIT")
        log.append("Color baked.")
        gt.nodes.active = g_tn
        bpy.ops.object.bake(type="NORMAL")
        log.append("Normal baked.")
        img_c.pack()
        img_n.pack()
    finally:
        high.data.materials.clear()
        for m in high_mats:
            high.data.materials.append(m)
        scene.render.engine = saved_engine
        for o in (high, low):
            o.hide_set(saved_hide[o.name][0])
            o.hide_viewport = saved_hide[o.name][1]
        game.hide_set(False)
        game.hide_viewport = False
    log.append("Time: %.0f s" % (time.time() - t0))
    return log


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

# ---------- run ----------
import bpy
msg = ""
try:
    log = step03()
    msg = "\n".join(log)
    results, info = make_previews(["Kazuma_game"], tag="_step03")
    msg += "\n\nDONE. Attach this image in the chat:\n" + "\n".join(results)
except Exception:
    msg += "\nERROR:\n" + traceback.format_exc()
print(msg)
try:
    bpy.context.window_manager.clipboard = msg
except Exception:
    pass
txt = bpy.data.texts.get("REPORT") or bpy.data.texts.new("REPORT")
txt.clear()
txt.write(msg)
