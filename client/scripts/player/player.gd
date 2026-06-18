extends CharacterBody3D
## 基础仙侠角色控制器 - Phase 1
## 支持：跑、跳、视角控制、基础物理交互

# ---------- 移动参数 ----------
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var jump_velocity: float = 8.0
@export var acceleration: float = 10.0
@export var friction: float = 8.0

# ---------- 视角参数 ----------
@export var mouse_sensitivity: float = 0.002
@export var camera_pitch_limit: float = 80.0

# ---------- 御剑飞行参数 ----------
@export var fly_speed: float = 15.0
@export var fly_up_speed: float = 6.0
@export var gravity_scale: float = 1.0

# ---------- 节点引用 ----------
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var sword: Node3D = $Sword

# ---------- 属性（HP/MP） ----------
@export var max_hp: int = 100
@export var max_mp: int = 100
var hp: int = 100
var mp: int = 100
var hp_regen: float = 1.0   # 每秒恢复
var mp_regen: float = 2.0

# ---------- 状态 ----------
var is_flying: bool = false
var current_speed: float = 0.0
var wind_direction: Vector3 = Vector3.ZERO  # 气流方向（御剑用）

# ---------- 系统引用 ----------
var magic_system: Node = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	magic_system = get_node_or_null("/root/Main/MagicSystem")
	hp = max_hp
	mp = max_mp

func _process(delta: float) -> void:
	# HP/MP 自动恢复
	hp = min(hp + hp_regen * delta, max_hp)
	mp = min(mp + mp_regen * delta, max_mp)

func _try_cast_spell(index: int) -> void:
	"""按快捷键尝试施法"""
	if magic_system == null:
		return
	var spells = magic_system.get_unlocked_spells()
	if index < spells.size():
		magic_system.cast_spell(spells[index].type)

func _input(event: InputEvent) -> void:
	# 鼠标控制视角
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(
			camera_pivot.rotation.x,
			deg_to_rad(-camera_pitch_limit),
			deg_to_rad(camera_pitch_limit)
		)

	# 法术快捷键 1-5
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _try_cast_spell(0)
			KEY_2: _try_cast_spell(1)
			KEY_3: _try_cast_spell(2)
			KEY_4: _try_cast_spell(3)
			KEY_5: _try_cast_spell(4)

func _physics_process(delta: float) -> void:
	# 御剑飞行模式切换
	if Input.is_action_just_pressed("sword_fly"):
		toggle_flying()

	if is_flying:
		handle_flying(delta)
	else:
		handle_ground_movement(delta)

# ===================== 地面移动 =====================

func handle_ground_movement(delta: float) -> void:
	# 输入方向
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# 重力
	if not is_on_floor():
		velocity.y += get_gravity().y * gravity_scale * delta

	# 跳跃
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 加速/减速
	var target_speed: float = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	current_speed = move_toward(current_speed, target_speed * input_dir.length(), acceleration * delta)

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)

	move_and_slide()

# ===================== 御剑飞行 =====================

func toggle_flying() -> void:
	is_flying = not is_flying
	if is_flying:
		gravity_scale = -0.3  # 反重力效果
		# TODO: 播放御剑动画 + 剑光效
	else:
		gravity_scale = 1.0
		# TODO: 播放落地动画

func handle_flying(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward: Vector3 = -camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x
	var fly_direction: Vector3 = (forward * input_dir.y + right * input_dir.x).normalized()

	# 高度控制：按跳跃上升，按下蹲下降
	if Input.is_action_pressed("jump"):
		fly_direction.y += 1.0
	if Input.is_key_pressed(KEY_CTRL):
		fly_direction.y -= 1.0

	# 气流影响（由场景中的 WindArea 触发）
	fly_direction += wind_direction * 0.5

	velocity = fly_direction * fly_speed
	move_and_slide()

# ===================== 工具方法 =====================

func set_wind(wind_vec: Vector3) -> void:
	"""由场景中的风场调用，影响御剑飞行"""
	wind_direction = wind_vec

func set_state(data: Dictionary) -> void:
	"""从存档恢复状态"""
	if data.has("position"):
		global_position = data.position
	if data.has("hp"):
		hp = data.hp
	if data.has("mp"):
		mp = data.mp
	if data.has("is_flying"):
		is_flying = data.is_flying

func get_current_state() -> Dictionary:
	"""给 UI/存档用的状态快照"""
	return {
		"position": global_position,
		"is_flying": is_flying,
		"hp": hp,
		"mp": mp,
		"max_hp": max_hp,
		"max_mp": max_mp
	}

# HP/MP 外部接口
func get_hp() -> int: return hp
func get_max_hp() -> int: return max_hp
func get_hp_ratio() -> float: return float(hp) / max_hp
func get_mp() -> int: return mp
func get_max_mp() -> int: return max_mp
func get_mp_ratio() -> float: return float(mp) / max_mp
func use_mp(amount: int) -> void: mp = max(mp - amount, 0)
func take_damage(amount: int) -> void: hp = max(hp - amount, 0)
func heal(amount: int) -> void: hp = min(hp + amount, max_hp)
