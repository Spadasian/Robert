extends CanvasLayer
## Esc pauses the game (action "pause"). Resume, abandon the run (it ends like a defeat, shards are still earned) or quit.
## It does not open while another screen already paused the game (upgrade choice, end screen).

@onready var resume_button: Button = $Center/Box/Resume
@onready var abandon_button: Button = $Center/Box/Abandon
@onready var quit_button: Button = $Center/Box/Quit

var is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(close)
	abandon_button.pressed.connect(_abandon)
	quit_button.pressed.connect(GameManager.quit_game)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_open:
		close()
		get_viewport().set_input_as_handled()
	elif _can_open():
		open()
		get_viewport().set_input_as_handled()


func _can_open() -> bool:
	if get_tree().paused:
		return false # the upgrade choice or the end screen is already showing
	var end_screen := get_tree().get_first_node_in_group("end_screen")
	if end_screen and end_screen.shown:
		return false
	var player := get_tree().get_first_node_in_group("player")
	if player and player.get_node("HealthComponent").is_dead():
		return false
	return true


func open() -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()


func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false


func _abandon() -> void:
	is_open = false
	visible = false
	var end_screen := get_tree().get_first_node_in_group("end_screen")
	if end_screen:
		end_screen.show_abandoned() # keeps the game paused and shows the shards
	else:
		GameManager.go_to_menu()
