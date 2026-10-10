extends Node3D
## A translucent copy of the player's body (the clones and the decoy of Yume). Fades out at the end of its life.

var material: StandardMaterial3D


func _ready() -> void:
	var mesh_instance := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.7
	mesh_instance.mesh = capsule
	mesh_instance.position.y = 0.85
	material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.98, 0.72, 0.88, 0.5)
	mesh_instance.material_override = material
	add_child(mesh_instance)


func set_alpha(alpha: float) -> void:
	if material:
		material.albedo_color.a = alpha
