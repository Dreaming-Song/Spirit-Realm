extends Node
## 修仙职业体系 — 定义五大流派属性/成长/技能树
##
## 使用方式：ClassSystem.get_class_data("sword_immortal")
## 所有数值可配置，方便平衡性调整

class_name ClassSystem

# ==================== 职业枚举 ====================
enum ClassType {
	SWORD_IMMORTAL,   # 剑修 · 金 — 高暴击单体爆发
	SPELL_WEAVER,     # 法修 · 火/水 — 范围元素伤害
	BODY_BREAKER,     # 体修 · 土 — 坦克控制
	ALCHEMY_MASTER,   # 丹修 · 木 — 治疗辅助
	TALISMAN_ADEPT,   # 符修 · 金/水 — 减益控制
}

# ==================== 职业显示名 ====================
static func get_class_name(t: int) -> String:
	match t:
		ClassType.SWORD_IMMORTAL:  return "剑修"
		ClassType.SPELL_WEAVER:    return "法修"
		ClassType.BODY_BREAKER:    return "体修"
		ClassType.ALCHEMY_MASTER:  return "丹修"
		ClassType.TALISMAN_ADEPT:  return "符修"
	return "散修"

static func get_class_title(t: int) -> String:
	match t:
		ClassType.SWORD_IMMORTAL:  return "剑仙"
		ClassType.SPELL_WEAVER:    return "法尊"
		ClassType.BODY_BREAKER:    return "武圣"
		ClassType.ALCHEMY_MASTER:  return "药王"
		ClassType.TALISMAN_ADEPT:  return "符圣"
	return "散修"

# ==================== 职业完整配置 ====================
static func get_class_data(t: int) -> Dictionary:
	match t:
		ClassType.SWORD_IMMORTAL:
			return {
				"name": "剑修",
				"title": "剑仙",
				"desc": "以剑入道，一剑破万法。高暴击、高单体爆发。",
				"element_affinity": "金",
				"primary_stat": "攻击",
				"secondary_stat": "暴击",
				
				# 基础属性（等级1时）
				"base_stats": {
					"max_hp": 80,
					"max_mp": 60,
					"attack": 18,
					"defense": 8,
					"speed": 1.2,
					"crit_rate": 0.15,    # 15% 暴击率
					"crit_damage": 2.0,    # 200% 暴击伤害
					"mp_regen": 2.0,
				},
				# 每级成长
				"growth": {
					"hp_per_level": 18,
					"mp_per_level": 12,
					"attack_per_level": 4.5,
					"defense_per_level": 1.5,
				},
				# 技能树（等级解锁）
				"skills": [
					{"id": "sword_slash",     "name": "剑气斩",    "level": 1,  "type": "active"},
					{"id": "sword_flurry",    "name": "剑影连击",  "level": 3,  "type": "active"},
					{"id": "sword_spirit",    "name": "剑意通明",  "level": 5,  "type": "passive"},
					{"id": "sword_rain",      "name": "万剑诀",    "level": 10, "type": "active"},
					{"id": "sword_thunder",   "name": "天剑引雷",  "level": 15, "type": "active"},
					{"id": "sword_intent",    "name": "剑心",      "level": 20, "type": "passive"},
				],
				# 特性
				"features": ["暴击精通", "剑气穿透", "剑意叠加"],
			}
		
		ClassType.SPELL_WEAVER:
			return {
				"name": "法修",
				"title": "法尊",
				"desc": "沟通天地五行，引动元素之力。大范围、高 AOE 伤害。",
				"element_affinity": "火/水",
				"primary_stat": "法术攻击",
				"secondary_stat": "范围",
				
				"base_stats": {
					"max_hp": 60,
					"max_mp": 100,
					"attack": 12,
					"defense": 5,
					"speed": 1.0,
					"crit_rate": 0.08,
					"crit_damage": 1.5,
					"mp_regen": 5.0,
				},
				"growth": {
					"hp_per_level": 12,
					"mp_per_level": 20,
					"attack_per_level": 5.0,
					"defense_per_level": 1.0,
				},
				"skills": [
					{"id": "fire_ball",       "name": "火球术",    "level": 1,  "type": "active"},
					{"id": "frost_array",     "name": "冰霜阵",    "level": 3,  "type": "active"},
					{"id": "mana_resonance",  "name": "法力共鸣",  "level": 5,  "type": "passive"},
					{"id": "thunder_bolt",    "name": "雷法·天罚", "level": 10, "type": "active"},
					{"id": "elemental_storm", "name": "五行崩裂",  "level": 15, "type": "active"},
					{"id": "elemental_affinity","name": "元素亲和", "level": 20, "type": "passive"},
				],
				"features": ["范围伤害+30%", "法力充沛", "元素穿透"],
			}
		
		ClassType.BODY_BREAKER:
			return {
				"name": "体修",
				"title": "武圣",
				"desc": "以肉身为兵，淬炼不灭金身。高防御、控制、团队承伤。",
				"element_affinity": "土",
				"primary_stat": "防御",
				"secondary_stat": "生命",
				
				"base_stats": {
					"max_hp": 120,
					"max_mp": 40,
					"attack": 10,
					"defense": 15,
					"speed": 0.9,
					"crit_rate": 0.05,
					"crit_damage": 1.5,
					"mp_regen": 1.0,
				},
				"growth": {
					"hp_per_level": 25,
					"mp_per_level": 8,
					"attack_per_level": 2.5,
					"defense_per_level": 4.0,
				},
				"skills": [
					{"id": "iron_body",      "name": "金刚体",    "level": 1,  "type": "active"},
					{"id": "quake_stomp",    "name": "震地击",    "level": 3,  "type": "active"},
					{"id": "iron_bones",     "name": "铁骨",      "level": 5,  "type": "passive"},
					{"id": "dragon_grab",    "name": "擒龙手",    "level": 10, "type": "active"},
					{"id": "golden_body",    "name": "不灭金身",  "level": 15, "type": "active"},
					{"id": "vital_force",    "name": "气血旺盛",  "level": 20, "type": "passive"},
				],
				"features": ["伤害减免+20%", "仇恨提升", "控制免疫"],
			}
		
		ClassType.ALCHEMY_MASTER:
			return {
				"name": "丹修",
				"title": "药王",
				"desc": "精通百草丹道，救死扶伤。治疗、驱散、增益。",
				"element_affinity": "木",
				"primary_stat": "治疗",
				"secondary_stat": "生命",
				
				"base_stats": {
					"max_hp": 90,
					"max_mp": 80,
					"attack": 8,
					"defense": 8,
					"speed": 1.0,
					"crit_rate": 0.05,
					"crit_damage": 1.5,
					"mp_regen": 3.5,
				},
				"growth": {
					"hp_per_level": 16,
					"mp_per_level": 16,
					"attack_per_level": 2.0,
					"defense_per_level": 2.0,
				},
				"skills": [
					{"id": "heal",           "name": "回春术",    "level": 1,  "type": "active"},
					{"id": "detox",          "name": "解毒咒",    "level": 3,  "type": "active"},
					{"id": "herb_mastery",   "name": "药性精通",  "level": 5,  "type": "passive"},
					{"id": "herb_shield",    "name": "百草护体",  "level": 10, "type": "active"},
					{"id": "revitalize",     "name": "炼丹养气",  "level": 15, "type": "active"},
					{"id": "toxin_resist",   "name": "百毒不侵",  "level": 20, "type": "passive"},
				],
				"features": ["治疗效果+25%", "解毒免疫", "丹药强化"],
			}
		
		ClassType.TALISMAN_ADEPT:
			return {
				"name": "符修",
				"title": "符圣",
				"desc": "以符箓为引，布阵困敌。减益、控制、战场操控。",
				"element_affinity": "金/水",
				"primary_stat": "法术攻击",
				"secondary_stat": "控制时长",
				
				"base_stats": {
					"max_hp": 70,
					"max_mp": 90,
					"attack": 14,
					"defense": 6,
					"speed": 1.1,
					"crit_rate": 0.10,
					"crit_damage": 1.8,
					"mp_regen": 3.0,
				},
				"growth": {
					"hp_per_level": 14,
					"mp_per_level": 18,
					"attack_per_level": 3.5,
					"defense_per_level": 1.5,
				},
				"skills": [
					{"id": "soul_seal",      "name": "镇魂符",    "level": 1,  "type": "active"},
					{"id": "ice_seal",       "name": "寒冰符",    "level": 3,  "type": "active"},
					{"id": "talisman_mastery","name": "符力精通",  "level": 5,  "type": "passive"},
					{"id": "thunder_seal",   "name": "天雷符",    "level": 10, "type": "active"},
					{"id": "eight_trigrams", "name": "八卦阵",    "level": 15, "type": "active"},
					{"id": "array_mastery",  "name": "阵法持久",  "level": 20, "type": "passive"},
				],
				"features": ["减益效果+30%", "符文强化", "阵法范围+50%"],
			}
	
	return {}

# ==================== 属性计算 ====================

## 根据职业 + 等级计算最终属性
static func calculate_stats(class_type: int, level: int, extra_bonus: Dictionary = {}) -> Dictionary:
	var data = get_class_data(class_type)
	if data.is_empty():
		return {}
	
	var base = data.base_stats.duplicate()
	var growth = data.growth
	
	# 等级成长
	var stats = {
		"max_hp": base.max_hp + growth.hp_per_level * (level - 1),
		"max_mp": base.max_mp + growth.mp_per_level * (level - 1),
		"attack": base.attack + growth.attack_per_level * (level - 1),
		"defense": base.defense + growth.defense_per_level * (level - 1),
		"speed": base.speed,
		"crit_rate": base.crit_rate,
		"crit_damage": base.crit_damage,
		"mp_regen": base.mp_regen,
	}
	
	# 额外加成（装备/丹药/Buff）
	for key in extra_bonus.keys():
		if stats.has(key):
			stats[key] += extra_bonus[key]
	
	return stats

## 获取五行克制倍率
## 金→木→土→水→火→金
static func get_element_multiplier(attacker_element: String, defender_element: String) -> float:
	if attacker_element.is_empty() or defender_element.is_empty():
		return 1.0
	
	var counter = {
		"金": "木",
		"木": "土",
		"土": "水",
		"水": "火",
		"火": "金",
	}
	
	if counter.get(attacker_element) == defender_element:
		return 1.5   # 克制：1.5倍
	elif counter.get(defender_element) == attacker_element:
		return 0.67  # 被克：0.67倍
	else:
		return 1.0   # 无克制
