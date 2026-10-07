class_name RoomData
extends Resource
## Describes one room: its type, scene and difficulty. The run generator picks from these.

# START is last so the numbers of the older types never change.
enum RoomType { COMBAT, ELITE, TREASURE, SHOP, EVENT, SHRINE, BOSS, START }

@export var id: String = ""
@export var display_name: String = ""
@export var room_type: RoomType = RoomType.COMBAT
@export var scene: PackedScene
@export var difficulty: int = 1
@export var reward_gold: int = 10
