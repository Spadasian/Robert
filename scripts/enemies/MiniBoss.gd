extends "res://scripts/enemies/Boss.gd"
## A mini-boss: the Boss.gd fight with one single phase, less health, and a MiniBossVariant that decides its name,
## look, speed and which attacks it uses. RoomManager picks the variant of the biome (miniboss_variant).

## True for the master of a Duel room: it uses the duel variant of the biome instead of the mini-boss one.
@export var duel: bool = false

var variant: Resource


func _ready() -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	variant = (room_manager.duel_variant if duel else room_manager.miniboss_variant) if room_manager else null
	if variant:
		_apply_variant()
	phase_two_ratio = 0.0 # a single phase
	super._ready()
	if variant:
		model.scale = Vector3.ONE * variant.model_scale
		base_color = variant.color
		body_material.albedo_color = base_color


func _apply_variant() -> void:
	boss_name = variant.display_name
	max_health *= variant.health_multiplier
	move_speed *= variant.speed_multiplier
	for property in ["combo_damage", "dash_damage", "shock_damage", "fan_damage", "leap_damage"]:
		set(property, get(property) * variant.damage_multiplier)
	for property in ["combo_windup", "combo_next_windup", "dash_windup", "shock_windup", "fan_windup", "leap_windup", "summon_windup"]:
		set(property, get(property) * variant.windup_multiplier)


func _near_options() -> Array:
	return variant.near_attacks if variant else [Attack.COMBO]


func _far_options() -> Array:
	return variant.far_attacks if variant else [Attack.DASH]
