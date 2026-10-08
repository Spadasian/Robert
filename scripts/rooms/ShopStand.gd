extends Area3D
## One item for sale in the shop. Stand next to it and press F (action "interact") to buy.
## ShopRoom calls setup() with an UpgradeData; unused stands are switched off with disable().

# Price in gold per rarity. Order matches UpgradeData.Rarity: COMMON, RARE, EPIC, LEGENDARY, CURSED.
const PRICES: Array[int] = [30, 50, 80, 120, 40]
# Kata techniques cost more than any ordinary item. Order matches UpgradeData.Rarity.
const TECHNIQUE_PRICES: Array[int] = [150, 180, 220, 300, 300]
const COLOR_AFFORD: Color = Color(1.0, 1.0, 1.0)
const COLOR_TOO_EXPENSIVE: Color = Color(1.0, 0.4, 0.4)
const COLOR_SOLD: Color = Color(0.6, 0.6, 0.6)

@onready var visual: MeshInstance3D = $Visual
@onready var info_label: Label3D = $InfoLabel
@onready var price_label: Label3D = $PriceLabel

var upgrade: Resource = null
var price: int = 0
var sold: bool = false
var player_near: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Hidden until ShopRoom gives it an item.
	visible = false
	set_deferred("monitoring", false)


func setup(data: Resource) -> void:
	upgrade = data
	var is_technique: bool = data is TechniqueData
	var is_relic: bool = data is RelicData
	if is_relic:
		price = _discounted(data.price)
	else:
		price = _discounted(TECHNIQUE_PRICES[data.rarity] if is_technique else PRICES[data.rarity])
	sold = false

	var color: Color = data.color if (is_technique or is_relic) else data.get_color()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.6
	visual.material_override = material

	info_label.text = "%s\n%s" % [data.display_name, data.description]
	if is_relic:
		info_label.text = "RELIC\n%s\n%s" % [data.display_name, data.description]
	if is_technique:
		info_label.text = "KATA - %s\n%s\n%s" % [data.get_category_name().to_upper(), data.display_name, data.description]
		var old: Resource = _kata().get_technique(data.category) if _kata() else null
		if old:
			info_label.text += "\nReplaces: %s" % old.display_name
	info_label.modulate = color

	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager and not run_manager.gold_changed.is_connected(_on_gold_changed):
		run_manager.gold_changed.connect(_on_gold_changed)

	visible = true
	set_deferred("monitoring", true)
	_refresh_price_label()


## Relics such as the Black Pearl lower every price (stat shop_discount).
func _discounted(base_price: int) -> int:
	var player := get_tree().get_first_node_in_group("player")
	var discount: float = 0.0
	if player:
		discount = player.get_node("StatsComponent").get_stat("shop_discount")
	return maxi(1, roundi(base_price * (1.0 - clampf(discount, 0.0, 0.9))))


func disable() -> void:
	visible = false
	set_deferred("monitoring", false)


func _unhandled_input(event: InputEvent) -> void:
	if player_near and not sold and upgrade != null and event.is_action_pressed("interact"):
		_try_buy()
		get_viewport().set_input_as_handled()


func _try_buy() -> void:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var upgrade_manager := get_tree().get_first_node_in_group("upgrade_manager")
	var hud := get_tree().get_first_node_in_group("hud")
	if run_manager == null or upgrade_manager == null:
		return
	if upgrade is TechniqueData and _kata() == null:
		return
	if not run_manager.spend_gold(price):
		if hud:
			hud.show_message("Not enough gold")
		return
	var color: Color = upgrade.color if (upgrade is TechniqueData or upgrade is RelicData) else upgrade.get_color()
	if upgrade is TechniqueData:
		_kata().set_technique(upgrade)
	elif upgrade is RelicData:
		run_manager.add_relic(upgrade)
	else:
		upgrade_manager.apply_upgrade(upgrade)
	AudioManager.play_sfx("buy")
	VFX.sparkle(global_position + Vector3(0.0, 1.2, 0.0), color)
	sold = true
	visual.visible = false
	info_label.visible = false
	if hud:
		hud.show_message("%s bought" % upgrade.display_name)
	_refresh_price_label()


func _kata() -> Node:
	var player := get_tree().get_first_node_in_group("player")
	return player.get_node_or_null("KataComponent") if player else null


func _refresh_price_label() -> void:
	if sold:
		price_label.text = "SOLD"
		price_label.modulate = COLOR_SOLD
		_update_prompt()
		return
	var prompt: String = "[F]  " if player_near else ""
	price_label.text = "%s%d gold" % [prompt, price]
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var can_afford: bool = run_manager != null and run_manager.gold >= price
	price_label.modulate = COLOR_AFFORD if can_afford else COLOR_TOO_EXPENSIVE
	_update_prompt()


## The same hint on the HUD, big enough to read: "[F]  Buy Blood Edge  -  30 gold".
func _update_prompt() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	if player_near and not sold and upgrade != null:
		var run_manager := get_tree().get_first_node_in_group("run_manager")
		var can_afford: bool = run_manager != null and run_manager.gold >= price
		hud.show_prompt(self, "[F]  Buy %s  -  %d gold" % [upgrade.display_name, price], COLOR_AFFORD if can_afford else COLOR_TOO_EXPENSIVE)
	else:
		hud.hide_prompt(self)


func _exit_tree() -> void:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	if hud:
		hud.hide_prompt(self)


func _on_gold_changed(_gold: int) -> void:
	if not is_inside_tree():
		return # the shop room was left and is kept out of the scene tree; it refreshes when entered again
	_refresh_price_label()


func _enter_tree() -> void:
	if is_node_ready():
		_refresh_price_label() # coming back to a shop room: the gold may have changed


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = true
		_refresh_price_label()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false
		_refresh_price_label()
