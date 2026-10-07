class_name RoomData
extends Resource
## Describes one room: its type, scene and difficulty. The run generator picks from these.

enum RoomType { COMBAT, ELITE, TREASURE, SHOP, EVENT, SHRINE, BOSS }

@export var id: String = ""
@export var display_name: String = ""
@export var room_type: RoomType = RoomType.COMBAT
@export var scene: PackedScene
@export var difficulty: int = 1
@export var reward_gold: int = 10
## Fight rooms give an upgrade choice when cleared; shop and treasure rooms do not.
@export var gives_upgrade_choice: bool = true
