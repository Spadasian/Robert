extends RuleBehavior
## A Perfect Dodge gives a shield.


func on_perfect_dodge(_source: Node) -> void:
	host.add_shield(p("amount", 20.0))
	host.show_text("SHIELD", Color(0.5, 0.9, 1.0))
