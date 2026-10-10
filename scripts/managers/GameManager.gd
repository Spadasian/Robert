extends Node
## Switches between the main menu and a run. Autoload "GameManager".
## Run scenes (RunManager, RoomManager...) are thrown away on every switch; permanent progress lives in MetaProgression.

const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"
const CHARACTER_SELECT_SCENE: String = "res://scenes/ui/CharacterSelect.tscn"
const CHARACTER_PATHS: Array[String] = [
	"res://resources/characters/kazuma.tres", "res://resources/characters/yume.tres",
	"res://resources/characters/takeda.tres", "res://resources/characters/kurotsuki.tres",
]
const RUN_SCENE: String = "res://scenes/world/Run.tscn"
const STANDARD_MODE: Resource = preload("res://resources/modes/standard.tres")
const QUICK_MODE: Resource = preload("res://resources/modes/quick.tres")

## The mode of the current (or last) run. "Play again" starts the same mode.
var run_mode: Resource = STANDARD_MODE


## The character of the current (or last) run. null = plain base stats (a Run scene started straight from the editor
## or by a test). "Play again" starts the same character.
var selected_character: Resource = null


## Menu: a mode was picked, now the player picks the character.
func open_character_select(mode: Resource) -> void:
	run_mode = mode
	_change_scene(CHARACTER_SELECT_SCENE)


func get_characters() -> Array:
	var characters: Array = []
	for path in CHARACTER_PATHS:
		characters.append(load(path))
	return characters


func start_run(mode: Resource = null, character: Resource = null) -> void:
	if mode != null:
		run_mode = mode
	if character != null:
		selected_character = character
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
