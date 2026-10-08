class_name HazardZone
extends Node3D
## A round zone on the floor that hurts the enemies standing in it, or makes them bleed, for a while.
## Used by Crow Feather, Onibi Flame, Crimson Rain, Tremor, Iron Rain... Plain distance checks (no physics).

const TICK: float = 0.25

var radius: float = 2.0
var duration: float = 3.0
var damage_per_second: float = 0.0
var bleed_per_second: float = 0.0 # a bleed stack of this strength is (re)applied while an enemy stands in the zone
var bleed_key: String = "" # zones with the same key share one bleed stack (a dash trail); empty = one stack per zone
var color: Color = Color(0.9, 0.2, 0.3, 0.35)

var age: float = 0.0
var tick_timer: float = 0.0
var disc: MeshInstance3D


func _ready() -> void:
	disc = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.03
	disc.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	disc.material_override = material
	add_child(disc)


func _physics_process(delta: float) -> void:
	age += delta
	tick_timer += delta
	if tick_timer >= TICK:
		tick_timer = 0.0
		_hurt_enemies()
	if disc and disc.material_override:
		var fade: float = clampf((duration - age) / 0.6, 0.0, 1.0)
		disc.material_override.albedo_color.a = color.a * fade
	if age >= duration:
		queue_free()


func _hurt_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.health.is_dead():
			continue
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() > radius:
			continue
		if damage_per_second > 0.0:
			enemy.health.take_damage(damage_per_second * TICK)
		if bleed_per_second > 0.0 and enemy.get("status") != null:
			enemy.status.apply_bleed(bleed_per_second, 1.0, bleed_key if bleed_key != "" else "zone%d" % get_instance_id())
