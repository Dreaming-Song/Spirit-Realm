extends CharacterBody3D
## 玩家控制器 — 输入处理 + 游戏循环操作入口
##
## 标准3D操作 + 交互（采集/战斗/建造/合成）
## 快捷键：E交互 / 1-9快捷栏 / I背包 / C修行 / B建造 / TAB合成
## 御剑飞行：F切换 / 跳跃上升 / Ctrl下降
## 法术快捷键：1-5（需解锁魔法系统）

class_name PlayerController

# ==================== 移动配置 ====================
@export var walk_speed: float = 5.0
@export var sprint_mult: float = 1.6
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

# ==================== 御剑飞行参数 ====================
@export var fly_speed: float = 15.0
@export var fly_up_speed: float = 6.0

# ==================== 引用 ====================
var game_manager: GameManager

# ==================== 状态 ====================
var _current_speed: float = 5.0
var _is_sprinting: bool = false
var _current_tool: String = ""  # 当前手持工具

# ==================== 输入抽象 ====================
var input_handler: InputHandler

# ==================== 御剑飞行状态 ====================
var is_flying: bool = false
var wind_direction: Vector3 = Vector3.ZERO  # 气流方向（风场影响）

# ==================== 水域状态 ====================
var is_in_water: bool = false         # 是否在水中
var ocean_level: float = -2.0         # 海平面高度（从TerrainManager读取）
var swim_speed: float = 8.0           # 游泳速度
var swim_buoyancy: float = 6.0        # 浮力强度

# ==================== 玩家基础属性 ====================
var current_hp: float = 100.0
var max_hp: float = 100.0
var current_mp: float = 50.0
var max_mp: float = 50.0

# ==================== 自动恢复 ====================
var hp_regen: float = 1.0   # 每秒恢复
var mp_regen: float = 2.0

# ==================== 节点引用 ====================
@onready var _camera: Camera3D = $Camera3D
@onready var _sword: Node3D = $Sword if has_node("Sword") else null

# ==================== 建造模式 ====================
var building_mode: BuildingMode = null

func _ready() -> void:
	# 获取 GameManager
	game_manager = get_node("/root/GameManager") if has_node("/root/GameManager") else null
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	# 🔧 B3/L5: 向 GameManager 注册自己
	if game_manager and game_manager.has_method("set_player"):
		game_manager.set_player(self)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# 从存档恢复属性
	_sync_stats()
	
	# 🔧 输入抽象初始化
	input_handler = get_node("/root/InputHandler") if has_node("/root/InputHandler") else null
	
	# 🔧 从 SettingsManager 读取鼠标灵敏度
	var sm = get_node("/root/SettingsManager") if has_node("/root/SettingsManager") else null
	if sm:
		mouse_sensitivity = sm.get_setting("mouse_sensitivity", 0.002)
		sm.settings_changed.connect(_on_setting_changed)
	
	# 🏗️ 创建建造模式处理器
	building_mode = BuildingMode.new()
	building_mode.name = "BuildingMode"
	add_child(building_mode)
	
	# 🔧 初始化交互探测器
	var detector = get_node("/root/InteractionDetector") if has_node("/root/InteractionDetector") else null
	if detector and detector.has_method("setup"):
		detector.setup(_camera)

func _process(delta: float) -> void:
	# HP/MP 自动恢复（不受 physics_process 状态影响）
	if game_manager and game_manager.current_state == GameManager.GameState.PLAYING:
		current_hp = min(current_hp + hp_regen * delta, max_hp)
		current_mp = min(current_mp + mp_regen * delta, max_mp)
	
	# 🌊 水域检测（从 TerrainManager 读取海平面高度）
	var terrain = get_node("/root/TerrainManager") if has_node("/root/TerrainManager") else null
	ocean_level = terrain.ocean_level if terrain else ocean_level
	is_in_water = global_position.y < ocean_level

func _input(event: InputEvent) -> void:
	# 🏗️ 建造模式拥有输入优先权
	if building_mode and building_mode.is_building_mode:
		building_mode._input(event)
		return
	
	# 鼠标视角
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_camera.rotate_x(-event.relative.y * mouse_sensitivity)
		_camera.rotation.x = clamp(_camera.rotation.x, -1.5, 1.5)
	
	# 🔧 手柄右摇杆视角
	if event is InputEventJoypadMotion:
		var axis_x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		var axis_y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		if abs(axis_x) > 0.1:
			rotate_y(-axis_x * mouse_sensitivity * 3.0)
		if abs(axis_y) > 0.1:
			_camera.rotate_x(-axis_y * mouse_sensitivity * 3.0)
			_camera.rotation.x = clamp(_camera.rotation.x, -1.5, 1.5)
	
	# 法术快捷键 1-5（在御剑飞行切换之前，避免冲突）
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _try_cast_spell(0)
			KEY_2: _try_cast_spell(1)
			KEY_3: _try_cast_spell(2)
			KEY_4: _try_cast_spell(3)
			KEY_5: _try_cast_spell(4)

func _physics_process(delta: float) -> void:
	if not game_manager or game_manager.current_state != GameManager.GameState.PLAYING:
		return
	
	# 御剑飞行切换（在输入检查中处理）
	if Input.is_action_just_pressed("sword_fly"):
		toggle_flying()
	
	if is_flying:
		handle_flying(delta)
		return  # 飞行模式不执行地面操作
	
	# 🌊 水域判断
	if is_in_water:
		_sync_stats()
		_handle_swimming(delta)
		return
	
	# 从装备获取移动速度
	_sync_stats()
	
	# 移动
	_handle_movement(delta)
	
	# 操作
	_handle_actions()

# ==================== 移动 ====================

func _handle_movement(delta: float) -> void:
	# 水域浮力 & 游泳
	if is_in_water:
		velocity.y += swim_buoyancy * delta
		if velocity.y > 2.0:
			velocity.y = lerp(velocity.y, 2.0, delta * 3.0)
		return  # 水域中不执行地面移动和重力
	_is_sprinting = Input.is_action_pressed("sprint")
	_current_speed = walk_speed * (sprint_mult if _is_sprinting else 1.0)
	
	# 载具速度加成
	if game_manager and game_manager.inventory:
		var speed_mult = game_manager.inventory.get_movement_speed_mult()
		_current_speed *= speed_mult
	
	# 方向输入（支持键盘/手柄/触控）
	var input_dir: Vector2
	if input_handler:
		var move_vec = input_handler.get_movement_vector()
		input_dir = Vector2(move_vec.x, -move_vec.y)
	else:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
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

# ==================== 游泳（水域状态） ====================

func _handle_swimming(delta: float) -> void:
	"""水中移动：水平方向 + 浮力"""
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	_current_speed = swim_speed
	_is_sprinting = Input.is_action_pressed("sprint")
	if _is_sprinting:
		_current_speed *= 1.5
	
	if direction:
		velocity.x = direction.x * _current_speed
		velocity.z = direction.z * _current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, _current_speed)
		velocity.z = move_toward(velocity.z, 0, _current_speed)
	
	# 上浮 / 下潜
	if Input.is_action_pressed("jump"):
		velocity.y += swim_buoyancy * delta * 2.0
	if Input.is_key_pressed(KEY_CTRL):
		velocity.y -= swim_buoyancy * delta * 2.0
	
	velocity.y = clamp(velocity.y, -5.0, 5.0)
	move_and_slide()

func _sync_stats() -> void:
	"""从装备和境界同步属性 🔧 L1: 修正基础值计算"""
	if not game_manager:
		return
	
	# 境界倍率（含基础HP/MP加成）
	var realm_mult = game_manager.realm.get_stat_multiplier()
	var base_hp = 100.0 + realm_mult.max_hp_bonus
	var base_mp = 50.0 + realm_mult.max_mp_bonus
	
	# 修行流派加成（仅返回流派带来的额外值）
	var cult_stats = game_manager.cultivation.calculate_total_stats()
	var cult_hp = cult_stats.get("max_hp", 0)
	var cult_mp = cult_stats.get("max_mp", 0)
	
	# 装备加成
	var equip_stats = game_manager.inventory.get_equipment_stats()
	var equip_hp = equip_stats.get("max_hp", 0)
	
	# 叠加计算（不再重复基础值）
	max_hp = base_hp + cult_hp + equip_hp
	max_mp = base_mp + cult_mp
	
	# 修正当前值不超过最大值
	current_hp = min(current_hp, max_hp)
	current_mp = min(current_mp, max_mp)
	
	# 🔧 B5: 同步法力到 SkillManager
	if game_manager.skill_manager:
		game_manager.skill_manager.set_mp(current_mp, max_mp)

# ==================== 御剑飞行 ====================

func toggle_flying() -> void:
	is_flying = not is_flying

## 外部设置飞行状态（由 HandHoldManager 同步领队状态时调用）
func set_flying_state(flying: bool) -> void:
	if flying != is_flying:
		is_flying = flying

func handle_flying(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward: Vector3 = -_camera.global_transform.basis.z
	var right: Vector3 = _camera.global_transform.basis.x
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

func set_wind(wind_vec: Vector3) -> void:
	"""由场景中的风场调用，影响御剑飞行"""
	wind_direction = wind_vec

# ==================== 法术系统 ====================

func _try_cast_spell(index: int) -> void:
	"""按快捷键尝试施法"""
	var magic_system = get_node_or_null("/root/MagicSystem")
	if magic_system == null:
		return
	var spells = magic_system.get_unlocked_spells()
	if index < spells.size():
		magic_system.cast_spell(spells[index].get("type", 0))

# ==================== 操作 ====================

func _handle_actions() -> void:
	# 🏗️ 建造模式 — 玩家只移动，不操作物品
	if building_mode and building_mode.is_building_mode:
		return
	
	# 🔧 L7: 如果 UI 面板打开，跳过玩家操作
	if _is_ui_open():
		return
	
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

## 🔧 L7: 检查是否有 UI 面板打开
func _is_ui_open() -> bool:
	var ui = get_node("/root/UIManager") if has_node("/root/UIManager") else null
	if ui and ui.has_method("is_any_panel_open"):
		return ui.is_any_panel_open()
	return false

# ==================== 交互系统 ====================

func _do_interact() -> void:
	"""使用交互探测器执行交互（如果正在牵手则先松开）"""
	# 优先检查牵手状态
	var hhm = get_node("/root/HandHoldManager") if has_node("/root/HandHoldManager") else null
	if hhm and hhm.is_holding():
		hhm.release_all("交互键松开")
		return
	
	var detector = get_node("/root/InteractionDetector") if has_node("/root/InteractionDetector") else null
	if detector and detector.has_method("perform_interaction"):
		var result = detector.perform_interaction(self)
		if result.get("success", false):
			var action = result.get("action", "")
			match action:
				"gather":
					var target = detector.get_current_target()
					var resource_id = target.get("resource_type", "wood")
					game_manager.gather_resource(resource_id, 1)
				"talk":
					var npc = result.get("npc", null)
					if npc:
						_start_dialogue(npc)
			print("交互成功: %s" % action)
		else:
			print("无可交互目标")
	else:
		# 回退方案：直接射线检测
		_fallback_interact()

func _fallback_interact() -> void:
	"""备用交互方案（无探测器时）"""
	var space_state = get_world_3d().direct_space_state
	var ray_origin = _camera.global_position
	var ray_end = ray_origin + _camera.global_transform.basis.z * -5.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		print("前方没有可交互目标")
		return
	
	var collider = result.get("collider", null)
	if collider and collider.has_method("gather"):
		var resource_id = collider.get("resource_type", "wood")
		game_manager.gather_resource(resource_id, 1)
	elif collider and collider.has_method("interact"):
		collider.interact(self)

func _start_dialogue(npc: Node) -> void:
	"""开始与NPC对话"""
	var ui = get_node("/root/UIManager") if has_node("/root/UIManager") else null
	if ui:
		ui.open_dialogue(npc)

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
	var spawn = game_manager.world_data.get("spawn_point", [0, 1, 0])
	if spawn is Array:
		global_position = Vector3(spawn[0], spawn[1], spawn[2])
	else:
		global_position = Vector3(0, 1, 0)

# ==================== HP/MP 外部接口 ====================

func get_hp() -> float: return current_hp
func get_max_hp() -> float: return max_hp
func get_hp_ratio() -> float: return current_hp / max_hp if max_hp > 0 else 0.0
func get_mp() -> float: return current_mp
func get_max_mp() -> float: return max_mp
func get_mp_ratio() -> float: return current_mp / max_mp if max_mp > 0 else 0.0
func use_mp(amount: int) -> void: current_mp = max(current_mp - amount, 0)

# ==================== 存档接口（Vector3 序列化修复） ====================

func get_current_state() -> Dictionary:
	"""给 UI/存档用的状态快照 — Vector3 转数组"""
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"is_flying": is_flying,
		"is_in_water": is_in_water,
		"hp": current_hp,
		"mp": current_mp,
		"max_hp": max_hp,
		"max_mp": max_mp
	}

func set_state(data: Dictionary) -> void:
	"""从存档恢复状态 — 数组转 Vector3"""
	if data.has("position"):
		var pos = data["position"]
		if pos is Array and pos.size() >= 3:
			global_position = Vector3(pos[0], pos[1], pos[2])
	if data.has("hp"):
		current_hp = float(data["hp"])
	if data.has("mp"):
		current_mp = float(data["mp"])
	if data.has("is_flying"):
		is_flying = data["is_flying"]
	if data.has("is_in_water"):
		is_in_water = data["is_in_water"]

# ==================== 设置同步 ====================

func _on_setting_changed(key: String, value) -> void:
	"""当 SettingsManager 的设置变更时同步"""
	if key == "mouse_sensitivity":
		mouse_sensitivity = value
