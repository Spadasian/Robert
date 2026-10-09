extends Node3D
## Purple wisps around the player that grow with Corruption, and a violet glow on the body.
## Added to the Player by Player.gd. Level 0 (below 25%) shows nothing; every threshold makes it stronger.

const LEVEL_COLORS: Array[Color] = [
	Color(0.5, 0.2, 0.9), Color(0.6, 0.2, 0.9), Color(0.75, 0.2, 0.8), Color(0.9, 0.15, 0.5), Color(1.0, 0.1, 0.2),
]

var particles: CPUParticles3D
var body_material: StandardMaterial3D
var aura: CPUParticles3D
var glow: OmniLight3D
var possessed: bool = false


func _ready() -> void:
	var player := get_parent()
	position.y = 0.9
	particles = CPUParticles3D.new()
	particles.mesh = VFX.get_particle_mesh()
	particles.emitting = false
	particles.lifetime = 1.3
	particles.local_coords = false # the wisps stay behind when the player moves
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.5
	particles.direction = Vector3.UP
	particles.spread = 20.0
	particles.initial_velocity_min = 0.4
	particles.initial_velocity_max = 1.0
	particles.gravity = Vector3(0.0, 0.5, 0.0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.1
	add_child(particles)

	var body: MeshInstance3D = player.body_mesh
	var original := body.get_active_material(0) as StandardMaterial3D
	if original:
		body_material = original.duplicate() as StandardMaterial3D # the glow must not change the shared material
		body.material_override = body_material
		body_material.emission_enabled = true
		body_material.emission = Color.BLACK

	aura = CPUParticles3D.new() # Possessed: a dark violet-black wind of wisps rising around him (the clothes and hair will follow when the model exists)
	aura.mesh = VFX.get_particle_mesh()
	aura.emitting = false
	aura.amount = 36
	aura.lifetime = 0.9
	aura.local_coords = false
	aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 0.55
	aura.direction = Vector3.UP
	aura.spread = 12.0
	aura.initial_velocity_min = 2.0
	aura.initial_velocity_max = 3.5
	aura.gravity = Vector3(0.8, 1.5, 0.4) # the "wind" always blows on him
	aura.scale_amount_min = 0.8
	aura.scale_amount_max = 1.6
	var aura_fade := Gradient.new()
	aura_fade.set_color(0, Color(0.45, 0.05, 0.75, 0.9))
	aura_fade.set_color(1, Color(0.02, 0.0, 0.05, 0.0))
	aura.color_ramp = aura_fade
	add_child(aura)
	glow = OmniLight3D.new()
	glow.light_color = Color(0.55, 0.1, 0.9)
	glow.light_energy = 0.0
	glow.omni_range = 5.0
	add_child(glow)

	var corruption: Node = player.get_node("CorruptionComponent")
	corruption.corruption_changed.connect(_on_corruption_changed)
	corruption.possessed_started.connect(func(): _set_possessed(true))
	corruption.possessed_ended.connect(func(): _set_possessed(false))
	_on_corruption_changed(corruption.value, corruption.level)


func _on_corruption_changed(_value: float, level: int) -> void:
	if possessed:
		return # the Possessed look stays until it ends
	var color: Color = LEVEL_COLORS[clampi(level, 0, LEVEL_COLORS.size() - 1)]
	particles.emitting = level > 0
	particles.amount = 6 + 6 * maxi(level, 1)
	var fade := Gradient.new()
	fade.set_color(0, Color(color.r, color.g, color.b, 0.8))
	fade.set_color(1, Color(color.r, color.g, color.b, 0.0))
	particles.color_ramp = fade
	if body_material:
		body_material.emission = color
		body_material.emission_energy_multiplier = 0.25 * level


func _set_possessed(on: bool) -> void:
	possessed = on
	aura.emitting = on
	glow.light_energy = 2.5 if on else 0.0
	if on:
		particles.emitting = false
		if body_material:
			body_material.emission = Color(0.35, 0.0, 0.6)
			body_material.emission_energy_multiplier = 1.2
	else:
		var corruption: Node = get_parent().get_node("CorruptionComponent")
		_on_corruption_changed(corruption.value, corruption.level)
