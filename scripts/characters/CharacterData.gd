class_name CharacterData
extends Resource
## A playable character: its stats, its passive and its look. Written by tools/content/generate_characters.py from
## design/KUROTSUKI_Personaje.xlsx. Every character has a basic attack (LMB) and four skills (RMB, Shift, Q, E);
## all of them share the same Kata. A skill that is not listed in `skill_scenes` stays the one in Player.tscn.

@export var id: String = ""
@export var display_name: String = ""
@export var role: String = "" # short title: "Ronin duelist"
@export_multiline var description: String = ""
@export var color: Color = Color(1, 1, 1) # placeholder colour of the body until the 3D model exists
@export var weapon: String = ""
## The 3D model of the weapon (a .glb in art/weapons, Y-up, in metres) and where it sits on the swing pivot of the
## basic attack: position, rotation (degrees) and scale. The model is turned so its tip points forward (+Z).
@export var weapon_scene: PackedScene
@export var weapon_position: Vector3 = Vector3(0.0, 0.0, 0.9)
@export var weapon_rotation: Vector3 = Vector3(90.0, 0.0, 0.0)
@export var weapon_scale: float = 1.0
## The basic attack (LMB) of this character. Keys (all optional): cooldown, swing_time, arc (degrees), reach,
## hits (cuts per press), hit_gap (seconds between the cuts), damage_ratio (of attack_damage, per cut), color.
@export var attack: Dictionary = {}
@export var implemented: bool = true # false: shown on the select screen but cannot be chosen yet

## Stats that differ from StatsComponent.base_stats: stat name -> value.
@export var stats: Dictionary = {}

## The passive (one per character): stat effects (UpgradeEffect) and/or a RuleBehavior with its numbers.
@export var passive_name: String = ""
@export_multiline var passive_text: String = ""
@export var passive_effects: Array[Resource] = []
@export var passive_behavior: Script
@export var passive_params: Dictionary = {}
@export var cursed_unlocked: bool = false # Born Cursed: the Cursed upgrades are offered from the start

## Slot ("lmb", "rmb", "shift", "q", "e") -> name shown on the select screen.
@export var skill_names: Dictionary = {}
## Slot ("rmb", "shift", "q", "e") -> PackedScene of a skill that replaces the default one of Player.tscn.
@export var skill_scenes: Dictionary = {}

const SLOT_ORDER: Array[String] = ["lmb", "rmb", "shift", "q", "e"]
const SLOT_LABELS: Dictionary = {"lmb": "LMB", "rmb": "RMB", "shift": "SHIFT", "q": "Q", "e": "E"}
## The stats shown on the select screen: name, label.
const SUMMARY_STATS: Array = [["max_health", "HP"], ["attack_damage", "Damage"], ["attack_speed", "Attack speed"], ["move_speed", "Speed"]]


## `id` and `params` make a character passive work like any item with a rule (RuleHost.add_behavior reads these).
var behavior: Script:
	get: return passive_behavior
var params: Dictionary:
	get: return passive_params
