class_name RunModeData
extends Resource
## A way to play: a list of biomes (Standard has several, Quick Run has one) and how many Soul Shards it pays.
## There is no timer: the run ends when the last boss falls or the player dies.

@export var id: String = ""
@export var display_name: String = "Run"
@export_multiline var description: String = ""
@export var biomes: Array[Resource] = [] # BiomeData resources, played in this order
@export var shard_multiplier: float = 1.0
