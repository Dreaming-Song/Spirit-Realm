extends Node
## 合成系统 — 参考MC/DST的合成机制
##
## 核心玩法循环：采集材料 → 靠近合成台 → 选择配方 → 消耗材料 → 产出物品
## 进阶：批量合成、自动合成、品质系统

class_name CraftingSystem

# ==================== 信号 ====================
signal item_crafted(recipe_id: String, result_id: String, count: int)
signal crafting_started(recipe_id: String, total_time: float)
signal crafting_progress(recipe_id: String, progress: float)
signal crafting_completed(recipe_id: String)
signal crafting_cancelled(recipe_id: String)
signal station_interacted(station_type: String, position: Vector3)

# ==================== 引用 ====================
var _realm: RealmSystem
var _inventory: Node  # 玩家背包，需实现 has_item / remove_item / add_item

# ==================== 合成状态 ====================
var _is_crafting: bool = false
var _current_recipe: String = ""
var _craft_timer: float = 0.0
var _craft_duration: float = 0.0
var _nearby_stations: Dictionary = {}  # {"station_type": count}

func _ready() -> void:
	_realm = get_node("/root/RealmSystem") if has_node("/root/RealmSystem") else RealmSystem.new()

func _process(delta: float) -> void:
	if _is_crafting:
		_craft_timer += delta
		var progress = min(_craft_timer / _craft_duration, 1.0)
		crafting_progress.emit(_current_recipe, progress)
		
		if _craft_timer >= _craft_duration:
			_complete_crafting()

# ==================== 合成台管理 ====================

## 玩家进入合成台范围
func enter_station_range(station_type: String) -> void:
	_nearby_stations[station_type] = _nearby_stations.get(station_type, 0) + 1
	print("🔧 进入 %s 范围" % station_type)

## 玩家离开合成台范围
func leave_station_range(station_type: String) -> void:
	var count = _nearby_stations.get(station_type, 0)
	if count > 1:
		_nearby_stations[station_type] = count - 1
	else:
		_nearby_stations.erase(station_type)

## 检查附近是否有指定合成台
func has_station_nearby(station: String) -> bool:
	if station.is_empty():
		return true  # 徒手合成
	return _nearby_stations.has(station)

## 获取附近所有合成台
func get_nearby_stations() -> Array[String]:
	return _nearby_stations.keys()

# ==================== 核心合成 ====================

## 尝试合成物品
## 返回 {success: bool, reason: string}
func craft(recipe_id: String, count: int = 1) -> Dictionary:
	if _is_crafting:
		return {"success": false, "reason": "正在合成中"}
	
	var recipe = RecipeDatabase.get_recipe(recipe_id)
	if recipe.is_empty():
		return {"success": false, "reason": "配方不存在"}
	
	# 1. 检查境界
	if _realm.current_realm < recipe.realm_required:
		return {"success": false, "reason": "境界不足，需要%s期" % 
			RealmSystem.get_realm_name(recipe.realm_required)}
	
	# 2. 检查合成台
	if not has_station_nearby(recipe.station):
		return {"success": false, "reason": "需要在「%s」附近" % recipe.station}
	
	# 3. 检查材料
	if not _inventory:
		return {"success": false, "reason": "背包系统未加载"}
	
	var total_materials = {}
	for mat_id in recipe.materials.keys():
		var needed = recipe.materials[mat_id] * count
		if not _inventory.has_item(mat_id, needed):
			var missing = needed - _inventory.get_item_count(mat_id)
			return {"success": false, "reason": "缺少材料：%s 还需%d个" % [mat_id, missing]}
		total_materials[mat_id] = needed
	
	# 4. 消耗材料
	for mat_id in total_materials.keys():
		_inventory.remove_item(mat_id, total_materials[mat_id])
	
	# 5. 开始合成
	_is_crafting = true
	_current_recipe = recipe_id
	_craft_duration = recipe.craft_time * count
	_craft_timer = 0.0
	
	# 记录批量次数
	_pending_count = count
	_pending_result = recipe.result
	_pending_result_count = recipe.result_count
	
	crafting_started.emit(recipe_id, _craft_duration)
	print("⚒️ 开始合成 %s × %d（%.1f秒）" % [recipe.name, count, _craft_duration])
	
	return {"success": true, "duration": _craft_duration}

var _pending_count: int = 1
var _pending_result: String = ""
var _pending_result_count: int = 1

func _complete_crafting() -> void:
	"""合成完成"""
	_is_crafting = false
	
	# 产出物品
	var total_count = _pending_result_count * _pending_count
	_inventory.add_item(_pending_result, total_count)
	
	item_crafted.emit(_current_recipe, _pending_result, total_count)
	crafting_completed.emit(_current_recipe)
	
	print("✅ 合成完成！获得 %s × %d" % [
		RecipeDatabase.get_recipe(_current_recipe).get("name", _pending_result),
		total_count
	])
	
	_current_recipe = ""

## 取消合成（返还部分材料）
func cancel_crafting() -> bool:
	if not _is_crafting:
		return false
	
	var recipe = RecipeDatabase.get_recipe(_current_recipe)
	if not recipe.is_empty() and _inventory:
		# 按进度返还材料：50%~100%
		var progress = _craft_timer / _craft_duration
		var refund_ratio = 0.5 + progress * 0.5
		
		for mat_id in recipe.materials.keys():
			var refund_count = int(recipe.materials[mat_id] * _pending_count * refund_ratio)
			if refund_count > 0:
				_inventory.add_item(mat_id, refund_count)
	
	_is_crafting = false
	crafting_cancelled.emit(_current_recipe)
	print("⏹️ 合成取消，已返还部分材料")
	return true

# ==================== 获取可用配方 ====================

## 获取当前可合成的所有配方（按合成台分组）
func get_available_recipes() -> Dictionary:
	var realm = _realm.current_realm if _realm else 0
	var all_recipes = RecipeDatabase.get_recipes_for_realm(realm)
	
	# 按合成台分组
	var grouped: Dictionary = {}
	for id in all_recipes.keys():
		var r = all_recipes[id]
		var station = r.station
		if station.is_empty():
			station = "徒手"
		if not grouped.has(station):
			grouped[station] = []
		grouped[station].append({"id": id, "data": r})
	
	return grouped

## 获取当前合成台的可用配方
func get_station_recipes(station: String) -> Array[Dictionary]:
	var realm = _realm.current_realm if _realm else 0
	var station_recipes = RecipeDatabase.get_recipes_for_station(station, realm)
	var result: Array[Dictionary] = []
	for id in station_recipes.keys():
		result.append({"id": id, "data": station_recipes[id]})
	return result

## 批量获取可合成列表（含材料是否足够标记）
func get_craftable_list() -> Array[Dictionary]:
	var realm = _realm.current_realm if _realm else 0
	var all_recipes = RecipeDatabase.get_recipes_for_realm(realm)
	var result: Array[Dictionary] = []
	
	for id in all_recipes.keys():
		var r = all_recipes[id]
		var has_station = has_station_nearby(r.station)
		var can_craft = _check_materials(r)
		
		result.append({
			"id": id,
			"data": r,
			"has_station": has_station,
			"can_craft": can_craft,
			"station_available": has_station_nearby(r.station),
		})
	
	return result

# ==================== 材料检查 ====================

func _check_materials(recipe: Dictionary) -> bool:
	if not _inventory:
		return false
	for mat_id in recipe.materials.keys():
		if not _inventory.has_item(mat_id, recipe.materials[mat_id]):
			return false
	return true

# ==================== 熔炼系统 ====================

## 熔炼物品（反向操作：物品→材料）
func smelt(item_id: String, count: int = 1) -> Dictionary:
	if not has_station_nearby("furnace") and not has_station_nearby("spirit_furnace"):
		return {"success": false, "reason": "需要在熔炉附近"}
	
	if not _inventory or not _inventory.has_item(item_id, count):
		return {"success": false, "reason": "材料不足"}
	
	# 获取物品的熔炼价值（由物品系统提供）
	var smelt_result = _get_smelt_result(item_id, count)
	if smelt_result.is_empty():
		return {"success": false, "reason": "该物品无法熔炼"}
	
	_inventory.remove_item(item_id, count)
	for result_id in smelt_result.keys():
		_inventory.add_item(result_id, smelt_result[result_id])
	
	return {"success": true, "results": smelt_result}

## 熔炼映射表（简化）
func _get_smelt_result(item_id: String, count: int) -> Dictionary:
	match item_id:
		"iron_ore":   return {"iron_ingot": count}
		"gold_ore":   return {"gold_ingot": count}
		"spirit_ore": return {"spirit_iron": count}
		"copper_ore": return {"copper_ingot": count}
	return {}
