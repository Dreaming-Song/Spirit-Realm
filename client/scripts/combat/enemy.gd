extends CharacterBody3D
## 妖兽系统 - Phase 4
## 基础 AI：巡逻 → 索敌 → 追击 → 战斗 → 死亡

signal enemy_damaged(enemy_id: String, damage: int, current_hp: int)
signal enemy_killed(enemy_id: String, enemy_type: String)
signal enemy_aggro(enemy_id: String)

# ---------- 妖兽类型 ----------
enum EnemyType {
	SPIRIT_WOLF,    # 灵狼 - 敏捷近战
	MIST_APE,       # 雾猿 - 投石远程
	FLAME_BOAR,     # 焰猪 - 冲撞
	IRON_TORTOISE,  # 铁龟 - 高防
}

# ---------- 属性 ----------
@export var enemy_type: int = EnemyType.SPIRIT_WOLF
@export var max_hp: int = 80
@export var attack_damage: int = 15
@export var attack_range: float = 2.5
@export var aggro_range: float = 15.0   # 索敌范围
@export var move_speed: float = 6.0
@export var patrol_range: float = 20.0  # 巡逻范围
@export var exp_reward: int = 50

var hp: int
var is_alive: bool = true

# ---------- AI 状态 ----------
enum AIState { PATROL, CHASE, ATTACK, RETURN, HURT, DEAD }
var ai_state: int = AIState.PATROL
var target_player: Node = null
var patrol_center: Vector3
var patrol_target: Vector3
var attack_cooldown: float = 0.0

@onready var player_ref: Node = get_tree().get_first_node_in_group("player")
@onready var navigation: NavigationAgent3D = $NavigationAgent3D
@onready var animation: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area3D = $Hitbox

func _ready() -> void:
	hp = max_hp
	patrol_center = global_position
	_pick_patrol_target()
	add_to_group("enemies")

	# 物理碰撞分组
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_entered)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	attack_cooldown = max(attack_cooldown - delta, 0)
	_update_player_ref()

	match ai_state:
		AIState.PATROL:
			_patrol(delta)
			_check_aggro()
		AIState.CHASE:
			_chase(delta)
		AIState.ATTACK:
			_perform_attack(delta)
		AIState.RETURN:
			_return_to_patrol(delta)
		AIState.HURT:
			# 受伤动画由外部触发
			pass
		AIState.DEAD:
			die()

func _update_player_ref() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")

# ===================== AI 行为 =====================

func _pick_patrol_target() -> void:
	"""随机巡逻点"""
	var angle = randf_range(0, TAU)
	var dist = randf_range(3.0, patrol_range)
	patrol_target = patrol_center + Vector3(cos(angle), 0, sin(angle)) * dist

func _patrol(delta: float) -> void:
	"""巡逻"""
	var dist = global_position.distance_to(patrol_target)
	if dist < 2.0:
		_pick_patrol_target()
	# 简单移动（无导航网格时沿直线）
	var dir = (patrol_target - global_position).normalized()
	velocity = dir * move_speed * 0.5
	look_at(Vector3(patrol_target.x, global_position.y, patrol_target.z), Vector3.UP)
	move_and_slide()

func _check_aggro() -> void:
	"""检测是否发现玩家"""
	if player_ref == null:
		return
	var dist = global_position.distance_to(player_ref.global_position)
	if dist <= aggro_range:
		target_player = player_ref
		ai_state = AIState.CHASE
		enemy_aggro.emit(name)

func _chase(delta: float) -> void:
	"""追击玩家"""
	if target_player == null or not is_instance_valid(target_player):
		ai_state = AIState.RETURN
		return

	var dist = global_position.distance_to(target_player.global_position)

	# 超出追回范围则返回
	if dist > aggro_range * 2.0:
		ai_state = AIState.RETURN
		return

	# 进入攻击范围
	if dist <= attack_range:
		ai_state = AIState.ATTACK
		return

	var dir = (target_player.global_position - global_position).normalized()
	velocity = dir * move_speed
	look_at(Vector3(target_player.global_position.x, global_position.y, target_player.global_position.z), Vector3.UP)
	move_and_slide()

func _perform_attack(delta: float) -> void:
	"""攻击行为"""
	if target_player == null:
		ai_state = AIState.CHASE
		return

	var dist = global_position.distance_to(target_player.global_position)
	if dist > attack_range:
		ai_state = AIState.CHASE
		return

	if attack_cooldown <= 0:
		# 攻击！造成伤害
		if player_ref and player_ref.has_method("take_damage"):
			player_ref.take_damage(attack_damage)
			print("⚔️ 妖兽攻击玩家，造成 %d 伤害" % attack_damage)
		attack_cooldown = 1.5  # 攻击CD
		# TODO: 播放攻击动画

	# 转向玩家
	look_at(Vector3(target_player.global_position.x, global_position.y, target_player.global_position.z), Vector3.UP)

func _return_to_patrol(delta: float) -> void:
	"""返回巡逻中心"""
	var dist = global_position.distance_to(patrol_center)
	if dist < 1.0:
		ai_state = AIState.PATROL
		target_player = null
		return
	var dir = (patrol_center - global_position).normalized()
	velocity = dir * move_speed * 0.7
	move_and_slide()

# ===================== 受伤/死亡 =====================

func take_damage(damage: int, source: String = "player") -> void:
	"""受到伤害"""
	if not is_alive:
		return

	# 简单减伤（铁龟高防）
	var effective_damage = damage
	if enemy_type == EnemyType.IRON_TORTOISE:
		effective_damage = int(damage * 0.5)

	hp = max(hp - effective_damage, 0)
	enemy_damaged.emit(name, effective_damage, hp)

	# 受击反馈
	ai_state = AIState.HURT
	# TODO: 受击动画
	await get_tree().create_timer(0.3).timeout
	if ai_state == AIState.HURT:
		ai_state = AIState.CHASE  # 追击攻击者

	if hp <= 0:
		die()

func die() -> void:
	"""死亡"""
	if not is_alive:
		return
	is_alive = false
	ai_state = AIState.DEAD
	enemy_killed.emit(name, EnemyType.keys()[enemy_type])

	# TODO: 死亡动画（播放后消失）
	await get_tree().create_timer(1.5).timeout
	# 掉落物
	_spawn_drops()
	queue_free()

func _spawn_drops() -> void:
	"""掉落物"""
	var drops = {
		EnemyType.SPIRIT_WOLF: [{"item": "灵狼牙", "prob": 0.7}],
		EnemyType.MIST_APE: [{"item": "猿猴果", "prob": 0.6}],
		EnemyType.FLAME_BOAR: [{"item": "火熔石", "prob": 0.5}, {"item": "兽肉", "prob": 0.8}],
		EnemyType.IRON_TORTOISE: [{"item": "龟甲片", "prob": 0.9}],
	}
	for drop in drops.get(enemy_type, []):
		if randf() < drop.prob:
			# TODO: 生成掉落物实体
			print("📦 掉落: " + drop.item)

# ===================== 攻击碰撞检测 =====================

func _on_hitbox_entered(body: Node) -> void:
	"""玩家近战武器命中妖兽"""
	if body.is_in_group("player") and ai_state != AIState.DEAD:
		# TODO: 读取玩家攻击力
		take_damage(25)

# ===================== 存档接口 =====================

func get_save_data() -> Dictionary:
	return {
		"enemy_type": enemy_type,
		"position": global_position,
		"hp": hp,
		"is_alive": is_alive,
		"ai_state": ai_state,
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("position"):
		global_position = data.position
	hp = data.get("hp", max_hp)
	is_alive = data.get("is_alive", true)
