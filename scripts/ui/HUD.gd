extends CanvasLayer
## Minimal HUD for now: player HP bar and the death screen. Real HUD comes in Phase 19.

@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPBar/Label
@onready var death_label: Label = $DeathLabel
@onready var message_label: Label = $MessageLabel
@onready var fade_rect: ColorRect = $Fade
@onready var gold_label: Label = $GoldLabel
@onready var corruption_label: Label = $CorruptionLabel
@onready var room_label: Label = $RoomLabel

var player_dead: bool = false
var message_serial: int = 0


func _ready() -> void:
	add_to_group("hud")
	death_label.visible = false
	message_label.visible = false
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var health: Node = player.get_node("HealthComponent")
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_player_died)
	_on_health_changed(health.current_health, health.max_health)

	var corruption: Node = player.get_node("CorruptionComponent")
	corruption.corruption_changed.connect(_on_corruption_changed)
	_on_corruption_changed(corruption.value, corruption.level)

	var room_manager: Node = get_tree().get_first_node_in_group("room_manager")
	if room_manager:
		room_manager.room_changed.connect(_on_room_changed)

	var run_manager: Node = get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.gold_changed.connect(_on_gold_changed)
		_on_gold_changed(run_manager.gold)


func _on_health_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d / %d" % [int(current), int(maximum)]


func _on_gold_changed(gold: int) -> void:
	gold_label.text = "Gold: %d" % gold


func _on_corruption_changed(value: float, _level: int) -> void:
	corruption_label.text = "Corruption: %d%%" % int(value)


func _on_room_changed(index: int, total: int) -> void:
	room_label.text = "Room %d / %d" % [index + 1, total]


func _on_player_died() -> void:
	player_dead = true
	death_label.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if player_dead and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func show_message(text: String, duration: float = 2.0) -> void:
	message_serial += 1
	var my_serial: int = message_serial
	message_label.text = text
	message_label.visible = true
	await get_tree().create_timer(duration).timeout
	if my_serial == message_serial:
		message_label.visible = false


func fade_out(duration: float = 0.25) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, duration)
	await tween.finished


func fade_in(duration: float = 0.25) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, duration)
	await tween.finished
