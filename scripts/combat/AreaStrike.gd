extends RefCounted
## A short burst of damage on a round area, made of a real Hitbox, so it crits, bleeds, charges the Ultimate and
## feeds the Kata like any other hit of the player. Used by the clones and decoys of Yume.

const HITBOX_SCRIPT: Script = preload("res://scripts/combat/Hitbox.gd")


## Hits everything around `center` (radius metres) once. The hitbox lives `duration` seconds and removes itself.
static func spawn(parent: Node, center: Vector3, radius: float, damage: float, source: Node, kind: String = "skill", duration: float = 0.12) -> Area3D:
	var hitbox := Area3D.new()
	hitbox.set_script(HITBOX_SCRIPT)
	hitbox.collision_layer = 8
	hitbox.collision_mask = 32
	hitbox.monitorable = false
	hitbox.team = "player"
	hitbox.kind = kind
	hitbox.damage = damage
	hitbox.source = source
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	hitbox.add_child(shape)
	parent.add_child(hitbox)
	hitbox.global_position = Vector3(center.x, 0.9, center.z)
	hitbox.set_active(true)
	var timer: SceneTreeTimer = hitbox.get_tree().create_timer(duration, false)
	timer.timeout.connect(func():
		if is_instance_valid(hitbox):
			hitbox.queue_free())
	return hitbox
