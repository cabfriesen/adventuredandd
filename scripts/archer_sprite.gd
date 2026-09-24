class_name ArcherSprite

static func texture() -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var skin := Color(0.93, 0.76, 0.58)
	var cloth := Color(0.2, 0.45, 0.28)
	var wood := Color(0.55, 0.34, 0.16)
	var hair := Color(0.35, 0.22, 0.12)
	_fill(image, 12, 3, 8, 7, skin)
	_fill(image, 12, 3, 8, 3, hair)
	_fill(image, 14, 6, 2, 2, Color(0.1, 0.1, 0.1))
	_fill(image, 11, 11, 10, 9, cloth)
	_fill(image, 8, 12, 3, 7, wood)
	_fill(image, 7, 12, 10, 2, wood)
	_fill(image, 7, 18, 10, 2, wood)
	_fill(image, 16, 13, 8, 1, Color(0.85, 0.85, 0.8))
	_fill(image, 12, 20, 3, 7, Color(0.25, 0.18, 0.12))
	_fill(image, 17, 20, 3, 7, Color(0.25, 0.18, 0.12))
	return ImageTexture.create_from_image(image)

static func _fill(image: Image, x0: int, y0: int, width: int, height: int, color: Color) -> void:
	for y in range(y0, y0 + height):
		for x in range(x0, x0 + width):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)
