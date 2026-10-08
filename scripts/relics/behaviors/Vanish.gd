extends RuleBehavior
## A Perfect Dodge makes you invisible for a moment: the enemies start no new attacks.


func on_perfect_dodge(_source: Node) -> void:
	host.hide_player(p("time", 0.8))
	host.show_text("VANISH", Color(0.7, 0.6, 1.0))
