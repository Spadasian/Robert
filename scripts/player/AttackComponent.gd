extends Node3D
## The basic attack (LMB). Hold the attack button to keep attacking (limited by the cooldown). The look and rhythm come
## from the character (CharacterData.attack and weapon model): Kazuma slashes with the katana; Yume cuts twice
## with her fans, quickly.

@export var attack_cooldown: float = 0.35
@export var swing_time: float = 0.15
@export var swing_arc_degrees: float = 140.0

@onready var aim: Node = $"../AimComponent"
@onready var stats: Node = $"../StatsComponent"
@onready var kata_events: Node = $"../KataEvents"
@onready var swing_pivot: Node3D = $SwingPivot
@onready var hitbox: Area3D = $SwingPivot/Hitbox
@onready var blade: MeshInstance3D = $SwingPivot/Blade

var cooldown_left: float = 0.0
var swing_side: float = 1.0
var swing_tween: Tween
var params: Dictionary = {} # CharacterData.attack
var weapon_model: Node3D
var swing_id: int = 0 # a newer attack cancels the cuts still waiting from the older one


func _ready() -> void:
	blade.visible = false
	hitbox.source = get_parent()
	hitbox.kind = "light"
	hitbox.set_active(false)


## The weapon and rhythm of the chosen character.
func apply_character(character: Resource) -> void:
	params = character.attack
	if character.weapon_scene != null:
		weapon_model = character.weapon_scene.instantiate()
		weapon_model.position = character.weapon_position
		weapon_model.rotation_degrees = character.weapon_rotation
		weapon_model.scale = Vector3.ONE * character.weapon_scale
		swing_pivot.add_child(weapon_model)
		blade.queue_free() # the plain box is replaced by the real model, which stays in the hand
		blade = null


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	rotation.y = atan2(aim.aim_direction.x, aim.aim_direction.z)
	var player := get_parent()
	if Input.is_action_pressed("attack") and cooldown_left <= 0.0 and not player.is_busy():
		start_attack()


func start_attack() -> void:
	cooldown_left = float(params.get("cooldown", attack_cooldown)) / stats.get_stat("attack_speed")
	kata_events.light_attack.emit()
	swing_id += 1
	var id: int = swing_id
	var cuts: int = int(params.get("hits", 1))
	for index in cuts:
		if index > 0:
			await get_tree().create_timer(float(params.get("hit_gap", 0.1)), false).timeout
			if id != swing_id or get_parent().health.is_dead():
				return
		_cut()


## One cut: the hitbox is on while the weapon swings through its arc.
func _cut() -> void:
	hitbox.damage = stats.get_stat("attack_damage") * float(params.get("damage_ratio", 1.0))
	var reach: float = stats.get_stat("attack_range") * float(params.get("reach", 1.0))
	hitbox.scale = Vector3(reach, 1.0, reach) # Weapon Master and the weapon of the character
	hitbox.set_active(true)
	if blade:
		blade.visible = true
	AudioManager.play_sfx("slash")
	var arc: float = float(params.get("arc", swing_arc_degrees))
	var color: Color = params.get("color", Color(0.9, 0.95, 1.0))
	VFX.slash_arc(global_position + Vector3(0.0, 0.9, 0.0), rotation.y, 2.3 * reach, arc * 0.93, color, 0.16)

	var half_arc: float = deg_to_rad(arc * 0.5) * swing_side
	swing_pivot.rotation.y = -half_arc
	if swing_tween:
		swing_tween.kill()
	swing_tween = create_tween()
	swing_tween.tween_property(swing_pivot, "rotation:y", half_arc, float(params.get("swing_time", swing_time)))
	swing_tween.tween_callback(end_attack)
	swing_side *= -1.0 # alternate swing direction


func end_attack() -> void:
	hitbox.set_active(false)
	if blade:
		blade.visible = false
