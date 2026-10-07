class_name BiomeData
extends Resource
## One biome = one dungeon: how many rooms of each type it has, how hard the enemies are and how it looks.
## A run mode (RunModeData) is a list of biomes; the boss of a biome leads to the next one.

@export var display_name: String = "Biome"
@export var grid_size: Vector2i = Vector2i(5, 4)
@export var combat_rooms: int = 4
@export var elite_rooms: int = 1
@export var treasure_rooms: int = 1
@export var shop_rooms: int = 1
@export var miniboss_rooms: int = 1 # one per biome; a required room (the boss door waits for it)
@export var duel_rooms: int = 0 # special rooms are optional
@export var arena_rooms: int = 0
@export var event_rooms: int = 0
@export var shrine_rooms: int = 0
## Enemies of this biome: their health and the damage they deal are multiplied by these.
@export var enemy_health_multiplier: float = 1.0
@export var enemy_damage_multiplier: float = 1.0
## The look of the biome (sky colour, ambient light, sun).
@export var background_color: Color = Color(0.04, 0.03, 0.07)
@export var ambient_color: Color = Color(0.45, 0.4, 0.6)
@export var sun_color: Color = Color(1.0, 1.0, 1.0)


## RoomData.RoomType -> how many rooms of that type (START and BOSS are always added by the generator).
func get_room_counts() -> Dictionary:
	return {
		RoomData.RoomType.COMBAT: combat_rooms, RoomData.RoomType.ELITE: elite_rooms,
		RoomData.RoomType.TREASURE: treasure_rooms, RoomData.RoomType.SHOP: shop_rooms,
		RoomData.RoomType.EVENT: event_rooms, RoomData.RoomType.SHRINE: shrine_rooms,
		RoomData.RoomType.MINIBOSS: miniboss_rooms, RoomData.RoomType.DUEL: duel_rooms, RoomData.RoomType.ARENA: arena_rooms,
	}
