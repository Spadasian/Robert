extends "res://scripts/rooms/Room.gd"
## A Duel with a master: one strong opponent (Duelist, a MiniBoss with a duel variant) in a small arena.
## Winning teaches a Kata technique (1 of 3). Winning without being hit also offers a Master technique.
## Optional room: the boss door does not wait for it.

var flawless: bool = true
var kata_events: Node


func start_room() -> void:
	super()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		kata_events = player.get_node("KataEvents")
		kata_events.damage_taken.connect(_on_player_hit)


func _on_player_hit(_amount: float) -> void:
	flawless = false


func _clear_room() -> void:
	if cleared:
		return
	var techniques := get_tree().get_first_node_in_group("technique_manager")
	if techniques:
		techniques.offer_pending = true # level ups wait for the reward
	if kata_events and kata_events.damage_taken.is_connected(_on_player_hit):
		kata_events.damage_taken.disconnect(_on_player_hit)
	super()
	_give_reward(techniques)


func _give_reward(techniques: Node) -> void:
	await get_tree().create_timer(1.2, false).timeout
	if techniques == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and player.get_node("HealthComponent").is_dead():
		techniques.offer_pending = false
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("FLAWLESS DUEL" if flawless else "DUEL WON", 2.0)
	var stats: Node = player.get_node("StatsComponent") if player else null
	var extra_cards: int = int(stats.get_stat("reward_cards")) if stats else 0
	var master_chance: float = stats.get_stat("master_chance") if stats else 0.0
	var with_master: bool = flawless or randf() < master_chance # a flawless duel always offers a Master
	techniques.offer([TechniqueData.Category.OPENING, TechniqueData.Category.FLOW, TechniqueData.Category.FINISHER], 3 + extra_cards, with_master)
