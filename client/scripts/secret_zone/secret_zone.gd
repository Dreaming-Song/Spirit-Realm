extends Node3D
## 宗门秘境 - Phase 4
## 物理解谜关卡：五行法术触发机关、巨石推动、平台升降

signal puzzle_solved(puzzle_id: String)
signal zone_cleared(zone_name: String)
signal treasure_found(treasure_name: String)

# ---------- 谜题类型 ----------
enum PuzzleType {
	WEIGHT_PLATE,   # 重量机关 - 需要巨石/玩家站上石板
	ELEMENT_GATE,   # 元素门 - 需要用对应法术攻击开门
	LIGHT_BEAM,     # 光束折射 - 调整镜子角度
	MATCH_SEQUENCE, # 顺序激活 - 按正确顺序踩踏/攻击
	TIMING_DODGE,   # 限时躲避 - 躲避机关触发
}

# ---------- 秘境配置 ----------
@export var zone_name: String = "灵药谷秘境"
@export var required_level: int = 3
@export var entry_position: Vector3 = Vector3.ZERO
@export var exit_position: Vector3 = Vector3(0, 0, 50)

var is_cleared: bool = false
var puzzles: Array = []
var time_limit: float = 0.0  # 0 = 不限时
var player_inside: bool = false
var entry_timer: float = 0.0

@onready var player_ref: Node = get_tree().get_first_node_in_group("player")
@onready var zone_trigger: Area3D = $ZoneTrigger
@onready var treasure_spawn: Node3D = $TreasureSpawn

func _ready() -> void:
	_init_puzzles()

func _init_puzzles() -> void:
	"""初始化秘境谜题"""
	# 谜题1: 重量机关 - 推巨石到石板上
	puzzles.append(_create_puzzle({
		"id": "puzzle_weight",
		"type": PuzzleType.WEIGHT_PLATE,
		"description": "将巨石推到石板上开启通道",
		"position": Vector3(5, 0, 10),
	}))

	# 谜题2: 元素门 - 用对应法术攻击开门
	puzzles.append(_create_puzzle({
		"id": "puzzle_fire_gate",
		"type": PuzzleType.ELEMENT_GATE,
		"description": "使用烈焰诀攻击火门",
		"position": Vector3(0, 0, 20),
		"element": "FIRE",
	}))

	# 谜题3: 顺序激活 - 按金-木-水-火-土顺序踩踏
	puzzles.append(_create_puzzle({
		"id": "puzzle_elements",
		"type": PuzzleType.MATCH_SEQUENCE,
		"description": "按五行相生顺序激活法阵：金→木→水→火→土",
		"position": Vector3(-5, 0, 30),
		"sequence": ["METAL", "WOOD", "WATER", "FIRE", "EARTH"],
	}))

# ===================== 谜题数据结构 =====================

class Puzzle:
	var id: String
	var type: int
	var description: String
	var position: Vector3
	var is_solved: bool = false
	# 元素门专用
	var element: String = ""
	# 顺序激活专用
	var sequence: Array = []
	var current_index: int = 0

func _create_puzzle(data: Dictionary) -> Puzzle:
	var p = Puzzle.new()
	p.id = data.id
	p.type = data.type
	p.description = data.description
	p.position = data.position
	p.element = data.get("element", "")
	p.sequence = data.get("sequence", [])
	return p

# ===================== 秘境入口/出口 =====================

func _on_zone_entered(body: Node) -> void:
	"""玩家进入秘境"""
	if body.is_in_group("player"):
		player_inside = true
		player_ref = body
		print("🏯 进入秘境: " + zone_name)
		# 检查等级要求
		# if player_ref has level check...

func _on_zone_exited(body: Node) -> void:
	"""玩家离开秘境"""
	if body.is_in_group("player"):
		player_inside = false

# ===================== 谜题交互 =====================

func interact_with_puzzle(puzzle_id: String, interaction_type: String, data: Dictionary = {}) -> bool:
	"""外部调用：玩家与谜题交互"""
	for p in puzzles:
		if p.id != puzzle_id or p.is_solved:
			continue

		var solved = false
		match p.type:
			PuzzleType.WEIGHT_PLATE:
				solved = _handle_weight_plate(p, data)
			PuzzleType.ELEMENT_GATE:
				solved = _handle_element_gate(p, data)
			PuzzleType.MATCH_SEQUENCE:
				solved = _handle_match_sequence(p, data)
			PuzzleType.LIGHT_BEAM:
				solved = _handle_light_beam(p, data)

		if solved:
			p.is_solved = true
			puzzle_solved.emit(p.id)
			_on_puzzle_solved(p)
			return true
	return false

func _handle_weight_plate(puzzle: Puzzle, data: Dictionary) -> bool:
	"""重量机关：检测是否有足够的重量压在板上"""
	var weight = data.get("weight", 0)
	# 玩家站上 = 80，巨石 = 500
	return weight >= 80

func _handle_element_gate(puzzle: Puzzle, data: Dictionary) -> bool:
	"""元素门：使用对应法术攻击"""
	var spell_type = data.get("spell_type", "")
	return spell_type == puzzle.element

func _handle_match_sequence(puzzle: Puzzle, data: Dictionary) -> bool:
	"""顺序激活：按五行相生顺序"""
	var activated_element = data.get("element", "")
	var expected = puzzle.sequence[puzzle.current_index]

	if activated_element == expected:
		puzzle.current_index += 1
		print("✅ 法阵 %s 激活 (%d/%d)" % [activated_element, puzzle.current_index, puzzle.sequence.size()])
		if puzzle.current_index >= puzzle.sequence.size():
			return true
	return false

func _handle_light_beam(puzzle: Puzzle, data: Dictionary) -> bool:
	"""光束折射：调整镜子到正确角度"""
	var angle = data.get("angle", 0)
	var correct = data.get("correct_angle", 0)
	return abs(angle - correct) < 5.0

# ===================== 谜题完成反馈 =====================

func _on_puzzle_solved(puzzle: Puzzle) -> void:
	"""谜题完成时触发机关"""
	match puzzle.id:
		"puzzle_weight":
			# 打开一扇石门
			_animate_gate_open(puzzle.position + Vector3(0, 1, 5))
		"puzzle_fire_gate":
			# 火门消失
			_animate_gate_open(puzzle.position)
		"puzzle_elements":
			# 中心高台升起，出现宝箱
			_spawn_treasure()

	# 检查是否全部谜题完成
	if _all_puzzles_solved():
		_clear_zone()

func _animate_gate_open(position: Vector3) -> void:
	"""石门打开动画"""
	print("🗿 石门打开: " + str(position))
	# TODO: Tween 动画，门体下移/消失

func _spawn_treasure() -> void:
	"""生成宝箱"""
	print("🎁 宝箱出现！")
	# TODO: 实例化宝箱节点
	treasure_found.emit(zone_name + "宝箱")

func _all_puzzles_solved() -> bool:
	for p in puzzles:
		if not p.is_solved:
			return false
	return true

func _clear_zone() -> void:
	"""秘境通关"""
	is_cleared = true
	zone_cleared.emit(zone_name)
	print("🏆 秘境通关: " + zone_name)
	# TODO: 出口传送门开启

# ===================== 秘境退出 =====================

func exit_zone(player: Node) -> void:
	"""传送玩家到出口"""
	player.global_position = exit_position
	player_inside = false

func get_progress() -> Dictionary:
	"""获取秘境进度"""
	return {
		"zone_name": zone_name,
		"is_cleared": is_cleared,
		"puzzles_solved": _count_solved(),
		"puzzles_total": puzzles.size(),
	}

func _count_solved() -> int:
	var count = 0
	for p in puzzles:
		if p.is_solved:
			count += 1
	return count

# ===================== 存档接口 =====================

func get_save_data() -> Dictionary:
	return {
		"is_cleared": is_cleared,
		"solved_puzzles": [p.id for p in puzzles if p.is_solved],
		"player_inside": player_inside,
	}

func load_save_data(data: Dictionary) -> void:
	is_cleared = data.get("is_cleared", false)
	var solved_ids = data.get("solved_puzzles", [])
	for p in puzzles:
		if p.id in solved_ids:
			p.is_solved = true
	player_inside = data.get("player_inside", false)
