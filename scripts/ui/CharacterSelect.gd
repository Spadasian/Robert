extends Control
## The screen after the mode was chosen: one card per character (stats, passive, skills). Click a card (or press 1-4)
## to start the run with that character. A character that is not ready yet is shown but cannot be chosen.
## Esc or the Back button returns to the main menu. The whole screen is built here, from the CharacterData resources.

var cards: Array = []


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.04, 0.09)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := _label("CHOOSE YOUR CHARACTER", 40, Color(0.85, 0.15, 0.2))
	box.add_child(title)
	var mode_name: String = GameManager.run_mode.display_name if GameManager.run_mode else ""
	box.add_child(_label(mode_name, 20, Color(0.7, 0.7, 0.8)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var index := 0
	for character in GameManager.get_characters():
		var card := _make_card(character, index)
		row.add_child(card)
		cards.append(card)
		index += 1

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(200, 46)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(GameManager.go_to_menu)
	box.add_child(back)
	AudioManager.play_music("music_menu")
	for card in cards:
		if not card.disabled:
			card.grab_focus()
			break


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameManager.go_to_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.keycode - KEY_1
		if index >= 0 and index < cards.size() and not cards[index].disabled:
			cards[index].pressed.emit()
			get_viewport().set_input_as_handled()


func choose(character: Resource) -> void:
	AudioManager.play_sfx("ui_click")
	GameManager.start_run(null, character)


func _make_card(character: Resource, index: int) -> Button:
	var color: Color = character.color
	var card := Button.new()
	card.custom_minimum_size = Vector2(290, 520)
	card.disabled = not character.implemented
	card.add_theme_stylebox_override("normal", _style(color, Color(0.1, 0.08, 0.14)))
	card.add_theme_stylebox_override("hover", _style(color, Color(0.2, 0.16, 0.28)))
	card.add_theme_stylebox_override("pressed", _style(color, Color(0.28, 0.2, 0.38)))
	card.add_theme_stylebox_override("focus", _style(color, Color(0.2, 0.16, 0.28)))
	card.add_theme_stylebox_override("disabled", _style(color.darkened(0.6), Color(0.07, 0.06, 0.1)))
	card.pressed.connect(choose.bind(character))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)

	var dim: float = 1.0 if character.implemented else 0.5
	box.add_child(_label(character.display_name, 32, color.lightened(0.15) * Color(1, 1, 1, dim)))
	box.add_child(_label(character.role, 16, Color(0.8, 0.8, 0.85, dim)))
	box.add_child(_label(character.weapon, 15, Color(0.65, 0.65, 0.75, dim)))
	var stats_text := ""
	for pair in CharacterData.SUMMARY_STATS:
		stats_text += "%s  %s\n" % [pair[1], _stat_text(character, pair[0])]
	box.add_child(_label(stats_text.strip_edges(), 17, Color(0.95, 0.95, 1.0, dim)))
	box.add_child(_label("PASSIVE: " + character.passive_name, 17, Color(1.0, 0.85, 0.4, dim)))
	box.add_child(_label(character.passive_text, 14, Color(0.8, 0.8, 0.85, dim)))
	var skills_text := ""
	for slot in CharacterData.SLOT_ORDER:
		skills_text += "%s  %s\n" % [CharacterData.SLOT_LABELS[slot], character.skill_names.get(slot, "-")]
	box.add_child(_label(skills_text.strip_edges(), 14, Color(0.7, 0.8, 0.95, dim)))
	var footer: String = "[%d]" % (index + 1) if character.implemented else "Coming soon"
	box.add_child(_label(footer, 18, Color(0.6, 0.6, 0.7)))
	return card


## The stat of a character (its own value or the base one), as text.
func _stat_text(character: Resource, stat_name: String) -> String:
	var defaults: Node = preload("res://scripts/player/StatsComponent.gd").new()
	var base: float = defaults.base_stats.get(stat_name, 0.0)
	defaults.free()
	var value: float = float(character.stats.get(stat_name, base))
	return str(snappedf(value, 0.01))


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _style(border_color: Color, background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style
