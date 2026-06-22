extends Node
## 配方数据库 — 按境界分层，参考MC/DST/Terraria的合成树
##
## 每阶配方按境界解锁：
##   凡→练→筑→金→婴→化→大→渡→飞
##   0   1   2   3   4   5   6   7   8

class_name RecipeDatabase

# ==================== 配方结构 ====================
struct Recipe:
	var id: String
	var name: String
	var desc: String
	var category: String          # tool/weapon/building/alchemy/talisman/furniture/decoration
	var station: String           # 合成台名称，""=徒手
	var materials: Dictionary     # {"item_id": count}
	var result: String            # 产出物ID
	var result_count: int         # 产出数量
	var craft_time: float         # 合成耗时（秒）
	var realm_required: int       # 所需境界
	var tier: int                 # 材料等级

# ==================== 所有配方 ====================
const RECIPES: Dictionary = {
	# ========== Tier 0：凡人期 ==========
	# -- 基础工具 --
	"stone_axe": {
		"name": "石斧", "category": "tool", "station": "workbench",
		"materials": {"wood": 3, "stone": 2, "vine": 1},
		"result": "stone_axe", "result_count": 1,
		"craft_time": 3.0, "realm_required": 0, "tier": 0,
		"desc": "砍树必备，效率低下但能用",
	},
	"stone_pickaxe": {
		"name": "石镐", "category": "tool", "station": "workbench",
		"materials": {"wood": 3, "stone": 3, "vine": 1},
		"result": "stone_pickaxe", "result_count": 1,
		"craft_time": 3.0, "realm_required": 0, "tier": 0,
		"desc": "挖矿采石，凡人首选",
	},
	"stone_hammer": {
		"name": "石锤", "category": "tool", "station": "workbench",
		"materials": {"wood": 4, "stone": 3},
		"result": "stone_hammer", "result_count": 1,
		"craft_time": 3.0, "realm_required": 0, "tier": 0,
		"desc": "拆解建筑，回收材料",
	},
	"wooden_sword": {
		"name": "木剑", "category": "weapon", "station": "workbench",
		"materials": {"wood": 5, "vine": 2},
		"result": "wooden_sword", "result_count": 1,
		"craft_time": 2.0, "realm_required": 0, "tier": 0,
		"desc": "粗制滥造的木剑，聊胜于无",
	},
	"wooden_bow": {
		"name": "木弓", "category": "weapon", "station": "workbench",
		"materials": {"wood": 4, "vine": 3},
		"result": "wooden_bow", "result_count": 1,
		"craft_time": 3.0, "realm_required": 0, "tier": 0,
		"desc": "简易木弓，远程防身",
	},
	
	# -- 基础建筑 --
	"thatch_wall": {
		"name": "茅草墙", "category": "building", "station": "",
		"materials": {"thatch": 4, "wood": 2},
		"result": "thatch_wall", "result_count": 1,
		"craft_time": 2.0, "realm_required": 0, "tier": 0,
		"desc": "最简陋的墙，风吹就倒",
	},
	"thatch_floor": {
		"name": "茅草地板", "category": "building", "station": "",
		"materials": {"thatch": 2, "wood": 1},
		"result": "thatch_floor", "result_count": 1,
		"craft_time": 1.5, "realm_required": 0, "tier": 0,
		"desc": "踩着还算干爽",
	},
	"wooden_wall": {
		"name": "木墙", "category": "building", "station": "workbench",
		"materials": {"wood": 4},
		"result": "wooden_wall", "result_count": 1,
		"craft_time": 3.0, "realm_required": 0, "tier": 0,
		"desc": "厚实木墙，遮风挡雨",
	},
	"wooden_door": {
		"name": "木门", "category": "building", "station": "workbench",
		"materials": {"wood": 6},
		"result": "wooden_door", "result_count": 1,
		"craft_time": 4.0, "realm_required": 0, "tier": 0,
		"desc": "有门才有家",
	},
	"wooden_chest": {
		"name": "木箱", "category": "storage", "station": "workbench",
		"materials": {"wood": 8, "stone": 2},
		"result": "wooden_chest", "result_count": 1,
		"craft_time": 5.0, "realm_required": 0, "tier": 0,
		"desc": "20格存储空间",
	},
	"campfire": {
		"name": "篝火", "category": "utility", "station": "",
		"materials": {"wood": 3, "stone": 3},
		"result": "campfire", "result_count": 1,
		"craft_time": 2.0, "realm_required": 0, "tier": 0,
		"desc": "照亮黑夜，烧制食物，驱散野兽",
	},
	"workbench": {
		"name": "工作台", "category": "station", "station": "",
		"materials": {"wood": 6, "stone": 3},
		"result": "workbench", "result_count": 1,
		"craft_time": 5.0, "realm_required": 0, "tier": 0,
		"desc": "万物合成之始，基础制造站",
	},
	"wooden_bed": {
		"name": "木床", "category": "furniture", "station": "workbench",
		"materials": {"wood": 8, "thatch": 5},
		"result": "wooden_bed", "result_count": 1,
		"craft_time": 6.0, "realm_required": 0, "tier": 0,
		"desc": "睡一觉恢复生命，设置重生点",
	},
	"torch": {
		"name": "火把", "category": "utility", "station": "",
		"materials": {"wood": 1, "vine": 1},
		"result": "torch", "result_count": 4,
		"craft_time": 1.0, "realm_required": 0, "tier": 0,
		"desc": "插在墙上或手持照明",
	},
	
	# ========== Tier 1：练气期 ==========
	"iron_axe": {
		"name": "铁斧", "category": "tool", "station": "workbench",
		"materials": {"wood": 2, "iron_ingot": 3},
		"result": "iron_axe", "result_count": 1,
		"craft_time": 5.0, "realm_required": 1, "tier": 1,
		"desc": "锋利铁斧，砍树效率翻倍",
	},
	"iron_pickaxe": {
		"name": "铁镐", "category": "tool", "station": "workbench",
		"materials": {"wood": 2, "iron_ingot": 4},
		"result": "iron_pickaxe", "result_count": 1,
		"craft_time": 5.0, "realm_required": 1, "tier": 1,
		"desc": "能挖铁矿和灵石",
	},
	"iron_sword": {
		"name": "铁剑", "category": "weapon", "station": "workbench",
		"materials": {"wood": 2, "iron_ingot": 5},
		"result": "iron_sword", "result_count": 1,
		"craft_time": 6.0, "realm_required": 1, "tier": 1,
		"desc": "百炼精铁剑，凡人利器",
	},
	"furnace": {
		"name": "熔炉", "category": "station", "station": "workbench",
		"materials": {"stone": 10, "wood": 5},
		"result": "furnace", "result_count": 1,
		"craft_time": 8.0, "realm_required": 1, "tier": 1,
		"desc": "冶炼金属，烧制陶瓷",
	},
	"stone_wall": {
		"name": "石墙", "category": "building", "station": "workbench",
		"materials": {"stone": 4},
		"result": "stone_wall", "result_count": 1,
		"craft_time": 4.0, "realm_required": 1, "tier": 1,
		"desc": "厚实石墙，防御力大幅提升",
	},
	"herb_garden": {
		"name": "灵田", "category": "farming", "station": "",
		"materials": {"wood": 4, "stone": 4, "dirt": 6},
		"result": "herb_garden", "result_count": 1,
		"craft_time": 8.0, "realm_required": 1, "tier": 1,
		"desc": "种植灵草药材的田地",
	},
	"alchemy_furnace": {
		"name": "炼丹炉", "category": "station", "station": "workbench",
		"materials": {"iron_ingot": 4, "stone": 8},
		"result": "alchemy_furnace", "result_count": 1,
		"craft_time": 8.0, "realm_required": 1, "tier": 1,
		"desc": "炼制基础丹药",
	},
	"qi_recovery_pill": {
		"name": "回气丹", "category": "alchemy", "station": "alchemy_furnace",
		"materials": {"herb_qi": 3, "herb_common": 2},
		"result": "qi_recovery_pill", "result_count": 3,
		"craft_time": 4.0, "realm_required": 1, "tier": 1,
		"desc": "恢复50点法力",
	},
	"basic_talisman": {
		"name": "基础符箓", "category": "talisman", "station": "workbench",
		"materials": {"paper": 2, "herb_qi": 1, "ink": 1},
		"result": "basic_talisman", "result_count": 2,
		"craft_time": 5.0, "realm_required": 1, "tier": 1,
		"desc": "释放一道基础五行法术",
	},
	
	# ========== Tier 2：筑基期 ==========
	"spirit_iron_sword": {
		"name": "灵铁剑", "category": "weapon", "station": "furnace",
		"materials": {"spirit_iron": 5, "spirit_stone": 2},
		"result": "spirit_iron_sword", "result_count": 1,
		"craft_time": 10.0, "realm_required": 2, "tier": 2,
		"desc": "附灵铁剑，可灌注灵力",
	},
	"brick_wall": {
		"name": "灵砖墙", "category": "building", "station": "furnace",
		"materials": {"spirit_brick": 4},
		"result": "brick_wall", "result_count": 1,
		"craft_time": 5.0, "realm_required": 2, "tier": 2,
		"desc": "灵气灌注的砖墙，坚固且美观",
	},
	"spirit_chest": {
		"name": "灵木箱", "category": "storage", "station": "workbench",
		"materials": {"spirit_wood": 6, "spirit_stone": 2},
		"result": "spirit_chest", "result_count": 1,
		"craft_time": 6.0, "realm_required": 2, "tier": 2,
		"desc": "40格存储空间",
	},
	"spirit_furnace": {
		"name": "灵熔炉", "category": "station", "station": "furnace",
		"materials": {"spirit_stone": 10, "iron_ingot": 5},
		"result": "spirit_furnace", "result_count": 1,
		"craft_time": 10.0, "realm_required": 2, "tier": 2,
		"desc": "精炼灵矿，锻造法器",
	},
	"spirit_lamp": {
		"name": "灵灯", "category": "decoration", "station": "workbench",
		"materials": {"spirit_stone": 2, "iron_ingot": 1},
		"result": "spirit_lamp", "result_count": 1,
		"craft_time": 3.0, "realm_required": 2, "tier": 2,
		"desc": "散发柔和灵光，照亮大片区域",
	},
	"spirit_door": {
		"name": "灵木门", "category": "building", "station": "workbench",
		"materials": {"spirit_wood": 6, "spirit_stone": 1},
		"result": "spirit_door", "result_count": 1,
		"craft_time": 5.0, "realm_required": 2, "tier": 2,
		"desc": "灵气加持的门，更坚固",
	},
	"foundation_pill": {
		"name": "筑基丹", "category": "alchemy", "station": "alchemy_furnace",
		"materials": {"herb_spirit": 5, "herb_qi": 3, "spirit_stone": 2},
		"result": "foundation_pill", "result_count": 1,
		"craft_time": 12.0, "realm_required": 2, "tier": 2,
		"desc": "突破筑基期的必须丹药",
	},
	
	# ========== Tier 3：金丹期 ==========
	"jade_sword": {
		"name": "玉灵剑", "category": "weapon", "station": "spirit_furnace",
		"materials": {"spirit_jade": 5, "gold_ingot": 3, "spirit_stone": 5},
		"result": "jade_sword", "result_count": 1,
		"craft_time": 20.0, "realm_required": 3, "tier": 3,
		"desc": "灵玉锻造，可飞行御剑",
	},
	"jade_wall": {
		"name": "灵石墙", "category": "building", "station": "spirit_furnace",
		"materials": {"spirit_stone": 4},
		"result": "jade_wall", "result_count": 1,
		"craft_time": 8.0, "realm_required": 3, "tier": 3,
		"desc": "灵石堆砌，灵气充盈",
	},
	"spirit_armor": {
		"name": "灵气甲", "category": "armor", "station": "spirit_furnace",
		"materials": {"spirit_iron": 8, "spirit_stone": 4, "gold_ingot": 2},
		"result": "spirit_armor", "result_count": 1,
		"craft_time": 15.0, "realm_required": 3, "tier": 3,
		"desc": "灵气护甲，大幅提升防御",
	},
	"protection_array": {
		"name": "护山大阵", "category": "building", "station": "spirit_furnace",
		"materials": {"spirit_stone": 20, "spirit_jade": 5, "gold_ingot": 5},
		"result": "protection_array", "result_count": 1,
		"craft_time": 30.0, "realm_required": 3, "tier": 3,
		"desc": "守护整片领地的结界大阵",
	},
	"golden_core_pill": {
		"name": "凝金丹", "category": "alchemy", "station": "alchemy_furnace",
		"materials": {"herb_spirit": 8, "beast_core": 3, "spirit_jade": 2},
		"result": "golden_core_pill", "result_count": 1,
		"craft_time": 20.0, "realm_required": 3, "tier": 3,
		"desc": "凝结金丹的必须丹药",
	},
	"flying_sword": {
		"name": "飞剑", "category": "transport", "station": "spirit_furnace",
		"materials": {"spirit_iron": 10, "spirit_jade": 3, "gold_ingot": 5},
		"result": "flying_sword", "result_count": 1,
		"craft_time": 25.0, "realm_required": 3, "tier": 3,
		"desc": "御剑飞行，遨游天地",
	},
	
	# ========== Tier 4：元婴期 ==========
	"crystal_wall": {
		"name": "玉晶墙", "category": "building", "station": "spirit_furnace",
		"materials": {"spirit_crystal": 4},
		"result": "crystal_wall", "result_count": 1,
		"craft_time": 10.0, "realm_required": 4, "tier": 4,
		"desc": "通体透明的晶壁，坚不可摧",
	},
	"teleport_array": {
		"name": "传送阵", "category": "building", "station": "spirit_furnace",
		"materials": {"spirit_crystal": 10, "spirit_stone": 20, "spirit_jade": 5},
		"result": "teleport_array", "result_count": 1,
		"craft_time": 40.0, "realm_required": 4, "tier": 4,
		"desc": "瞬间传送至绑定的其他传送阵",
	},
	"nascent_soul_pill": {
		"name": "化婴丹", "category": "alchemy", "station": "alchemy_furnace",
		"materials": {"herb_celestial": 5, "beast_core": 5, "spirit_crystal": 3},
		"result": "nascent_soul_pill", "result_count": 1,
		"craft_time": 30.0, "realm_required": 4, "tier": 4,
		"desc": "碎丹成婴的必须丹药",
	},
	"pocket_dimension": {
		"name": "洞天福地", "category": "building", "station": "spirit_furnace",
		"materials": {"spirit_crystal": 20, "spirit_jade": 10, "spirit_stone": 50},
		"result": "pocket_dimension", "result_count": 1,
		"craft_time": 60.0, "realm_required": 4, "tier": 4,
		"desc": "开辟独立空间作为洞府",
	},
	
	# ========== Tier 5+：化神及以上（简略） ==========
	"floating_island": {
		"name": "浮空平台", "category": "building", "station": "spirit_furnace",
		"materials": {"spirit_crystal": 30, "celestial_stone": 10, "spirit_stone": 100},
		"result": "floating_island", "result_count": 1,
		"craft_time": 120.0, "realm_required": 5, "tier": 5,
		"desc": "悬浮于空中的平台，建造天空之城的基础",
	},
	"artifact_sword": {
		"name": "后天灵宝·斩仙", "category": "weapon", "station": "spirit_furnace",
		"materials": {"celestial_iron": 10, "dragon_scale": 3, "phoenix_feather": 3},
		"result": "artifact_sword", "result_count": 1,
		"craft_time": 120.0, "realm_required": 6, "tier": 6,
		"desc": "后天灵宝，一剑可斩山河",
	},
}

# ==================== 工具方法 ====================

## 获取所有配方
static func get_all_recipes() -> Dictionary:
	return RECIPES

## 按境界获取可用的配方
static func get_recipes_for_realm(realm: int) -> Dictionary:
	var result: Dictionary = {}
	for id in RECIPES.keys():
		if RECIPES[id].realm_required <= realm:
			result[id] = RECIPES[id]
	return result

## 按类别获取配方
static func get_recipes_by_category(category: String, realm: int = 999) -> Dictionary:
	var result: Dictionary = {}
	for id in RECIPES.keys():
		var r = RECIPES[id]
		if r.category == category and r.realm_required <= realm:
			result[id] = r
	return result

## 获取某个配方的完整数据
static func get_recipe(recipe_id: String) -> Dictionary:
	return RECIPES.get(recipe_id, {})

## 按合成台筛选
static func get_recipes_for_station(station: String, realm: int = 999) -> Dictionary:
	var result: Dictionary = {}
	for id in RECIPES.keys():
		var r = RECIPES[id]
		if r.station == station and r.realm_required <= realm:
			result[id] = r
	return result

## 获取所有合成台类型
static func get_all_stations() -> Array[String]:
	var stations: Array[String] = []
	for id in RECIPES.keys():
		var s = RECIPES[id].station
		if not s.is_empty() and not s in stations:
			stations.append(s)
	return stations

## 搜索配方
static func search_recipes(query: String, realm: int = 999) -> Dictionary:
	var result: Dictionary = {}
	var q = query.to_lower()
	for id in RECIPES.keys():
		var r = RECIPES[id]
		if r.realm_required <= realm:
			if q in id.to_lower() or q in r.name.to_lower() or q in r.desc.to_lower():
				result[id] = r
	return result
