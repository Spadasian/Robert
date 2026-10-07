class_name TechniqueData
extends Resource
## A Kata technique. The Kata has one slot for each category: how it starts (Opening), how it builds up (Flow),
## how it ends (Finisher), and a rare Master technique that changes the rules. The behaviour is a small script
## (extends TechniqueBehavior); the numbers it uses live in `params`, so a new technique is a .tres + a script.

enum Category { OPENING, FLOW, FINISHER, MASTER }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.OPENING
@export var rarity: UpgradeData.Rarity = UpgradeData.Rarity.COMMON
@export var color: Color = Color(0.85, 0.85, 0.9)
@export var icon: Texture2D
@export var behavior: Script
@export var params: Dictionary = {}

const CATEGORY_NAMES: Array[String] = ["Opening", "Flow", "Finisher", "Master"]


func get_category_name() -> String:
	return CATEGORY_NAMES[category]
