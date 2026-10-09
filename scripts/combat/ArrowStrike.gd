extends Node3D
## A strike on a round spot of the floor, announced by a red circle (Iron Rain arrows, the Crimson Tide explosions).
## After `delay` seconds it hurts the player if he is inside, through the player's hurtbox, so a dash or a
## Perfect Dodge makes it miss like any other hit.

var radius: float = 1.6
var delay: float = 1.2
var damage: float = 8.0
var color: Color = Color(1.0, 0.2, 0.2, 0.45)
var arrows: bool = true # arrows fall into the circle just before it hits

var age: float = 0.0
var struck: bool = false
var disc: MeshInstance3D
var arrow_nodes: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("arrow_strike")
	disc = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.03
	disc.mesh = mesh
	disc.material_override = _glow(Color(color.r, color.g, color.b, 0.15))
	add_child(disc)
	if arrows:
		for index in 5:
			var arrow := MeshInstance3D.new()
			var shaft := CylinderMesh.new()
			shaft.top_radius = 0.03
			shaft.bottom_radius = 0.03
			shaft.height = 1.2
			arrow.mesh = shaft
			arrow.material_override = _glow(Color(0.85, 0.85, 0.9, 0.9))
			var angle: float = TAU * index / 5.0
			var spot: float = radius * 0.6 if index > 0 else 0.0
			arrow.position = Vector3(cos(angle) * spot, 12.0, sin(angle) * spot)
			add_child(arrow)
			arrow_nodes.append(arrow)


func _physics_process(delta: float) -> void:
	age += delta
	if struck:
		return
	var progress: float = clampf(age / delay, 0.0, 1.0)
	disc.material_override.albedo_color.a = lerpf(0.15, color.a, progress)
	for arrow in arrow_nodes:
		arrow.position.y = lerpf(12.0, 0.6, pow(progress, 3.0))
	if age >= delay:
		_strike()


func _strike() -> void:
	struck = true
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and not player.health.is_dead():
		var offset: Vector3 = player.global_position - global_position
		offset.y = 0.0
		if offset.length() <= radius:
			player.hurtbox.receive_hit(damage, null)
	VFX.ring(global_position + Vector3(0.0, 0.1, 0.0), radius, Color(color.r, color.g, color.b, 0.9), 0.3)
	VFX.hit_spark(global_position + Vector3(0.0, 0.3, 0.0), Color(1.0, 0.6, 0.4))
	for arrow in arrow_nodes:
		arrow.visible = false
	disc.material_override.albedo_color = Color(1.0, 0.9, 0.7, 0.6)
	await get_tree().create_timer(0.15, false).timeout
	queue_free()


func _glow(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	return material
