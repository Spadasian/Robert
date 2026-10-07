extends Node
## The Kata: the player's fighting style. OPENING (how a sequence starts) -> FLOW (how it builds up) ->
## FINISHER (how it ends, the heavy attack). Each part is a technique (TechniqueData + a TechniqueBehavior script).
## Without any technique found, the default ones play: the first light hit opens the Kata, light hits add Flow,
## and a heavy attack at the end hits harder the more Flow there is.
##
## The Kata listens to KataEvents; it closes after `open_timeout` seconds without Flow activity, on a new room,
## or when the finisher is used.

signal kata_changed # slots, running state or Flow changed (the HUD redraws)
signal opened
signal closed(reason: String)
signal finisher_performed(context: Dictionary)

const Category = TechniqueData.Category
const DEFAULT_OPENING: Resource = preload("res://resources/techniques/neutral_stance.tres")
const DEFAULT_FLOW: Resource = preload("res://resources/techniques/steady_flow.tres")
const DEFAULT_FINISHER: Resource = preload("res://resources/techniques/heavy_slash.tres")

@export var open_timeout: float = 3.0 # seconds without Flow activity before a running Kata closes
@export var flow_cap: float = 1.0

@onready var events: Node = $"../KataEvents"

var slots: Dictionary = {} # Category -> TechniqueData
var behaviors: Dictionary = {} # Category -> TechniqueBehavior
var is_open: bool = false
var flow_value: float = 0.0
var idle_time: float = 0.0


func _ready() -> void:
	set_technique(DEFAULT_OPENING)
	set_technique(DEFAULT_FLOW)
	set_technique(DEFAULT_FINISHER)
	events.light_attack.connect(func(): _on_event("light_attack", {}))
	events.heavy_attack.connect(func(): _on_event("heavy_attack", {}))
	events.hit_dealt.connect(func(info: Dictionary): _on_event("hit_dealt", info))
	events.critical_hit.connect(func(info: Dictionary): _on_event("critical_hit", info))
	events.kill.connect(func(info: Dictionary): _on_event("kill", info))
	events.dodge.connect(func(): _on_event("dodge", {}))
	events.perfect_dodge.connect(func(source: Node): _on_event("perfect_dodge", {"source": source}))
	events.damage_taken.connect(func(amount: float): _on_event("damage_taken", {"amount": amount}))
	events.skill_used.connect(func(skill: Node): _on_event("skill_used", {"skill": skill}))
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager:
		room_manager.room_loaded.connect(func(_room: Node): close("room"))


func get_technique(category: int) -> Resource:
	return slots.get(category)


func has_technique(technique_id: String) -> bool:
	for data in slots.values():
		if data.id == technique_id:
			return true
	return false


## True when the slot still holds the starting technique (nothing was found for it yet).
func is_default(category: int) -> bool:
	var data: Resource = slots.get(category)
	return data == null or data == DEFAULT_OPENING or data == DEFAULT_FLOW or data == DEFAULT_FINISHER


## Puts a technique in the slot of its category. Returns the technique that was there (or null).
func set_technique(data: Resource) -> Resource:
	var previous: Resource = slots.get(data.category)
	var behavior: TechniqueBehavior = data.behavior.new() if data.behavior else TechniqueBehavior.new()
	behavior.data = data
	slots[data.category] = data
	behaviors[data.category] = behavior
	kata_changed.emit()
	return previous


func _active_behaviors() -> Array:
	return behaviors.values()


func _on_event(event: String, payload: Dictionary) -> void:
	if not is_open:
		if behaviors[Category.OPENING].opening_matches(self, event, payload):
			_open()
			# the event that opened the Kata also counts for the Flow
			for behavior in _active_behaviors():
				behavior.on_event(self, event, payload)
		return
	for behavior in _active_behaviors():
		behavior.on_event(self, event, payload)


func _open() -> void:
	is_open = true
	flow_value = 0.0
	idle_time = 0.0
	for behavior in _active_behaviors():
		behavior.on_open(self)
	opened.emit()
	kata_changed.emit()


func close(reason: String) -> void:
	if not is_open:
		return
	is_open = false
	for behavior in _active_behaviors():
		behavior.on_close(self, reason)
	flow_value = 0.0
	idle_time = 0.0
	closed.emit(reason)
	kata_changed.emit()


## Techniques call this to add (or take away, with a negative number) Flow. It also counts as activity.
func add_flow(amount: float) -> void:
	flow_value = clampf(flow_value + amount, 0.0, flow_cap)
	idle_time = 0.0
	kata_changed.emit()


## Techniques call this when something happened that should keep the Kata alive without changing the Flow.
func touch() -> void:
	idle_time = 0.0


## The heavy attack asks this when its strike begins. If a Kata is running, the heavy attack becomes its Finisher:
## the techniques can multiply its damage and add effects, then the Kata ends. Returns the context.
func begin_finisher(heavy: Node) -> Dictionary:
	var context: Dictionary = {"damage_multiplier": 1.0, "flow": flow_value, "was_open": is_open}
	if not is_open:
		return context
	for behavior in _active_behaviors():
		context.damage_multiplier *= behavior.finisher_multiplier(self)
	for behavior in _active_behaviors():
		behavior.on_finisher_strike(self, heavy, context)
	finisher_performed.emit(context)
	close("finisher")
	return context


func _physics_process(delta: float) -> void:
	if not is_open:
		return
	idle_time += delta
	for behavior in _active_behaviors():
		behavior.on_tick(self, delta)
	if idle_time >= open_timeout:
		close("timeout")
	else:
		kata_changed.emit() # the timer line on the HUD moves
