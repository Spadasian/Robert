extends Node
## Corruption 0-100. It grows a little with every kill. Thresholds: 25% +5% damage, 50% +20% damage and the Cursed
## upgrades join the offers (for the rest of the run), 75% +30% damage, a purple edge on the screen and the Kata waits
## 1 s less before it closes. At 100% the player is POSSESSED for a while: faster, +60% damage, takes half the damage,
## heals from the damage he deals. During it the bar drains from 100 to 0; afterwards a cooldown (no Corruption
## gained), then the bar starts filling from kills again.
## Numbers are constants at the top of the file, easy to adjust.

signal corruption_changed(value: float, level: int)
signal threshold_reached(level: int)
signal possessed_started
signal possessed_ended
signal state_changed # possessed / cooldown changed (the HUD label)

const THRESHOLDS: Array[float] = [25.0, 50.0, 75.0, 100.0]
const DAMAGE_BONUS: Array[float] = [0.0, 0.05, 0.20, 0.30, 0.30] # by level
const KILL_GAIN: float = 1.5 # Corruption for every kill
const POSSESSED_TIME: float = 15.0
const POSSESSED_COOLDOWN: float = 20.0
const POSSESSED_DAMAGE: float = 0.6 # +60% damage
const POSSESSED_SPEED: float = 0.25 # +25% movement speed
const POSSESSED_ATTACK_SPEED: float = 0.3 # +30% attack speed
const POSSESSED_DAMAGE_TAKEN: float = -0.5 # -50% damage taken
const POSSESSED_LIFESTEAL: float = 0.10 # of the damage dealt
const KATA_TIMEOUT_PENALTY: float = 1.0 # seconds, from 75%

@export var max_corruption: float = 100.0

var value: float = 0.0
var level: int = 0 # 0 = below 25%, 4 = 100%
var possessed: bool = false
var possessed_left: float = 0.0
var cooldown_left: float = 0.0
var cursed_unlocked: bool = false # reached 50% once in this run
var modifiers: Array = []

var player: Node


func _ready() -> void:
	player = get_parent()
	var events: Node = player.get_node_or_null("KataEvents")
	if events:
		events.kill.connect(_on_kill)
		events.hit_dealt.connect(_on_hit_dealt)


func _on_kill(_info: Dictionary) -> void:
	var extra: float = player.stats.get_stat("corruption_on_hit") if player.get("stats") else 0.0 # Dark Breath
	add_corruption(KILL_GAIN + extra)


func _on_hit_dealt(info: Dictionary) -> void:
	if possessed and not player.health.is_dead():
		player.health.heal(info.get("damage", 0.0) * POSSESSED_LIFESTEAL)


## Corruption cannot be gained while Possessed or during the cooldown after it.
func add_corruption(amount: float) -> void:
	if possessed or cooldown_left > 0.0:
		return
	set_corruption(value + amount)


func set_corruption(new_value: float) -> void:
	var old_level: int = level
	value = clampf(new_value, 0.0, max_corruption)
	level = 0
	for threshold in THRESHOLDS:
		if value >= threshold:
			level += 1
	if level >= 2:
		cursed_unlocked = true
	corruption_changed.emit(value, level)
	if level > old_level:
		threshold_reached.emit(level)
	if level >= 4 and not possessed and cooldown_left <= 0.0:
		_start_possessed()


## Multiplier of all the damage the player deals.
func damage_multiplier() -> float:
	if possessed:
		return 1.0 + POSSESSED_DAMAGE
	return 1.0 + DAMAGE_BONUS[clampi(level, 0, DAMAGE_BONUS.size() - 1)]


## Seconds taken off the time a running Kata waits before it closes.
func timeout_penalty() -> float:
	return KATA_TIMEOUT_PENALTY if level >= 3 and not possessed else 0.0


## 0..1, how strong the purple edge of the screen is (from 75%, full while Possessed).
func edge_strength() -> float:
	if possessed:
		return 1.0
	return clampf((value - 75.0) / 25.0, 0.0, 1.0) * 0.6 + (0.25 if level >= 3 else 0.0)


func _physics_process(delta: float) -> void:
	if possessed:
		possessed_left -= delta
		var ratio: float = clampf(possessed_left / POSSESSED_TIME, 0.0, 1.0)
		value = max_corruption * ratio # the bar drains while it lasts
		corruption_changed.emit(value, level)
		if possessed_left <= 0.0 or player.health.is_dead():
			_end_possessed()
		state_changed.emit()
	elif cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - delta, 0.0)
		state_changed.emit()


func _start_possessed() -> void:
	possessed = true
	possessed_left = POSSESSED_TIME
	var stats: Node = player.stats
	modifiers = [
		_modifier(stats, "move_speed", POSSESSED_SPEED),
		_modifier(stats, "attack_speed", POSSESSED_ATTACK_SPEED),
		_modifier(stats, "damage_taken", POSSESSED_DAMAGE_TAKEN),
	]
	possessed_started.emit()
	state_changed.emit()


func _end_possessed() -> void:
	possessed = false
	possessed_left = 0.0
	for effect in modifiers:
		player.stats.remove_modifier(effect)
	modifiers.clear()
	value = 0.0
	level = 0
	cooldown_left = POSSESSED_COOLDOWN
	corruption_changed.emit(value, level)
	possessed_ended.emit()
	state_changed.emit()


func _modifier(stats: Node, stat_name: String, amount: float) -> Resource:
	var effect := UpgradeEffect.new()
	effect.stat = stat_name
	effect.operation = UpgradeEffect.Operation.PERCENT
	effect.value = amount
	stats.add_modifier(effect)
	return effect
