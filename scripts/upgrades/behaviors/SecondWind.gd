extends RuleBehavior
## After a Finisher the Kata opens again.


func on_finisher(_context: Dictionary) -> void:
	# the Kata closes right after this event, so reopen it a moment later
	host.get_tree().create_timer(0.05, false).timeout.connect(func(): host.player.kata.force_open(p("flow", 0.3)))
