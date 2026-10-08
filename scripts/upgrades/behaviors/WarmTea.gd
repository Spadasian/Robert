extends RuleBehavior
## Entering a Shop or Treasure room heals.


func on_room_entered(room_type: int) -> void:
	if room_type == RoomData.RoomType.SHOP or room_type == RoomData.RoomType.TREASURE:
		host.heal_percent(p("ratio", 0.15))
