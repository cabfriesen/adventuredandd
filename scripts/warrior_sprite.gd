class_name WarriorSprite

static func texture() -> Texture2D:
	var bytes := FileAccess.get_file_as_bytes("res://sprites/warrior.png")
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)
