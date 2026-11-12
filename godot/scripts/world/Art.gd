class_name Art
extends RefCounted
## Art — every texture in the build, generated in code.
##
## The project ships no art assets. GRAPHICS.md calls for hand-drawn billboard
## sprites with four readable emotional states; until that art exists (and until the
## Gap 9 readability prototype is run on real viewers) each person is a small
## pixel figure drawn here. The four states are carried by POSTURE first and tint
## second, because posture survives the night desaturation and distance:
##   neutral    upright, arms at sides
##   afraid     hunched, arms drawn in, head down and turned
##   angry      squared, arms out from the body, weight forward
##   corrupted  slack, head tilted, long arms, teal at the edges (#2a5a5a family)
##
## Pillar 2: people are named and individually recognisable — coat, hair and one
## carried object each — so the player reads WHO is standing at a post from afar.

const W := 32
const H := 48

const SKIN := Color(0.80, 0.66, 0.55)
const INK := Color(0.10, 0.10, 0.12)
const CORRUPT := Color(0.165, 0.353, 0.353)

## Look per person. hat: none | cap | brim | bun | scarf.  prop: none | book | lantern | bag | tool | level | leash
const LOOKS := {
	"ruth": {"coat": Color(0.62, 0.50, 0.28), "legs": Color(0.24, 0.22, 0.20), "hair": Color(0.20, 0.14, 0.10), "hat": "bun", "prop": "none", "apron": true},
	"thomas": {"coat": Color(0.80, 0.80, 0.78), "legs": Color(0.22, 0.24, 0.28), "hair": Color(0.16, 0.14, 0.14), "hat": "none", "prop": "bag"},
	"maren": {"coat": Color(0.36, 0.50, 0.38), "legs": Color(0.26, 0.24, 0.26), "hair": Color(0.72, 0.60, 0.38), "hat": "none", "prop": "book"},
	"elias": {"coat": Color(0.32, 0.40, 0.54), "legs": Color(0.18, 0.20, 0.24), "hair": Color(0.30, 0.26, 0.22), "hat": "cap", "prop": "lantern"},
	"constance": {"coat": Color(0.16, 0.15, 0.18), "legs": Color(0.16, 0.15, 0.18), "hair": Color(0.88, 0.88, 0.86), "hat": "scarf", "prop": "none", "skirt": true},
	"peder": {"coat": Color(0.44, 0.30, 0.20), "legs": Color(0.22, 0.20, 0.18), "hair": Color(0.46, 0.34, 0.22), "hat": "none", "prop": "tool", "beard": true},
	# Arrivals wear what they were wearing. They read as from somewhere else.
	"ines": {"coat": Color(0.86, 0.52, 0.16), "legs": Color(0.22, 0.26, 0.36), "hair": Color(0.14, 0.10, 0.08), "hat": "none", "prop": "level"},
	"dov": {"coat": Color(0.18, 0.26, 0.46), "legs": Color(0.16, 0.18, 0.24), "hair": Color(0.12, 0.10, 0.10), "hat": "none", "prop": "none"},
	"hana": {"coat": Color(0.84, 0.74, 0.22), "legs": Color(0.20, 0.20, 0.26), "hair": Color(0.10, 0.08, 0.08), "hat": "none", "prop": "none"},
	"callum": {"coat": Color(0.40, 0.44, 0.26), "legs": Color(0.30, 0.26, 0.20), "hair": Color(0.36, 0.22, 0.14), "hat": "cap", "prop": "none"},
	"bea": {"coat": Color(0.60, 0.48, 0.66), "legs": Color(0.22, 0.22, 0.28), "hair": Color(0.78, 0.74, 0.66), "hat": "none", "prop": "leash"},
	"rep_compact": {"coat": Color(0.12, 0.12, 0.13), "legs": Color(0.12, 0.12, 0.13), "hair": Color(0.50, 0.48, 0.46), "hat": "brim", "prop": "none"},
	"rep_association": {"coat": Color(0.52, 0.30, 0.22), "legs": Color(0.24, 0.22, 0.20), "hair": Color(0.20, 0.16, 0.12), "hat": "cap", "prop": "none"},
	"rep_dix": {"coat": Color(0.66, 0.58, 0.44), "legs": Color(0.30, 0.28, 0.26), "hair": Color(0.26, 0.22, 0.18), "hat": "none", "prop": "bag"},
}

static var _cache: Dictionary = {}


static func figure(look_id: String, emotion: String = "neutral") -> ImageTexture:
	var key := "%s|%s" % [look_id, emotion]
	if _cache.has(key):
		return _cache[key]
	var look: Dictionary = LOOKS.get(look_id, LOOKS["dov"])
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var coat: Color = look["coat"]
	var legs: Color = look["legs"]
	var skin := SKIN
	var hx := 12          # head left x
	var hy := 4           # head top y
	var body_top := 14
	var arm_out := 0      # how far arms stand off the body
	var arm_len := 14
	var lean := 0         # body x shift
	match emotion:
		"afraid":
			hy = 8; body_top = 17; lean = 1; hx = 13
			skin = SKIN.lerp(Color(0.80, 0.84, 0.96), 0.45)
			coat = coat.lerp(Color(0.60, 0.64, 0.80), 0.18)
		"angry":
			arm_out = 3; hy = 5
			skin = SKIN.lerp(Color(0.86, 0.42, 0.36), 0.40)
		"corrupted":
			hx = 14; hy = 6; arm_len = 20; lean = -1
			skin = SKIN.lerp(CORRUPT, 0.55)
			coat = coat.lerp(CORRUPT, 0.35)
			legs = legs.lerp(CORRUPT, 0.25)

	# Legs.
	var leg_top := 33
	if bool(look.get("skirt", false)):
		_rect(img, 10 + lean, leg_top - 3, 12, 13, coat.darkened(0.1))
		_rect(img, 12 + lean, 44, 3, 3, INK)
		_rect(img, 17 + lean, 44, 3, 3, INK)
	else:
		var spread := 1 if emotion == "angry" else 0
		_rect(img, 11 + lean - spread, leg_top, 4, 12, legs)
		_rect(img, 17 + lean + spread, leg_top, 4, 12, legs)
		_rect(img, 10 + lean - spread, 45, 5, 2, INK)
		_rect(img, 17 + lean + spread, 45, 5, 2, INK)
	# Torso.
	_rect(img, 10 + lean, body_top, 12, leg_top - body_top + 1, coat)
	_rect(img, 10 + lean, body_top, 12, 2, coat.lightened(0.18))
	_rect(img, 15 + lean, body_top + 2, 1, leg_top - body_top - 2, coat.darkened(0.25))
	if bool(look.get("apron", false)):
		_rect(img, 12 + lean, body_top + 8, 8, leg_top - body_top - 6, Color(0.82, 0.78, 0.68))
	# Arms.
	if emotion == "afraid":
		# Drawn in across the chest.
		_rect(img, 9 + lean, body_top + 3, 3, 7, coat.darkened(0.15))
		_rect(img, 20 + lean, body_top + 3, 3, 7, coat.darkened(0.15))
		_rect(img, 11 + lean, body_top + 8, 10, 3, coat.darkened(0.2))
		_rect(img, 14 + lean, body_top + 8, 4, 3, skin)
	else:
		_rect(img, 7 + lean - arm_out, body_top + 1, 3, arm_len, coat.darkened(0.15))
		_rect(img, 22 + lean + arm_out, body_top + 1, 3, arm_len, coat.darkened(0.15))
		_rect(img, 7 + lean - arm_out, body_top + 1 + arm_len, 3, 3, skin)
		_rect(img, 22 + lean + arm_out, body_top + 1 + arm_len, 3, 3, skin)
	# Head.
	_rect(img, hx, hy, 8, 9, skin)
	_rect(img, hx + 1, hy + 9, 6, 2, skin.darkened(0.2))
	var hair: Color = look["hair"]
	match str(look["hat"]):
		"cap":
			_rect(img, hx - 1, hy - 1, 10, 3, hair.darkened(0.2))
			_rect(img, hx - 3, hy + 1, 4, 1, hair.darkened(0.3))
		"brim":
			_rect(img, hx - 3, hy, 14, 2, INK)
			_rect(img, hx, hy - 4, 8, 4, INK)
		"bun":
			_rect(img, hx, hy - 1, 8, 3, hair)
			_rect(img, hx + 6, hy - 3, 4, 4, hair)
		"scarf":
			_rect(img, hx - 1, hy - 1, 10, 3, hair)
			_rect(img, hx - 1, hy + 2, 2, 6, hair)
			_rect(img, 9 + lean, body_top, 14, 4, Color(0.34, 0.32, 0.36))
		_:
			_rect(img, hx, hy - 1, 8, 3, hair)
			_rect(img, hx, hy + 1, 1, 4, hair)
	if bool(look.get("beard", false)):
		_rect(img, hx + 1, hy + 6, 6, 4, hair)
	# Face: two eyes. Wide when afraid, a brow line when angry, none when corrupted.
	match emotion:
		"afraid":
			_rect(img, hx + 1, hy + 3, 2, 2, Color(0.96, 0.96, 0.98))
			_rect(img, hx + 5, hy + 3, 2, 2, Color(0.96, 0.96, 0.98))
			img.set_pixel(hx + 2, hy + 4, INK)
			img.set_pixel(hx + 6, hy + 4, INK)
		"angry":
			_rect(img, hx + 1, hy + 3, 6, 1, INK)
			img.set_pixel(hx + 2, hy + 4, INK)
			img.set_pixel(hx + 5, hy + 4, INK)
		"corrupted":
			_rect(img, hx + 1, hy + 4, 6, 1, CORRUPT.lightened(0.5))
		_:
			img.set_pixel(hx + 2, hy + 4, INK)
			img.set_pixel(hx + 5, hy + 4, INK)
	# Carried object (identity cue). Dropped when afraid or corrupted.
	if emotion == "neutral" or emotion == "angry":
		var px := 23 + lean + arm_out
		var py := body_top + arm_len
		match str(look["prop"]):
			"book":
				_rect(img, px - 1, py - 3, 5, 6, Color(0.50, 0.20, 0.16))
				_rect(img, px, py - 2, 3, 4, Color(0.90, 0.88, 0.80))
			"lantern":
				_rect(img, px, py + 2, 4, 5, Color(0.25, 0.22, 0.18))
				_rect(img, px + 1, py + 3, 2, 3, Color(1.0, 0.78, 0.36))
			"bag":
				_rect(img, px - 1, py + 2, 6, 5, Color(0.30, 0.20, 0.14))
			"tool":
				_rect(img, px + 1, py - 6, 1, 12, Color(0.55, 0.42, 0.26))
				_rect(img, px - 1, py - 7, 5, 2, Color(0.55, 0.56, 0.60))
			"level":
				_rect(img, px - 2, py + 1, 8, 2, Color(0.90, 0.80, 0.20))
			"leash":
				_rect(img, px + 1, py + 2, 1, 8, Color(0.60, 0.20, 0.20))
	if emotion == "corrupted":
		# The edge of the figure takes the colour of the hollow.
		for y in H:
			for x in W:
				if img.get_pixel(x, y).a > 0.0 and (x == 0 or img.get_pixel(x - 1, y).a == 0.0):
					img.set_pixel(x, y, CORRUPT.lightened(0.25))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## The Surveyor's Shadow: monochrome, value ~0.15, seen from far. frame: walk0 | walk1 | measure | mark.
static func surveyor(frame: String) -> ImageTexture:
	var key := "surveyor|" + frame
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(0.157, 0.157, 0.157)
	# Long coat, hat, no face.
	_rect(img, 11, 2, 10, 2, c)
	_rect(img, 13, 0, 6, 3, c)
	_rect(img, 13, 4, 6, 7, c)
	_rect(img, 10, 11, 12, 26, c)
	_rect(img, 9, 30, 14, 8, c)
	match frame:
		"walk0":
			_rect(img, 11, 38, 4, 9, c); _rect(img, 18, 38, 4, 7, c)
		"walk1":
			_rect(img, 11, 38, 4, 7, c); _rect(img, 18, 38, 4, 9, c)
		_:
			_rect(img, 11, 38, 4, 9, c); _rect(img, 17, 38, 4, 9, c)
	match frame:
		"measure":
			# A staff, held upright, sighted along.
			_rect(img, 25, 4, 1, 43, c)
			_rect(img, 22, 14, 4, 3, c)
		"mark":
			# One arm out, level.
			_rect(img, 0, 13, 11, 3, c)
			_rect(img, 22, 12, 3, 14, c)
		_:
			_rect(img, 7, 12, 3, 16, c); _rect(img, 22, 12, 3, 16, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Painted ground: one texture for the whole township. zone_at maps a world
## position to a zone id ("" outside). Paths are worn pale between the zones.
static func ground(size_px: int, world_half: float, zone_at: Callable, paths: Array) -> ImageTexture:
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 1911
	noise.frequency = 0.045
	var fine := FastNoiseLite.new()
	fine.seed = 77
	fine.frequency = 0.35
	const BASE := {
		"": Color(0.30, 0.34, 0.26),
		"zone_1": Color(0.44, 0.41, 0.33),
		"zone_2": Color(0.47, 0.45, 0.39),
		"zone_3": Color(0.40, 0.44, 0.36),
		"zone_4": Color(0.47, 0.42, 0.32),
		"zone_5": Color(0.15, 0.20, 0.17),
	}
	for py in size_px:
		for px in size_px:
			var wx := (float(px) / float(size_px) - 0.5) * 2.0 * world_half
			var wz := (float(py) / float(size_px) - 0.5) * 2.0 * world_half
			# Jitter the lookup so zone edges are ragged, not ruled.
			var j := noise.get_noise_2d(wx * 3.0, wz * 3.0) * 1.6
			var zone: String = zone_at.call(Vector3(wx + j, 0.0, wz - j))
			var col: Color = BASE.get(zone, BASE[""])
			var n := noise.get_noise_2d(wx, wz) * 0.07 + fine.get_noise_2d(wx, wz) * 0.035
			col = Color(col.r + n, col.g + n, col.b + n * 0.8)
			# Worn paths.
			var d := 999.0
			for seg in paths:
				d = minf(d, _seg_dist(Vector2(wx, wz), seg[0], seg[1]))
			if d < 1.3:
				col = col.lerp(Color(0.56, 0.52, 0.43), clampf(1.0 - d / 1.3, 0.0, 1.0) * 0.75)
			img.set_pixel(px, py, col)
	return ImageTexture.create_from_image(img)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(maxi(0, y), mini(H, y + h)):
		for xx in range(maxi(0, x), mini(W, x + w)):
			img.set_pixel(xx, yy, c)


## A flat material helper used all over the township.
static func mat(color: Color, rough: float = 1.0, emission: Color = Color(0, 0, 0), energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m
