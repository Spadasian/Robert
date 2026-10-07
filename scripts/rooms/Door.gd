extends Area3D
## One door of a room, on the wall that faces `direction`. A room has four (Doors node); only the ones that lead
## to another room of the dungeon exist. A door opens when its room is cleared. The door that leads to the boss
## stays locked (purple, tagged BOSS) until every other room of the dungeon is cleared.

signal entered(direction: String)
signal locked_touched(direction: String)

@export var direction: String = "east"

var exists: bool = false
var is_open: bool = false
var is_locked: bool = false

var material: StandardMaterial3D

@onready var visual: MeshInstance3D = $DoorVisual
@onready var tag: Label3D = $Tag


func _ready() -> void:
	material = visual.get_active_material(0).duplicate() as StandardMaterial3D
	visual.material_override = material
	body_entered.connect(_on_body_entered)
	_refresh()


func setup(has_neighbor: bool, leads_to_boss: bool) -> void:
	exists = has_neighbor
	is_locked = has_neighbor and leads_to_boss
	is_open = false
	tag.text = "BOSS" if (has_neighbor and leads_to_boss) else ""
	_refresh()


func set_open(value: bool) -> void:
	is_open = value and not is_locked
	_refresh()


func set_locked(value: bool) -> void:
	is_locked = value
	if value:
		is_open = false
	_refresh()


func _refresh() -> void:
	if material == null:
		return
	visible = exists
	set_deferred("monitoring", exists)
	var color := Color(0.3, 0.05, 0.05) # closed
	var glow := false
	if is_locked:
		color = Color(0.5, 0.2, 0.75)
	elif is_open:
		color = Color(0.2, 0.9, 0.8)
		glow = true
	material.albedo_color = color
	material.emission_enabled = glow
	material.emission = color


func _on_body_entered(body: Node3D) -> void:
	if not exists or not body.is_in_group("player"):
		return
	if is_locked:
		locked_touched.emit(direction)
	elif is_open:
		entered.emit(direction)
