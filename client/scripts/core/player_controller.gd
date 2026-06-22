extends CharacterBody3D
## 玩家控制器 — 输入处理 + 游戏循环操作入口
##
## 标准3D操作 + 交互（采集/战斗/建造/合成）
## 快捷键：E交互 / 1-9快捷栏 / I背包 / C修行 / B建造 / TAB合成

class_name PlayerController

# ==================== 移动配置 ====================
@export var walk_speed: float = 5.0
@export var sprint_mult: float = 1.6
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

# ==================== 引用 ====================
var game_manager: GameManager

# ==================== 状态 ====================
var _current_speed: float = 5.0
var _is_sprinting: bool = false
var _current_tool: String = ""  # 当前手持工具

# ==================== 玩家基础属性 ====================
var current_hp: float = 100.0
var max_hp: float = 100.0
var current_mp: float = 50.0
var max_mp: float = 50.0

# ==================== HUD节点 ====================
@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	# 获取 GameManager
	game_manager = get_node("/root/GameManager") if has_node("/root/GameManager") else null
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# 从存档恢复属性
	_sync_stats()

func _input(event: InputEvent) -> void:
	# 鼠标视角
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_camera.rotate_x(-event.relative.y * mouse_sensitivity)
		_camera.rotation.x = clamp(_camera.rotation.x, -1.5, 1.5)

func _physics_process(delta: float) -> void:
	if not game_manager or game_manager.current_state != GameManager.GameState.PLAYING:
		return
	
	# 从装备获取移动速度
	_sync_stats()
	
	# 移动
	_handle_movement(delta)
	
	# 操作
	_handle_actions()

# ==================== 移动 ====================

func _handle_movement(delta: float) -> void:
	# 速度处理
	_is_sprinting = Input.is_action_pressed("sprint")
	_current_speed = walk_speed * (sprint_mult if _is_sprinting else 1.0)
	
	# 载具速度加成
	if game_manager and game_manager.inventory:
		var speed_mult = game_manager.inventory.get_movement_speed_mult()
		_current_speed *= speed_mult
	
	# 方向输入
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * _current_speed
		velocity.z = direction.z * _current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, _current_speed)
		velocity.z = move_toward(velocity.z, 0, _current_speed)
	
	# 跳跃
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	# 重力
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0
	
	move_and_slide()

func _sync_stats() -> void:
	"""从装备和境界同步属性"""
	if not game_manager:
		return
	
	# 境界倍率
	var realm_mult = game_manager.realm.get_stat_multiplier()
	var base_hp = 100 + realm_mult.max_hp_bonus
	var base_mp = 50 + realm_mult.max_mp_bonus
	
	# 修行流派加成
	var cult_stats = game_manager.cultivation.calculate_total_stats()
	max_hp = base_hp + cult_stats.get("max_hp", 0)
	max_mp = base_mp + cult_stats.get("max_mp", 0)
	
	# 装备加成
	var equip_stats = game_manager.inventory.get_equipment_stats()
	max_hp += equip_stats.get("max_hp", 0)

# ==================== 操作 ====================

func _handle_actions() -> void:
	# E — 交互/采集
	if Input.is_action_just_pressed("interact"):
		_do_interact()
	
	# Q — 丢弃物品
	if Input.is_action_just_pressed("drop_item"):
		_do_drop()
	
	# 数字键1-9 — 快捷栏
	for i in range(9):
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			_use_hotbar(i)

# ==================== 交互系统 ====================

func _do_interact() -> void:
	"""射线检测前方的物体进行交互"""
	var space_state = get_world_3d().direct_space_state
	var ray_origin = _camera.global_position
	var ray_end = ray_origin + _camera.global_transform.basis.z * -5.0  # 5格距离
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		print("👆 前方没有可交互目标")
		return
	
	var collider = result.collider
	
	# 根据碰撞物类型处理
	if collider.has_method("gather"):
		# 采集资源（树木/矿石/草药）
		var resource_id = collider.get("resource_type", "wood")
		game_manager.gather_resource(resource_id, 1)
		
	elif collider.has_method("interact"):
		# 交互（门/箱子/合成台）
		collider.interact(self)
	
	else:
		print("👆 检测到 %s，但不可交互" % collider.name)

# ==================== 物品操作 ====================

func _use_hotbar(index: int) -> void:
	"""使用快捷栏物品"""
	if not game_manager or not game_manager.inventory:
		return
	
	var slots = game_manager.inventory.get_all_slots()
	if index >= slots.size():
		return
	
	var slot = slots[index]
	if slot.item_id.is_empty():
		return
	
	var item_data = ItemDatabase.get_item(slot.item_id)
	
	match item_data.get("category", -1):
		ItemDatabase.ItemCategory.CONSUMABLE:
			# 使用消耗品
			game_manager.use_item(index)
		
		ItemDatabase.ItemCategory.TOOL, ItemDatabase.ItemCategory.WEAPON:
			# 装备工具/武器
			game_manager.inventory.equip_item(index)
		
		ItemDatabase.ItemCategory.BUILDING:
			# 进入建造模式（由 BuildingUI 处理）
			print("🏗️ 准备建造: %s" % item_data.name)
		
		ItemDatabase.ItemCategory.STATION, ItemDatabase.ItemCategory.FURNITURE:
			# 放置功能性建筑
			game_manager.place_building(slot.item_id, 
				global_position + global_transform.basis.z * -2.0)

func _do_drop() -> void:
	"""丢弃当前手持物品"""
	var tool_id = game_manager.inventory.get_equipped_tool()
	if tool_id.is_empty():
		return
	# 卸下装备
	game_manager.inventory.unequip_item("tool")

# ==================== 受击/治疗 ====================

func take_damage(amount: int) -> void:
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		_die()

func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)

func _die() -> void:
	print("💀 阵亡！")
	game_manager.player_died.emit()
	# 重生
	current_hp = max_hp * 0.5
	# 回到出生点
	global_position = game_manager.world_data.get("spawn_point", Vector3(0, 1, 0))
