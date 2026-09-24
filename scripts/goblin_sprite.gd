class_name GoblinSprite

static func texture() -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var skin := Color(0.35, 0.72, 0.28)
	var dark := Color(0.12, 0.28, 0.1)
	var cloth := Color(0.42, 0.28, 0.16)
	var steel := Color(0.82, 0.84, 0.88)
	var grip := Color(0.45, 0.28, 0.12)
	_fill(image, 12, 4, 8, 8, skin)
	_fill(image, 13, 6, 2, 2, Color(0.05, 0.05, 0.05))
	_fill(image, 17, 6, 2, 2, Color(0.05, 0.05, 0.05))
	_fill(image, 11, 12, 10, 8, cloth)
	_fill(image, 8, 13, 3, 3, skin)
	_fill(image, 21, 13, 3, 3, skin)
	_fill(image, 12, 20, 3, 6, dark)
	_fill(image, 17, 20, 3, 6, dark)
	_fill(image, 22, 16, 2, 8, grip)
	_fill(image, 23, 10, 3, 8, steel)
	_fill(image, 22, 9, 5, 2, steel)
	for x in image.get_width():
		for y in image.get_height():
			var color := image.get_pixel(x, y)
			if color.a < 0.5:
				continue
			if _near_empty(image, x, y):
				image.set_pixel(x, y, Color(0.05, 0.07, 0.08, color.a))
	return ImageTexture.create_from_image(image)

static func _fill(image: Image, x0: int, y0: int, width: int, height: int, color: Color) -> void:
	for y in range(y0, y0 + height):
		for x in range(x0, x0 + width):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)

static func _near_empty(image: Image, x: int, y: int) -> bool:
	for point in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var next: Vector2i = Vector2i(x, y) + point
		if next.x < 0 or next.y < 0 or next.x >= image.get_width() or next.y >= image.get_height():
			return true
		if image.get_pixel(next.x, next.y).a < 0.5:
			return true
	return false
