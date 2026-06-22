extends Node
## Buff/减益系统 — 战斗状态效果管理
##
## 管理所有临时效果：增益、减益、持续伤害、控制
## 挂载到玩家/敌人节点上

class_name BuffSystem

# ==================== Buff 类型枚举 ====================
enum BuffType {
	BUFF,         # 增益
	DEBUFF,       # 减益
	DOT,          # 持续伤害
	HOT,          # 持续治疗
	SHIELD,       # 护盾
	CONTROL,      # 控制（眩晕/冰冻/沉默）
	IMMUNITY,     # 免疫
}

# ==================== Buff 数据结构 ====================
struct BuffInstance:
	var id: String               # 唯一 ID
	var name: String
	var type: BuffType
	var source: String           # "skill_xxx" 或 "item_xxx"
	var remaining: float         # 剩余时间
	var duration: float          # 总时长
	var tick_interval: float     # DOT/HOT 跳动间隔
	var tick_timer: float
	var effects: Dictionary      # 效果参数表
	var stacks: int              # 层数
	var max_stacks: int
	var icon_path: String        # UI 图标路径

# ==================== 信号 ====================
signal buff_applied(buff_id: String, buff_name: String, stacks: int)
signal buff_expired(buff_id: String, buff_name: String)
signal buff_stacks_changed(buff_id: String, stacks: int)
signal buff_tick(buff_id: String, value: int, is_damage: bool)

# ==================== 运行时 ====================
var _active_buffs: Dictionary = {}  # buff_id → BuffInstance
var _owner: Node                    # 持有者（玩家/敌人）

func _init(owner_node: Node) -> void:
	_owner = owner_node

func _process(delta: float) -> void:
	if _active_buffs.is_empty():
		return
	
	var expired: Array[String] = []
	
	for buff_id in _active_buffs.keys():
		var buff = _active_buffs[buff_id]
		buff.remaining -= delta
		
		# DOT/HOT 跳动
		if buff.type in [BuffType.DOT, BuffType.HOT] and buff.tick_interval > 0:
			buff.tick_timer -= delta
			if buff.tick_timer <= 0:
				buff.tick_timer = buff.tick_interval
				_process_tick(buff)
		
		# 到期标记
		if buff.remaining <= 0:
			expired.append(buff_id)
	
	# 清理过期
	for buff_id in expired:
		_remove_buff(buff_id)

# ==================== 公共接口 ====================

## 添加 Buff
func add_buff(
	name: String,
	type: BuffType,
	duration: float,
	effects: Dictionary,
	source: String = "",
	stacks: int = 1,
	max_stacks: int = 5,
	tick_interval: float = 0.0
) -> String:
	var buff_id = "%s_%s" % [name, randi()]
	
	# 同类 Buff 叠层
	for existing_id in _active_buffs.keys():
		var existing = _active_buffs[existing_id]
		if existing.name == name and existing.source == source:
			# 叠层
			existing.stacks = min(existing.stacks + stacks, existing.max_stacks)
			existing.remaining = max(existing.remaining, duration)  # 刷新时长
			buff_stacks_changed.emit(existing_id, existing.stacks)
			return existing_id
	
	# 新建
	var buff = BuffInstance.new()
	buff.id = buff_id
	buff.name = name
	buff.type = type
	buff.source = source
	buff.remaining = duration
	buff.duration = duration
	buff.tick_interval = tick_interval
	buff.tick_timer = tick_interval
	buff.effects = effects
	buff.stacks = stacks
	buff.max_stacks = max_stacks
	
	_active_buffs[buff_id] = buff
	buff_applied.emit(buff_id, name, stacks)
	
	return buff_id

## 移除指定 Buff
func remove_buff(buff_id: String) -> void:
	_remove_buff(buff_id)

## 按名称移除 Buff（如解毒）
func remove_buff_by_name(name: String) -> bool:
	for buff_id in _active_buffs.keys():
		if _active_buffs[buff_id].name == name:
			_remove_buff(buff_id)
			return true
	return false

## 清除所有减益
func clear_debuffs() -> void:
	var to_remove: Array[String] = []
	for buff_id in _active_buffs.keys():
		if _active_buffs[buff_id].type in [BuffType.DEBUFF, BuffType.DOT, BuffType.CONTROL]:
			to_remove.append(buff_id)
	for buff_id in to_remove:
		_remove_buff(buff_id)

## 清除所有
func clear_all() -> void:
	for buff_id in _active_buffs.keys():
		_remove_buff(buff_id)

## 检查是否有指定类型的 Buff
func has_buff_type(type: BuffType) -> bool:
	for buff in _active_buffs.values():
		if buff.type == type:
			return true
	return false

## 检查是否有指定名称的 Buff
func has_buff(name: String) -> bool:
	for buff in _active_buffs.values():
		if buff.name == name:
			return true
	return false

## 获取指定类型的层数总和
func get_total_stacks(type: BuffType) -> int:
	var total = 0
	for buff in _active_buffs.values():
		if buff.type == type:
			total += buff.stacks
	return total

## 获取当前所有活跃 Buff
func get_active_buffs() -> Array[BuffInstance]:
	return _active_buffs.values()

## 获取 Buff 数量
func get_buff_count() -> int:
	return _active_buffs.size()

# ==================== 内部方法 ====================

func _remove_buff(buff_id: String) -> void:
	if not _active_buffs.has(buff_id):
		return
	var buff = _active_buffs[buff_id]
	var name = buff.name
	_active_buffs.erase(buff_id)
	buff_expired.emit(buff_id, name)

func _process_tick(buff: BuffInstance) -> void:
	var value = buff.effects.get("tick_damage", 0) * buff.stacks
	if buff.type == BuffType.DOT:
		# 对持有者造成伤害
		if _owner and _owner.has_method("take_damage"):
			_owner.take_damage(value)
		buff_tick.emit(buff.id, value, true)
	elif buff.type == BuffType.HOT:
		# 治疗持有者
		if _owner and _owner.has_method("heal"):
			_owner.heal(value)
		buff_tick.emit(buff.id, value, false)

# ==================== 预制 Buff 工厂 ====================

## 流血 — 持续物理伤害
static func create_bleed(damage_per_tick: int = 5, duration: float = 4.0, stacks: int = 1) -> Dictionary:
	return {
		"name": "流血",
		"type": BuffType.DOT,
		"duration": duration,
		"tick_interval": 1.0,
		"effects": {"tick_damage": damage_per_tick},
		"stacks": stacks,
		"max_stacks": 5,
	}

## 灼烧 — 持续火焰伤害
static func create_burn(damage_per_tick: int = 8, duration: float = 3.0) -> Dictionary:
	return {
		"name": "灼烧",
		"type": BuffType.DOT,
		"duration": duration,
		"tick_interval": 1.0,
		"effects": {"tick_damage": damage_per_tick},
		"stacks": 1,
		"max_stacks": 3,
	}

## 减速
static func create_slow(slow_pct: float = 0.4, duration: float = 3.0) -> Dictionary:
	return {
		"name": "减速",
		"type": BuffType.DEBUFF,
		"duration": duration,
		"tick_interval": 0,
		"effects": {"speed_reduction": slow_pct},
		"stacks": 1,
		"max_stacks": 1,
	}

## 眩晕
static func create_stun(duration: float = 1.5) -> Dictionary:
	return {
		"name": "眩晕",
		"type": BuffType.CONTROL,
		"duration": duration,
		"tick_interval": 0,
		"effects": {"cannot_act": true},
		"stacks": 1,
		"max_stacks": 1,
	}

## 防御提升
static func create_defense_up(bonus_pct: float = 0.5, duration: float = 4.0) -> Dictionary:
	return {
		"name": "金刚护体",
		"type": BuffType.BUFF,
		"duration": duration,
		"tick_interval": 0,
		"effects": {"defense_bonus_pct": bonus_pct},
		"stacks": 1,
		"max_stacks": 1,
	}

## 持续治疗
static func create_regen(heal_per_tick: int = 5, duration: float = 6.0) -> Dictionary:
	return {
		"name": "回春",
		"type": BuffType.HOT,
		"duration": duration,
		"tick_interval": 1.0,
		"effects": {"tick_damage": 0, "tick_heal": heal_per_tick},
		"stacks": 1,
		"max_stacks": 3,
	}

## 沉默
static func create_silence(duration: float = 2.0) -> Dictionary:
	return {
		"name": "沉默",
		"type": BuffType.CONTROL,
		"duration": duration,
		"tick_interval": 0,
		"effects": {"cannot_skill": true},
		"stacks": 1,
		"max_stacks": 1,
	}
