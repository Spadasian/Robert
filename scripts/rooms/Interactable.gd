extends Area3D
## Something the player can use by standing close and pressing F (shop item, chest...).
## Needs an optional child Label3D called "PromptLabel". Subclasses override _interact() and get_prompt_text().

signal interacted

@export var prompt: String = "Interact"

var player_in_range: bool = false
var enabled: bool = true

@onready var prompt_label: Label3D = get_node_or_null("PromptLabel")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_prompt()


func get_prompt_text() -> String:
	return prompt


func set_enabled(value: bool) -> void:
	enabled = value
	_refresh_prompt()


func _interact() -> void:
	interacted.emit()


func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and enabled and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_interact()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_refresh_prompt()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		_refresh_prompt()


func _refresh_prompt() -> void:
	if prompt_label == null:
		return
	prompt_label.visible = player_in_range and enabled
	prompt_label.text = "[F] " + get_prompt_text()
