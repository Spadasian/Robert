extends TechniqueBehavior
## Flow: builds fast while you are not hit, and the blade is quicker (+attack speed). The first hit you take wipes
## all the Flow and the speed bonus.

var effect: Resource


func on_open(kata: Node) -> void:
	_give_bonus(kata)


func on_event(kata: Node, event: String, payload: Dictionary) -> void:
	if event == "hit_dealt" and payload.get("kind", "") in ["light", "shuriken"] and payload.get("hit_count", 1) <= 1:
		kata.add_flow(param("gain_per_hit", 0.4))
	elif event == "damage_taken":
		kata.add_flow(-kata.flow_cap)
		_remove_bonus(kata)


func on_close(kata: Node, _reason: String) -> void:
	_remove_bonus(kata)


func _give_bonus(kata: Node) -> void:
	_remove_bonus(kata)
	var stats: Node = kata.get_parent().get_node_or_null("StatsComponent")
	if stats == null:
		return
	effect = UpgradeEffect.new()
	effect.stat = "attack_speed"
	effect.operation = UpgradeEffect.Operation.PERCENT
	effect.value = param("attack_speed", 0.25)
	stats.add_modifier(effect)


func _remove_bonus(kata: Node) -> void:
	if effect == null:
		return
	var stats: Node = kata.get_parent().get_node_or_null("StatsComponent")
	if stats:
		stats.remove_modifier(effect)
	effect = null
