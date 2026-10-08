extends Node
## The Kata: the player's fighting style. OPENING (how a sequence starts) -> FLOW (how it builds up) ->
## FINISHER (how it ends, the heavy attack). Each part is a technique (TechniqueData + a TechniqueBehavior script).
## The Kata does not exist at the start of a run: with no technique the player only has plain light and heavy attacks.
## The first technique found AWAKENS it. It is a chain: a slot without a technique does NOTHING.
## No Opening: the Kata never opens. No Flow: the Flow bar never grows. No Finisher: the heavy attack gets no bonus,
## however full the Flow is. The MASTER slot is optional.
##
## The Kata listens to KataEvents; it closes after `open_timeout` seconds without Flow activity, on a new room,
## or when the finisher is used.

signal kata_changed # slots, running state or Flow changed (the HUD redraws)
signal awakened # the first technique was found
signal opened
signal closed(reason: String)
signal finisher_performed(context: Dictionary)

const Category = TechniqueData.Category

@export var open_timeout: float = 3.0 # seconds without Flow activity before a running Kata closes
@export var flow_cap: float = 1.0

@onready var events: Node = $"../KataEvents"

var slots: Dictionary = {} # Category -> TechniqueData (only techniques that were found)
var behaviors: Dictionary = {} # Category -> TechniqueBehavior (only for techniques that were found)
var is_awake: bool = false
var is_open: bool = false
var flow_value: float = 0.0
var idle_time: float = 0.0
var flow_shield_left: float = 0.0 # seconds during which no Flow can be lost (Paper Lantern)


func _ready() -> void:
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


## True when nothing was found for the slot yet (the slot does nothing).
func is_empty_slot(category: int) -> bool:
	return not slots.has(category)


## Puts a technique in the slot of its category. Returns the technique that was there (or null).
## The first technique ever found awakens the Kata.
func set_technique(data: Resource) -> Resource:
	var previous: Resource = slots.get(data.category)
	slots[data.category] = data
	behaviors[data.category] = _make_behavior(data)
	if not is_awake:
		is_awake = true
		awakened.emit()
	kata_changed.emit()
	return previous


func _make_behavior(data: Resource) -> TechniqueBehavior:
	var behavior: TechniqueBehavior = data.behavior.new() if data.behavior else TechniqueBehavior.new()
	behavior.data = data
	return behavior


func _active_behaviors() -> Array:
	return behaviors.values()


func _on_event(event: String, payload: Dictionary) -> void:
	if not is_awake:
		return
	if not is_open:
		if behaviors.has(Category.OPENING) and behaviors[Category.OPENING].opening_matches(self, event, payload):
			_open()
			# the event that opened the Kata also counts for the Flow
			for behavior in _active_behaviors():
				behavior.on_event(self, event, payload)
		elif behaviors.has(Category.MASTER):
			behaviors[Category.MASTER].on_event(self, event, payload) # a Master technique can act while the Kata is closed
		return
	for behavior in _active_behaviors():
		behavior.on_event(self, event, payload)


## Opens the Kata without its Opening (Second Wind, Echo Opening, Shrine Bell). Does nothing while it sleeps.
func force_open(initial_flow: float = 0.0) -> void:
	if not is_awake:
		return
	if not is_open:
		_open()
	add_flow(initial_flow)


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
	if not behaviors.has(Category.FLOW):
		idle_time = 0.0
		return # the chain: without a Flow technique the bar does not grow
	var stats: Node = _stats()
	if stats:
		amount *= stats.get_stat("flow_gain") if amount > 0.0 else stats.get_stat("flow_loss")
	if amount < 0.0 and flow_shield_left > 0.0:
		idle_time = 0.0
		return # Paper Lantern: no Flow is lost for a moment after a hit
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
	if not is_awake or not is_open or not behaviors.has(Category.FINISHER):
		context.was_open = false # no Finisher technique: the heavy attack stays plain and the Kata keeps running
		return context
	for behavior in _active_behaviors():
		context.damage_multiplier *= behavior.finisher_multiplier(self)
	for behavior in _active_behaviors():
		behavior.on_finisher_strike(self, heavy, context)
	finisher_performed.emit(context)
	close("finisher")
	return context


func _stats() -> Node:
	return get_parent().get_node_or_null("StatsComponent")


## Seconds without activity before the running Kata closes (Lingering Mist adds to it).
func get_open_timeout() -> float:
	var stats: Node = _stats()
	return open_timeout + (stats.get_stat("kata_timeout_bonus") if stats else 0.0)


func _physics_process(delta: float) -> void:
	flow_shield_left = maxf(flow_shield_left - delta, 0.0)
	if not is_open:
		return
	idle_time += delta
	for behavior in _active_behaviors():
		behavior.on_tick(self, delta)
	if idle_time >= get_open_timeout():
		close("timeout")
	else:
		kata_changed.emit() # the timer line on the HUD moves
