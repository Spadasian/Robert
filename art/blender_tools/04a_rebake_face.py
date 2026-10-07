# 04a_rebake_face.py - re-does the face projection (from the concept sheet) on the repaired
# Kazuma_game, only on the head/scarf area. Result goes to a NEW image "Kazuma_color_v4".
import bpy, bmesh, traceback
import numpy as np

# face area in meters. The FACE DETAIL panel of the sheet covers x -0.14..0.12 and z 1.31..1.64,
# so we stay inside it (change if the result covers too much / too little)
Z_MIN, Z_MAX = 1.40, 1.63
X_MIN, X_MAX = -0.13, 0.115
MIN_FRONT = 0.2   # a face must look toward the front (-Y) at least this much

scene = bpy.context.scene
msg = []
try:
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    game = bpy.data.objects["Kazuma_game"]
    mat_fp = bpy.data.materials["FaceProject"]
    nt = mat_fp.node_tree
    old_img = bpy.data.images["Kazuma_color"]

    # remember how the old projection was set up (the Math nodes)
    for n in nt.nodes:
        if n.type == "MATH":
            vals = [round(i.default_value, 5) for i in n.inputs if not i.is_linked]
            msg.append("Math node %s: %s %s clamp=%s" % (n.name, n.operation, vals, n.use_clamp))

    # 1. copy of the mesh with only the face / scarf faces
    prev = bpy.data.objects.get("FaceOnly")
    if prev:
        pm = prev.data
        bpy.data.objects.remove(prev, do_unlink=True)
        bpy.data.meshes.remove(pm)
    face = game.copy()
    face.data = game.data.copy()
    face.name = "FaceOnly"
    scene.collection.objects.link(face)
    bm = bmesh.new()
    bm.from_mesh(face.data)
    mw = game.matrix_world
    rot = mw.to_3x3()
    drop = []
    for f in bm.faces:
        c = mw @ f.calc_center_median()
        nrm = rot @ f.normal
        if not (Z_MIN <= c.z <= Z_MAX and X_MIN <= c.x <= X_MAX and nrm.y < -MIN_FRONT):
            drop.append(f)
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    msg.append("Face faces kept: %d" % len(bm.faces))
    bm.to_mesh(face.data)
    bm.free()

    # 2. bake the projection into a temporary, transparent image
    face.data.materials.clear()
    face.data.materials.append(mat_fp)
    if "Face_bake_tmp" in bpy.data.images:
        bpy.data.images.remove(bpy.data.images["Face_bake_tmp"])
    tmp = bpy.data.images.new("Face_bake_tmp", 4096, 4096, alpha=False)
    sentinel = np.array([1.0, 0.0, 1.0, 1.0], dtype=np.float32)  # magenta = "not baked"
    tmp.pixels.foreach_set(np.tile(sentinel, 4096 * 4096))
    target = nt.nodes["BakeTarget"]
    prev_image = target.image
    target.image = tmp
    nt.nodes.active = target

    saved_engine = scene.render.engine
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 8
    b = scene.render.bake
    b.use_selected_to_active = False
    b.use_clear = False
    b.margin = 6
    b.margin_type = "EXTEND"
    b.target = "IMAGE_TEXTURES"
    face.hide_set(False)
    face.hide_viewport = False
    bpy.ops.object.select_all(action="DESELECT")
    face.select_set(True)
    bpy.context.view_layer.objects.active = face
    bpy.ops.object.bake(type="EMIT")
    scene.render.engine = saved_engine
    target.image = prev_image

    # 3. paste the baked area over a copy of the old texture
    size = 4096 * 4096 * 4
    a_old = np.empty(size, dtype=np.float32)
    old_img.pixels.foreach_get(a_old)
    a_new = np.empty(size, dtype=np.float32)
    tmp.pixels.foreach_get(a_new)
    old = a_old.reshape(-1, 4)
    new = a_new.reshape(-1, 4)
    mask = np.abs(new - sentinel).max(axis=1) > 0.01
    msg.append("Pixels replaced: %d" % int(mask.sum()))
    old[mask] = new[mask]
    old[mask, 3] = 1.0
    del new, a_new
    if "Kazuma_color_v4" in bpy.data.images:
        bpy.data.images.remove(bpy.data.images["Kazuma_color_v4"])
    res = bpy.data.images.new("Kazuma_color_v4", 4096, 4096, alpha=False)
    res.pixels.foreach_set(a_old)
    res.pack()

    # 4. use it on Kazuma_game, clean up
    mat_g = bpy.data.materials["Kazuma_game_mat_old"]
    for n in mat_g.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image == old_img:
            n.image = res
            mat_g.node_tree.nodes.active = n
    fm = face.data
    bpy.data.objects.remove(face, do_unlink=True)
    bpy.data.meshes.remove(fm)
    bpy.data.images.remove(tmp)
    msg.append("DONE. Now run 04b_previews.py")
except Exception:
    msg.append("ERROR:\n" + traceback.format_exc())

text = "\n".join(msg)
print(text)
try:
    bpy.context.window_manager.clipboard = text
except Exception:
    pass
