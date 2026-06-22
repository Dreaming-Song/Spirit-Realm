extends Node
## 修仙境界系统 — 凡人→飞升 完整成长线
##
## 每个境界解锁新能力、新工具、新建筑、新合成配方
## 境界突破需要：修为值 + 特殊材料 + 突破任务

class_name RealmSystem

# ==================== 九重境界 ====================
enum Realm {
	MORTAL,          # 凡人 —— 初始
	QI_CONDENSATION, # 练气 —— 筑基前期
	FOUNDATION,      # 筑基 —— 金丹前期
	GOLDEN_CORE,     # 金丹 —— 元婴前期
	NASCENT_SOUL,    # 元婴 —— 化神前期
	DIVINE_TRANSFORM, # 化神 —— 大乘前期
	GREAT_VEHICLE,   # 大乘 —— 渡劫前期
	TRIBULATION,     # 渡劫 —— 飞升前期
	ASCENSION,       # 飞升 —— 大圆满
}

# ==================== 境界数据 ====================
static func get_realm_data(realm: int) -> Dictionary:
	match realm:
		Realm.MORTAL:
			return {
				"name": "凡人",
				"title": "凡夫俗子",
				"desc": "肉体凡胎，尚未踏入修仙之路。",
				"next_realm_name": "练气期",
				"breakthrough_xp": 100,       # 需要修为值
				"breakthrough_items": [],       # 需要特殊物品
				"breakthrough_desc": "感受到天地灵气的存在",
				"stat_mult": 1.0,              # 属性倍率
				"max_hp_bonus": 0,
				"max_mp_bonus": 0,
				"build_tier": 0,               # 建筑等级（0=茅草/木）
				"craft_tier": 0,               # 合成等级
				"unlocks": ["基础工具", "茅草建筑", "篝火", "工作台"],
			}
		
		Realm.QI_CONDENSATION:
			return {
				"name": "练气",
				"title": "吐纳天地",
				"desc": "初窥门径，已能引气入体。",
				"next_realm_name": "筑基期",
				"breakthrough_xp": 500,
				"breakthrough_items": [{"item": "聚气草", "count": 5}],
				"breakthrough_desc": "打通任督二脉，真气贯通",
				"stat_mult": 1.5,
				"max_hp_bonus": 50,
				"max_mp_bonus": 30,
				"build_tier": 1,
				"craft_tier": 1,
				"unlocks": ["铁制工具", "石墙建筑", "炼丹炉", "灵田", "基础符箓"],
			}
		
		Realm.FOUNDATION:
			return {
				"name": "筑基",
				"title": "道基初成",
				"desc": "铸造道基，脱胎换骨。",
				"next_realm_name": "金丹期",
				"breakthrough_xp": 2000,
				"breakthrough_items": [{"item": "筑基丹", "count": 1}, {"item": "灵石", "count": 10}],
				"breakthrough_desc": "以丹药为引，筑就无上道基",
				"stat_mult": 2.5,
				"max_hp_bonus": 200,
				"max_mp_bonus": 100,
				"build_tier": 2,
				"craft_tier": 2,
				"unlocks": ["灵铁工具", "砖石建筑", "聚灵阵", "法器锻造", "中级丹药"],
			}
		
		Realm.GOLDEN_CORE:
			return {
				"name": "金丹",
				"title": "金丹大道",
				"desc": "凝结金丹，神通初显。",
				"next_realm_name": "元婴期",
				"breakthrough_xp": 8000,
				"breakthrough_items": [{"item": "凝金丹", "count": 1}, {"item": "妖兽内丹", "count": 3}],
				"breakthrough_desc": "引天地灵气灌体，凝结金丹",
				"stat_mult": 4.0,
				"max_hp_bonus": 500,
				"max_mp_bonus": 300,
				"build_tier": 3,
				"craft_tier": 3,
				"unlocks": ["法宝工具", "灵石建筑", "护山大阵", "飞行法器", "金丹丹药"],
			}
		
		Realm.NASCENT_SOUL:
			return {
				"name": "元婴",
				"title": "元婴出窍",
				"desc": "元婴已成，一念千里。",
				"next_realm_name": "化神期",
				"breakthrough_xp": 25000,
				"breakthrough_items": [{"item": "化婴果", "count": 1}, {"item": "星辰铁", "count": 5}],
				"breakthrough_desc": "碎丹成婴，神识外放",
				"stat_mult": 6.0,
				"max_hp_bonus": 1500,
				"max_mp_bonus": 800,
				"build_tier": 4,
				"craft_tier": 4,
				"unlocks": ["仙器雏形", "玉晶建筑", "传送阵", "洞天开辟", "元婴丹药"],
			}
		
		Realm.DIVINE_TRANSFORM:
			return {
				"name": "化神",
				"title": "返璞归真",
				"desc": "化神合道，言出法随。",
				"next_realm_name": "大乘期",
				"breakthrough_xp": 80000,
				"breakthrough_items": [{"item": "化神仙丹", "count": 1}, {"item": "龙鳞", "count": 3}],
				"breakthrough_desc": "神魂与天地共鸣，化神入道",
				"stat_mult": 9.0,
				"max_hp_bonus": 4000,
				"max_mp_bonus": 2000,
				"build_tier": 5,
				"craft_tier": 5,
				"unlocks": ["仙器锻造", "浮空建筑", "天地法阵", "捏土造物", "化神丹药"],
			}
		
		Realm.GREAT_VEHICLE:
			return {
				"name": "大乘",
				"title": "大乘圆满",
				"desc": "功参造化，只差一步。",
				"next_realm_name": "渡劫期",
				"breakthrough_xp": 200000,
				"breakthrough_items": [{"item": "大乘舍利", "count": 1}, {"item": "九天玄铁", "count": 5}],
				"breakthrough_desc": "积累无量功德，大乘圆满",
				"stat_mult": 13.0,
				"max_hp_bonus": 10000,
				"max_mp_bonus": 5000,
				"build_tier": 6,
				"craft_tier": 6,
				"unlocks": ["后天灵宝", "星辰建筑", "改天换地", "秘境创造"],
			}
		
		Realm.TRIBULATION:
			return {
				"name": "渡劫",
				"title": "天劫临头",
				"desc": "九九天劫，九死一生。",
				"next_realm_name": "飞升期",
				"breakthrough_xp": 500000,
				"breakthrough_items": [{"item": "渡劫丹", "count": 1},
					{"item": "天劫石", "count": 1}, {"item": "万年灵乳", "count": 3}],
				"breakthrough_desc": "引动九九天劫，淬体锻魂",
				"stat_mult": 18.0,
				"max_hp_bonus": 25000,
				"max_mp_bonus": 12000,
				"build_tier": 7,
				"craft_tier": 7,
				"unlocks": ["先天灵宝", "天界建筑", "法则感悟", "时空阵法"],
			}
		
		Realm.ASCENSION:
			return {
				"name": "飞升",
				"title": "羽化登仙",
				"desc": "超脱凡俗，位列仙班。",
				"next_realm_name": "已圆满",
				"breakthrough_xp": 0,
				"breakthrough_items": [],
				"breakthrough_desc": "功德圆满，破碎虚空飞升上界",
				"stat_mult": 25.0,
				"max_hp_bonus": 50000,
				"max_mp_bonus": 25000,
				"build_tier": 8,
				"craft_tier": 8,
				"unlocks": ["先天至宝", "造化建筑", "创世之力", "开辟仙界"],
			}
	
	return {}

# ==================== 境界名 ====================
static func get_realm_name(realm: int) -> String:
	return get_realm_data(realm).get("name", "未知")

static func get_realm_title(realm: int) -> String:
	return get_realm_data(realm).get("title", "")

# ==================== 运行状态 ====================
var current_realm: int = Realm.MORTAL
var cultivation_xp: int = 0          # 当前修为值
var breakthrough_progress: float = 0.0  # 0~1

signal realm_changed(old_realm: int, new_realm: int, realm_name: String)
signal breakthrough_possible(realm: int)
signal xp_changed(xp: int, next_threshold: int)

# ==================== 修为与突破 ====================

func add_cultivation_xp(amount: int) -> void:
	"""增加修为值"""
	cultivation_xp += amount
	var data = get_realm_data(current_realm)
	var needed = data.breakthrough_xp
	breakthrough_progress = min(float(cultivation_xp) / float(max(needed, 1)), 1.0)
	xp_changed.emit(cultivation_xp, needed)
	
	# 达到突破条件
	if breakthrough_progress >= 1.0:
		breakthrough_possible.emit(current_realm)

## 尝试突破境界
func try_breakthrough(inventory_checker: Callable = func(_item, _count): return true) -> bool:
	"""inventory_checker(item_id, count) → bool，检查是否有足够材料"""
	if current_realm >= Realm.ASCENSION:
		return false
	
	var data = get_realm_data(current_realm)
	
	# 检查修为
	if cultivation_xp < data.breakthrough_xp:
		print("⚠️ 修为不足（%d/%d）" % [cultivation_xp, data.breakthrough_xp])
		return false
	
	# 检查突破材料
	for req in data.breakthrough_items:
		if not inventory_checker.call(req.item, req.count):
			print("⚠️ 缺少突破材料：%s × %d" % [req.item, req.count])
			return false
	
	# 突破成功！
	var old_realm = current_realm
	current_realm += 1
	cultivation_xp = 0
	breakthrough_progress = 0.0
	
	print("🌟🌟🌟 突破成功！%s → %s（%s）🌟🌟🌟" % [
		get_realm_name(old_realm), get_realm_name(current_realm),
		get_realm_data(current_realm).breakthrough_desc
	])
	
	realm_changed.emit(old_realm, current_realm, get_realm_name(current_realm))
	return true

# ==================== 属性计算 ====================

## 根据境界计算属性倍率
func get_stat_multiplier() -> Dictionary:
	var data = get_realm_data(current_realm)
	return {
		"stat_mult": data.stat_mult,
		"max_hp_bonus": data.max_hp_bonus,
		"max_mp_bonus": data.max_mp_bonus,
	}

## 获取当前可用的建筑等级（材料层级）
func get_build_tier() -> int:
	return get_realm_data(current_realm).build_tier

## 获取当前可用的合成等级
func get_craft_tier() -> int:
	return get_realm_data(current_realm).craft_tier

## 获取当前解锁能力列表
func get_current_unlocks() -> Array[String]:
	var unlocks: Array[String] = []
	for r in range(Realm.MORTAL, current_realm + 1):
		var data = get_realm_data(r)
		unlocks += data.get("unlocks", [])
	return unlocks

## 检查是否已解锁某能力
func has_unlock(capability: String) -> bool:
	return capability in get_current_unlocks()

# ==================== 存档 ====================

func get_save_data() -> Dictionary:
	return {
		"current_realm": current_realm,
		"cultivation_xp": cultivation_xp,
	}

func load_save_data(data: Dictionary) -> void:
	current_realm = data.get("current_realm", Realm.MORTAL)
	cultivation_xp = data.get("cultivation_xp", 0)
