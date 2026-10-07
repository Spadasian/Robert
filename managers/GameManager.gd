extends Node
## Switches between the main menu and a run. Autoload "GameManager".
## Run scenes (RunManager, RoomManager...) are thrown away on every switch; permanent progress lives in MetaProgression.

const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"
const RUN_SCENE: String = "res://scenes/world/Run.tscn"


func start_run() -> void:
	_change_scene(RUN_SCENE)


func go_to_menu() -> void:
	_change_scene(MAIN_MENU_SCENE)


func quit_game() -> void:
	get_tree().quit()


func _change_scene(path: String) -> void:
	get_tree().paused = false
	var error: int = get_tree().change_scene_to_file(path)
	if error != OK:
		push_warning("GameManager: cannot load %s (error %d)" % [path, error])
