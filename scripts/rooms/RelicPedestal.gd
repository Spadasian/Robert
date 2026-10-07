extends Area3D
## One relic on offer in a treasure room. Stand next to it and press F (action "interact") to take it for free.
## Taking one makes the other pedestals disappear. TreasureRoom calls setup() with a RelicData.

signal taken

@onready var visual: MeshInstance3D = $Visual
@onready var info_label: Label3D = $InfoLabel
@onready var hint_label: Label3D = $HintLabel

var relic: Resource = null
var claimed: bool = false
var player_near: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	visible = false # hidden until TreasureRoom gives it a relic
	set_deferred("monitoring", false)


func setup(data: Resource) -> void:
	relic = data
	claimed = false
	var material := StandardMaterial3D.new()
	material.albedo_color = data.color
	material.emission_enabled = true
	material.emission = data.color
	material.emission_energy_multiplier = 0.8
	visual.material_override = material
	info_label.text = "%s\n%s" % [data.display_name, data.description]
	info_label.modulate = data.color
	hint_label.text = "Take"
	visible = true
	set_deferred("monitoring", true)


func disable() -> void:
	visible = false
	player_near = false
	set_deferred("monitoring", false)
	_hide_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if player_near and not claimed and relic != null and event.is_action_pressed("interact"):
		_take()
		get_viewport().set_input_as_handled()


func _take() -> void:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager == null:
		return
	claimed = true
	run_manager.add_relic(relic)
	AudioManager.play_sfx("relic")
	VFX.sparkle(global_position + Vector3(0.0, 1.2, 0.0), relic.color)
	VFX.shake(0.1, 0.2)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("%s acquired" % relic.display_name, 2.5)
	taken.emit() # TreasureRoom hides every pedestal, this one included


func _hide_prompt() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.hide_prompt(self)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not claimed:
		player_near = true
		hint_label.text = "[F]  Take"
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_prompt(self, "[F]  Take %s" % relic.display_name, relic.color.lightened(0.3))


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false
		hint_label.text = "Take"
		_hide_prompt()


func _exit_tree() -> void:
	_hide_prompt()
