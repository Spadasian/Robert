extends "res://scripts/player/skills/PlayerSkill.gd"
## The charge of an Ultimate (E), shared by every character. It has no cooldown: it charges only from KILLS (a plain
## hit gives nothing, unless an upgrade raises the stat "ultimate_hit_charge") and can be used when the meter is full.
## The skill of each character extends this and does its own thing in _start().

signal charge_changed(charge: float, maximum: float)

@export var max_charge: float = 100.0
@export var charge_per_hit: float = 0.0 # a hit that does not kill; upgrades add to it with "ultimate_hit_charge"
@export var charge_per_kill: float = 6.0
@export var duration: float = 3.5

var charge: float = 0.0
var time_active: float = 0.0
var duration_bonus: float = 0.0
var charge_locked: bool = false # Silent Night: the Ultimate does not charge


func _ready() -> void:
	super._ready()
	cooldown = 0.0


func is_available() -> bool:
	return charge >= max_charge


func add_charge(amount: float) -> void:
	if is_active or charge_locked or amount <= 0.0:
		return # no recharging while it runs
	charge = minf(charge + amount * player.stats.get_stat("ultimate_charge"), max_charge)
	charge_changed.emit(charge, max_charge)


## Spirit Lantern: kills during the Ultimate keep it going a little longer.
func extend_time(seconds: float) -> void:
	if is_active:
		duration_bonus += seconds


func on_player_hit_dealt(target_killed: bool) -> void:
	if target_killed:
		add_charge(charge_per_kill)
	else:
		add_charge(charge_per_hit + player.stats.get_stat("ultimate_hit_charge"))


## Call at the start of the skill: the meter empties and the Kata hears that the Ultimate began.
func spend_charge() -> void:
	charge = 0.0
	charge_changed.emit(charge, max_charge)
	time_active = 0.0
	duration_bonus = 0.0
	player.kata_events.skill_resolved.emit(self)


func get_unavailable_ratio() -> float:
	if is_active:
		return 0.0
	return 1.0 - charge / max_charge


func get_status_text() -> String:
	if is_active:
		return "%.1f" % maxf(duration - time_active, 0.0)
	return "READY" if charge >= max_charge else "%d%%" % int(charge / max_charge * 100.0)
