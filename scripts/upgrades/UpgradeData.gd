class_name UpgradeData
extends Resource
## A temporary run upgrade. Create new ones as .tres files, no code needed.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY, CURSED }

# Order matches the Rarity enum.
const RARITY_WEIGHTS: Array[float] = [60.0, 25.0, 10.0, 3.0, 8.0]
const RARITY_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.85), Color(0.35, 0.6, 1.0), Color(0.7, 0.4, 0.95),
	Color(1.0, 0.65, 0.15), Color(0.8, 0.1, 0.2),
]
const RARITY_NAMES: Array[String] = ["Common", "Rare", "Epic", "Legendary", "Cursed"]

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON
@export var effects: Array[Resource] = [] # UpgradeEffect resources
## A special rule (see RuleBehavior) with its numbers; empty for upgrades that only change stats.
@export var behavior: Script
@export var params: Dictionary = {}
## A style upgrade of one character (its id, e.g. "yume"): that character sees it about 3 times more often. Empty = for all.
@export var character: String = ""
@export var build: String = "" # which style of play it belongs to (for the lists, not used in the game)


func get_weight() -> float:
	return RARITY_WEIGHTS[rarity]


func get_color() -> Color:
	return RARITY_COLORS[rarity]


func get_rarity_name() -> String:
	return RARITY_NAMES[rarity]
