extends CharacterBody3D
## 灵宠系统 - Phase 2
## 跟随玩家、喂食互动、解锁技能、载人飞行

signal pet_level_up(pet_name: String, new_level: int)
signal skill_unlocked(pet_name: String, skill_name: String)

# ---------- 灵宠定义 ----------
enum PetType { CRANE, FOX, PANDA, PIXIU }

@export var pet_type: int = PetType.CRANE
@export var pet_name: String = "小鹤"

# ---------- 属性 ----------
@export var move_speed: float = 8.0
@export var follow_distance: float = 3.0
@export var stop_distance: float = 1.5
@export var level: int = 1
@export var exp: int = 0
@export var exp_to_next: int = 100
@export var loyalty: int = 50  # 亲密度 0-100，影响技能解锁

# ---------- 养成 ----------
var hunger: int = 100           # 饱食度 0-100
var favorite_food: Array = []   # 喜欢的食物类型
var unlocked_skills: Array = []  # 已解锁技能
var is_mount_mode: bool = false # 是否载人飞行

# ---------- 节点引用 ----------
@onready var player: Node3D = null
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var pet_mesh: Node3D = $PetMesh

# AI 状态
enum PetState { FOLLOW, IDLE, EATING, FLYING_MOUNT }
var current_state: int = PetState.FOLLOW

func _ready() -> void:
	add_to_group("pets")
	# 寻找玩家
	player = get_tree().get_first_node_in_group("player")
	move_speed += level * 0.5  # 等级越高跑越快

func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return

	match current_state:
		PetState.FOLLOW:
			_update_follow(delta)
		PetState.FLYING_MOUNT:
			_update_mount_fly(delta)
		_:
			pass

# ===================== 跟随逻辑 =====================

func _update_follow(delta: float) -> void:
	if player == null:
		return

	var dist: float = global_position.distance_to(player.global_position)

	if dist > follow_distance:
		# 面向玩家移动
		var target_dir: Vector3 = (player.global_position - global_position).normalized()
		target_dir.y = 0
		if target_dir.length() > 0:
			var target_pos: Vector3 = global_position + target_dir * move_speed * delta
			# 简单避障
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(global_position, target_pos)
			var result = space_state.intersect_ray(query)
			if result.is_empty():
				global_position = target_pos
			else:
				# 有障碍物，随机偏移
				target_dir = target_dir.rotated(Vector3.UP, randf_range(-1.0, 1.0))
				global_position += target_dir * move_speed * delta * 0.5

		# 朝向玩家
		var look_target: Vector3 = player.global_position
		look_target.y = global_position.y
		look_at(look_target, Vector3.UP)
	elif dist < stop_distance:
		# 太近了，稍微后退
		pass
	else:
		# 在跟随距离内，做 idle 动作
		pass

	# 如果玩家开始御剑，灵宠也飞起来
	if player.has_method("is_flying") and player.is_flying:
		global_position.y = player.global_position.y - 1.0

# ===================== 载人飞行 =====================

func _update_mount_fly(delta: float) -> void:
	if player == null:
		return
	# 跟随玩家飞行指令
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward: Vector3 = -player.get_node("CameraPivot/Camera3D").global_transform.basis.z
	var right: Vector3 = player.get_node("CameraPivot/Camera3D").global_transform.basis.x
	var fly_dir: Vector3 = (forward * input_dir.y + right * input_dir.x).normalized()

	velocity = fly_dir * move_speed * 1.5
	if Input.is_action_pressed("jump"):
		velocity.y += 5.0
	if Input.is_key_pressed(KEY_CTRL):
		velocity.y -= 5.0

	move_and_slide()

	# 同步玩家位置
	if player.get_parent() != self:
		player.reparent(self)
	player.global_position = global_position + Vector3(0, 1.5, -0.5)

# ===================== 喂食互动 =====================

func feed(food_type: int) -> Dictionary:
	"""喂食灵宠，返回亲密度变化"""
	var result = { "loyalty_change": 0, "message": "" }
	if hunger <= 0:
		result.message = pet_name + "已经饱了"
		return result

	hunger = max(hunger - 20, 0)
	var is_favorite: bool = food_type in favorite_food

	if is_favorite:
		loyalty = min(loyalty + 10, 100)
		exp += 30
		result.loyalty_change = 10
		result.message = pet_name + "很喜欢！亲密度+10"
	else:
		loyalty = min(loyalty + 3, 100)
		exp += 10
		result.loyalty_change = 3
		result.message = pet_name + "吃了一些"

	# 检查升级
	_check_level_up()
	# 检查技能解锁
	_check_skill_unlock()
	return result

func _check_level_up() -> void:
	while exp >= exp_to_next:
		exp -= exp_to_next
		level += 1
		exp_to_next = int(exp_to_next * 1.5)
		move_speed += 0.5
		pet_level_up.emit(pet_name, level)

func _check_skill_unlock() -> void:
	"""根据亲密度解锁技能"""
	var skill_thresholds = [
		{ "loyalty": 30, "skill": "跟随加速" },
		{ "loyalty": 50, "skill": "采集助手" },
		{ "loyalty": 70, "skill": "载人飞行" },
		{ "loyalty": 90, "skill": "辅助战斗" },
	]

	for threshold in skill_thresholds:
		if loyalty >= threshold.loyalty and not (threshold.skill in unlocked_skills):
			unlocked_skills.append(threshold.skill)
			skill_unlocked.emit(pet_name, threshold.skill)

			if threshold.skill == "载人飞行":
				is_mount_mode = true

# ===================== 技能接口 =====================

func can_mount() -> bool:
	return "载人飞行" in unlocked_skills

func toggle_mount() -> bool:
	if not can_mount():
		return false
	is_mount_mode = not is_mount_mode
	if is_mount_mode:
		current_state = PetState.FLYING_MOUNT
	else:
		current_state = PetState.FOLLOW
		if player.get_parent() == self:
			player.reparent(get_tree().current_scene)
	return true

func get_pet_info() -> Dictionary:
	return {
		"name": pet_name,
		"type": pet_type,
		"level": level,
		"exp": exp,
		"exp_to_next": exp_to_next,
		"loyalty": loyalty,
		"hunger": hunger,
		"skills": unlocked_skills,
		"can_mount": can_mount()
	}

# ===================== 存档接口 =====================

func get_save_data() -> Dictionary:
	return {
		"pet_type": pet_type,
		"pet_name": pet_name,
		"level": level,
		"exp": exp,
		"loyalty": loyalty,
		"hunger": hunger,
		"unlocked_skills": unlocked_skills,
	}

func load_save_data(data: Dictionary) -> void:
	pet_type = data.get("pet_type", PetType.CRANE)
	pet_name = data.get("pet_name", "小鹤")
	level = data.get("level", 1)
	exp = data.get("exp", 0)
	loyalty = data.get("loyalty", 50)
	hunger = data.get("hunger", 100)
	unlocked_skills = data.get("unlocked_skills", [])
