class_name Placeholder
extends RefCounted
## Placeholder — generates simple colored textures in code so the slice needs NO
## hand-drawn art (per task constraint). GRAPHICS.md calls for hand-drawn billboard
## sprites with 4 emotional states; here each state is a flat color swatch with a
## small "face" so the four states are visually distinguishable at a glance. This is
## the prototype stand-in for the Gap 9 sprite-readability art and is documented as such.

# Emotion -> base body color (loosely follows GRAPHICS.md EMOTION_COLORS register).
const EMOTION_COLORS := {
	"neutral": Color(0.78, 0.74, 0.66),
	"afraid": Color(0.62, 0.66, 0.80),
	"angry": Color(0.80, 0.55, 0.52),
	"corrupted": Color(0.36, 0.66, 0.64),
}

const W := 64
const H := 96


## Returns an ImageTexture for an NPC body in the given emotional state.
static func npc_texture(emotion: String, accent: Color = Color(0.95, 0.85, 0.55)) -> ImageTexture:
	var col: Color = EMOTION_COLORS.get(emotion, EMOTION_COLORS["neutral"])
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Body block.
	for y in range(24, H):
		for x in range(14, W - 14):
			img.set_pixel(x, y, col)
	# Head block.
	for y in range(4, 24):
		for x in range(22, W - 22):
			img.set_pixel(x, y, col.lightened(0.12))

	# A face mark whose shape changes per emotion (cheap distinguishability).
	var ink := Color(0.1, 0.1, 0.12)
	match emotion:
		"neutral":
			_dot(img, 26, 12, ink); _dot(img, 37, 12, ink)
		"afraid":
			_dot(img, 26, 11, ink); _dot(img, 37, 11, ink)
			_dot(img, 31, 18, ink)  # open mouth
		"angry":
			_dot(img, 25, 13, ink); _dot(img, 38, 13, ink)
			_dot(img, 27, 10, ink); _dot(img, 36, 10, ink)  # brow
		"corrupted":
			_dot(img, 26, 12, ink); _dot(img, 37, 12, ink)
			for x in range(22, W - 22):  # corruption band
				img.set_pixel(x, 20, Color(0.18, 0.42, 0.42))

	# Accent strip (role marker) along the shoulders.
	for x in range(14, W - 14):
		img.set_pixel(x, 26, accent)
		img.set_pixel(x, 27, accent)

	return ImageTexture.create_from_image(img)


static func _dot(img: Image, cx: int, cy: int, c: Color) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := cx + dx
			var y := cy + dy
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				img.set_pixel(x, y, c)


## Flat ground / building texture.
static func solid_texture(color: Color, size: int = 8) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
