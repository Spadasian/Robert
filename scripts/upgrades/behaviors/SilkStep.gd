extends RuleBehavior
## Yume: after a Perfect Dodge the enemies lose sight of you for a while.


func on_perfect_dodge(_source: Node) -> void:
	host.hide_player(p("time", 1.0))
