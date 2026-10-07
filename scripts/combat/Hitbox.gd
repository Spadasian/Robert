extends Area3D
## Deals damage to any Hurtbox it touches (once per activation). Ignores same-team hurtboxes.
## Final damage goes through CombatManager so upgrades can change it.

@export var damage: float = 10.0
@export var team: String = "player"
## What kind of attack this is, for the Kata: "light", "heavy" or "skill" (empty for enemies).
@export var kind: String = ""
## Set by Kata finishers for one swing: the next hits are critical / kill targets below this health ratio.
var force_crit: bool = false
var execute_below: float = 0.0

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
	var was_crit: bool = CombatManager.last_hit_was_crit
	if force_crit and not was_crit:
		final_damage *= CombatManager.CRIT_MULTIPLIER
		was_crit = true
	if execute_below > 0.0 and target_health and target_health.current_health <= target_health.max_health * execute_below:
		final_damage = maxf(final_damage, target_health.current_health)
	area.receive_hit(final_damage, attacker)
	var info: Dictionary = {"target": area.get_parent(), "damage": final_damage, "crit": was_crit, "kind": kind, "hit_count": already_hit.size()}
	CombatManager.after_hit(attacker, target_health, info)
	if team == "player": # the player's hits get a thud and sparks (hits on the player: see Player._on_damaged)
		AudioManager.play_sfx("hit")
		VFX.hit_spark(area.global_position + Vector3(0.0, 1.0, 0.0))
