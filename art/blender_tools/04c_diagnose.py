# 04c_diagnose.py - only READS. Shows which preview files exist (and when they were written),
# whether the textures are black, and which texture the model really uses.
import bpy, os, time, traceback
import numpy as np

L = ["Now: " + time.strftime("%H:%M:%S")]
try:
    L.append("Blend file: " + bpy.data.filepath)
    d = os.path.join(os.path.dirname(bpy.data.filepath), "previews")
    L.append("Previews folder: " + d + " exists=" + str(os.path.isdir(d)))
    if os.path.isdir(d):
        for f in sorted(os.listdir(d)):
            t = time.strftime("%H:%M:%S", time.localtime(os.path.getmtime(os.path.join(d, f))))
            L.append("  %s  written at %s" % (f, t))
    L.append("Text blocks in this file: " + str([t.name for t in bpy.data.texts]))
    for name in ("Kazuma_color", "Kazuma_color_v3", "Kazuma_color_v4"):
        im = bpy.data.images.get(name)
        if not im:
            L.append("%s: (missing)" % name)
            continue
        a = np.empty(im.size[0] * im.size[1] * 4, dtype=np.float32)
        im.pixels.foreach_get(a)
        a = a.reshape(-1, 4)
        black = float((a[:, :3].max(axis=1) < 0.02).mean() * 100)
        L.append("%s: average color=%s, black pixels=%.1f%%" % (name, a[:, :3].mean(axis=0).round(3), black))
    g = bpy.data.objects.get("Kazuma_game")
    if g:
        L.append("Kazuma_game: visible=%s, materials=%s" % (not g.hide_get(), [m.name for m in g.data.materials]))
        for m in g.data.materials:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE":
                    L.append("  %s uses image %s" % (m.name, n.image.name if n.image else None))
except Exception:
    L.append("ERROR:\n" + traceback.format_exc())
msg = "\n".join(L)
print(msg)
try:
    bpy.context.window_manager.clipboard = msg
except Exception:
    pass
