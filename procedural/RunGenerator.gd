class_name RunGenerator
extends RefCounted
## Builds the list of rooms for one run from a layout (room types in order) and a pool of RoomData.
## It never builds geometry: it only decides WHICH premade room comes at each step.
##
## Layout values are RoomData.RoomType numbers:
## 0 COMBAT, 1 ELITE, 2 TREASURE, 3 SHOP, 4 EVENT, 5 SHRINE, 6 BOSS
## Slots whose type has no room in the pool yet are skipped, so the layout can already list future room types.


static func generate(pool: Array, layout: PackedInt32Array, rng: RandomNumberGenerator) -> Array:
	var plan: Array = []
	var unused_by_type: Dictionary = {}
	var previous: Resource = null
	var last_step: int = maxi(layout.size() - 1, 1)

	for step in layout.size():
		var slot_type: int = layout[step]
		var rooms_of_type: Array = pool.filter(func(room): return room.room_type == slot_type)
		if rooms_of_type.is_empty():
			print("RunGenerator: no room of type %d in the pool yet, skipping slot %d" % [slot_type, step])
			continue

		# Each room is used once per type before any repeats ("shuffle bag").
		var unused: Array = unused_by_type.get(slot_type, [])
		if unused.is_empty():
			unused = rooms_of_type.duplicate()

		# Difficulty rises from 1 to 3 across the run; rooms closer to the target are more likely.
		var target_difficulty: float = 1.0 + 2.0 * float(step) / float(last_step)
		var chosen: Resource = _pick_weighted(unused, target_difficulty, previous, rng)
		unused.erase(chosen)
		unused_by_type[slot_type] = unused
		plan.append(chosen)
		previous = chosen
	return plan


static func _pick_weighted(options: Array, target_difficulty: float, previous: Resource, rng: RandomNumberGenerator) -> Resource:
	var candidates: Array = options.filter(func(room): return room != previous)
	if candidates.is_empty():
		candidates = options
	var weights: Array[float] = []
	var total: float = 0.0
	for room in candidates:
		var weight: float = 1.0 / (1.0 + absf(room.difficulty - target_difficulty))
		weights.append(weight)
		total += weight
	var roll: float = rng.randf() * total
	for index in candidates.size():
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates[candidates.size() - 1]
