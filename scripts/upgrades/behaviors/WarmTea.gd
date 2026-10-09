extends RuleBehavior
## Entering a Shop heals, once per biome (the first Shop you enter in it).

var used_in_biome: bool = false


func on_biome_started(_index: int) -> void:
	used_in_biome = false


func on_room_entered(room_type: int) -> void:
	if room_type == RoomData.RoomType.SHOP and not used_in_biome:
		used_in_biome = true
		host.heal_percent(p("ratio", 0.15))
