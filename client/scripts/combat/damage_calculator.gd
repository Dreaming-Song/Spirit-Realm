extends Node
## 伤害计算器 — 五行克制、暴击、减伤、最终伤害公式
##
## 纯静态方法，供所有战斗系统调用

class_name DamageCalculator

# ==================== 五行克制表 ====================
const ELEMENT_COUNTER: Dictionary = {
	"金": "木", "木": "土", "土": "水",
	"水": "火", "火": "金",
}
const COUNTER_MULTIPLIER: float = 1.5
const RESIST_MULTIPLIER: float = 0.67

# ==================== 伤害计算 ====================

## 计算最终伤害
## 参数：
##   attacker_stats  — 攻击者属性 {attack, crit_rate, crit_damage, ...}
##   defender_stats  — 防御者属性 {defense, damage_reduction, ...}
##   skill_data      — 技能数据 {damage_mult, element, effects}
##   extra_modifiers — 额外加成（装备/阵法/丹药）
##
## 返回：{damage, is_crit, element, details}
static func calculate_damage(
	attacker_stats: Dictionary,
	defender_stats: Dictionary,
	skill_data: Dictionary,
	extra_modifiers: Dictionary = {}
) -> Dictionary:
	
	# 1. 基础攻击力
	var base_attack = attacker_stats.get("attack", 10)
	var damage_mult = skill_data.get("damage_mult", 1.0)
	var raw_damage = base_attack * damage_mult
	
	# 2. 技能额外伤害加成
	var skill_bonus = skill_data.get("damage_bonus", 0.0)
	raw_damage += skill_bonus
	
	# 3. 防御减免
	var defense = defender_stats.get("defense", 0)
	# 减伤公式：防御/(防御+100)，软上限
	var defense_reduction = defense / (defense + 100.0)
	raw_damage *= (1.0 - defense_reduction)
	
	# 4. 常驻减伤
	var damage_reduction = defender_stats.get("damage_reduction", 0.0)
	raw_damage *= (1.0 - damage_reduction)
	
	# 5. 五行克制
	var attacker_element = skill_data.get("element", "")
	var defender_element = defender_stats.get("element", "")
	var element_mult = 1.0
	var element_detail = ""
	
	if not attacker_element.is_empty() and not defender_element.is_empty():
		if ELEMENT_COUNTER.get(attacker_element) == defender_element:
			element_mult = COUNTER_MULTIPLIER  # 克制
			element_detail = "克制"
		elif ELEMENT_COUNTER.get(defender_element) == attacker_element:
			element_mult = RESIST_MULTIPLIER   # 被克
			element_detail = "被克"
	
	raw_damage *= element_mult
	
	# 6. 元素伤害加成
	var element_damage_bonus = attacker_stats.get("element_damage_bonus", 0.0)
	raw_damage *= (1.0 + element_damage_bonus)
	
	# 7. 暴击判定
	var crit_rate = attacker_stats.get("crit_rate", 0.0)
	var crit_damage = attacker_stats.get("crit_damage", 1.5)
	var is_crit = false
	
	# 技能指定必定暴击
	if skill_data.get("effects", {}).get("crit_guarantee", false):
		is_crit = true
	elif randf() < crit_rate:
		is_crit = true
	
	if is_crit:
		raw_damage *= crit_damage
	
	# 8. 随机波动 ±10%
	var variance = randf_range(0.9, 1.1)
	raw_damage *= variance
	
	# 9. 最低保底
	var final_damage = max(int(raw_damage), 1)
	
	# 10. 额外修饰
	for key in extra_modifiers.keys():
		match key:
			"damage_bonus_pct":
				final_damage = int(final_damage * (1.0 + extra_modifiers[key]))
			"flat_damage":
				final_damage += extra_modifiers[key]
	
	return {
		"damage": final_damage,
		"is_crit": is_crit,
		"element": attacker_element,
		"element_mult": element_mult,
		"element_detail": element_detail,
		"defense_reduction": defense_reduction,
		"raw_before_variance": raw_damage,
	}

# ==================== 治疗计算 ====================

## 计算治疗量
static func calculate_healing(
	healer_stats: Dictionary,
	target_stats: Dictionary,
	skill_data: Dictionary
) -> int:
	var base_attack = healer_stats.get("attack", 10)
	var heal_mult = skill_data.get("effects", {}).get("heal_mult", 1.0)
	var heal_bonus = healer_stats.get("heal_bonus", 0.0)
	
	var heal_amount = base_attack * heal_mult * (1.0 + heal_bonus)
	
	# 目标受治疗加成
	var incoming_heal_bonus = target_stats.get("incoming_heal_bonus", 0.0)
	heal_amount *= (1.0 + incoming_heal_bonus)
	
	var variance = randf_range(0.95, 1.05)
	return max(int(heal_amount * variance), 1)

# ==================== 护盾计算 ====================

static func calculate_shield(
	caster_stats: Dictionary,
	skill_data: Dictionary
) -> int:
	var base_attack = caster_stats.get("attack", 10)
	var shield_mult = skill_data.get("effects", {}).get("shield_mult", 1.0)
	return max(int(base_attack * shield_mult), 1)

# ==================== 状态效果概率 ====================

## 判断状态是否生效（考虑抗性）
static func roll_status_effect(
	effect_name: String,
	base_prob: float,
	defender_stats: Dictionary
) -> bool:
	var status_resist = defender_stats.get("status_resist", 0.0)
	var effective_prob = base_prob * (1.0 - status_resist)
	return randf() < effective_prob

# ==================== 辅助 ====================

## 获取元素克制关系描述
static func get_element_relation_desc(attacker: String, defender: String) -> String:
	if attacker.is_empty() or defender.is_empty():
		return "无克制"
	
	if ELEMENT_COUNTER.get(attacker) == defender:
		return "%s 克制 %s (×%.1f)" % [attacker, defender, COUNTER_MULTIPLIER]
	elif ELEMENT_COUNTER.get(defender) == attacker:
		return "%s 被 %s 克制 (×%.1f)" % [attacker, defender, RESIST_MULTIPLIER]
	else:
		return "无克制关系"
