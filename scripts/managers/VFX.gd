extends Node
## Small visual effects built from code, so the game has hit sparks, slashes and so on before there is any art.
## Autoload "VFX". Every effect is added to the current scene and removes itself. Real art can replace any of them
## later by changing the function body; the callers do not change.

const FLOOR_Y: float = 0.06

var _particle_mesh: QuadMesh
var _particle_material: StandardMaterial3D
var _arc_textures: Dictionary = {}
var _streak_texture: ImageTexture


func _ready() -> void:
	_particle_material = StandardMaterial3D.new()
	_particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_particle_material.vertex_color_use_as_albedo = true
	_particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_particle_mesh = QuadMesh.new()
	_particle_mesh.size = Vector2(0.2, 0.2)
	_particle_mesh.material = _particle_material


# ---------------------------------------------------------------- particles

## The shared little quad that particles are drawn with (also used by the Corruption wisps).
func get_particle_mesh() -> QuadMesh:
	return _particle_mesh


## Quick sparks when something is hit.
func hit_spark(position: Vector3, color: Color = Color(1.0, 0.9, 0.55)) -> void:
	_burst(position, 10, 0.3, 5.0, color, 1.0, 360.0, 0.0)


## A soft puff that rises and fades, for deaths.
func death_puff(position: Vector3, color: Color = Color.WHITE, big: bool = false) -> void:
	_burst(position, 36 if big else 20, 0.9 if big else 0.7, 3.5 if big else 2.2, color, 2.2 if big else 1.6, 180.0, 1.5)


## A small glitter, for pickups and relics.
func sparkle(position: Vector3, color: Color = Color(1.0, 0.85, 0.3)) -> void:
	_burst(position, 14, 0.7, 2.6, color, 0.9, 360.0, 3.0)


## Dust where a dash starts.
func dust(position: Vector3) -> void:
	_burst(Vector3(position.x, 0.15, position.z), 8, 0.4, 1.8, Color(0.75, 0.7, 0.65, 0.8), 1.4, 90.0, 0.0)


func _burst(position: Vector3, amount: int, lifetime: float, speed: float, color: Color, size: float, spread: float, lift: float) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var particles := CPUParticles3D.new()
	particles.mesh = _particle_mesh
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = spread
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0.0, lift - 4.0 if lift == 0.0 else lift, 0.0)
	particles.scale_amount_min = size * 0.6
	particles.scale_amount_max = size
	# Particles move with the node (it never moves after this). With world-space particles Godot culled
	# the effect whenever it was far from the world origin, so hits only showed in the middle of the map.
	particles.local_coords = true
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color.r, color.g, color.b, 0.0))
	particles.color_ramp = fade
	root.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	get_tree().create_timer(lifetime + 0.3).timeout.connect(particles.queue_free)


# ---------------------------------------------------------------- flat shapes

## A crescent slash in the air in front of `position`. yaw = atan2(dir.x, dir.z) of the direction it faces.
func slash_arc(position: Vector3, yaw: float, radius: float, arc_degrees: float, color: Color, duration: float = 0.18) -> void:
	_flat_shape(position, yaw, radius * 2.0, radius * 2.0, _get_arc_texture(arc_degrees), color, duration)


## An expanding ring on the ground (shockwave, counter).
func ring(position: Vector3, radius: float, color: Color, duration: float = 0.35) -> void:
	_flat_shape(Vector3(position.x, FLOOR_Y + 0.05, position.z), 0.0, radius * 2.0, radius * 2.0, _get_arc_texture(360.0), color, duration, 0.4)


## A straight streak between two points (the Iaijutsu cut).
func streak(from_position: Vector3, to_position: Vector3, width: float, color: Color, duration: float = 0.3) -> void:
	var flat: Vector3 = to_position - from_position
	flat.y = 0.0
	if flat.length() < 0.1:
		return
	var middle: Vector3 = (from_position + to_position) * 0.5
	_flat_shape(middle, atan2(flat.x, flat.z), width, flat.length(), _get_streak_texture(), color, duration, 1.0, true)


func _flat_shape(position: Vector3, yaw: float, width: float, length: float, texture: Texture2D, color: Color, duration: float, start_scale: float = 0.6, keep_length: bool = false) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, length)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = texture
	material.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mesh.material = material
	quad.mesh = mesh
	root.add_child(quad)
	quad.global_position = position
	quad.rotation = Vector3(-PI / 2.0, yaw, 0.0) # lie flat, then turn to face the direction
	quad.scale = Vector3(start_scale if not keep_length else 1.0, start_scale if not keep_length else 1.0, 1.0)
	var tween := quad.create_tween().set_parallel(true)
	tween.tween_property(quad, "scale", Vector3.ONE * (1.1 if not keep_length else 1.0), duration)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(quad.queue_free)


## A fading copy of a mesh where it is now (dash afterimages).
func ghost(source: MeshInstance3D, color: Color, duration: float = 0.25) -> void:
	var root: Node = get_tree().current_scene
	if root == null or source == null:
		return
	var copy := MeshInstance3D.new()
	copy.mesh = source.mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, 0.55)
	copy.material_override = material
	root.add_child(copy)
	copy.global_transform = source.global_transform
	var tween := copy.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.tween_callback(copy.queue_free)


## Shakes the camera for a moment. strength is in world units (0.1 small, 0.3 strong).
func shake(strength: float, duration: float = 0.2) -> void:
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(strength, duration)


# ---------------------------------------------------------------- textures made in code

## A soft band shaped like a ring or an arc, centred on the "forward" side (the +Z direction after the quad lies flat).
func _get_arc_texture(arc_degrees: float) -> ImageTexture:
	var key: int = int(arc_degrees)
	if _arc_textures.has(key):
		return _arc_textures[key]
	var size: int = 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half_arc: float = deg_to_rad(minf(arc_degrees, 360.0)) * 0.5
	for py in size:
		for px in size:
			var x: float = (px + 0.5) / size * 2.0 - 1.0
			var y: float = (py + 0.5) / size * 2.0 - 1.0
			var radius: float = sqrt(x * x + y * y)
			var alpha: float = smoothstep(0.55, 0.85, radius) * (1.0 - smoothstep(0.93, 1.0, radius))
			if arc_degrees < 360.0:
				alpha *= 1.0 - smoothstep(half_arc * 0.65, half_arc, absf(atan2(x, y))) # image down = forward
			image.set_pixel(px, py, Color(1.0, 1.0, 1.0, alpha))
	var texture := ImageTexture.create_from_image(image)
	_arc_textures[key] = texture
	return texture


## A bright line that fades towards its long edges.
func _get_streak_texture() -> ImageTexture:
	if _streak_texture:
		return _streak_texture
	var width: int = 32
	var length: int = 64
	var image := Image.create(width, length, false, Image.FORMAT_RGBA8)
	for py in length:
		for px in width:
			var x: float = absf((px + 0.5) / width * 2.0 - 1.0)
			var y: float = absf((py + 0.5) / length * 2.0 - 1.0)
			image.set_pixel(px, py, Color(1.0, 1.0, 1.0, (1.0 - smoothstep(0.0, 1.0, x)) * (1.0 - smoothstep(0.7, 1.0, y))))
	_streak_texture = ImageTexture.create_from_image(image)
	return _streak_texture
