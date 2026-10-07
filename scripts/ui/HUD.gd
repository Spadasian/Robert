extends CanvasLayer
## In-run HUD: health (with a damage trail, low-health vignette and hit flash), corruption with its thresholds,
## gold, dash charges, the upgrades taken, run progress, an interaction prompt, messages, the boss bar and the fade.

const LOW_HEALTH_RATIO: float = 0.3 # below this the screen edges pulse red
const TRAIL_DELAY: float = 0.35
const TRAIL_TIME: float = 0.4
const FLASH_ALPHA: float = 0.28

# Corruption bar colour for level 0..4 (below 25%, 25, 50, 75, 100).
const CORRUPTION_COLORS: Array[Color] = [
	Color(0.5, 0.25, 0.8), Color(0.62, 0.22, 0.8), Color(0.78, 0.2, 0.72), Color(0.9, 0.15, 0.5), Color(1.0, 0.1, 0.2),
]
# Dot colour per RoomData.RoomType: COMBAT, ELITE, TREASURE, SHOP, EVENT, SHRINE, BOSS.
const ROOM_COLORS: Array[Color] = [
	Color(0.8, 0.8, 0.88), Color(1.0, 0.6, 0.2), Color(1.0, 0.85, 0.3), Color(0.4, 0.9, 0.5),
	Color(0.6, 0.7, 1.0), Color(0.7, 0.5, 1.0), Color(0.9, 0.15, 0.2),
]

@onready var vignette: TextureRect = $Overlay/Vignette
@onready var hit_flash: ColorRect = $Overlay/HitFlash
@onready var hp_bar: ProgressBar = $StatusPanel/Box/HPBox/HPBar
@onready var hp_trail: ProgressBar = $StatusPanel/Box/HPBox/HPTrail
@onready var hp_label: Label = $StatusPanel/Box/HPBox/HPLabel
@onready var corruption_bar: ProgressBar = $StatusPanel/Box/CorruptionBox/CorruptionBar
@onready var corruption_label: Label = $StatusPanel/Box/CorruptionBox/CorruptionLabel
@onready var gold_label: Label = $StatusPanel/Box/GoldRow/GoldLabel
@onready var dash_box: HBoxContainer = $StatusPanel/Box/DashBox
@onready var upgrade_row: HFlowContainer = $StatusPanel/Box/UpgradeRow
@onready var minimap: Control = $ProgressBox/MiniMap
@onready var room_name_label: Label = $ProgressBox/RoomName
@onready var prompt_label: Label = $PromptLabel
@onready var message_label: Label = $MessageLabel
@onready var fade_rect: ColorRect = $Fade

var player_dead: bool = false
var message_serial: int = 0
var health_ratio: float = 1.0
var time: float = 0.0
var trail_tween: Tween
var flash_tween: Tween
var stats: Node
var shown_upgrades: int = 0
var skill_slots: Array = [] # one dictionary per skill: skill, cover, time_label, border
var dash: Node
var dash_pips: Array[ProgressBar] = []
var prompt_owner: Object = null
var boss_box: VBoxContainer
var boss_name_label: Label
var boss_bar: ProgressBar


func _ready() -> void:
	add_to_group("hud")
	message_label.visible = false
	prompt_label.visible = false
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var health: Node = player.get_node("HealthComponent")
	health.health_changed.connect(_on_health_changed)
	health.damaged.connect(_on_player_damaged)
	health.died.connect(_on_player_died)
	_on_health_changed(health.current_health, health.max_health)

	var corruption: Node = player.get_node("CorruptionComponent")
	corruption.corruption_changed.connect(_on_corruption_changed)
	_on_corruption_changed(corruption.value, corruption.level)

	var room_manager: Node = get_tree().get_first_node_in_group("room_manager")
	if room_manager:
		room_manager.map_changed.connect(_on_map_changed)
		room_manager.room_loaded.connect(_on_room_loaded)

	var run_manager: Node = get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.gold_changed.connect(_on_gold_changed)
		_on_gold_changed(run_manager.gold)

	stats = player.get_node("StatsComponent")
	stats.stats_changed.connect(_refresh_upgrades)
	if run_manager:
		run_manager.relics_changed.connect(_refresh_upgrades)
	_refresh_upgrades()

	dash = player.get_node("DashComponent")
	_build_skill_bar(player)


func _process(delta: float) -> void:
	time += delta
	_update_vignette()
	_update_dash_pips()
	_update_skill_bar()


# ---------------------------------------------------------------- health

func _on_health_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_trail.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d / %d" % [int(current), int(maximum)]
	health_ratio = current / maxf(maximum, 1.0)
	if trail_tween:
		trail_tween.kill()
	if current >= hp_trail.value:
		hp_trail.value = current # healing: the trail follows at once
	else:
		# Damage: the pale trail stays for a moment, then drains down to the real value.
		trail_tween = create_tween()
		trail_tween.tween_interval(TRAIL_DELAY)
		trail_tween.tween_property(hp_trail, "value", current, TRAIL_TIME)


func _on_player_damaged(_amount: float) -> void:
	if flash_tween:
		flash_tween.kill()
	hit_flash.color.a = FLASH_ALPHA
	flash_tween = create_tween()
	flash_tween.tween_property(hit_flash, "color:a", 0.0, 0.25)


func _update_vignette() -> void:
	var strength: float = 0.0
	if not player_dead and health_ratio <= LOW_HEALTH_RATIO:
		strength = 1.0 - health_ratio / LOW_HEALTH_RATIO # stronger the lower the health
		strength *= 0.65 + 0.35 * sin(time * 5.0) # slow pulse
	vignette.modulate.a = clampf(strength, 0.0, 1.0)


func _on_player_died() -> void:
	player_dead = true # the death screen itself is handled by EndScreen


# ---------------------------------------------------------------- corruption, gold, upgrades

func _on_corruption_changed(value: float, level: int) -> void:
	corruption_bar.value = value
	corruption_label.text = "Corruption %d%%" % int(value)
	var fill := corruption_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = CORRUPTION_COLORS[clampi(level, 0, CORRUPTION_COLORS.size() - 1)]


func _on_gold_changed(gold: int) -> void:
	gold_label.text = str(gold)


## One small tile per relic (first, thicker border) and per upgrade taken this run. Hover for name and description.
func _refresh_upgrades() -> void:
	if stats == null:
		return
	var run_manager: Node = get_tree().get_first_node_in_group("run_manager")
	var relics: Array = run_manager.relics if run_manager else []
	if relics.size() + stats.upgrades.size() == shown_upgrades:
		return
	for old_tile in upgrade_row.get_children():
		upgrade_row.remove_child(old_tile)
		old_tile.queue_free()
	for relic in relics:
		upgrade_row.add_child(_make_item_tile(relic, relic.color, 3, "Relic: %s\n%s" % [relic.display_name, relic.description]))
	for upgrade in stats.upgrades:
		var tooltip: String = "%s (%s)\n%s" % [upgrade.display_name, upgrade.get_rarity_name(), upgrade.description]
		upgrade_row.add_child(_make_item_tile(upgrade, upgrade.get_color(), 2, tooltip))
	shown_upgrades = relics.size() + stats.upgrades.size()


func _make_item_tile(item: Resource, border_color: Color, border_width: int, tooltip: String) -> Control:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(38.0, 38.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.9)
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	tile.add_theme_stylebox_override("panel", style)
	tile.tooltip_text = tooltip
	if item.icon:
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(icon)
	else:
		var label := Label.new() # until there is real icon art: the initials of the name
		label.text = _initials(item.display_name)
		label.add_theme_font_size_override("font_size", 14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(label)
	return tile


func _initials(upgrade_name: String) -> String:
	var result: String = ""
	for word in upgrade_name.split(" ", false):
		result += word[0].to_upper()
		if result.length() >= 2:
			break
	return result


# ---------------------------------------------------------------- run progress

## The minimap and "Cleared 3 / 7" under it. Called when a room is entered or cleared.
func _on_map_changed() -> void:
	var room_manager: Node = get_tree().get_first_node_in_group("room_manager")
	if room_manager == null or room_manager.current_room_data == null:
		return
	minimap.refresh(room_manager)
	var biome_text: String = ""
	if room_manager.biomes.size() > 1:
		biome_text = "Biome %d/%d   " % [room_manager.biome_index + 1, room_manager.biomes.size()]
	room_name_label.text = "%sCleared %d / %d   %s" % [biome_text, room_manager.rooms_done, room_manager.rooms_total, room_manager.current_room_data.display_name]


func _on_room_loaded(_room: Node) -> void:
	prompt_label.visible = false # a prompt from the room we just left
	prompt_owner = null


# ---------------------------------------------------------------- interaction prompt

## Bottom-centre hint such as "[F] Buy Blood Edge". Whoever shows it must hide it again with the same owner.
func show_prompt(owner: Object, text: String, color: Color = Color.WHITE) -> void:
	prompt_owner = owner
	prompt_label.text = text
	prompt_label.add_theme_color_override("font_color", color)
	prompt_label.visible = true


func hide_prompt(owner: Object) -> void:
	if prompt_owner == owner:
		prompt_label.visible = false
		prompt_owner = null


# ---------------------------------------------------------------- dash charges

## One bar per dash charge; the next one fills while it recharges. The row grows with upgrades such as Shadow Step.
func _update_dash_pips() -> void:
	if dash == null:
		return
	while dash_pips.size() < dash.max_charges:
		var pip := ProgressBar.new()
		pip.custom_minimum_size = Vector2(34.0, 12.0)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.max_value = 1.0
		pip.step = 0.01
		pip.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.3, 0.9, 0.9)
		pip.add_theme_stylebox_override("fill", fill)
		dash_box.add_child(pip)
		dash_pips.append(pip)
	for index in dash_pips.size():
		var pip: ProgressBar = dash_pips[index]
		pip.visible = index < dash.max_charges
		if index < dash.charges:
			pip.value = 1.0
		elif index == dash.charges:
			pip.value = clampf(1.0 - dash.recharge_left / dash.dash_cooldown, 0.0, 1.0)
		else:
			pip.value = 0.0


# ---------------------------------------------------------------- messages, fade, boss bar

func show_message(text: String, duration: float = 2.0) -> void:
	message_serial += 1
	var my_serial: int = message_serial
	message_label.text = text
	message_label.visible = true
	await get_tree().create_timer(duration).timeout
	if my_serial == message_serial:
		message_label.visible = false


func fade_out(duration: float = 0.25) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, duration)
	await tween.finished


func fade_in(duration: float = 0.25) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, duration)
	await tween.finished


## Boss health bar at the top centre. Built in code the first time a boss asks for it.
func show_boss_bar(boss_name: String, max_health: float) -> void:
	if boss_box == null:
		_build_boss_bar()
	boss_name_label.text = boss_name
	boss_bar.max_value = max_health
	boss_bar.value = max_health
	boss_box.visible = true


func update_boss_bar(current: float, maximum: float) -> void:
	if boss_bar == null:
		return
	boss_bar.max_value = maximum
	boss_bar.value = current


func hide_boss_bar() -> void:
	if boss_box:
		boss_box.visible = false


func _build_boss_bar() -> void:
	boss_box = VBoxContainer.new()
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.offset_left = -300.0
	boss_box.offset_right = 300.0
	boss_box.offset_top = 20.0
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_name_label = Label.new()
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 22)
	boss_box.add_child(boss_name_label)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(600.0, 22.0)
	boss_bar.show_percentage = false
	boss_bar.add_theme_stylebox_override("fill", _boss_fill_style())
	boss_box.add_child(boss_bar)
	add_child(boss_box)
	move_child(boss_box, fade_rect.get_index()) # keep the fade-to-black above it


func _boss_fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.75, 0.1, 0.15)
	return style


# ---------------------------------------------------------------- skill slots

const SLOT_SIZE: float = 68.0

## Bottom-centre slots for the player's skills (right click, Q, E). A dark cover shrinks while a skill recharges
## (for the ultimate it shrinks as the meter fills); the border turns gold when the skill is ready.
func _build_skill_bar(player: Node) -> void:
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -130.0
	box.offset_right = 130.0
	box.offset_top = -92.0
	box.offset_bottom = -20.0
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	move_child(box, fade_rect.get_index()) # keep the fade-to-black above it

	for skill in player.skills:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(slot)

		var panel := Panel.new()
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.07, 0.12, 0.85)
		style.set_border_width_all(3)
		style.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", style)
		slot.add_child(panel)

		var cover := ColorRect.new()
		cover.color = Color(0.0, 0.0, 0.0, 0.62)
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(cover)

		slot.add_child(_slot_label(skill.key_label, Vector2(6.0, 2.0), 15, HORIZONTAL_ALIGNMENT_LEFT))
		slot.add_child(_slot_label(skill.display_name, Vector2(0.0, SLOT_SIZE - 17.0), 10, HORIZONTAL_ALIGNMENT_CENTER))
		var time_label := _slot_label("", Vector2(0.0, 20.0), 18, HORIZONTAL_ALIGNMENT_CENTER)
		slot.add_child(time_label)

		skill_slots.append({"skill": skill, "cover": cover, "time_label": time_label, "style": style})


func _slot_label(text: String, position: Vector2, font_size: int, alignment: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.custom_minimum_size = Vector2(SLOT_SIZE, 0.0) if alignment == HORIZONTAL_ALIGNMENT_CENTER else Vector2.ZERO
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _update_skill_bar() -> void:
	for entry in skill_slots:
		var skill: PlayerSkill = entry["skill"]
		var ratio: float = skill.get_unavailable_ratio()
		var cover: ColorRect = entry["cover"]
		cover.position = Vector2.ZERO
		cover.size = Vector2(SLOT_SIZE, SLOT_SIZE * ratio)
		entry["time_label"].text = skill.get_status_text()
		var style: StyleBoxFlat = entry["style"]
		if skill.is_active:
			style.border_color = Color.WHITE
		elif skill.is_available():
			style.border_color = Color(1.0, 0.8, 0.3)
		else:
			style.border_color = Color(0.35, 0.35, 0.45)
