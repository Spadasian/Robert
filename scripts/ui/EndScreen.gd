extends CanvasLayer
## Shown when the run ends: defeat (the player died) or victory (the exit of the boss room was reached).
## Pauses the game and offers a new run. Its process mode is "Always" so the buttons work while paused.

const DEATH_DELAY: float = 1.2 # lets the death animation play before the screen appears
const INPUT_DELAY: float = 0.8 # ignores keys for a moment so a mashed key cannot restart by accident

@onready var title_label: Label = $Center/Box/Title
@onready var subtitle_label: Label = $Center/Box/Subtitle
@onready var stats_label: Label = $Center/Box/Columns/StatsBox/Stats
@onready var shards_label: Label = $Center/Box/Columns/StatsBox/Shards
@onready var play_again_button: Button = $Center/Box/Buttons/PlayAgain
@onready var main_menu_button: Button = $Center/Box/Buttons/MainMenu
@onready var quit_button: Button = $Center/Box/Buttons/Quit

var shown: bool = false
var accepts_input: bool = false
var restarting: bool = false
var shards_earned: int = 0


func _ready() -> void:
	add_to_group("end_screen")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	play_again_button.pressed.connect(_restart)
	main_menu_button.pressed.connect(_go_to_menu)
	quit_button.pressed.connect(_quit)
	MetaProgression.shards_changed.connect(_on_shards_changed)

	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.get_node("HealthComponent").died.connect(_on_player_died)
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager:
		room_manager.run_completed.connect(_on_run_completed)


func _on_player_died() -> void:
	await get_tree().create_timer(DEATH_DELAY).timeout
	if not shown:
		AudioManager.play_sfx("defeat")
	_show("YOU DIED", "The night claims another soul.", Color(0.85, 0.15, 0.2))


func _on_run_completed() -> void:
	if not shown:
		AudioManager.play_sfx("victory")
	_show("VICTORY", "Lord Kageyama has fallen.", Color(0.95, 0.8, 0.3))


func show_abandoned() -> void:
	_show("RUN ABANDONED", "You walked away from the night.", Color(0.7, 0.7, 0.8))


func _on_shards_changed(_total: int) -> void:
	if shown:
		_refresh_shards() # after buying something in the shrine


func _show(title: String, subtitle: String, color: Color) -> void:
	if shown:
		return
	shown = true
	AudioManager.stop_music(1.2)
	AudioManager.stop_ambience(1.2)
	title_label.text = title
	title_label.add_theme_color_override("font_color", color)
	subtitle_label.text = subtitle
	stats_label.text = _build_stats()
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		shards_earned = MetaProgression.finish_run(run_manager)
	_refresh_shards()
	visible = true
	get_tree().paused = true
	play_again_button.grab_focus()
	await get_tree().create_timer(INPUT_DELAY).timeout
	accepts_input = true


func _refresh_shards() -> void:
	shards_label.text = "Soul Shards: +%d\nTotal: %d" % [shards_earned, MetaProgression.soul_shards]



func _build_stats() -> String:
	var lines: Array[String] = []
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		lines.append("Mode: %s" % run_manager.mode_name)
		lines.append("Bosses defeated: %d / %d" % [run_manager.bosses_defeated, run_manager.biome_count])
		lines.append("Level reached: %d" % run_manager.level)
		lines.append("Rooms cleared: %d" % run_manager.rooms_cleared)
		lines.append("Enemies defeated: %d" % run_manager.enemies_defeated)
		lines.append("Gold earned: %d" % run_manager.gold_earned)
		lines.append("Time: %s" % _format_time(run_manager.elapsed_time))
	var player := get_tree().get_first_node_in_group("player")
	if player:
		lines.append("Upgrades: %d" % player.get_node("StatsComponent").upgrades.size())
	return "\n".join(lines)


func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not accepts_input:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_restart()


func _restart() -> void:
	if restarting:
		return
	restarting = true
	GameManager.start_run()


func _go_to_menu() -> void:
	if restarting:
		return
	restarting = true
	GameManager.go_to_menu()


func _quit() -> void:
	GameManager.quit_game()
