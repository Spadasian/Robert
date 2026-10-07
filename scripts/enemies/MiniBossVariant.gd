class_name MiniBossVariant
extends Resource
## One kind of mini-boss: its name, look, strength and which attacks it uses. The run picks a different variant for
## every biome (RoomManager), so the fight is not always the same. The attacks are the ones Boss.gd already has.
## Attack numbers: 0 COMBO, 1 DASH, 2 SHOCKWAVE, 3 FAN, 4 LEAP, 5 SUMMON.

@export var id: String = ""
@export var display_name: String = "Mini-boss"
@export var color: Color = Color(0.7, 0.2, 0.2)
@export var model_scale: float = 1.0
@export var health_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export var windup_multiplier: float = 1.0 # below 1.0 = faster, harder to read
@export var near_attacks: Array[int] = [0] # used when the player is close
@export var far_attacks: Array[int] = [1] # used when the player is far
@export_multiline var description: String = ""
