extends Control
## The dungeon map in the corner of the HUD: rooms you entered are coloured by type, rooms next to them that you have
## not entered yet show as "?", the room you are in has a white frame, and doors are lines between rooms.

# Colour per RoomData.RoomType: COMBAT, ELITE, TREASURE, SHOP, EVENT, SHRINE, BOSS, START, MINIBOSS, DUEL, ARENA.
const COLORS: Array[Color] = [
	Color(0.8, 0.8, 0.88), Color(1.0, 0.6, 0.2), Color(1.0, 0.85, 0.3), Color(0.4, 0.9, 0.5),
	Color(0.6, 0.7, 1.0), Color(0.7, 0.5, 1.0), Color(0.75, 0.25, 0.9), Color(0.55, 0.6, 0.7),
	Color(1.0, 0.35, 0.3), Color(0.4, 0.85, 1.0), Color(1.0, 0.6, 0.2),
]
const MAX_STEP: float = 34.0

var room_manager: Node


func refresh(manager: Node) -> void:
	room_manager = manager
	queue_redraw()


func _draw() -> void:
	if room_manager == null or room_manager.dungeon.is_empty():
		return
	var cells: Dictionary = room_manager.dungeon.cells
	var visited: Dictionary = room_manager.visited

	var low := Vector2i(1000, 1000)
	var high := Vector2i(-1000, -1000)
	for cell in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	var columns: int = high.x - low.x + 1
	var rows: int = high.y - low.y + 1
	var step: float = minf(minf(size.x / columns, size.y / rows), MAX_STEP)
	var box: float = step * 0.76
	var origin := Vector2(size.x - columns * step, 0.0) # hugs the right edge

	# doors between rooms that the player knows about
	for cell in cells:
		for direction in ["east", "south"]:
			var other: Vector2i = cells[cell].doors.get(direction, Vector2i(-999, -999))
			if cells.has(other) and (visited.has(cell) or visited.has(other)):
				draw_line(_center(cell, low, step, origin), _center(other, low, step, origin), Color(1, 1, 1, 0.3), 2.0)

	var font: Font = ThemeDB.fallback_font
	for cell in cells:
		var is_visited: bool = visited.has(cell)
		var is_known: bool = is_visited
		if not is_visited:
			for direction in cells[cell].doors:
				if visited.has(cells[cell].doors[direction]):
					is_known = true
		if not is_known:
			continue
		var rect := Rect2(_center(cell, low, step, origin) - Vector2(box, box) * 0.5, Vector2(box, box))
		if is_visited:
			var color: Color = COLORS[clampi(cells[cell].data.room_type, 0, COLORS.size() - 1)]
			if not room_manager.is_cell_cleared(cell):
				color.a = 0.55 # entered but not cleared yet
			draw_rect(rect, color)
		elif _knows_room_types() and cell != room_manager.dungeon.boss:
			var type_color: Color = COLORS[clampi(cells[cell].data.room_type, 0, COLORS.size() - 1)]
			type_color.a = 0.35 # Wanderer's Map: the type of the neighbouring rooms is shown, dimmed
			draw_rect(rect, type_color)
			draw_rect(rect, Color(type_color.r, type_color.g, type_color.b, 0.9), false, 1.5)
		else:
			var is_boss: bool = cell == room_manager.dungeon.boss
			draw_rect(rect, Color(0.12, 0.1, 0.18, 0.85))
			draw_rect(rect, COLORS[6] if is_boss else Color(0.6, 0.6, 0.7, 0.7), false, 1.5)
			draw_string(font, rect.position + Vector2(0.0, box * 0.74), "B" if is_boss else "?",
				HORIZONTAL_ALIGNMENT_CENTER, box, int(box * 0.6), COLORS[6] if is_boss else Color(0.8, 0.8, 0.9))
		if cell == room_manager.current_cell:
			draw_rect(rect.grow(2.0), Color.WHITE, false, 2.0)


func _knows_room_types() -> bool:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	return run_manager != null and run_manager.has_relic("wanderer_map")


func _center(cell: Vector2i, low: Vector2i, step: float, origin: Vector2) -> Vector2:
	return origin + (Vector2(cell - low) + Vector2(0.5, 0.5)) * step
