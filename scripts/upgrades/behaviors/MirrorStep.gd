extends RuleBehavior
## A Perfect Dodge gives the dash charge back.


func on_perfect_dodge(_source: Node) -> void:
	var dash: Node = host.player.dash
	dash.charges = mini(dash.charges + 1, dash.max_charges)
