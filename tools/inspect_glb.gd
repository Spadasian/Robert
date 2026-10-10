extends SceneTree
func dump(n: Node, depth: int) -> void:
	var s := "  ".repeat(depth) + n.name + " [" + n.get_class() + "]"
	if n is MeshInstance3D:
		var aabb: AABB = n.get_aabb()
		s += " aabb pos=" + str(aabb.position) + " size=" + str(aabb.size) + " surfaces=" + str(n.mesh.get_surface_count())
		var m = n.get_active_material(0)
		s += " mat=" + (m.get_class() if m else "none")
	if n is Node3D:
		s += " pos=" + str(n.position) + " rot=" + str(n.rotation_degrees) + " scale=" + str(n.scale)
	print(s)
	for c in n.get_children():
		dump(c, depth + 1)
func _initialize() -> void:
	for f in ["katana_kazuma", "tessen_yume", "kanabo_takeda", "tekko_kagi_kurotsuki"]:
		print("=== ", f)
		var scene: PackedScene = load("res://art/weapons/%s.glb" % f)
		var inst: Node = scene.instantiate()
		dump(inst, 0)
		inst.free()
	quit()
