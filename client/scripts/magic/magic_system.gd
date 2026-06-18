extends Node
## 五行法术系统 - Phase 2
## 管理法术解锁、法力消耗、按键触发

signal spell_cast(spell_name: String, origin: Vector3, direction: Vector3)

# ---------- 法术定义 ----------
enum SpellType { 
	FIRE,     # 火 - 点燃、伤害
	WATER,    # 水 - 冰冻、治疗
	EARTH,    # 土 - 巨石、推障
	WOOD,     # 木 - 催生、缠绕
	METAL     # 金 - 破解机关
}

class SpellData:
	var type: int
	var name: String
	var mp_cost: int
	var cooldown: float
	var damage: int
	var range: float
	var is_unlocked: bool
	var last_cast_time: float

var spells: Dictionary = {}  # SpellType -> SpellData

# ---------- 引用 ----------
@onready var player: CharacterBody3D = get_parent()

func _ready() -> void:
	_init_spells()

func _init_spells() -> void:
	"""初始化所有法术"""
	var spell_defs = [
		{ "type": SpellType.FIRE,  "name": "烈焰诀", "mp_cost": 15, "cooldown": 2.0, "damage": 30, "range": 15.0 },
		{ "type": SpellType.WATER, "name": "寒冰咒", "mp_cost": 12, "cooldown": 3.0, "damage": 20, "range": 12.0 },
		{ "type": SpellType.EARTH, "name": "地煞诀", "mp_cost": 20, "cooldown": 5.0, "damage": 40, "range": 8.0 },
		{ "type": SpellType.WOOD,  "name": "木灵术", "mp_cost": 10, "cooldown": 4.0, "damage": 5,  "range": 10.0 },
		{ "type": SpellType.METAL, "name": "金罡破", "mp_cost": 18, "cooldown": 6.0, "damage": 35, "range": 20.0 },
	]
	for def in spell_defs:
		var s = SpellData.new()
		s.type = def.type
		s.name = def.name
		s.mp_cost = def.mp_cost
		s.cooldown = def.cooldown
		s.damage = def.damage
		s.range = def.range
		s.is_unlocked = true  # Phase 2: 默认全解锁，后续用任务解锁
		s.last_cast_time = -999.0
		spells[def.type] = s

func cast_spell(spell_type: int) -> bool:
	"""尝试施放法术"""
	if not spells.has(spell_type):
		return false

	var spell: SpellData = spells[spell_type]
	if not spell.is_unlocked:
		# TODO: 提示"法术未解锁"
		return false

	# 冷却检查
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - spell.last_cast_time < spell.cooldown:
		return false

	# 法力检查
	if player.has_method("get_mp"):
		if player.get_mp() < spell.mp_cost:
			return false
		player.use_mp(spell.mp_cost)

	spell.last_cast_time = now

	# 触发法术效果
	var origin: Vector3 = player.global_position + Vector3.UP * 1.5
	var direction: Vector3 = -player.get_node("CameraPivot/Camera3D").global_transform.basis.z
	spell_cast.emit(spell.name, origin, direction)
	_spawn_spell_effect(spell_type, origin, direction)
	return true

func _spawn_spell_effect(spell_type: int, origin: Vector3, direction: Vector3) -> void:
	"""生成法术特效/物理体"""
	match spell_type:
		SpellType.FIRE:
			_spawn_fireball(origin, direction)
		SpellType.WATER:
			_spawn_ice_blast(origin, direction)
		SpellType.EARTH:
			_spawn_boulder(origin, direction)
		SpellType.WOOD:
			_spawn_vine_growth(origin, direction)
		SpellType.METAL:
			_spawn_metal_shard(origin, direction)

func _spawn_fireball(origin: Vector3, direction: Vector3) -> void:
	"""火球 - 飞行物+点燃区域"""
	var ball: RigidBody3D = RigidBody3D.new()
	ball.global_position = origin
	ball.add_child( MeshInstance3D.new() )  # TODO: 替换为火球模型
	ball.apply_impulse(direction * 20.0, Vector3.ZERO)
	get_tree().current_scene.add_child(ball)
	# 5秒后爆炸
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(ball):
		# TODO: 爆炸特效 + 点燃周围可燃物
		ball.queue_free()

func _spawn_ice_blast(origin: Vector3, direction: Vector3) -> void:
	"""冰爆 - 范围冰冻"""
	# TODO: 粒子特效 + 范围内敌人减速/冻结
	pass

func _spawn_boulder(origin: Vector3, direction: Vector3) -> void:
	"""巨石 - 物理推障"""
	var boulder: RigidBody3D = RigidBody3D.new()
	boulder.global_position = origin + direction * 2.0
	# 设置巨石形状
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	boulder.add_child(shape)
	boulder.mass = 500.0  # 很重，可推动障碍物
	boulder.apply_impulse(direction * 10.0, Vector3.ZERO)
	get_tree().current_scene.add_child(boulder)
	# 30秒后消失
	await get_tree().create_timer(30.0).timeout
	if is_instance_valid(boulder):
		boulder.queue_free()

func _spawn_vine_growth(origin: Vector3, direction: Vector3) -> void:
	"""木系 - 催生藤蔓/树木"""
	# TODO: 检测目标位置，如果是树苗则催生成大树
	# TODO: 如果是敌人则缠绕减速
	pass

func _spawn_metal_shard(origin: Vector3, direction: Vector3) -> void:
	"""金系 - 金属碎片穿透"""
	var shard: RigidBody3D = RigidBody3D.new()
	shard.global_position = origin
	shard.apply_impulse(direction * 30.0, Vector3.ZERO)
	get_tree().current_scene.add_child(shard)
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(shard):
		shard.queue_free()

func get_unlocked_spells() -> Array:
	"""获取已解锁法术列表"""
	var result: Array = []
	for s in spells.values():
		if s.is_unlocked:
			result.append({ "name": s.name, "type": s.type })
	return result

func get_spell_cooldown_ratio(spell_type: int) -> float:
	"""获取冷却进度 (0~1)，用于UI显示"""
	if not spells.has(spell_type):
		return 1.0
	var s: SpellData = spells[spell_type]
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - s.last_cast_time
	return clamp(elapsed / s.cooldown, 0.0, 1.0)
