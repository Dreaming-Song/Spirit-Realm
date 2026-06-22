extends Node
## 修行系统 — 多流派自由修行核心
##
## 角色不再绑定单一职业，而是可自由选择修炼多个流派：
## - 全修五派（博而不精）
## - 专精一派（登峰造极）
## - 只学部分技能（随意搭配）
##
## 修行点数通过战斗/任务/修炼获得，自由分配到各流派

class_name CultivationSystem

# ==================== 信号 ====================
signal school_leveled(school_type: int, new_level: int, mastery_name: String)
signal skill_unlocked(skill_id: String, skill_name: String, school_name: String)
signal cultivation_points_changed(points: int)
signal specialization_changed(school_type: int)

# ==================== 玩家修行数据 ====================
## 每个流派的等级（可独立提升）
var school_levels: Dictionary = {
	CultivationSchool.SchoolType.SWORD: 0,
	CultivationSchool.SchoolType.SPELL: 0,
	CultivationSchool.SchoolType.BODY: 0,
	CultivationSchool.SchoolType.ALCHEMY: 0,
	CultivationSchool.SchoolType.TALISMAN: 0,
}

## 已学习的技能（skill_id → true）
var learned_skills: Dictionary = {}

## 修行点数（自由分配）
var cultivation_points: int = 0

## 当前总等级（所有流派等级之和）
var total_cultivation_level: int = 0

## 专精流派（选择一项获得专精加成，可随时更换但需冷却）
var specialized_school: int = -1
var _specialization_cooldown: float = 0.0

# ==================== 初始化 ====================

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if _specialization_cooldown > 0:
		_specialization_cooldown -= delta

# ==================== 修行点数管理 ====================

## 加点：提升指定流派的等级
func invest_in_school(school_type: int, levels: int = 1) -> bool:
	if cultivation_points < levels:
		print("⚠️ 修行点数不足（需要 %d，当前 %d）" % [levels, cultivation_points])
		return false
	
	var current = school_levels.get(school_type, 0)
	school_levels[school_type] = current + levels
	cultivation_points -= levels
	total_cultivation_level += levels
	
	# 检查新解锁的技能
	_check_new_skills(school_type, current, school_levels[school_type])
	
	# 信号
	var mastery = CultivationSchool.get_mastery_name(school_levels[school_type])
	school_leveled.emit(school_type, school_levels[school_type], mastery)
	cultivation_points_changed.emit(cultivation_points)
	
	print("📈 %s → Lv.%d（%s）" % [
		CultivationSchool.get_school_name(school_type),
		school_levels[school_type], mastery
	])
	return true

## 批量加点（UI用）
func batch_invest(distribution: Dictionary) -> bool:
	"""distribution = {school_type: levels}"""
	var total_cost = 0
	for levels in distribution.values():
		total_cost += levels
	
	if cultivation_points < total_cost:
		return false
	
	for school_type in distribution.keys():
		var levels = distribution[school_type]
		var current = school_levels.get(school_type, 0)
		school_levels[school_type] = current + levels
		_check_new_skills(school_type, current, school_levels[school_type])
		
		var mastery = CultivationSchool.get_mastery_name(school_levels[school_type])
		school_leveled.emit(school_type, school_levels[school_type], mastery)
	
	cultivation_points -= total_cost
	total_cultivation_level += total_cost
	cultivation_points_changed.emit(cultivation_points)
	return true

# ==================== 技能解锁 ====================

func _check_new_skills(school_type: int, old_level: int, new_level: int) -> void:
	"""检查该流派新等级解锁了哪些技能"""
	var data = CultivationSchool.get_school_data(school_type)
	for skill in data.get("skills", []):
		var skill_id = skill.id
		var req_level = skill.level
		
		# 如果之前没解锁，现在达到等级了
		if old_level < req_level and new_level >= req_level:
			learned_skills[skill_id] = true
			skill_unlocked.emit(skill_id, skill.name, data.name)
			print("📖 解锁技能【%s】（%s Lv.%d）" % [skill.name, data.name, req_level])

## 获取已解锁的所有技能 ID
func get_learned_skill_ids() -> Array[String]:
	return learned_skills.keys()

## 检查技能是否已解锁
func has_skill(skill_id: String) -> bool:
	return learned_skills.has(skill_id)

## 强制学习一个技能（剧情/奇遇用）
func force_learn_skill(skill_id: String) -> void:
	learned_skills[skill_id] = true
	print("🌟 奇遇！领悟技能：%s" % skill_id)

# ==================== 专精系统 ====================

## 设置专精流派
func set_specialization(school_type: int) -> bool:
	if _specialization_cooldown > 0:
		print("⚠️ 专精冷却中（剩余 %.1f秒）" % _specialization_cooldown)
		return false
	
	if school_levels.get(school_type, 0) < 3:
		print("⚠️ 该流派等级≥3才能设为专精")
		return false
	
	# 取消旧专精
	var old = specialized_school
	specialized_school = school_type
	_specialization_cooldown = 60.0  # 1分钟冷却
	specialization_changed.emit(school_type)
	
	print("🎯 专精流派更改为：%s" % CultivationSchool.get_school_name(school_type))
	return true

## 判断是否专精该流派
func is_specialized(school_type: int) -> bool:
	return specialized_school == school_type

## 获取专精加成倍率
func get_specialization_mult() -> float:
	if specialized_school >= 0:
		return 1.25  # 专精流派效果+25%
	return 1.0

# ==================== 属性计算 ====================

## 根据所有流派的等级计算最终属性
func calculate_total_stats() -> Dictionary:
	var final_stats = {
		"max_hp": 100,        # 基础生命
		"max_mp": 50,         # 基础法力
		"attack": 8,          # 基础攻击
		"defense": 5,         # 基础防御
		"speed": 1.0,
		"crit_rate": 0.05,
		"crit_damage": 1.5,
		"mp_regen": 2.0,
		"hp_regen": 0.5,
		"heal_bonus": 0.0,
		"damage_reduction": 0.0,
		"element_damage_bonus": 0.0,
		"status_resist": 0.0,
		"debuff_duration_bonus": 0.0,
	}
	
	# 遍历所有流派，叠加每级属性
	var all_schools = CultivationSchool.get_all_schools()
	for school_type in all_schools:
		var level = school_levels.get(school_type, 0)
		if level <= 0:
			continue
		
		var data = CultivationSchool.get_school_data(school_type)
		var per_level = data.get("stat_per_level", {})
		var spec_mult = 1.0
		
		# 专精加成
		if school_type == specialized_school:
			spec_mult = get_specialization_mult()
		
		# 叠加每级属性
		for stat_key in per_level.keys():
			var value = per_level[stat_key] * level * spec_mult
			if final_stats.has(stat_key):
				final_stats[stat_key] += value
		
		# 境界突破加成
		var mastery = CultivationSchool.get_mastery_enum(level)
		var mastery_bonus = data.get("mastery_bonus", {}).get(mastery, {})
		for stat_key in mastery_bonus.keys():
			if final_stats.has(stat_key):
				final_stats[stat_key] += mastery_bonus[stat_key] * spec_mult
	
	# 数值取整
	for key in ["max_hp", "max_mp", "attack", "defense"]:
		final_stats[key] = int(final_stats[key])
	
	# 属性上限约束
	final_stats["crit_rate"] = min(final_stats["crit_rate"], 0.80)
	final_stats["damage_reduction"] = min(final_stats["damage_reduction"], 0.60)
	
	return final_stats

# ==================== 查询 ====================

## 获取流派等级
func get_school_level(school_type: int) -> int:
	return school_levels.get(school_type, 0)

## 获取流派境界名
func get_school_mastery_name(school_type: int) -> String:
	var level = school_levels.get(school_type, 0)
	return CultivationSchool.get_mastery_name(level)

## 获取所有流派等级一览
func get_all_school_levels() -> Dictionary:
	return school_levels.duplicate()

## 获取流派总览（供UI显示）
func get_school_overview() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for st in CultivationSchool.get_all_schools():
		var data = CultivationSchool.get_school_data(st)
		var level = school_levels.get(st, 0)
		var mastery = CultivationSchool.get_mastery_name(level)
		result.append({
			"type": st,
			"name": data.name,
			"desc": data.desc,
			"element": data.element,
			"level": level,
			"mastery": mastery,
			"is_specialized": st == specialized_school,
			"skills_count": _get_learned_skills_count(st),
			"total_skills": data.get("skills", []).size(),
		})
	return result

## 获取流派已学技能数
func _get_learned_skills_count(school_type: int) -> int:
	var data = CultivationSchool.get_school_data(school_type)
	var count = 0
	for skill in data.get("skills", []):
		if learned_skills.has(skill.id):
			count += 1
	return count

## 获取可分配的总点数（由修为值换算）
func add_cultivation_xp(xp: int) -> int:
	"""返回获得的修行点数"""
	var points_gained = xp / 100  # 100修为 = 1点
	if points_gained > 0:
		cultivation_points += points_gained
		cultivation_points_changed.emit(cultivation_points)
	return points_gained

# ==================== 存档 ====================

func get_save_data() -> Dictionary:
	return {
		"school_levels": school_levels,
		"learned_skills": learned_skills.keys(),
		"cultivation_points": cultivation_points,
		"specialized_school": specialized_school,
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("school_levels"):
		for k in data.school_levels.keys():
			school_levels[int(k)] = data.school_levels[k]
	if data.has("learned_skills"):
		for skill_id in data.learned_skills:
			learned_skills[skill_id] = true
	cultivation_points = data.get("cultivation_points", 0)
	specialized_school = data.get("specialized_school", -1)
