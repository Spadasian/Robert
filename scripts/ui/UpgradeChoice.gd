extends CanvasLayer
## Shows 3 upgrade cards and pauses the game until one is chosen (click, or keys 1 / 2 / 3).
## Usage: var chosen = await upgrade_choice.choose(list_of_UpgradeData)

signal upgrade_chosen(upgrade: Resource)

@onready var card_row: HBoxContainer = $Center/VBox/CardRow

var current_choices: Array = []


func _ready() -> void:
	visible = false


func choose(choices: Array) -> Resource:
	current_choices = choices
	for old_card in card_row.get_children():
		card_row.remove_child(old_card)
		old_card.queue_free()
	for index in choices.size():
		card_row.add_child(_make_card(choices[index], index))

	visible = true
	get_tree().paused = true
	var chosen: Resource = await upgrade_chosen
	get_tree().paused = false
	visible = false
	current_choices = []
	return chosen


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var index: int = event.keycode - KEY_1
	if index >= 0 and index < current_choices.size():
		_select(current_choices[index])
		get_viewport().set_input_as_handled()


func _select(upgrade: Resource) -> void:
	if visible:
		AudioManager.play_sfx("upgrade")
		upgrade_chosen.emit(upgrade)


func _make_card(upgrade: Resource, index: int) -> Button:
	var color: Color = upgrade.get_color()
	var card := Button.new()
	card.custom_minimum_size = Vector2(260, 340)
	card.add_theme_stylebox_override("normal", _make_style(color, Color(0.1, 0.08, 0.14)))
	card.add_theme_stylebox_override("hover", _make_style(color, Color(0.22, 0.17, 0.3)))
	card.add_theme_stylebox_override("pressed", _make_style(color, Color(0.3, 0.22, 0.4)))
	card.add_theme_stylebox_override("focus", _make_style(color, Color(0.22, 0.17, 0.3)))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)

	box.add_child(_make_label(upgrade.get_rarity_name().to_upper(), 16, color))
	if upgrade.icon:
		var icon := TextureRect.new()
		icon.texture = upgrade.icon
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.custom_minimum_size = Vector2(64, 64)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
	box.add_child(_make_label(upgrade.display_name, 28, Color.WHITE))
	var description := _make_label(upgrade.description, 20, Color(0.8, 0.8, 0.85))
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(description)
	box.add_child(_make_label("[%d]" % (index + 1), 18, Color(0.6, 0.6, 0.7)))

	card.pressed.connect(_select.bind(upgrade))
	return card


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_style(border_color: Color, background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style
