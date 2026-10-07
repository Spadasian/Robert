class_name RelicData
extends Resource
## A relic: a passive item for the whole run, found in treasure rooms. It has no button and no timer.
## Its effects are UpgradeEffect resources (the same ones upgrades use), applied through StatsComponent modifiers.
## Some effects need a stat that other scripts read (free_hits_per_room: Player, gold_gain: RunManager,
## shop_discount: ShopStand). New relic = new .tres in resources/relics/ + add it to RunManager.relic_pool in Run.tscn.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var color: Color = Color(1.0, 0.85, 0.4) # border of its tile in the HUD and its pedestal
@export var effects: Array[Resource] = [] # UpgradeEffect resources
