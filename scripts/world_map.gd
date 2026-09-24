class_name WorldMap

static func surface() -> Dictionary:
	var grass := {}
	var forest := {}
	var plains := {}
	var roads := {}
	var blocked := {}
	var cells: Array[Vector2i] = []

	for q in range(-8, 9):
		for r in range(-8, 9):
			var cell := Vector2i(q, r)
			var dist := HexGrid.distance(cell, Vector2i.ZERO)
			if dist <= 2:
				grass[cell] = true
			elif dist <= 7:
				forest[cell] = true
	for q in range(3, 13):
		var line := Vector2i(q, 0)
		grass.erase(line)
		forest[line] = true

	var plains_center := Vector2i(0, -12)
	for q in range(-6, 7):
		for r in range(-18, -6):
			var cell := Vector2i(q, r)
			if HexGrid.distance(cell, plains_center) <= 5 and not forest.has(cell) and not grass.has(cell):
				plains[cell] = true

	for q in range(13, 31):
		roads[Vector2i(q, 0)] = true
	for extra in [Vector2i(23, 1), Vector2i(24, 1), Vector2i(26, 1)]:
		roads[extra] = true
	for q in range(21, 31):
		roads[Vector2i(q, 3)] = true
	for extra in [
		Vector2i(21, 1), Vector2i(21, 2),
		Vector2i(24, 2),
		Vector2i(27, 1), Vector2i(27, 2),
		Vector2i(30, 1), Vector2i(30, 2),
	]:
		roads[extra] = true

	var houses := [
		{"color": Color(0.72, 0.28, 0.22), "cells": [Vector2i(22, -1), Vector2i(23, -1), Vector2i(23, -2)]},
		{"color": Color(0.25, 0.38, 0.72), "cells": [Vector2i(26, -1), Vector2i(27, -1), Vector2i(27, -2)]},
		{"color": Color(0.78, 0.5, 0.22), "cells": [Vector2i(22, 1), Vector2i(22, 2), Vector2i(23, 2)]},
		{"color": Color(0.48, 0.28, 0.62), "cells": [Vector2i(25, 1), Vector2i(25, 2), Vector2i(26, 2)]},
		{"color": Color(0.78, 0.7, 0.28), "cells": [Vector2i(29, -1), Vector2i(30, -1), Vector2i(30, -2)]},
	]
	for house in houses:
		for cell in house["cells"]:
			blocked[cell] = true

	var seen := {}
	for group in [grass, forest, plains, roads, blocked]:
		for cell in group.keys():
			if seen.has(cell):
				continue
			seen[cell] = true
			cells.append(cell)

	var villagers := [
		{"id": "quest_a", "role": "quest", "cell": Vector2i(22, 0), "shirt": Color(0.85, 0.3, 0.25)},
		{"id": "quest_b", "role": "quest", "cell": Vector2i(26, 0), "shirt": Color(0.3, 0.45, 0.85)},
		{"id": "shop", "role": "shop", "cell": Vector2i(23, 1), "shirt": Color(0.85, 0.55, 0.2)},
		{"id": "thief", "role": "thief", "cell": Vector2i(26, 1), "shirt": Color(0.62, 0.4, 0.78)},
		{"id": "hint", "role": "hint", "cell": Vector2i(29, 0), "shirt": Color(0.86, 0.78, 0.3)},
	]

	return {
		"cells": cells,
		"grass": grass,
		"forest": forest,
		"plains": plains,
		"roads": roads,
		"blocked": blocked,
		"houses": houses,
		"villagers": villagers,
		"goblin": Vector2i(0, -9),
		"spawns": [Vector2i.ZERO, Vector2i(1, -1), Vector2i(0, 1), Vector2i(-1, 0)],
	}
