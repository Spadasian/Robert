extends Control
## Main menu: start a run, spend Soul Shards in the Soul Shrine, quit.

@onready var play_button: Button = $Center/Box/Play
@onready var quick_button: Button = $Center/Box/QuickRun
@onready var mode_info_label: Label = $Center/Box/ModeInfo
@onready var shrine_button: Button = $Center/Box/ShrineButton
@onready var quit_button: Button = $Center/Box/Quit
@onready var shards_label: Label = $Center/Box/Shards
@onready var shrine_overlay: Control = $ShrineOverlay
@onready var shrine_shards_label: Label = $ShrineOverlay/Center/Panel/Margin/Box/ShardsLabel
@onready var back_button: Button = $ShrineOverlay/Center/Panel/Margin/Box/Back
@onready var options_button: Button = $Center/Box/OptionsButton
@onready var options_overlay: Control = $OptionsOverlay
@onready var options_back_button: Button = $OptionsOverlay/Center/Panel/Margin/Box/Back


func _ready() -> void:
	shrine_overlay.visible = false
	options_overlay.visible = false
	AudioManager.play_music("music_menu")
	AudioManager.stop_ambience()
	options_button.pressed.connect(_open_options)
	options_back_button.pressed.connect(_close_options)
	play_button.pressed.connect(GameManager.open_character_select.bind(GameManager.STANDARD_MODE))
	quick_button.pressed.connect(GameManager.open_character_select.bind(GameManager.QUICK_MODE))
	for button_and_mode in [[play_button, GameManager.STANDARD_MODE], [quick_button, GameManager.QUICK_MODE]]:
		var mode: Resource = button_and_mode[1]
		button_and_mode[0].focus_entered.connect(func(): mode_info_label.text = mode.description)
		button_and_mode[0].mouse_entered.connect(func(): mode_info_label.text = mode.description)
	shrine_button.pressed.connect(_open_shrine)
	back_button.pressed.connect(_close_shrine)
	quit_button.pressed.connect(GameManager.quit_game)
	MetaProgression.shards_changed.connect(_on_shards_changed)
	_on_shards_changed(MetaProgression.soul_shards)
	play_button.grab_focus()


func _on_shards_changed(total: int) -> void:
	shards_label.text = "Soul Shards: %d" % total
	shrine_shards_label.text = "Soul Shards: %d" % total


func _open_shrine() -> void:
	shrine_overlay.visible = true
	back_button.grab_focus()


func _close_shrine() -> void:
	shrine_overlay.visible = false
	shrine_button.grab_focus()


func _open_options() -> void:
	options_overlay.visible = true
	options_back_button.grab_focus()


func _close_options() -> void:
	options_overlay.visible = false
	options_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if shrine_overlay.visible:
		_close_shrine()
		get_viewport().set_input_as_handled()
	elif options_overlay.visible:
		_close_options()
		get_viewport().set_input_as_handled()
