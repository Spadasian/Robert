# 03a_fix_holes.py - creates the NEW object "Kazuma_game" from "Kazuma_low" and closes the holes.
# Your other objects are not changed.
import bpy, bmesh, os, time, traceback

scene = bpy.context.scene
log = []
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

msg = "STEP 03a DONE\n" + "\n".join(log)
print(msg)
try:
    bpy.context.window_manager.clipboard = msg
except Exception:
    pass
