extends Node
## 修行流派数据定义 — 五大流派 + 境界体系
##
## 不再是职业选择，而是可自由修炼的修行方向
## 可以：全修5派 / 只学部分 / 专精其一

class_name CultivationSchool

# ==================== 流派枚举 ====================
enum SchoolType {
	SWORD,      # 剑道 — 金
	SPELL,      # 法术 — 火/水
	BODY,       # 体术 — 土
	ALCHEMY,    # 丹道 — 木
	TALISMAN,   # 符道 — 金/水
}

# ==================== 境界体系 ====================
## 每个流派独立计算境界，境界影响属性加成和可学技能
enum MasteryLevel {
	NONE,           # 未接触
	BEGINNER,       # 初窥门径 (Lv1-3)
	INTERMEDIATE,   # 略有小成 (Lv4-7)
	ADVANCED,       # 融会贯通 (Lv8-10)
	MASTER,         # 登峰造极 (Lv11+)
}

## 境界名称（显示用）
static func get_mastery_name(level: int) -> String:
	if level >= 11:  return "登峰造极"
	if level >= 8:   return "融会贯通"
	if level >= 4:   return "略有小成"
	if level >= 1:   return "初窥门径"
	return "未接触"

## 境界枚举
static func get_mastery_enum(level: int) -> int:
	if level >= 11:  return MasteryLevel.MASTER
	if level >= 8:   return MasteryLevel.ADVANCED
	if level >= 4:   return MasteryLevel.INTERMEDIATE
	if level >= 1:   return MasteryLevel.BEGINNER
	return MasteryLevel.NONE

# ==================== 流派完整数据 ====================
static func get_school_data(t: int) -> Dictionary:
	match t:
		SchoolType.SWORD:
			return {
				"name": "剑道",
				"desc": "以剑入道，一剑破万法。追求极致的单体杀伤。",
				"element": "金",
				"icon": "res://assets/icons/sword.png",
				
				# 每级属性成长（修炼该流派时叠加）
				"stat_per_level": {
					"attack": 3.5,
					"crit_rate": 0.012,   # 每级+1.2%暴击
					"crit_damage": 0.04,  # 每级+4%爆伤
				},
				# 境界突破额外加成
				"mastery_bonus": {
					MasteryLevel.BEGINNER:     {"attack": 5},
					MasteryLevel.INTERMEDIATE: {"crit_rate": 0.05},
					MasteryLevel.ADVANCED:     {"crit_damage": 0.3},
					MasteryLevel.MASTER:       {"attack": 20, "crit_damage": 0.5},
				},
				# 技能解锁（按流派等级）
				"skills": [
					{"id": "sword_slash",   "name": "剑气斩",     "level": 1},
					{"id": "sword_flurry",  "name": "剑影连击",   "level": 3},
					{"id": "sword_spirit",  "name": "剑意通明",   "level": 5},
					{"id": "sword_rain",    "name": "万剑诀",     "level": 8},
					{"id": "sword_thunder", "name": "天剑引雷",   "level": 11},
					{"id": "sword_intent",  "name": "剑心",       "level": 14},
				],
			}
		
		SchoolType.SPELL:
			return {
				"name": "法术",
				"desc": "沟通天地五行，引动元素之力。大范围毁灭。",
				"element": "火/水",
				"icon": "res://assets/icons/spell.png",
				
				"stat_per_level": {
					"attack": 4.0,
					"max_mp": 15,
					"mp_regen": 0.4,
				},
				"mastery_bonus": {
					MasteryLevel.BEGINNER:     {"max_mp": 30},
					MasteryLevel.INTERMEDIATE: {"attack": 8, "mp_regen": 2},
					MasteryLevel.ADVANCED:     {"attack": 15, "element_damage_bonus": 0.15},
					MasteryLevel.MASTER:       {"attack": 25, "max_mp": 100, "mp_regen": 5},
				},
				"skills": [
					{"id": "fire_ball",       "name": "火球术",      "level": 1},
					{"id": "frost_array",     "name": "冰霜阵",      "level": 3},
					{"id": "mana_resonance",  "name": "法力共鸣",    "level": 5},
					{"id": "thunder_bolt",    "name": "雷法·天罚",   "level": 8},
					{"id": "elemental_storm", "name": "五行崩裂",    "level": 11},
					{"id": "elemental_affinity","name": "元素亲和",  "level": 14},
				],
			}
		
		SchoolType.BODY:
			return {
				"name": "体术",
				"desc": "以肉身为兵，淬炼不灭金身。钢铁壁垒。",
				"element": "土",
				"icon": "res://assets/icons/body.png",
				
				"stat_per_level": {
					"max_hp": 20,
					"defense": 3.0,
					"hp_regen": 0.3,
				},
				"mastery_bonus": {
					MasteryLevel.BEGINNER:     {"max_hp": 50, "defense": 5},
					MasteryLevel.INTERMEDIATE: {"max_hp": 100, "damage_reduction": 0.05},
					MasteryLevel.ADVANCED:     {"max_hp": 200, "defense": 15},
					MasteryLevel.MASTER:       {"max_hp": 500, "damage_reduction": 0.15},
				},
				"skills": [
					{"id": "iron_body",      "name": "金刚体",      "level": 1},
					{"id": "quake_stomp",    "name": "震地击",      "level": 3},
					{"id": "iron_bones",     "name": "铁骨",        "level": 5},
					{"id": "dragon_grab",    "name": "擒龙手",      "level": 8},
					{"id": "golden_body",    "name": "不灭金身",    "level": 11},
					{"id": "vital_force",    "name": "气血旺盛",    "level": 14},
				],
			}
		
		SchoolType.ALCHEMY:
			return {
				"name": "丹道",
				"desc": "精通百草丹道，救死扶伤。生命之泉。",
				"element": "木",
				"icon": "res://assets/icons/alchemy.png",
				
				"stat_per_level": {
					"max_hp": 10,
					"max_mp": 10,
					"heal_bonus": 0.03,
				},
				"mastery_bonus": {
					MasteryLevel.BEGINNER:     {"heal_bonus": 0.08},
					MasteryLevel.INTERMEDIATE: {"max_hp": 80, "max_mp": 50},
					MasteryLevel.ADVANCED:     {"heal_bonus": 0.15, "status_resist": 0.2},
					MasteryLevel.MASTER:       {"heal_bonus": 0.3, "max_hp": 200, "status_resist": 0.4},
				},
				"skills": [
					{"id": "heal",           "name": "回春术",      "level": 1},
					{"id": "detox",          "name": "解毒咒",      "level": 3},
					{"id": "herb_mastery",   "name": "药性精通",    "level": 5},
					{"id": "herb_shield",    "name": "百草护体",    "level": 8},
					{"id": "revitalize",     "name": "炼丹养气",    "level": 11},
					{"id": "toxin_resist",   "name": "百毒不侵",    "level": 14},
				],
			}
		
		SchoolType.TALISMAN:
			return {
				"name": "符道",
				"desc": "以符箓为引，布阵困敌。战场掌控者。",
				"element": "金/水",
				"icon": "res://assets/icons/talisman.png",
				
				"stat_per_level": {
					"attack": 2.5,
					"max_mp": 12,
					"speed": 0.02,
				},
				"mastery_bonus": {
					MasteryLevel.BEGINNER:     {"max_mp": 30},
					MasteryLevel.INTERMEDIATE: {"attack": 6, "speed": 0.1},
					MasteryLevel.ADVANCED:     {"debuff_duration_bonus": 1.5},
					MasteryLevel.MASTER:       {"attack": 18, "max_mp": 80, "debuff_duration_bonus": 2.0},
				},
				"skills": [
					{"id": "soul_seal",      "name": "镇魂符",      "level": 1},
					{"id": "ice_seal",       "name": "寒冰符",      "level": 3},
					{"id": "talisman_mastery","name": "符力精通",    "level": 5},
					{"id": "thunder_seal",   "name": "天雷符",      "level": 8},
					{"id": "eight_trigrams", "name": "八卦阵",      "level": 11},
					{"id": "array_mastery",  "name": "阵法持久",    "level": 14},
				],
			}
	
	return {}

## 流派显示名
static func get_school_name(t: int) -> String:
	return get_school_data(t).get("name", "未知")

## 获取所有流派
static func get_all_schools() -> Array[int]:
	return [SchoolType.SWORD, SchoolType.SPELL, SchoolType.BODY, 
			SchoolType.ALCHEMY, SchoolType.TALISMAN]
