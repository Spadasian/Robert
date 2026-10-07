extends VBoxContainer
## The list of permanent upgrades with their buy buttons. Used on the main menu and on the end screen.
## Rebuilds itself whenever MetaProgression.shards_changed fires (after a purchase or a finished run).


func _ready() -> void:
	MetaProgression.shards_changed.connect(_on_shards_changed)
	_rebuild()


func _on_shards_changed(_total: int) -> void:
	_rebuild()


func _rebuild() -> void:
	for old_row in get_children():
		remove_child(old_row)
		old_row.queue_free()
	for upgrade in MetaProgression.UPGRADES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var info := Label.new()
		info.custom_minimum_size = Vector2(300, 0)
		info.text = "%s  %d/%d\n%s" % [upgrade.display_name, MetaProgression.get_level(upgrade.id), upgrade.get_max_level(), upgrade.description]
		info.add_theme_font_size_override("font_size", 18)
		row.add_child(info)

		var button := Button.new()
		button.custom_minimum_size = Vector2(110, 44)
		var cost: int = MetaProgression.get_cost(upgrade)
		if cost < 0:
			button.text = "MAX"
			button.disabled = true
		else:
			button.text = "Buy  %d" % cost
			button.disabled = not MetaProgression.can_buy(upgrade)
			button.pressed.connect(_on_buy_pressed.bind(upgrade))
		row.add_child(button)
		add_child(row)


func _on_buy_pressed(upgrade: Resource) -> void:
	if MetaProgression.buy(upgrade): # shards_changed then rebuilds the list
		AudioManager.play_sfx("buy")
