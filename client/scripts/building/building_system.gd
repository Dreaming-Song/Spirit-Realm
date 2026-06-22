extends Node
## 建筑系统 — 网格建造，参考MC+Terraria+Dst的混合设计
##
## 核心机制：
## - 网格对齐（1x1单位）
## - 建筑有耐久度，可被破坏
## - 结构支撑逻辑（DST式：需要地基支撑）
## - 按境界解锁建筑等级
## - 大建筑自动合并为整体

class_name BuildingSystem

# ==================== 建筑块类型 ====================
enum PieceType {
	WALL,       # 墙（实体碰撞）
	FLOOR,      # 地板
	ROOF,       # 屋顶
	DOOR,       # 门（可开关）
	WINDOW,     # 窗
	STAIRS,     # 楼梯
	PILLAR,     # 柱子
	FOUNDATION, # 地基（必须放在地面上）
	FENCE,      # 栅栏
	DECORATION, # 装饰物
	STATION,    # 合成台/功能性建筑
	LIGHT,      # 光源
	CHEST,      # 储物箱
	BED,        # 床
}

# ==================== 材料等级 ====================
enum MaterialTier {
	THATCH,      # 茅草 — 凡人期
	WOOD,        # 木材 — 凡人期
	STONE,       # 石头 — 练气期
	BRICK,       # 灵砖 — 筑基期
	JADE,        # 灵石/玉 — 金丹期
	CRYSTAL,     # 玉晶 — 元婴期
	CELESTIAL,   # 星辰 — 化神期
	TRANSCENDENT, # 造化 — 大乘期+
}

# ==================== 材料数据 ====================
static func get_tier_data(tier: int) -> Dictionary:
	match tier:
		MaterialTier.THATCH:
			return {"name": "茅草", "hp": 50,  "color": Color(0.76, 0.60, 0.42)}
		MaterialTier.WOOD:
			return {"name": "木材", "hp": 100, "color": Color(0.55, 0.35, 0.15)}
		MaterialTier.STONE:
			return {"name": "石料", "hp": 200, "color": Color(0.50, 0.50, 0.50)}
		MaterialTier.BRICK:
			return {"name": "灵砖", "hp": 400, "color": Color(0.60, 0.45, 0.70)}
		MaterialTier.JADE:
			return {"name": "灵石", "hp": 800, "color": Color(0.30, 0.80, 0.60)}
		MaterialTier.CRYSTAL:
			return {"name": "玉晶", "hp": 1500, "color": Color(0.40, 0.60, 1.00)}
		MaterialTier.CELESTIAL:
			return {"name": "星辰", "hp": 3000, "color": Color(1.00, 0.85, 0.40)}
		MaterialTier.TRANSCENDENT:
			return {"name": "造化", "hp": 6000, "color": Color(1.00, 0.50, 0.80)}
	return {"name": "未知", "hp": 50, "color": Color.WHITE}

# ==================== 建筑块预制体数据 ====================
static func get_piece_data(piece_type: int, tier: int) -> Dictionary:
	var base_data = {
		"hp": get_tier_data(tier).hp,
		"width": 1.0,
		"height": 1.0,
		"depth": 0.1 if piece_type in [PieceType.WALL, PieceType.DOOR] else 1.0,
		"collision": piece_type in [PieceType.WALL, PieceType.DOOR, PieceType.PILLAR, PieceType.FOUNDATION],
		"light_pass": piece_type == PieceType.WINDOW,
		"can_stack": piece_type in [PieceType.WALL, PieceType.FLOOR, PieceType.PILLAR],
		"grid_size": 1.0,
	}
	
	# 特殊类型数据
	match piece_type:
		PieceType.DOOR:
			base_data.width = 0.8
			base_data.openable = true
		PieceType.STAIRS:
			base_data.width = 1.0
			base_data.height = 0.5
			base_data.slope = true
	
	return base_data

# ==================== 运行时 ====================

## 已放置的建筑 {grid_key: BuildingPiece}
var _placed_pieces: Dictionary = {}
var _piece_counter: int = 0

## 网格尺寸
var grid_size: float = 1.0
var build_range: float = 8.0  # 玩家可放置距离

@onready var _player_ref: Node3D

signal piece_placed(piece_id: String, piece_type: int, tier: int, position: Vector3)
signal piece_destroyed(piece_id: String, piece_type: int, position: Vector3)
signal piece_damaged(piece_id: String, hp: int, max_hp: int)

# ==================== 放置建筑 ====================

## 尝试放置建筑块
## 返回 {success: bool, reason: string}
func try_place(piece_type: int, tier: int, position: Vector3, rotation: float = 0.0) -> Dictionary:
	# 1. 网格对齐
	var grid_pos = _snap_to_grid(position)
	var grid_key = _grid_key(grid_pos)
	
	# 2. 检查是否已被占用
	if _placed_pieces.has(grid_key):
		return {"success": false, "reason": "该位置已有建筑"}
	
	# 3. 检查支撑（非地基需要下方有支撑）
	if piece_type != PieceType.FOUNDATION:
		var below_key = _grid_key(grid_pos + Vector3(0, -grid_size, 0))
		if not _placed_pieces.has(below_key):
			var below_type = _placed_pieces.get(below_key, {}).get("type", -1)
			if below_type not in [PieceType.FOUNDATION, PieceType.FLOOR, PieceType.WALL]:
				return {"success": false, "reason": "需要下方有支撑"}
	
	# 4. 检查范围
	if _player_ref:
		var dist = grid_pos.distance_to(_player_ref.global_position)
		if dist > build_range:
			return {"success": false, "reason": "距离太远"}
	
	# 5. 检查材料（通过CraftingSystem消耗）
	# 假设调用方已处理材料消耗
	
	# 6. 创建建筑块
	var piece = _create_piece(piece_type, tier, grid_pos, rotation)
	if not piece:
		return {"success": false, "reason": "建筑块创建失败"}
	
	_placed_pieces[grid_key] = piece
	
	piece_placed.emit(piece.id, piece_type, tier, grid_pos)
	print("🏗️ 放置 %s %s 于 (%d, %d, %d)" % [
		get_tier_data(tier).name, _get_piece_name(piece_type),
		int(grid_pos.x), int(grid_pos.y), int(grid_pos.z)
	])
	
	return {"success": true, "piece": piece}

## 拆除建筑
func demolish(grid_pos: Vector3) -> Dictionary:
	var grid_key = _grid_key(grid_pos)
	if not _placed_pieces.has(grid_key):
		return {"success": false, "reason": "该位置没有建筑"}
	
	var piece = _placed_pieces[grid_key]
	_placed_pieces.erase(grid_key)
	
	# 返还部分材料（50%）
	# TODO: 调用CraftingSystem返还
	
	piece_destroyed.emit(piece.id, piece.type, grid_pos)
	print("💥 拆除建筑于 (%d, %d, %d)" % [int(grid_pos.x), int(grid_pos.y), int(grid_pos.z)])
	
	return {"success": true}

# ==================== 建筑交互 ====================

## 开关门
func toggle_door(grid_pos: Vector3) -> bool:
	var piece = _placed_pieces.get(_grid_key(grid_pos))
	if not piece or piece.type != PieceType.DOOR:
		return false
	piece.is_open = not piece.is_open
	return true

## 建筑受击
func damage_piece(grid_pos: Vector3, damage: int) -> void:
	var piece = _placed_pieces.get(_grid_key(grid_pos))
	if not piece:
		return
	
	piece.hp -= damage
	piece_damaged.emit(piece.id, piece.hp, piece.max_hp)
	
	if piece.hp <= 0:
		demolish(grid_pos)

# ==================== 内部 ====================

## 网格对齐
func _snap_to_grid(pos: Vector3) -> Vector3:
	return Vector3(
		floor(pos.x / grid_size + 0.5) * grid_size,
		floor(pos.y / grid_size + 0.5) * grid_size,
		floor(pos.z / grid_size + 0.5) * grid_size
	)

func _grid_key(pos: Vector3) -> String:
	return "%d_%d_%d" % [int(pos.x / grid_size), int(pos.y / grid_size), int(pos.z / grid_size)]

func _create_piece(piece_type: int, tier: int, position: Vector3, rotation: float) -> Dictionary:
	_piece_counter += 1
	return {
		"id": "piece_%d" % _piece_counter,
		"type": piece_type,
		"tier": tier,
		"position": position,
		"rotation": rotation,
		"hp": get_tier_data(tier).hp,
		"max_hp": get_tier_data(tier).hp,
		"is_open": false,
		"created_at": Time.get_ticks_msec(),
		"grid_key": _grid_key(position),
	}

static func _get_piece_name(t: int) -> String:
	match t:
		PieceType.WALL: return "墙"
		PieceType.FLOOR: return "地板"
		PieceType.ROOF: return "屋顶"
		PieceType.DOOR: return "门"
		PieceType.WINDOW: return "窗"
		PieceType.STAIRS: return "楼梯"
		PieceType.PILLAR: return "柱子"
		PieceType.FOUNDATION: return "地基"
		PieceType.FENCE: return "栅栏"
		PieceType.DECORATION: return "装饰"
		PieceType.STATION: return "功能台"
		PieceType.LIGHT: return "灯具"
		PieceType.CHEST: return "箱子"
		PieceType.BED: return "床"
	return "未知"

# ==================== 查询 ====================

## 获取指定位置建筑
func get_piece_at(pos: Vector3) -> Dictionary:
	return _placed_pieces.get(_grid_key(pos), {})

## 获取区域内所有建筑
func get_pieces_in_area(center: Vector3, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var r = int(radius / grid_size)
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			for z in range(-r, r + 1):
				var pos = center + Vector3(x * grid_size, y * grid_size, z * grid_size)
				var piece = _placed_pieces.get(_grid_key(pos))
				if piece:
					result.append(piece)
	return result

## 获取已放置总数
func get_total_pieces() -> int:
	return _placed_pieces.size()

## 按类型统计
func get_piece_count_by_type() -> Dictionary:
	var counts: Dictionary = {}
	for piece in _placed_pieces.values():
		var t = piece.type
		counts[t] = counts.get(t, 0) + 1
	return counts

# ==================== 存档 ====================

func get_save_data() -> Dictionary:
	return {
		"placed_pieces": _placed_pieces,
		"piece_counter": _piece_counter,
	}

func load_save_data(data: Dictionary) -> void:
	_placed_pieces = data.get("placed_pieces", {})
	_piece_counter = data.get("piece_counter", 0)
