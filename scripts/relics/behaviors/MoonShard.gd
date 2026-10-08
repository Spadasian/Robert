extends RuleBehavior
## Whatever opens the Kata, it starts with some Flow.


func on_kata_opened() -> void:
	var kata: Node = host.player.kata
	var missing: float = p("flow", 0.5) - kata.flow_value
	if missing > 0.0:
		kata.add_flow(missing / maxf(host.player.stats.get_stat("flow_gain"), 0.1))
