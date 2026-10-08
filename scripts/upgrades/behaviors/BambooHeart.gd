extends RuleBehavior
## Clearing a fight room heals.


func on_room_cleared(_room_type: int) -> void:
	host.heal_percent(p("ratio", 0.1))
