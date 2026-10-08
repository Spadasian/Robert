extends RuleBehavior
## A shield that comes back in every room.


func setup() -> void:
	host.set_shield(maxf(host.shield, p("amount", 15.0)))


func on_room_entered(_room_type: int) -> void:
	host.set_shield(maxf(host.shield, p("amount", 15.0)))
