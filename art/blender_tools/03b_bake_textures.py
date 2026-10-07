# 03b_bake_textures.py - bakes clean colors + normals from "Kazuma_high" onto "Kazuma_game".
# Run 03a first. This takes 1-5 minutes; Blender looks frozen, that is normal.
import bpy, bmesh, os, time, traceback

t0 = time.time()
log = []
scene = bpy.context.scene
view_layer = bpy.context.view_layer
high = bpy.data.objects["Kazuma_high"]
low = bpy.data.objects["Kazuma_low"]
game = bpy.data.objects["Kazuma_game"]
if bpy.context.object and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")

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
msg = "STEP 03b DONE\n" + "\n".join(log)
print(msg)
try:
    bpy.context.window_manager.clipboard = msg
except Exception:
    pass
