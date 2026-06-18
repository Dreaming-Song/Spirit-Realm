extends Node
## 非线性任务系统 - Phase 4
## 支持：主线/支线/日常/隐藏任务、多分支选择、条件判断

signal quest_available(quest_id: String, quest_name: String)
signal quest_accepted(quest_id: String)
signal quest_progressed(quest_id: String, step_name: String)
signal quest_completed(quest_id: String, rewards: Dictionary)
signal quest_failed(quest_id: String)

# ---------- 任务类型 ----------
enum QuestType {
	MAIN,       # 主线
	SIDE,       # 支线
	DAILY,      # 日常（每日刷新）
	HIDDEN,     # 隐藏（触发式）
}

# ---------- 条件类型 ----------
enum ConditionType {
	KILL_MONSTER,    # 击杀指定怪物 count 只
	COLLECT_ITEM,    # 采集 count 个某物品
	REACH_POINT,     # 到达指定位置
	TALK_NPC,        # 与 NPC 对话
	LEVEL_REACH,     # 达到指定等级
	PET_LOYALTY,     # 灵宠亲密度达到
	USE_MAGIC,       # 使用指定法术
}

# ---------- 任务数据结构 ----------
class QuestStep:
	var description: String
	var condition_type: int
	var target_id: String      # 目标 ID（怪物/物品/NPC）
	var target_count: int = 1
	var current_count: int = 0
	var position: Vector3      # 目标位置（REACH_POINT 用）

class QuestReward:
	var exp: int = 0
	var gold: int = 0
	var items: Dictionary = {}  # item_name -> count
	var spells_unlock: Array = []
	var pet_unlock: Array = []

class Quest:
	var quest_id: String
	var name: String
	var description: String
	var type: int
	var requirements: Dictionary = {}  # 接任务前提
	var steps: Array = []              # QuestStep[]
	var current_step: int = 0
	var rewards: QuestReward
	var time_limit: float = 0.0       # 0 = 不限时
	var is_accepted: bool = false
	var is_completed: bool = false

# ---------- 全局任务库 ----------
var _quest_library: Dictionary = {}   # quest_id -> Quest
var _active_quests: Dictionary = {}    # id -> Quest（进行中）
var _completed_quests: Array = []      # 已完成的任务ID
var _daily_reset_time: float = 0.0

# 引用
var player_ref: Node

func _ready() -> void:
	player_ref = get_tree().get_first_node_in_group("player")
	_init_quest_library()
	# 每天重置日常任务
	var timer = Timer.new()
	timer.wait_time = 86400.0  # 24小时
	timer.timeout.connect(_reset_daily_quests)
	timer.one_shot = false
	add_child(timer)

func _init_quest_library() -> void:
	"""初始化所有任务"""
	_add_main_quests()
	_add_side_quests()
	_add_daily_quests()
	_add_hidden_quests()

func _add_main_quests() -> void:
	"""主线任务"""
	_create_quest({
		"id": "main_01",
		"name": "初入仙途",
		"desc": "前往灵药谷采集 5 株灵草",
		"type": QuestType.MAIN,
		"steps": [
			{ "desc": "前往灵药谷", "cond": ConditionType.REACH_POINT, "pos": Vector3(120, 0, 80) },
			{ "desc": "采集灵草 0/5", "cond": ConditionType.COLLECT_ITEM, "target": "灵草", "count": 5 },
			{ "desc": "回到新手村向师父复命", "cond": ConditionType.TALK_NPC, "target": "npc_mentor" },
		],
		"rewards": { "exp": 200, "gold": 50, "items": { "回春丹": 2 } }
	})
	_create_quest({
		"id": "main_02",
		"name": "灵宠之契",
		"desc": "获得一只灵宠并提升亲密度至 30",
		"type": QuestType.MAIN,
		"requirements": { "quest_completed": "main_01" },
		"steps": [
			{ "desc": "前往灵宠园选择灵宠", "cond": ConditionType.TALK_NPC, "target": "npc_pet_master" },
			{ "desc": "喂食灵宠提升亲密度至 30", "cond": ConditionType.PET_LOYALTY, "target": "loyalty", "count": 30 },
		],
		"rewards": { "exp": 500, "gold": 100, "pet_unlock": ["小鹤"] }
	})

func _add_side_quests() -> void:
	"""支线任务"""
	_create_quest({
		"id": "side_alchemy",
		"name": "炼丹初窥",
		"desc": "炼制一颗回春丹",
		"type": QuestType.SIDE,
		"steps": [
			{ "desc": "采集灵草 0/2", "cond": ConditionType.COLLECT_ITEM, "target": "灵草", "count": 2 },
			{ "desc": "采集灵泉水", "cond": ConditionType.COLLECT_ITEM, "target": "灵泉水", "count": 1 },
			{ "desc": "在丹炉炼制回春丹", "cond": ConditionType.USE_MAGIC, "target": "回春丹" },
		],
		"rewards": { "exp": 300, "gold": 80, "items": { "凝气丹": 1 } }
	})
	_create_quest({
		"id": "side_sword",
		"name": "御剑试炼",
		"desc": "御剑飞行到达山顶",
		"type": QuestType.SIDE,
		"requirements": { "level_reach": 3 },
		"steps": [
			{ "desc": "开启御剑飞行", "cond": ConditionType.USE_MAGIC, "target": "御剑" },
			{ "desc": "飞抵山顶", "cond": ConditionType.REACH_POINT, "pos": Vector3(-50, 80, 200) },
		],
		"rewards": { "exp": 800, "gold": 200 }
	})

func _add_daily_quests() -> void:
	"""日常任务（每日重置）"""
	_create_quest({
		"id": "daily_kill",
		"name": "日常·斩妖",
		"desc": "击杀 10 只妖兽",
		"type": QuestType.DAILY,
		"steps": [
			{ "desc": "击杀妖兽 0/10", "cond": ConditionType.KILL_MONSTER, "target": "monster_generic", "count": 10 },
		],
		"rewards": { "exp": 500, "gold": 150 }
	})
	_create_quest({
		"id": "daily_collect",
		"name": "日常·采药",
		"desc": "采集 20 株灵草",
		"type": QuestType.DAILY,
		"steps": [
			{ "desc": "采集灵草 0/20", "cond": ConditionType.COLLECT_ITEM, "target": "灵草", "count": 20 },
		],
		"rewards": { "exp": 300, "gold": 100 }
	})

func _add_hidden_quests() -> void:
	"""隐藏任务（触发式）"""
	_create_quest({
		"id": "hidden_pet",
		"name": "隐藏·神兽秘境",
		"desc": "找到隐藏秘境中的神兽",
		"type": QuestType.HIDDEN,
		"steps": [
			{ "desc": "在月华潭边发现神秘脚印", "cond": ConditionType.REACH_POINT, "pos": Vector3(250, 0, -100) },
			{ "desc": "使用木灵术催生古树开启入口", "cond": ConditionType.USE_MAGIC, "target": "木系法术" },
			{ "desc": "与神兽对话", "cond": ConditionType.TALK_NPC, "target": "npc_spirit_beast" },
		],
		"rewards": { "exp": 2000, "gold": 500, "pet_unlock": ["貔貅"] }
	})

# ===================== 任务创建 =====================

func _create_quest(data: Dictionary) -> Quest:
	"""从数据字典创建任务"""
	var quest = Quest.new()
	quest.quest_id = data.id
	quest.name = data.name
	quest.description = data.desc
	quest.type = data.get("type", QuestType.SIDE)
	quest.requirements = data.get("requirements", {})
	quest.rewards = QuestReward.new()

	var rew = data.get("rewards", {})
	quest.rewards.exp = rew.get("exp", 0)
	quest.rewards.gold = rew.get("gold", 0)
	quest.rewards.items = rew.get("items", {})
	quest.rewards.spells_unlock = rew.get("spells_unlock", [])
	quest.rewards.pet_unlock = rew.get("pet_unlock", [])

	# 步骤
	for s in data.get("steps", []):
		var step = QuestStep.new()
		step.description = s.desc
		step.condition_type = s.cond
		step.target_id = s.get("target", "")
		step.target_count = s.get("count", 1)
		step.position = s.get("pos", Vector3.ZERO)
		step.current_count = 0
		quest.steps.append(step)

	_quest_library[quest.quest_id] = quest
	return quest

# ===================== 任务流程 =====================

func accept_quest(quest_id: String) -> bool:
	"""接受任务"""
	if not _quest_library.has(quest_id):
		return false
	if _active_quests.has(quest_id) or quest_id in _completed_quests:
		return false

	var quest: Quest = _quest_library[quest_id]
	if not _check_requirements(quest.requirements):
		return false

	# 复制一份给活跃任务
	var quest_copy = _deep_copy_quest(quest)
	quest_copy.is_accepted = true
	_active_quests[quest_id] = quest_copy

	quest_accepted.emit(quest_id)
	return true

func check_progress(condition_type: int, target_id: String, amount: int = 1) -> void:
	"""外部调用：推进任务进度"""
	for quest in _active_quests.values():
		if quest.is_completed:
			continue
		var step: QuestStep = quest.steps[quest.current_step]
		if step.condition_type != condition_type:
			continue
		if step.target_id != "" and step.target_id != target_id:
			continue

		step.current_count = min(step.current_count + amount, step.target_count)
		quest_progressed.emit(quest.quest_id, step.description)

		# 检查步骤是否完成
		if step.current_count >= step.target_count:
			quest.current_step += 1
			if quest.current_step >= quest.steps.size():
				_complete_quest(quest)
			else:
				# 更新 UI 提示下一步
				quest_progressed.emit(quest.quest_id, "step_complete")

func _complete_quest(quest: Quest) -> void:
	"""完成任务，发放奖励"""
	quest.is_completed = true
	_active_quests.erase(quest.quest_id)
	_completed_quests.append(quest.quest_id)

	# 发放奖励
	if player_ref:
		player_ref.heal(quest.rewards.exp)  # TODO: 独立经验系统
		# 发放物品
		for item_name, count in quest.rewards.items.items():
			pass  # TODO: 背包系统
		# 解锁法术
		for spell_name in quest.rewards.spells_unlock:
			pass  # TODO: 法术解锁
		# 解锁灵宠
		for pet_name in quest.rewards.pet_unlock:
			pass  # TODO: 灵宠解锁

	quest_completed.emit(quest.quest_id, {
		"exp": quest.rewards.exp,
		"gold": quest.rewards.gold,
		"items": quest.rewards.items,
	})

func _check_requirements(req: Dictionary) -> bool:
	"""检查任务接取条件"""
	if req.has("quest_completed"):
		if not (req.quest_completed in _completed_quests):
			return false
	if req.has("level_reach"):
		if player_ref == null or player_ref.get("level", 0) < req.level_reach:
			return false
	# TODO: 更多条件类型
	return true

# ===================== 日常重置 =====================

func _reset_daily_quests() -> void:
	"""每日重置日常任务"""
	for qid in _quest_library.keys():
		var q = _quest_library[qid]
		if q.type == QuestType.DAILY:
			# 清空活跃的日常
			if _active_quests.has(qid):
				_active_quests.erase(qid)
			# 从完成列表移除
			if qid in _completed_quests:
				_completed_quests.erase(qid)
	# 重新发任务
	for qid in _quest_library.keys():
		var q = _quest_library[qid]
		if q.type == QuestType.DAILY:
			quest_available.emit(qid, q.name)

# ===================== UI 查询接口 =====================

func get_available_quests() -> Array:
	"""获取可接任务列表"""
	var available: Array = []
	for q in _quest_library.values():
		if not _active_quests.has(q.quest_id) and not (q.quest_id in _completed_quests):
			if _check_requirements(q.requirements):
				available.append({
					"id": q.quest_id, "name": q.name,
					"desc": q.description, "type": q.type
				})
	return available

func get_active_quests() -> Array:
	"""获取进行中任务列表"""
	var active: Array = []
	for q in _active_quests.values():
		var step = q.steps[q.current_step] if q.current_step < q.steps.size() else null
		active.append({
			"id": q.quest_id, "name": q.name,
			"step_desc": step.description if step else "完成！",
			"step_progress": step.current_count if step else 0,
			"step_target": step.target_count if step else 0,
		})
	return active

# ===================== 工具 =====================

func _deep_copy_quest(original: Quest) -> Quest:
	"""深拷贝任务"""
	var copy = Quest.new()
	copy.quest_id = original.quest_id
	copy.name = original.name
	copy.description = original.description
	copy.type = original.type
	copy.requirements = original.requirements.duplicate(true)
	copy.current_step = 0
	copy.rewards = original.rewards
	copy.time_limit = original.time_limit
	for s in original.steps:
		var step = QuestStep.new()
		step.description = s.description
		step.condition_type = s.condition_type
		step.target_id = s.target_id
		step.target_count = s.target_count
		step.current_count = 0
		step.position = s.position
		copy.steps.append(step)
	return copy

# ===================== 存档接口 =====================

func get_save_data() -> Dictionary:
	return {
		"active_quests": _active_quests.keys(),
		"completed_quests": _completed_quests,
		# TODO: 保存每个活跃任务的进度
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("completed_quests"):
		_completed_quests = data.completed_quests
	# TODO: 恢复活跃任务进度
