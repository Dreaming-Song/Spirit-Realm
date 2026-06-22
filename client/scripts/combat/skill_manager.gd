extends Node
## 技能管理器 — 对接多流派修行系统
##
## 技能解锁由 CultivationSystem 控制，SkillManager 负责：
## - 技能释放/冷却/法力消耗
## - 查找技能数据
## - 连击/状态追踪

class_name SkillManager

# ==================== 技能数据库 ====================
const SKILL_DB: Dictionary = {
	# ==== 剑道 ====
	"sword_slash": {
		"name": "剑气斩", "school": "剑道",
		"cooldown": 1.5, "mp_cost": 10,
		"damage_mult": 1.2, "range": 3.0, "element": "金",
		"effects": {"bleed_prob": 0.3, "bleed_damage": 5},
		"desc": "凝聚剑气向前斩击，120%伤害，30%概率流血",
	},
	"sword_flurry": {
		"name": "剑影连击", "school": "剑道",
		"cooldown": 4.0, "mp_cost": 18,
		"damage_mult": 0.6, "range": 3.5, "element": "金",
		"effects": {"multi_hit": 3},
		"desc": "快速连斩3次，每次60%伤害",
	},
	"sword_spirit": {
		"name": "剑意通明", "school": "剑道", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"crit_rate_bonus": 0.08},
		"desc": "被动·暴击率+8%",
	},
	"sword_rain": {
		"name": "万剑诀", "school": "剑道",
		"cooldown": 8.0, "mp_cost": 35,
		"damage_mult": 0.8, "range": 8.0, "element": "金",
		"effects": {"aoe": true, "count": 12},
		"desc": "召唤万剑齐落，对范围内敌人造成80%伤害×12剑",
	},
	"sword_thunder": {
		"name": "天剑引雷", "school": "剑道",
		"cooldown": 15.0, "mp_cost": 50,
		"damage_mult": 3.5, "range": 4.0, "element": "金",
		"effects": {"crit_guarantee": true},
		"desc": "引天雷附于剑上，350%伤害，必定暴击",
	},
	"sword_intent": {
		"name": "剑心", "school": "剑道", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"crit_damage_bonus": 0.5},
		"desc": "被动·暴击伤害+50%",
	},
	
	# ==== 法术 ====
	"fire_ball": {
		"name": "火球术", "school": "法术",
		"cooldown": 1.0, "mp_cost": 12,
		"damage_mult": 1.0, "range": 6.0, "element": "火",
		"effects": {"burn_prob": 0.4, "burn_damage": 8},
		"desc": "凝聚火球攻击，100%伤害，40%概率灼烧",
	},
	"frost_array": {
		"name": "冰霜阵", "school": "法术",
		"cooldown": 5.0, "mp_cost": 20,
		"damage_mult": 0.7, "range": 5.0, "element": "水",
		"effects": {"slow_pct": 0.6, "slow_duration": 3.0, "aoe": true},
		"desc": "冰霜法阵，70%伤害+60%减速3秒",
	},
	"mana_resonance": {
		"name": "法力共鸣", "school": "法术", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"mp_regen_bonus": 3.0},
		"desc": "被动·每秒额外回复3点法力",
	},
	"thunder_bolt": {
		"name": "雷法·天罚", "school": "法术",
		"cooldown": 7.0, "mp_cost": 30,
		"damage_mult": 2.0, "range": 8.0, "element": "火",
		"effects": {"stun_prob": 0.3, "stun_duration": 1.5, "aoe": true},
		"desc": "引天雷劈落，200%范围伤害，30%概率眩晕1.5秒",
	},
	"elemental_storm": {
		"name": "五行崩裂", "school": "法术",
		"cooldown": 12.0, "mp_cost": 50,
		"damage_mult": 1.5, "range": 10.0, "element": "火",
		"effects": {"aoe": true, "element_chaos": true},
		"desc": "引动五行之力爆破，150%范围伤害",
	},
	"elemental_affinity": {
		"name": "元素亲和", "school": "法术", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"element_damage_bonus": 0.2},
		"desc": "被动·元素伤害+20%",
	},
	
	# ==== 体术 ====
	"iron_body": {
		"name": "金刚体", "school": "体术",
		"cooldown": 6.0, "mp_cost": 15,
		"damage_mult": 0.5, "range": 2.5, "element": "土",
		"effects": {"defense_buff_pct": 0.5, "buff_duration": 4.0},
		"desc": "金刚护体，防御+50%持续4秒",
	},
	"quake_stomp": {
		"name": "震地击", "school": "体术",
		"cooldown": 4.0, "mp_cost": 12,
		"damage_mult": 0.8, "range": 4.0, "element": "土",
		"effects": {"stun_prob": 0.5, "stun_duration": 1.0, "aoe": true},
		"desc": "猛踏地面，80%范围伤害+50%眩晕1秒",
	},
	"iron_bones": {
		"name": "铁骨", "school": "体术", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"damage_reduction": 0.10},
		"desc": "被动·常驻减伤10%",
	},
	"dragon_grab": {
		"name": "擒龙手", "school": "体术",
		"cooldown": 8.0, "mp_cost": 20,
		"damage_mult": 1.2, "range": 5.0, "element": "土",
		"effects": {"pull": true, "stun_duration": 1.0},
		"desc": "隔空擒拿，拉至身前眩晕1秒，120%伤害",
	},
	"golden_body": {
		"name": "不灭金身", "school": "体术",
		"cooldown": 30.0, "mp_cost": 60,
		"damage_mult": 0, "range": 0, "element": "土",
		"effects": {"invincible": true, "duration": 3.0, "heal_pct": 0.20},
		"desc": "3秒无敌+恢复20%生命值",
	},
	"vital_force": {
		"name": "气血旺盛", "school": "体术", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"hp_regen": 3.0},
		"desc": "被动·每秒恢复3点生命",
	},
	
	# ==== 丹道 ====
	"heal": {
		"name": "回春术", "school": "丹道",
		"cooldown": 2.0, "mp_cost": 15,
		"damage_mult": 0, "range": 5.0, "element": "木",
		"effects": {"heal_mult": 1.5},
		"desc": "以木灵之力治愈，恢复150%攻击力的生命",
	},
	"detox": {
		"name": "解毒咒", "school": "丹道",
		"cooldown": 3.0, "mp_cost": 10,
		"damage_mult": 0, "range": 5.0, "element": "木",
		"effects": {"cure": true, "cure_all": true},
		"desc": "驱散目标的负面状态",
	},
	"herb_mastery": {
		"name": "药性精通", "school": "丹道", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"heal_bonus": 0.25},
		"desc": "被动·治疗效果+25%",
	},
	"herb_shield": {
		"name": "百草护体", "school": "丹道",
		"cooldown": 8.0, "mp_cost": 25,
		"damage_mult": 0, "range": 5.0, "element": "木",
		"effects": {"shield_mult": 2.0, "shield_duration": 5.0},
		"desc": "百草之力形成护盾，吸收200%攻击力伤害",
	},
	"revitalize": {
		"name": "炼丹养气", "school": "丹道",
		"cooldown": 20.0, "mp_cost": 40,
		"damage_mult": 0, "range": 8.0, "element": "木",
		"effects": {"aoe_heal_mult": 1.0, "mp_restore": 30},
		"desc": "群体恢复100%攻击力生命+回复30法力",
	},
	"toxin_resist": {
		"name": "百毒不侵", "school": "丹道", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"status_resist": 0.5},
		"desc": "被动·负面状态抗性+50%",
	},
	
	# ==== 符道 ====
	"soul_seal": {
		"name": "镇魂符", "school": "符道",
		"cooldown": 2.0, "mp_cost": 12,
		"damage_mult": 0.8, "range": 6.0, "element": "金",
		"effects": {"silence_prob": 0.4, "silence_duration": 2.0},
		"desc": "打出镇魂符咒，80%伤害+40%沉默2秒",
	},
	"ice_seal": {
		"name": "寒冰符", "school": "符道",
		"cooldown": 5.0, "mp_cost": 18,
		"damage_mult": 1.1, "range": 6.0, "element": "水",
		"effects": {"freeze_prob": 0.3, "freeze_duration": 2.0},
		"desc": "寒冰符冻结目标，110%伤害+30%冰冻2秒",
	},
	"talisman_mastery": {
		"name": "符力精通", "school": "符道", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"debuff_duration_bonus": 1.5},
		"desc": "被动·减益持续时间×1.5",
	},
	"thunder_seal": {
		"name": "天雷符", "school": "符道",
		"cooldown": 7.0, "mp_cost": 28,
		"damage_mult": 1.8, "range": 7.0, "element": "金",
		"effects": {"paralyze_prob": 0.5, "paralyze_duration": 1.5},
		"desc": "天雷符箓降下雷击，180%伤害+50%麻痹1.5秒",
	},
	"eight_trigrams": {
		"name": "八卦阵", "school": "符道",
		"cooldown": 12.0, "mp_cost": 40,
		"damage_mult": 0.5, "range": 8.0, "element": "金",
		"effects": {"aoe": true, "debuff_all_pct": 0.3, "field_duration": 6.0},
		"desc": "八卦大阵，范围内敌人全属性-30%持续6秒",
	},
	"array_mastery": {
		"name": "阵法持久", "school": "符道", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"array_range_bonus": 0.5},
		"desc": "被动·阵法范围+50%",
	},
}

# ==================== 运行时状态 ====================
var _cooldowns: Dictionary = {}       # skill_id → remaining
var _cultivation: CultivationSystem    # 引用修行系统
var _current_mp: float = 0
var _max_mp: float = 0

# 信号
signal skill_used(skill_id: String, skill_name: String, target: Node)
signal skill_on_cooldown(skill_id: String, remaining: float)
signal mp_changed(current: float, max: float)
signal skill_not_learned(skill_id: String, skill_name: String)

func _ready() -> void:
	_cultivation = get_tree().get_first_node_in_group("player_cultivation")
	if not _cultivation:
		# 尝试从 autoload 拿
		_cultivation = get_node("/root/CultivationSystem") if has_node("/root/CultivationSystem") else CultivationSystem.new()

func _process(delta: float) -> void:
	# 冷却递减
	for skill_id in _cooldowns.keys():
		_cooldowns[skill_id] -= delta
		if _cooldowns[skill_id] <= 0:
			_cooldowns.erase(skill_id)
	
	# 法力恢复
	if _cultivation:
		var stats = _cultivation.calculate_total_stats()
		_current_mp = min(_current_mp + stats.get("mp_regen", 2.0) * delta, _max_mp)

# ==================== 核心接口 ====================

## 尝试释放技能
## 返回 {success, damage, is_crit, ...} 或 {success: false, reason: "..."}
func use_skill(skill_id: String, caster: Node, target: Node = null) -> Dictionary:
	if not _cultivation:
		return {"success": false, "reason": "修行系统未加载"}
	
	# 1. 检查是否已学习该技能
	if not _cultivation.has_skill(skill_id):
		skill_not_learned.emit(skill_id, get_skill_data(skill_id).get("name", skill_id))
		return {"success": false, "reason": "未学习该技能"}
	
	var data = SKILL_DB.get(skill_id)
	if not data:
		return {"success": false, "reason": "技能不存在"}
	
	# 2. 检查冷却
	if _cooldowns.has(skill_id):
		skill_on_cooldown.emit(skill_id, _cooldowns[skill_id])
		return {"success": false, "reason": "冷却中"}
	
	# 3. 检查法力
	var stats = _cultivation.calculate_total_stats()
	_max_mp = stats.get("max_mp", 50)
	if _current_mp < data.mp_cost:
		return {"success": false, "reason": "法力不足"}
	
	# 4. 消耗法力
	_current_mp -= data.mp_cost
	mp_changed.emit(_current_mp, _max_mp)
	
	# 5. 设置冷却
	if data.cooldown > 0:
		_cooldowns[skill_id] = data.cooldown
	
	# 6. 计算伤害（如果是伤害技能）
	var result = {"success": true, "skill_id": skill_id, "skill_name": data.name}
	
	if data.damage_mult > 0:
		var dmg_result = DamageCalculator.calculate_damage(stats, {}, data)
		result["damage"] = dmg_result.damage
		result["is_crit"] = dmg_result.is_crit
		result["element"] = dmg_result.element
	
	# 7. 信号
	skill_used.emit(skill_id, data.name, target)
	
	return result

## 同步法力值（从外部设置）
func set_mp(mp: float, max_mp: float) -> void:
	_current_mp = mp
	_max_mp = max_mp
	mp_changed.emit(_current_mp, _max_mp)

## 恢复法力
func restore_mp(amount: float) -> void:
	_current_mp = min(_current_mp + amount, _max_mp)
	mp_changed.emit(_current_mp, _max_mp)

# ==================== 查询接口 ====================

## 获取技能数据
static func get_skill_data(skill_id: String) -> Dictionary:
	return SKILL_DB.get(skill_id, {})

## 获取所有技能（按流派分组）
static func get_skills_by_school() -> Dictionary:
	var result: Dictionary = {}
	for skill_id in SKILL_DB.keys():
		var data = SKILL_DB[skill_id]
		var school = data.get("school", "其他")
		if not result.has(school):
			result[school] = []
		result[school].append({"id": skill_id, "data": data})
	return result

## 获取某流派的所有技能 ID
static func get_school_skill_ids(school_name: String) -> Array[String]:
	var ids: Array[String] = []
	for skill_id in SKILL_DB.keys():
		if SKILL_DB[skill_id].get("school") == school_name:
			ids.append(skill_id)
	return ids

## 获取技能剩余冷却
func get_cooldown(skill_id: String) -> float:
	return _cooldowns.get(skill_id, 0.0)

## 获取当前法力
func get_current_mp() -> float:
	return _current_mp

## 获取最大法力
func get_max_mp() -> float:
	return _max_mp
