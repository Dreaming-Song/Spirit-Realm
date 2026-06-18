extends Node
## 存档系统 - Phase 2
## 本地 JSON 存档（模拟 SQLite，后续可对接 Python 后端）

signal save_completed(slot_name: String)
signal load_completed(slot_name: String)

# ---------- 存档槽 ----------
const SAVE_DIR: String = "user://saves/"
const MAX_SLOTS: int = 5

# ---------- 引用 ----------
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player")
@onready var alchemy_system: Node = get_node_or_null("/root/Main/AlchemySystem")
@onready var pet: Node = get_tree().get_first_node_in_group("pets")

func _ready() -> void:
	DirAccess.make_dir_recursive(SAVE_DIR)

# ===================== 存档 =====================

func save_game(slot_index: int) -> bool:
	"""保存到指定存档槽 (0~4)"""
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return false

	var data: Dictionary = _collect_save_data()
	var file_path: String = SAVE_DIR + "slot_%d.json" % slot_index

	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("存档写入失败: " + file_path)
		return false

	file.store_string(JSON.stringify(data, "  "))
	file.close()

	save_completed.emit("slot_%d" % slot_index)
	return true

func _collect_save_data() -> Dictionary:
	"""收集所有可存档数据"""
	var data: Dictionary = {
		"version": "0.1.0",
		"timestamp": Time.get_unix_time_from_system(),
		"player": {},
		"alchemy": {},
		"pets": [],
	}

	# 玩家数据
	if player and player.has_method("get_current_state"):
		data.player = player.get_current_state()

	# 炼丹数据
	if alchemy_system and alchemy_system.has_method("get_save_data"):
		data.alchemy = alchemy_system.get_save_data()

	# 灵宠数据
	if pet and pet.has_method("get_save_data"):
		data.pets.append(pet.get_save_data())

	return data

# ===================== 读档 =====================

func load_game(slot_index: int) -> bool:
	"""从存档槽读取"""
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return false

	var file_path: String = SAVE_DIR + "slot_%d.json" % slot_index
	if not FileAccess.file_exists(file_path):
		push_warning("存档不存在: " + file_path)
		return false

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false

	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(text)
	if parse_result != OK:
		push_error("存档解析失败")
		return false

	_apply_save_data(json.data)
	load_completed.emit("slot_%d" % slot_index)
	return true

func _apply_save_data(data: Dictionary) -> void:
	"""应用存档数据"""
	if data.has("player") and player and player.has_method("set_state"):
		player.set_state(data.player)

	if data.has("alchemy") and alchemy_system and alchemy_system.has_method("load_save_data"):
		alchemy_system.load_save_data(data.alchemy)

	if data.has("pets") and pet and pet.has_method("load_save_data"):
		pet.load_save_data(data.pets[0])

# ===================== 存档管理 =====================

func get_slot_info(slot_index: int) -> Dictionary:
	"""读取某个存档槽的摘要信息"""
	var file_path: String = SAVE_DIR + "slot_%d.json" % slot_index
	if not FileAccess.file_exists(file_path):
		return { "exists": false }

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	json.parse(text)

	return {
		"exists": true,
		"timestamp": json.data.get("timestamp", 0),
		"version": json.data.get("version", ""),
		"player_name": json.data.get("player", {}).get("name", "无名侠客"),
		"level": json.data.get("player", {}).get("level", 1),
		"play_time": json.data.get("player", {}).get("play_time", 0),
	}

func delete_slot(slot_index: int) -> bool:
	"""删除存档"""
	var file_path: String = SAVE_DIR + "slot_%d.json" % slot_index
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		return true
	return false

func get_save_list() -> Array:
	"""获取所有存档槽状态"""
	var list: Array = []
	for i in range(MAX_SLOTS):
		list.append(get_slot_info(i))
	return list
