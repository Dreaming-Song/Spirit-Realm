extends Node
## 炼丹系统 - Phase 2
## 采集材料 → 丹炉炼制 → 成品丹药

signal alchemy_completed(recipe_name: String, result_item: String)

# ---------- 材料类型 ----------
enum IngredientType {
	HERB_SPIRIT,     # 灵草
	HERB_MOON,       # 月华草
	ORE_CRYSTAL,     # 灵晶矿
	ORE_FLAME,       # 火熔石
	WOOD_ANCIENT,    # 古木
	WATER_SPRING,    # 灵泉水
}

# ---------- 丹药配方 ----------
class Recipe:
	var name: String
	var ingredients: Dictionary  # IngredientType -> 数量
	var result: String
	var effect: String          # 效果描述
	var cook_time: float        # 炼制时长
	var difficulty: int         # 难度（影响成功率）

var all_recipes: Dictionary = {}  # recipe_name -> Recipe
var player_ingredients: Dictionary = {}  # IngredientType -> 数量

func _ready() -> void:
	_init_recipes()

func _init_recipes() -> void:
	"""初始化配方库"""
	var recipes_data = [
		{
			"name": "回春丹",
			"ingredients": { IngredientType.HERB_SPIRIT: 2, IngredientType.WATER_SPRING: 1 },
			"result": "回春丹",
			"effect": "恢复 50 HP",
			"cook_time": 5.0,
			"difficulty": 1
		},
		{
			"name": "凝气丹",
			"ingredients": { IngredientType.HERB_MOON: 2, IngredientType.ORE_CRYSTAL: 1 },
			"result": "凝气丹",
			"effect": "恢复 50 MP",
			"cook_time": 6.0,
			"difficulty": 1
		},
		{
			"name": "火灵丹",
			"ingredients": { IngredientType.ORE_FLAME: 2, IngredientType.HERB_SPIRIT: 1 },
			"result": "火灵丹",
			"effect": "火系法术伤害+20%，持续60秒",
			"cook_time": 10.0,
			"difficulty": 2
		},
		{
			"name": "金刚丹",
			"ingredients": { IngredientType.ORE_CRYSTAL: 2, IngredientType.WOOD_ANCIENT: 1 },
			"result": "金刚丹",
			"effect": "防御+30%，持续60秒",
			"cook_time": 12.0,
			"difficulty": 2
		},
		{
			"name": "筑基丹",
			"ingredients": { IngredientType.ORE_FLAME: 2, IngredientType.HERB_MOON: 2, IngredientType.WOOD_ANCIENT: 1 },
			"result": "筑基丹",
			"effect": "永久 HP+20, MP+20",
			"cook_time": 20.0,
			"difficulty": 3
		},
	]
	for d in recipes_data:
		var r = Recipe.new()
		r.name = d.name
		r.ingredients = d.ingredients
		r.result = d.result
		r.effect = d.effect
		r.cook_time = d.cook_time
		r.difficulty = d.difficulty
		all_recipes[r.name] = r

# ===================== 材料管理 =====================

func add_ingredient(type: int, amount: int = 1) -> void:
	"""添加材料到背包"""
	if not player_ingredients.has(type):
		player_ingredients[type] = 0
	player_ingredients[type] += amount

func has_ingredients(recipe: Recipe) -> bool:
	"""检查是否有所需材料"""
	for ing_type, count in recipe.ingredients.items():
		if player_ingredients.get(ing_type, 0) < count:
			return false
	return true

func consume_ingredients(recipe: Recipe) -> void:
	"""消耗材料"""
	for ing_type, count in recipe.ingredients.items():
		player_ingredients[ing_type] -= count
		if player_ingredients[ing_type] <= 0:
			player_ingredients.erase(ing_type)

# ===================== 炼制系统 =====================

func start_cooking(recipe_name: String, cauldron: Node3D) -> bool:
	"""开始炼丹"""
	if not all_recipes.has(recipe_name):
		return false
	var recipe: Recipe = all_recipes[recipe_name]
	if not has_ingredients(recipe):
		return false

	consume_ingredients(recipe)
	# 交给丹炉节点处理计时和效果
	cauldron.start_cooking(recipe)
	return true

func attempt_discover(ingredients_list: Array) -> String:
	"""探索合成：放入未知材料组合，尝试发现新配方"""
	# 遍历配方库，看是否匹配
	for recipe in all_recipes.values():
		# 检查材料组合是否匹配
		var match_count: int = 0
		for ing in ingredients_list:
			if recipe.ingredients.has(ing):
				match_count += 1
		# 简单匹配逻辑：若材料全部匹配且数量一致则成功
		if match_count == recipe.ingredients.size() and match_count == ingredients_list.size():
			alchemy_completed.emit(recipe.name, recipe.result)
			return recipe.result
	return "未知混合物"

# ===================== 存档接口 =====================

func get_save_data() -> Dictionary:
	return {
		"ingredients": player_ingredients,
		"discovered_recipes": []  # TODO: 记录已发现配方
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("ingredients"):
		player_ingredients = data.ingredients
