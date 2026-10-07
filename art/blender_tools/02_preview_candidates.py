# 02_preview_candidates.py - makes preview pictures. Does NOT change your models.
# For each candidate it saves ONE image: front | left | back | right | face close-up.
# Output folder: "previews" next to your .blend file.
import bpy, os, math
from mathutils import Vector

CANDIDATES = ["Meshy_textured", "Kazuma_low"]
BODY_W, BODY_H = 450, 600
FACE = 600

scene = bpy.context.scene
out_dir = os.path.join(os.path.dirname(bpy.data.filepath) or os.path.expanduser("~"), "previews")
os.makedirs(out_dir, exist_ok=True)

# ---- remember everything we touch, so we can restore it at the end
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

# make the Base Color texture the "active" one, so the Workbench shows the right image
info = []
for obj_name in CANDIDATES:
    obj = bpy.data.objects.get(obj_name)
    if not obj:
        continue
    for slot in obj.material_slots:
        mat = slot.material
        if not (mat and mat.use_nodes):
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

VIEWS = [  # name, position, rotation (degrees)
    ("front", (0, -6, 0.85), (90, 0, 0)),
    ("left", (-6, 0, 0.85), (90, 0, -90)),
    ("back", (0, 6, 0.85), (90, 0, 180)),
    ("right", (6, 0, 0.85), (90, 0, 90)),
]

def shoot(path, pos, rot, scale, w, h):
    cam.location = pos
    cam.rotation_euler = [math.radians(a) for a in rot]
    cam_data.ortho_scale = scale
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

results = []
try:
    for obj_name in CANDIDATES:
        obj = bpy.data.objects.get(obj_name)
        if not obj:
            continue
        for o in bpy.data.objects:
            if o.type == "MESH":
                o.hide_render = (o.name != obj_name)
        parts = []
        for vname, pos, rot in VIEWS:
            p = os.path.join(out_dir, "%s_%s.png" % (obj_name, vname))
            shoot(p, pos, rot, 2.2, BODY_W, BODY_H)
            parts.append(p)
        p = os.path.join(out_dir, "%s_face.png" % obj_name)
        shoot(p, (0, -6, 1.55), (90, 0, 0), 0.5, FACE, FACE)
        parts.append(p)

        final = os.path.join(out_dir, "PREVIEW_%s.png" % obj_name)
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
            results.append("(could not join images: %s) single images are in the folder" % e)
finally:
    # ---- restore your scene exactly as it was
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

msg = "DONE. Attach these images in the chat:\n" + "\n".join(results) + "\n" + "\n".join(info)
print(msg)
try:
    bpy.context.window_manager.clipboard = msg
except Exception:
    pass
