extends Area3D
## Deals damage to any Hurtbox it touches (once per activation). Ignores same-team hurtboxes.
## Final damage goes through CombatManager so upgrades can change it.

@export var damage: float = 10.0
@export var team: String = "player"

var source: Node
var already_hit: Array = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func set_active(active: bool) -> void:
	if active:
		already_hit.clear()
	set_deferred("monitoring", active)


func _on_area_entered(area: Area3D) -> void:
	if not area.has_method("receive_hit"):
		return
	if area.team == team or area in already_hit:
		return
	already_hit.append(area)
	# A projectile can outlive the enemy that shot it: then there is no attacker any more (null), the damage still counts.
	var attacker: Node = source if is_instance_valid(source) else null
	var target_health: Node = area.get_parent().get_node_or_null("HealthComponent")
	var final_damage: float = CombatManager.calculate_damage(damage, attacker, target_health)
	if team == "enemy": # later biomes hit harder
		var run_manager := get_tree().get_first_node_in_group("run_manager")
		if run_manager:
			final_damage *= run_manager.enemy_damage_multiplier
	area.receive_hit(final_damage, attacker)
	CombatManager.after_hit(attacker, target_health)
	if team == "player": # the player's hits get a thud and sparks (hits on the player: see Player._on_damaged)
		AudioManager.play_sfx("hit")
		VFX.hit_spark(area.global_position + Vector3(0.0, 1.0, 0.0))
