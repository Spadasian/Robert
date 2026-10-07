class_name DungeonGenerator
extends RefCounted
## Builds the map of one dungeon: rooms placed on a small grid and joined by doors.
## It never builds geometry; it only decides which premade room goes in which cell and which doors connect them.
##
## Result (a Dictionary):
##   cells:       Vector2i -> { "data": RoomData, "doors": { "east": Vector2i (neighbour cell), ... } }
##   start, boss: Vector2i cells
##   boss_parent: Vector2i, the only room that has a door to the boss
##   boss_door:   String, the side of boss_parent's door that leads to the boss
##   distance:    Vector2i -> steps from the start room

const DIRECTIONS: Dictionary = {
	"north": Vector2i(0, -1), "east": Vector2i(1, 0), "south": Vector2i(0, 1), "west": Vector2i(-1, 0),
}
const OPPOSITE: Dictionary = {"north": "south", "east": "west", "south": "north", "west": "east"}
const LOOP_CHANCE: float = 0.3 # chance that two touching rooms get a door between them (makes loops)


## counts: RoomData.RoomType (int) -> how many rooms of that type. START and BOSS are always added.
## Types with no room in the pool are skipped, so the counts can already list room types that do not exist yet.
static func generate(pool: Array, counts: Dictionary, grid: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var types: Array[int] = []
	for type in counts:
		var available: bool = pool.any(func(room): return room.room_type == type)
		if not available:
			print("DungeonGenerator: no room of type %d in the pool yet, skipping" % type)
			continue
		for i in int(counts[type]):
			types.append(type)
	_shuffle(types, rng)

	var start: Vector2i = Vector2i(grid.x / 2, grid.y / 2)
	var neighbours: Dictionary = {start: {}} # cell -> { direction: neighbour cell }
	var wanted_cells: int = 1 + types.size()

	# 1. grow a connected group of rooms from the start
	var guard: int = 0
	while neighbours.size() < wanted_cells and guard < 2000:
		guard += 1
		var cells: Array = neighbours.keys()
		var from: Vector2i = cells[rng.randi() % cells.size()]
		var direction: String = DIRECTIONS.keys()[rng.randi() % 4]
		var target: Vector2i = from + DIRECTIONS[direction]
		if neighbours.has(target) or not _inside(target, grid):
			continue
		neighbours[target] = {}
		_connect(neighbours, from, direction)

	# 2. a few extra doors between touching rooms, so the map has loops
	for cell in neighbours.keys():
		for direction in ["east", "south"]:
			var other: Vector2i = cell + DIRECTIONS[direction]
			if neighbours.has(other) and not neighbours[cell].has(direction) and rng.randf() < LOOP_CHANCE:
				_connect(neighbours, cell, direction)

	var distance: Dictionary = _distances(neighbours, start)

	# 3. the boss room: an empty cell next to the room that is farthest from the start, joined by one door only
	var boss: Vector2i = start
	var boss_parent: Vector2i = start
	var boss_door: String = "east"
	var best: int = -1
	var options: Array = []
	for cell in neighbours.keys():
		for direction in DIRECTIONS:
			var spot: Vector2i = cell + DIRECTIONS[direction]
			if neighbours.has(spot) or not _inside(spot, grid):
				continue
			var steps: int = distance[cell]
			if steps > best:
				best = steps
				options = []
			if steps == best:
				options.append([cell, direction, spot])
	if not options.is_empty():
		var pick: Array = options[rng.randi() % options.size()]
		boss_parent = pick[0]
		boss_door = pick[1]
		boss = pick[2]
		neighbours[boss] = {}
		_connect(neighbours, boss_parent, boss_door)
		distance[boss] = best + 1
	else:
		push_warning("DungeonGenerator: the grid is full, no space for the boss room (make the grid bigger)")

	# 4. choose a premade room for every cell (harder rooms farther from the start)
	var assigned: Array[int] = types.duplicate()
	var cells_by_distance: Array = neighbours.keys().filter(func(cell): return cell != start and cell != boss)
	cells_by_distance.sort_custom(func(a, b): return distance[a] < distance[b])
	var max_distance: float = maxf(float(best), 1.0)
	var bags: Dictionary = {} # type -> rooms not used yet
	var result_cells: Dictionary = {}
	result_cells[start] = {"data": _pick(pool, RoomData.RoomType.START, 0.0, bags, rng), "doors": neighbours[start]}
	result_cells[boss] = {"data": _pick(pool, RoomData.RoomType.BOSS, 3.0, bags, rng), "doors": neighbours[boss]}
	for cell in cells_by_distance:
		var type: int = assigned.pop_back()
		var target_difficulty: float = 1.0 + 2.0 * float(distance[cell]) / max_distance
		result_cells[cell] = {"data": _pick(pool, type, target_difficulty, bags, rng), "doors": neighbours[cell]}

	return {
		"cells": result_cells, "start": start, "boss": boss,
		"boss_parent": boss_parent, "boss_door": boss_door, "distance": distance,
	}


static func _inside(cell: Vector2i, grid: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid.x and cell.y < grid.y


static func _connect(neighbours: Dictionary, cell: Vector2i, direction: String) -> void:
	var other: Vector2i = cell + DIRECTIONS[direction]
	neighbours[cell][direction] = other
	neighbours[other][OPPOSITE[direction]] = cell


static func _distances(neighbours: Dictionary, start: Vector2i) -> Dictionary:
	var distance: Dictionary = {start: 0}
	var queue: Array = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for direction in neighbours[cell]:
			var other: Vector2i = neighbours[cell][direction]
			if not distance.has(other):
				distance[other] = distance[cell] + 1
				queue.append(other)
	return distance


## A room of this type; every room of a type is used once before any repeats (same idea as RunGenerator).
static func _pick(pool: Array, type: int, target_difficulty: float, bags: Dictionary, rng: RandomNumberGenerator) -> Resource:
	var of_type: Array = pool.filter(func(room): return room.room_type == type)
	if of_type.is_empty():
		push_warning("DungeonGenerator: no room of type %d, using the first room of the pool" % type)
		return pool[0]
	var unused: Array = bags.get(type, [])
	if unused.is_empty():
		unused = of_type.duplicate()
	var chosen: Resource = RunGenerator._pick_weighted(unused, target_difficulty, null, rng)
	unused.erase(chosen)
	bags[type] = unused
	return chosen


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var swap = items[i]
		items[i] = items[j]
		items[j] = swap
