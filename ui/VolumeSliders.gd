extends VBoxContainer
## Two sliders: music volume and effects volume. Used in the pause menu and in the main menu options.
## Changes apply at once; the save file is written a moment after the last change.

@onready var music_slider: HSlider = $MusicRow/Slider
@onready var sfx_slider: HSlider = $SfxRow/Slider

var save_timer: Timer


func _ready() -> void:
	music_slider.set_value_no_signal(AudioManager.music_volume)
	sfx_slider.set_value_no_signal(AudioManager.sfx_volume)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	sfx_slider.drag_ended.connect(_on_sfx_drag_ended)
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.6
	save_timer.timeout.connect(SaveManager.save_game)
	add_child(save_timer)


func _on_music_changed(value: float) -> void:
	AudioManager.set_music_volume(value)
	save_timer.start()


func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	save_timer.start()


func _on_sfx_drag_ended(_changed: bool) -> void:
	AudioManager.play_sfx("hit") # a sample at the new volume
