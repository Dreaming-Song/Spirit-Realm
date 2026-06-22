extends Node
## 游戏核心管理器 — 串联所有子系统的指挥中心
##
## 职责：
## 1. 初始化所有子系统（顺序依赖）
## 2. 管理游戏状态（运行中/暂停/存档）
## 3. 连接子系统间的信号通道
## 4. 全局游戏循环 tick

class_name GameManager

# ==================== 游戏状态 ====================
enum GameState {
	INIT,           # 初始化中
	MAIN_MENU,      # 主菜单
	LOADING,        # 加载中
	PLAYING,        # 游戏中
	PAUSED,         # 暂停
	SAVING,         # 存档中
	QUITTING,       # 退出中
}

var current_state: int = GameState.INIT
var game_time: float = 0.0          # 游戏总运行时间（秒）
var day_time: float = 0.0           # 白天时间（0~24000，MC式）
var world_data: Dictionary = {}     # 世界数据

# ==================== 引用所有子系统 ====================
var realm: RealmSystem
var cultivation: CultivationSystem
var inventory: InventorySystem
var crafting: CraftingSystem
var building: BuildingSystem
var skill_manager: SkillManager
var map_gen: MapGenerator
var player: Node3D

# ==================== 信号 ====================
signal game_state_changed(old_state: int, new_state: int)
signal game_initialized()
signal day_night_changed(is_day: bool, time: float)
signal player_died()
signal world_loaded(world_data: Dictionary)

func _ready() -> void:
	_initialize_systems()

func _process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return
	
	game_time += delta
	day_time = fmod(game_time * 0.5, 24000.0)  # 1秒=0.5游戏刻
	
	# 昼夜信号（每整刻触发一次）
	if int(day_time) % 100 == 0:
		day_night_changed.emit(day_time > 12000, day_time)

# ==================== 初始化管线 ====================

func _initialize_systems() -> void:
	print("🚀 游戏初始化开始...")
	current_state = GameState.INIT
	
	# 1. 境界系统（最底层，其他系统依赖它判断解锁）
	realm = RealmSystem.new()
	add_child(realm)
	print("  ✅ RealmSystem")
	
	# 2. 修行系统（流派等级、技能解锁）
	cultivation = CultivationSystem.new()
	add_child(cultivation)
	print("  ✅ CultivationSystem")
	
	# 3. 物品数据库（纯静态，无需初始化）
	print("  ✅ ItemDatabase (static)")
	
	# 4. 背包系统
	inventory = InventorySystem.new()
	add_child(inventory)
	print("  ✅ InventorySystem")
	
	# 5. 合成系统
	crafting = CraftingSystem.new()
	add_child(crafting)
	print("  ✅ CraftingSystem")
	
	# 6. 建筑系统
	building = BuildingSystem.new()
	add_child(building)
	print("  ✅ BuildingSystem")
	
	# 7. 技能管理器
	skill_manager = SkillManager.new()
	add_child(skill_manager)
	print("  ✅ SkillManager")
	
	# 8. 地图生成器
	map_gen = MapGenerator.new()
	add_child(map_gen)
	map_gen.world_seed = randi()
	print("  ✅ MapGenerator")
	
	# 连接信号通路
	_connect_signals()
	
	game_initialized.emit()
	print("🎮 游戏初始化完成！进入主菜单")
	current_state = GameState.MAIN_MENU

func _connect_signals() -> void:
	"""跨系统信号通道"""
	# 境界突破 → 解锁新合成配方
	realm.realm_changed.connect(_on_realm_changed)
	
	# 背包变更 → 更新HUD
	inventory.inventory_changed.connect(_on_inventory_changed)
	
	# 合成完成 → 更新背包
	crafting.item_crafted.connect(_on_item_crafted)
	
	# 建筑放置 → 消耗背包材料
	building.piece_placed.connect(_on_piece_placed)

# ==================== 游戏生命周期 ====================

## 开始新游戏
func start_new_game() -> void:
	current_state = GameState.LOADING
	
	# 生成世界
	world_data = map_gen.generate_world()
	world_loaded.emit(world_data)
	
	# 设置出生点
	var spawn = world_data.get("spawn_point", Vector3(0, 1, 0))
	print("🌍 世界生成完毕，出生点: (%d, %d, %d)" % [spawn.x, spawn.y, spawn.z])
	
	# 初始背包：送一套新手装备
	inventory.add_item("stone_axe", 1)
	inventory.add_item("stone_pickaxe", 1)
	inventory.add_item("wooden_sword", 1)
	inventory.add_item("torch", 8)
	inventory.add_item("herb_common", 5)
	
	# 给一些初始修行点数
	cultivation.cultivation_points = 3
	
	current_state = GameState.PLAYING
	game_state_changed.emit(GameState.LOADING, GameState.PLAYING)
	print("🎮 进入游戏！")

## 暂停/恢复
func toggle_pause() -> void:
	match current_state:
		GameState.PLAYING:
			current_state = GameState.PAUSED
			game_state_changed.emit(GameState.PLAYING, GameState.PAUSED)
		GameState.PAUSED:
			current_state = GameState.PLAYING
			game_state_changed.emit(GameState.PAUSED, GameState.PLAYING)

## 存档
func save_game(slot: int = 0) -> bool:
	if current_state not in [GameState.PLAYING, GameState.PAUSED]:
		return false
	
	current_state = GameState.SAVING
	
	var save_data = {
		"version": "0.1",
		"game_time": game_time,
		"world_seed": map_gen.world_seed,
		"realm": realm.get_save_data(),
		"cultivation": cultivation.get_save_data(),
		"inventory": inventory.get_save_data(),
		"building": building.get_save_data(),
	}
	
	# 调用存档系统
	var save_sys = get_node("/root/SaveSystem")
	if save_sys:
		var ok = save_sys.save_game(save_data, slot)
		print("💾 存档到槽位 %d %s" % [slot, "成功" if ok else "失败"])
	else:
		# 无存档系统，存本地文件
		var file = FileAccess.open("user://save_%d.json" % slot, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(save_data))
			file.close()
			print("💾 存档到文件 save_%d.json" % slot)
	
	current_state = GameState.PLAYING
	return true

## 读档
func load_game(slot: int = 0) -> bool:
	current_state = GameState.LOADING
	
	var save_sys = get_node("/root/SaveSystem")
	var save_data = {}
	
	if save_sys:
		save_data = save_sys.load_game(slot)
	else:
		if not FileAccess.file_exists("user://save_%d.json" % slot):
			return false
		var file = FileAccess.open("user://save_%d.json" % slot, FileAccess.READ)
		if file:
			save_data = JSON.parse_string(file.get_as_text())
			file.close()
	
	if save_data.is_empty():
		return false
	
	# 恢复各系统
	game_time = save_data.get("game_time", 0.0)
	map_gen.world_seed = save_data.get("world_seed", randi())
	realm.load_save_data(save_data.get("realm", {}))
	cultivation.load_save_data(save_data.get("cultivation", {}))
	inventory.load_save_data(save_data.get("inventory", {}))
	building.load_save_data(save_data.get("building", {}))
	
	# 重新生成世界
	world_data = map_gen.generate_world()
	world_loaded.emit(world_data)
	
	current_state = GameState.PLAYING
	game_state_changed.emit(GameState.LOADING, GameState.PLAYING)
	print("📂 读档完成！")
	return true

# ==================== 信号处理 ====================

func _on_realm_changed(old_realm: int, new_realm: int, name: String) -> void:
	print("🌟 境界突破！%s" % name)
	# 突破后自动解锁新技能
	if cultivation:
		var unlocks = realm.get_current_unlocks()
		for unlock in unlocks:
			print("  解锁: %s" % unlock)

func _on_inventory_changed(slot: int, item_id: String, count: int) -> void:
	pass  # HUD 会更新

func _on_item_crafted(recipe_id: String, result_id: String, count: int) -> void:
	var name = ItemDatabase.get_item_name(result_id)
	print("🛠️ 合成完成: %s × %d" % [name, count])

func _on_piece_placed(piece_id: String, piece_type: int, tier: int, pos: Vector3) -> void:
	pass  # 更新世界数据

# ==================== 玩家操作入口 ====================

## 采集资源
func gather_resource(resource_id: String, count: int = 1) -> void:
	var item_data = ItemDatabase.get_item(resource_id)
	if item_data.is_empty():
		return
	
	# 检查工具
	if item_data.get("gatherable", false):
		var needed_tool = item_data.get("gather_tool", "hand")
		var needed_tier = item_data.get("gather_tier", 0)
		var equipped_tool = inventory.get_equipped_tool()
		var tool_tier = ItemDatabase.get_tier(equipped_tool)
		
		if tool_tier < needed_tier:
			print("⚠️ 需要更高级的工具采集 %s（需%d级，当前%d级）" % 
				[item_data.name, needed_tier, tool_tier])
			return
		
		# 消耗工具耐久
		if not equipped_tool.is_empty():
			var tool_slot = _find_equipped_tool_slot()
			if tool_slot >= 0:
				inventory.use_durability(tool_slot, 1)
	
	# 实际添加物品
	var added = inventory.add_item(resource_id, count)
	if added > 0:
		# 获得少量修为
		var xp_gained = count * 2
		realm.add_cultivation_xp(xp_gained)
		cultivation.add_cultivation_xp(xp_gained)
		print("🌿 采集 %s × %d (+%d修为)" % [item_data.name, added, xp_gained])

func _find_equipped_tool_slot() -> int:
	var tool_id = inventory.get_equipped_tool()
	if tool_id.is_empty():
		return -1
	for i in range(inventory.get_all_slots().size()):
		var slot = inventory.get_slot(i)
		if slot.item_id == tool_id and slot.count > 0:
			return i
	return -1

## 建造建筑
func place_building(item_id: String, position: Vector3) -> Dictionary:
	var item_data = ItemDatabase.get_item(item_id)
	if not item_data.get("buildable", false) and not item_data.get("placeable", false):
		return {"success": false, "reason": "该物品不可放置"}
	
	# 消耗背包中的建筑块
	if not inventory.has_item(item_id, 1):
		return {"success": false, "reason": "材料不足"}
	
	# 告诉建筑系统放置
	var piece_type = item_data.get("piece_type", 0)
	var piece_tier = item_data.get("piece_tier", 0)
	var result = building.try_place(piece_type, piece_tier, position)
	
	if result.success:
		inventory.remove_item(item_id, 1)
	
	return result

## 合成物品
func craft_item(recipe_id: String, count: int = 1) -> Dictionary:
	return crafting.craft(recipe_id, count)

## 使用物品
func use_item(slot_index: int) -> Dictionary:
	var result = inventory.use_item(slot_index)
	if result.success:
		# 使用丹药获得修为
		if result.effects.has("hp_restore"):
			print("💚 恢复 %d 生命" % result.effects.hp_restore)
		if result.effects.has("mp_restore"):
			print("💙 恢复 %d 法力" % result.effects.mp_restore)
		if result.effects.has("breakthrough_boost"):
			var xp = result.effects.breakthrough_boost * 500
			realm.add_cultivation_xp(xp)
			print("🌟 获得 %d 修为（突破助力）" % xp)
	return result

## 修行加点
func invest_cultivation(school_type: int, levels: int = 1) -> bool:
	return cultivation.invest_in_school(school_type, levels)

## 尝试境界突破
func try_breakthrough() -> bool:
	return realm.try_breakthrough(func(_item, _count): return inventory.has_item(_item, _count))
