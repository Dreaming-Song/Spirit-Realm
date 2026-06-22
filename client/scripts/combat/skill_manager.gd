extends Node
## 技能管理器 — 技能释放、冷却、连击、状态追踪
##
## 挂载到玩家节点，处理技能输入和执行

class_name SkillManager

# ==================== 技能数据结构 ====================
struct SkillData:
	var id: String
	var name: String
	var type: String          # "active" / "passive"
	var level_required: int
	var cooldown_time: float  # 秒
	var mp_cost: int
	var damage_mult: float    # 攻击力百分比
	var range: float
	var element: String
	var effects: Dictionary   # 附加效果
	var description: String

# ==================== 技能配置表 ====================
const SKILL_DB: Dictionary = {
	# ---- 剑修技能 ----
	"sword_slash": {
		"name": "剑气斩", "type": "active",
		"cooldown": 1.5, "mp_cost": 10,
		"damage_mult": 1.2, "range": 3.0, "element": "金",
		"effects": {"bleed": 0.3, "bleed_damage": 5},
		"desc": "凝聚剑气向前斩击，造成120%伤害，30%概率流血",
	},
	"sword_flurry": {
		"name": "剑影连击", "type": "active",
		"cooldown": 4.0, "mp_cost": 18,
		"damage_mult": 0.6, "range": 3.5, "element": "金",
		"effects": {"multi_hit": 3},
		"desc": "快速连斩3次，每次造成60%伤害",
	},
	"sword_spirit": {
		"name": "剑意通明", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"crit_rate_bonus": 0.08},
		"desc": "剑意灌注，暴击率+8%",
	},
	"sword_rain": {
		"name": "万剑诀", "type": "active",
		"cooldown": 8.0, "mp_cost": 35,
		"damage_mult": 0.8, "range": 8.0, "element": "金",
		"effects": {"aoe": true, "count": 12},
		"desc": "召唤万剑齐落，对范围内敌人造成80%伤害×12剑",
	},
	"sword_thunder": {
		"name": "天剑引雷", "type": "active",
		"cooldown": 15.0, "mp_cost": 50,
		"damage_mult": 3.5, "range": 4.0, "element": "金",
		"effects": {"crit_guarantee": true},
		"desc": "引天雷附于剑上，造成350%伤害，必定暴击",
	},
	"sword_intent": {
		"name": "剑心", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"crit_damage_bonus": 0.5},
		"desc": "剑心通明，暴击伤害+50%",
	},
	
	# ---- 法修技能 ----
	"fire_ball": {
		"name": "火球术", "type": "active",
		"cooldown": 1.0, "mp_cost": 12,
		"damage_mult": 1.0, "range": 6.0, "element": "火",
		"effects": {"burn": 0.4, "burn_damage": 8},
		"desc": "凝聚火球攻击，100%伤害，40%概率灼烧",
	},
	"frost_array": {
		"name": "冰霜阵", "type": "active",
		"cooldown": 5.0, "mp_cost": 20,
		"damage_mult": 0.7, "range": 5.0, "element": "水",
		"effects": {"slow": 0.6, "slow_duration": 3.0, "aoe": true},
		"desc": "在地面展开冰霜法阵，70%伤害+60%减速3秒",
	},
	"mana_resonance": {
		"name": "法力共鸣", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"mp_regen_bonus": 3.0},
		"desc": "法力流动加速，每秒额外回复3点法力",
	},
	"thunder_bolt": {
		"name": "雷法·天罚", "type": "active",
		"cooldown": 7.0, "mp_cost": 30,
		"damage_mult": 2.0, "range": 8.0, "element": "火",
		"effects": {"stun": 0.3, "stun_duration": 1.5, "aoe": true},
		"desc": "引天雷劈落，200%范围伤害，30%概率眩晕1.5秒",
	},
	"elemental_storm": {
		"name": "五行崩裂", "type": "active",
		"cooldown": 12.0, "mp_cost": 50,
		"damage_mult": 1.5, "range": 10.0, "element": "火",
		"effects": {"aoe": true, "element_chaos": true},
		"desc": "引动五行之力爆破，150%范围伤害，五行属性随机",
	},
	"elemental_affinity": {
		"name": "元素亲和", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"element_damage_bonus": 0.2},
		"desc": "元素之力亲和，所有元素伤害+20%",
	},
	
	# ---- 体修技能 ----
	"iron_body": {
		"name": "金刚体", "type": "active",
		"cooldown": 6.0, "mp_cost": 15,
		"damage_mult": 0.5, "range": 2.5, "element": "土",
		"effects": {"defense_up": 0.5, "defense_duration": 4.0},
		"desc": "金刚护体，防御提升50%持续4秒，造成50%伤害",
	},
	"quake_stomp": {
		"name": "震地击", "type": "active",
		"cooldown": 4.0, "mp_cost": 12,
		"damage_mult": 0.8, "range": 4.0, "element": "土",
		"effects": {"stun": 0.5, "stun_duration": 1.0, "aoe": true},
		"desc": "猛踏地面，80%范围伤害+50%概率眩晕1秒",
	},
	"iron_bones": {
		"name": "铁骨", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"damage_reduction": 0.10},
		"desc": "淬炼铁骨，常驻伤害减免10%",
	},
	"dragon_grab": {
		"name": "擒龙手", "type": "active",
		"cooldown": 8.0, "mp_cost": 20,
		"damage_mult": 1.2, "range": 5.0, "element": "土",
		"effects": {"pull": true, "stun": 1.0},
		"desc": "隔空擒拿，将敌人拉至身前并眩晕1秒，120%伤害",
	},
	"golden_body": {
		"name": "不灭金身", "type": "active",
		"cooldown": 30.0, "mp_cost": 60,
		"damage_mult": 0, "range": 0, "element": "土",
		"effects": {"invincible": true, "duration": 3.0, "heal_pct": 0.20},
		"desc": "3秒无敌+恢复20%生命值",
	},
	"vital_force": {
		"name": "气血旺盛", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"hp_regen": 3.0},
		"desc": "气血循环不息，每秒恢复3点生命",
	},
	
	# ---- 丹修技能 ----
	"heal": {
		"name": "回春术", "type": "active",
		"cooldown": 2.0, "mp_cost": 15,
		"damage_mult": 0, "range": 5.0, "element": "木",
		"effects": {"heal_mult": 1.5, "target": "ally"},
		"desc": "以木灵之力治愈伤口，恢复150%攻击力的生命",
	},
	"detox": {
		"name": "解毒咒", "type": "active",
		"cooldown": 3.0, "mp_cost": 10,
		"damage_mult": 0, "range": 5.0, "element": "木",
		"effects": {"cure": true, "cure_all": true},
		"desc": "驱散目标的负面状态",
	},
	"herb_mastery": {
		"name": "药性精通", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"heal_bonus": 0.25},
		"desc": "药性理解精深，治疗效果+25%",
	},
	"herb_shield": {
		"name": "百草护体", "type": "active",
		"cooldown": 8.0, "mp_cost": 25,
		"damage_mult": 0, "range": 5.0, "element": "木",
		"effects": {"shield_mult": 2.0, "shield_duration": 5.0, "target": "ally"},
		"desc": "百草之力形成护盾，吸收200%攻击力伤害，持续5秒",
	},
	"revitalize": {
		"name": "炼丹养气", "type": "active",
		"cooldown": 20.0, "mp_cost": 40,
		"damage_mult": 0, "range": 8.0, "element": "木",
		"effects": {"aoe_heal_mult": 1.0, "mp_restore": 30},
		"desc": "释放丹气，群体恢复100%攻击力生命+回复30法力",
	},
	"toxin_resist": {
		"name": "百毒不侵", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"status_resist": 0.5},
		"desc": "常年炼丹，负面状态抗性+50%",
	},
	
	# ---- 符修技能 ----
	"soul_seal": {
		"name": "镇魂符", "type": "active",
		"cooldown": 2.0, "mp_cost": 12,
		"damage_mult": 0.8, "range": 6.0, "element": "金",
		"effects": {"silence": 0.4, "silence_duration": 2.0},
		"desc": "打出镇魂符咒，80%伤害+40%概率沉默2秒",
	},
	"ice_seal": {
		"name": "寒冰符", "type": "active",
		"cooldown": 5.0, "mp_cost": 18,
		"damage_mult": 1.1, "range": 6.0, "element": "水",
		"effects": {"freeze": 0.3, "freeze_duration": 2.0},
		"desc": "寒冰符冻结目标，110%伤害+30%概率冰冻2秒",
	},
	"talisman_mastery": {
		"name": "符力精通", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"debuff_duration_bonus": 1.5},
		"desc": "符箓之力强化，减益效果持续时间×1.5",
	},
	"thunder_seal": {
		"name": "天雷符", "type": "active",
		"cooldown": 7.0, "mp_cost": 28,
		"damage_mult": 1.8, "range": 7.0, "element": "金",
		"effects": {"paralyze": 0.5, "paralyze_duration": 1.5},
		"desc": "天雷符箓降下雷击，180%伤害+50%麻痹1.5秒",
	},
	"eight_trigrams": {
		"name": "八卦阵", "type": "active",
		"cooldown": 12.0, "mp_cost": 40,
		"damage_mult": 0.5, "range": 8.0, "element": "金",
		"effects": {"aoe": true, "debuff_all": 0.3, "field_duration": 6.0},
		"desc": "布下八卦大阵，使范围内敌人全属性降低30%，持续6秒",
	},
	"array_mastery": {
		"name": "阵法持久", "type": "passive",
		"cooldown": 0, "mp_cost": 0,
		"damage_mult": 0, "range": 0, "element": "",
		"effects": {"array_range_bonus": 0.5},
		"desc": "阵法范围+50%，阵法持续时间+30%",
	},
}

# ==================== 运行时状态 ====================
var _cooldowns: Dictionary = {}       # skill_id → remaining
var _player_stats: Dictionary = {}    # 当前玩家属性缓存
var _class_type: int = -1
var _level: int = 1
var _unlocked_skills: Array[String] = []
var _passive_bonuses: Dictionary = {} # 被动效果累加

# 信号
signal skill_used(skill_id: String, skill_name: String, target: Node)
signal skill_on_cooldown(skill_id: String, remaining: float)
signal skill_unlocked(skill_id: String, skill_name: String)
signal mp_changed(current: float, max: float)

func _process(delta: float) -> void:
	# 冷却递减
	for skill_id in _cooldowns.keys():
		_cooldowns[skill_id] -= delta
		if _cooldowns[skill_id] <= 0:
			_cooldowns.erase(skill_id)

# ==================== 初始化 ====================

func initialize(class_type: int, level: int, extra_stats: Dictionary = {}) -> void:
	_class_type = class_type
	_level = level
	_player_stats = ClassSystem.calculate_stats(class_type, level, extra_stats)
	
	# 解锁该等级的技能
	_refresh_unlocked_skills()
	
	# 计算被动加成
	_calculate_passive_bonuses()

func _refresh_unlocked_skills() -> void:
	var class_data = ClassSystem.get_class_data(_class_type)
	_unlocked_skills.clear()
	
	for skill in class_data.skills:
		if _level >= skill.level:
			_unlocked_skills.append(skill.id)
			skill_unlocked.emit(skill.id, skill.name)
	
	print("📖 已解锁 %d 个技能" % _unlocked_skills.size())

func _calculate_passive_bonuses() -> void:
	_passive_bonuses.clear()
	
	for skill_id in _unlocked_skills:
		var data = SKILL_DB.get(skill_id, {})
		if data.get("type") != "passive":
			continue
		var effects = data.get("effects", {})
		for key in effects.keys():
			_passive_bonuses[key] = _passive_bonuses.get(key, 0.0) + effects[key]
	
	# 应用到玩家属性
	for key in _passive_bonuses.keys():
		match key:
			"crit_rate_bonus":
				_player_stats["crit_rate"] = _player_stats.get("crit_rate", 0.0) + _passive_bonuses[key]
			"crit_damage_bonus":
				_player_stats["crit_damage"] = _player_stats.get("crit_damage", 0.0) + _passive_bonuses[key]
			"mp_regen_bonus":
				_player_stats["mp_regen"] = _player_stats.get("mp_regen", 0.0) + _passive_bonuses[key]
			"damage_reduction":
				_player_stats["damage_reduction"] = _player_stats.get("damage_reduction", 0.0) + _passive_bonuses[key]
			"hp_regen":
				_player_stats["hp_regen"] = _player_stats.get("hp_regen", 0.0) + _passive_bonuses[key]
			"heal_bonus":
				_player_stats["heal_bonus"] = _player_stats.get("heal_bonus", 0.0) + _passive_bonuses[key]
			"element_damage_bonus":
				_player_stats["element_damage_bonus"] = _player_stats.get("element_damage_bonus", 0.0) + _passive_bonuses[key]
			"status_resist":
				_player_stats["status_resist"] = _player_stats.get("status_resist", 0.0) + _passive_bonuses[key]

# ==================== 技能执行 ====================

## 尝试释放技能，返回是否成功
func use_skill(skill_id: String, caster: Node, target: Node = null) -> bool:
	if not _unlocked_skills.has(skill_id):
		print("⚠️ 技能 %s 未解锁" % skill_id)
		return false
	
	var data = SKILL_DB.get(skill_id)
	if not data:
		return false
	
	# 检查冷却
	if _cooldowns.has(skill_id):
		skill_on_cooldown.emit(skill_id, _cooldowns[skill_id])
		return false
	
	# 检查法力
	if _player_stats.get("max_mp", 0) < data.mp_cost:
		print("⚠️ 法力不足")
		return false
	
	# 扣除法力
	_player_stats["max_mp"] = _player_stats.get("max_mp", 0) - data.mp_cost
	mp_changed.emit(_player_stats["max_mp"], ClassSystem.get_class_data(_class_type).base_stats.max_mp)
	
	# 设置冷却
	if data.cooldown > 0:
		_cooldowns[skill_id] = data.cooldown
	
	# 发出信号
	skill_used.emit(skill_id, data.name, target)
	
	return true

## 获取技能数据
static func get_skill_data(skill_id: String) -> Dictionary:
	return SKILL_DB.get(skill_id, {})

## 获取技能剩余冷却
func get_cooldown(skill_id: String) -> float:
	return _cooldowns.get(skill_id, 0.0)

## 获取已解锁技能列表
func get_unlocked_skills() -> Array[String]:
	return _unlocked_skills.duplicate()

## 获取玩家当前属性
func get_player_stats() -> Dictionary:
	return _player_stats.duplicate()

## 获取被动加成
func get_passive_bonuses() -> Dictionary:
	return _passive_bonuses.duplicate()

## 升级时调用
func on_level_up(new_level: int) -> void:
	_level = new_level
	_refresh_unlocked_skills()
	_calculate_passive_bonuses()
