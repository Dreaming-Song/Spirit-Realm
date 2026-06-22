## 程序化方块纹理生成
## 无需外部图片资源，运行时生成所有方块纹理
## 与 BuildingSystem.PieceType 枚举对应

class_name BuildingTextures

# 纹理像素尺寸
const TEXTURE_SIZE: int = 64

## 生成指定方块类型的纹理
static func generate(piece_type: int) -> ImageTexture:
	var img = Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	
	var light := Color(1.0, 1.0, 1.0)
	var dark := Color(0.7, 0.7, 0.7)
	
	match piece_type:
		BuildingSystem.PieceType.WALL:
			_generate_wall_texture(img, light, dark)
		BuildingSystem.PieceType.FLOOR:
			_generate_floor_texture(img, light, dark)
		BuildingSystem.PieceType.FOUNDATION:
			_generate_foundation_texture(img)
		BuildingSystem.PieceType.ROOF:
			_generate_roof_texture(img, light)
		BuildingSystem.PieceType.PILLAR:
			_generate_pillar_texture(img)
		BuildingSystem.PieceType.DOOR:
			_generate_wall_texture(img, light, dark)  # 门复用墙纹理
		_:
			_generate_default_texture(img)
	
	return ImageTexture.create_from_image(img)

# ==================== 各类型纹理生成 ====================

static func _generate_wall_texture(img: Image, light: Color, dark: Color) -> void:
	"""砖墙图案：交错排砖"""
	var size = img.get_size().x
	var brick_h = size / 8
	var brick_w = size / 4
	
	for row in range(8):
		var offset = (brick_w / 2) if row % 2 == 0 else 0
		for col in range(4):
			var x0 = col * brick_w + offset
			var y0 = row * brick_h
			var c = dark if (row + col) % 2 == 0 else light
			for x in range(brick_w - 1):
				for y in range(brick_h - 1):
					var px = x0 + x
					var py = y0 + y
					if px < size and py < size:
						img.set_pixel(px, py, c)
			# 砖缝
			for x in range(brick_w):
				if x0 + x < size:
					img.set_pixel(x0 + x, y0 + brick_h - 2, Color(0.2, 0.15, 0.1))

static func _generate_floor_texture(img: Image, light: Color, dark: Color) -> void:
	"""木地板：纵向木板条"""
	var size = img.get_size().x
	var plank_w = size / 8
	
	for i in range(8):
		var x0 = i * plank_w
		var c = light if i % 2 == 0 else dark
		for x in range(plank_w - 1):
			for y in range(size):
				var px = x0 + x
				var noise = 0.05 * sin(y * 0.3 + i * 1.2)
				var final_c = Color(
					clamp(c.r + noise, 0.0, 1.0),
					clamp(c.g + noise * 0.7, 0.0, 1.0),
					clamp(c.b + noise * 0.5, 0.0, 1.0)
				)
				img.set_pixel(px, y, final_c)
		# 木板缝隙
		for y in range(size):
			img.set_pixel(x0 + plank_w - 1, y, Color(0.15, 0.1, 0.05))

static func _generate_foundation_texture(img: Image) -> void:
	"""碎石/鹅卵石：随机斑点"""
	var size = img.get_size().x
	for x in range(size):
		for y in range(size):
			var noise = sin(x * 0.3) * cos(y * 0.25) * 0.15
			var c = Color(0.6 + noise, 0.58 + noise, 0.55 + noise)
			img.set_pixel(x, y, c)
	# 随机石子
	for _i in range(40):
		var sx = randi() % size
		var sy = randi() % size
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var px = sx + dx
				var py = sy + dy
				if px >= 0 and px < size and py >= 0 and py < size:
					img.set_pixel(px, py, Color(0.45, 0.4, 0.35))

static func _generate_roof_texture(img: Image, base_color: Color) -> void:
	"""瓦片图案：半圆叠瓦"""
	var size = img.get_size().x
	var tile_r = 6
	
	for row in range(0, size, tile_r * 2):
		var offset_x = tile_r if (row / (tile_r * 2)) as int % 2 == 1 else 0
		for col in range(offset_x, size, tile_r * 2):
			# 瓦片半圆
			for dx in range(-tile_r, tile_r):
				for dy in range(-tile_r, 0):
					if dx * dx + dy * dy < tile_r * tile_r:
						var px = col + dx
						var py = row + dy + tile_r
						if px >= 0 and px < size and py >= 0 and py < size:
							img.set_pixel(px, py, base_color)
			# 瓦片下缘阴影
			for dx in range(-tile_r, tile_r):
				var px = col + dx
				var py = row + tile_r
				if px >= 0 and px < size and py >= 0 and py < size:
					img.set_pixel(px, py, Color(0.3, 0.25, 0.2))

static func _generate_pillar_texture(img: Image) -> void:
	"""大理石纹：流动条纹"""
	var size = img.get_size().x
	for x in range(size):
		for y in range(size):
			var noise = sin(x * 0.2 + y * 0.15) * cos(x * 0.1 - y * 0.2) * 0.1
			var c = Color(0.85 + noise, 0.82 + noise, 0.78 + noise)
			img.set_pixel(x, y, c)
	# 细纹
	for _i in range(15):
		var bx = randi() % size
		var by = randi() % size
		var angle = randf() * PI
		for t in range(20):
			var px = bx + int(cos(angle) * t)
			var py = by + int(sin(angle) * t)
			if px >= 0 and px < size and py >= 0 and py < size:
				img.set_pixel(px, py, Color(0.6, 0.58, 0.55))

static func _generate_default_texture(img: Image) -> void:
	"""细砂纹理（兜底）"""
	var size = img.get_size().x
	for x in range(size):
		for y in range(size):
			var noise = sin(x * 0.5 + y * 0.3) * 0.08
			var c = Color(0.75 + noise, 0.72 + noise, 0.68 + noise)
			img.set_pixel(x, y, c)
