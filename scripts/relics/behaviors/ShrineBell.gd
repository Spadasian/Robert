extends RuleBehavior
## Boss and mini-boss rooms start with the Kata open and full of Flow.


func on_room_entered(room_type: int) -> void:
	if room_type == RoomData.RoomType.BOSS or room_type == RoomData.RoomType.MINIBOSS:
		host.player.kata.force_open(1.0)
