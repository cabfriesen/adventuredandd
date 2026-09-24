class_name HexGrid

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	var ds := -dq - dr
	return (absi(dq) + absi(dr) + absi(ds)) / 2

static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for dir in DIRS:
		found.append(cell + dir)
	return found

static func cheapest_path(start: Vector2i, goal: Vector2i, walkable: Dictionary, enter_cost: Dictionary, blocked: Dictionary) -> Array[Vector2i]:
	if start == goal:
		return [start]
	if not walkable.has(goal) or blocked.has(goal):
		return []
	var cost := {start: 0}
	var came_from := {start: start}
	var open: Array[Vector2i] = [start]
	while not open.is_empty():
		var best_index := 0
		for index in open.size():
			if int(cost[open[index]]) < int(cost[open[best_index]]):
				best_index = index
		var current: Vector2i = open.pop_at(best_index)
		if current == goal:
			return _rebuild(came_from, start, goal)
		for next in neighbors(current):
			if not walkable.has(next) or blocked.has(next) or next == start:
				continue
			var step_cost := int(enter_cost.get(next, 1))
			var next_cost := int(cost[current]) + step_cost
			if cost.has(next) and next_cost >= int(cost[next]):
				continue
			cost[next] = next_cost
			came_from[next] = current
			if not open.has(next):
				open.append(next)
	return []

static func shortest_path(start: Vector2i, goal: Vector2i, walkable: Dictionary) -> Array[Vector2i]:
	if start == goal:
		return [start]
	if not walkable.has(goal):
		return []
	var came_from := {start: start}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for next in neighbors(current):
			if not walkable.has(next) or came_from.has(next):
				continue
			came_from[next] = current
			if next == goal:
				return _rebuild(came_from, start, goal)
			queue.append(next)
	return []

static func _rebuild(came_from: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var cursor := goal
	while cursor != start:
		cursor = came_from[cursor]
		path.append(cursor)
	path.reverse()
	return path
