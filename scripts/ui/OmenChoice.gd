extends CanvasLayer
## Shows the omens of an Arena as cards and pauses the game until one is chosen (click, or keys 1 / 2 / 3).
## Usage: var omen = await omen_choice.choose(list_of_omen_dictionaries)  (see ArenaRoom.OMENS)

signal omen_chosen(omen: Dictionary)

@onready var card_row: HBoxContainer = $Center/VBox/CardRow

var current_choices: Array = []


func _enter_tree() -> void:
	add_to_group("omen_choice")


func _ready() -> void:
	visible = false


func choose(omens: Array) -> Dictionary:
	current_choices = omens
	for old_card in card_row.get_children():
		card_row.remove_child(old_card)
		old_card.queue_free()
	for index in omens.size():
		card_row.add_child(_make_card(omens[index], index))
	visible = true
	get_tree().paused = true
	var chosen: Dictionary = await omen_chosen
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


func _select(omen: Dictionary) -> void:
	if visible:
		AudioManager.play_sfx("upgrade")
		omen_chosen.emit(omen)


func _make_card(omen: Dictionary, index: int) -> Button:
	var color: Color = omen.color
	var card := Button.new()
	card.custom_minimum_size = Vector2(280, 360)
	card.add_theme_stylebox_override("normal", _make_style(color, Color(0.1, 0.08, 0.14)))
	card.add_theme_stylebox_override("hover", _make_style(color, Color(0.22, 0.17, 0.3)))
	card.add_theme_stylebox_override("pressed", _make_style(color, Color(0.3, 0.22, 0.4)))
	card.add_theme_stylebox_override("focus", _make_style(color, Color(0.22, 0.17, 0.3)))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	box.add_child(_make_label(omen.name, 28, color))
	var text := _make_label(omen.text, 18, Color(0.8, 0.8, 0.85))
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text)
	box.add_child(_make_label("Reward: " + omen.reward, 17, Color(1.0, 0.85, 0.4)))
	box.add_child(_make_label("[%d]" % (index + 1), 18, Color(0.6, 0.6, 0.7)))
	card.pressed.connect(_select.bind(omen))
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
