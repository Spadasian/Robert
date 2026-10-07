extends "res://scripts/rooms/Interactable.gd"
## One item for sale in the shop: an upgrade (set by ShopRoom) or a heal.

enum ItemType { UPGRADE, HEAL }

# Price by rarity: Common, Rare, Epic, Legendary, Cursed
const PRICE_BY_RARITY: Array[int] = [20, 35, 60, 100, 45]

@export var item_type: ItemType = ItemType.UPGRADE
@export var heal_amount: float = 30.0
@export var heal_price: int = 15

var upgrade: Resource
var price: int = 0
var sold: bool = false

@onready var item_label: Label3D = $ItemLabel
@onready var orb: MeshInstance3D = $Orb


func _ready() -> void:
	super._ready()
	orb.material_override = orb.get_active_material(0).duplicate()
	if item_type == ItemType.HEAL:
		price = heal_price
		_set_orb_color(Color(0.3, 0.9, 0.4))
	_update_labels()


func setup_upgrade(new_upgrade: Resource) -> void:
	upgrade = new_upgrade
	price = PRICE_BY_RARITY[upgrade.rarity]
	_set_orb_color(upgrade.get_color())
	_update_labels()


func disable_empty() -> void:
	sold = true
	orb.visible = false
	set_enabled(false)
	item_label.text = ""


func get_prompt_text() -> String:
	return "Buy for %d gold" % price


func _interact() -> void:
	if sold:
		return
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var hud := get_tree().get_first_node_in_group("hud")
	if not run_manager.spend_gold(price):
		if hud:
			hud.show_message("Not enough gold")
		return
	var player := get_tree().get_first_node_in_group("player")
	if item_type == ItemType.UPGRADE:
		get_tree().get_first_node_in_group("upgrade_manager").apply_upgrade(upgrade)
		if hud:
			hud.show_message("%s acquired" % upgrade.display_name)
	else:
		player.get_node("HealthComponent").heal(heal_amount)
		if hud:
			hud.show_message("Healed %d HP" % int(heal_amount))
	sold = true
	orb.visible = false
	set_enabled(false)
	item_label.text = "SOLD"


func _set_orb_color(color: Color) -> void:
	var material := orb.material_override as StandardMaterial3D
	material.albedo_color = color
	material.emission = color


func _update_labels() -> void:
	if item_type == ItemType.HEAL:
		item_label.text = "Healing\n+%d HP\n%d gold" % [int(heal_amount), price]
		item_label.modulate = Color(0.5, 1.0, 0.6)
	elif upgrade:
		item_label.text = "%s\n%s\n%d gold" % [upgrade.display_name, upgrade.description, price]
		item_label.modulate = upgrade.get_color()
