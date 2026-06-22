extends Node
## 建造模式 — MC风格方块放置/破坏（重构版）
##
## 按 B 进入建造模式，显示半透明预览方块
## 左键放置，右键长按破坏（带裂纹效果）
## 依赖：BuildingVisual, BuildingGhost, BuildingTextures

class_name BuildingMode

# ==================== 信号 ====================
signal building_mode_toggled(active: bool)
signal block_placed(piece_type: int, position: Vector3)
signal block_broken(position: Vector3)

# ==================== 子模块 ====================
var ghost: BuildingGhost
var sfx: BuildingSFX

# ==================== 引用 ====================
var _building_system: BuildingSystem
var _player: Node3D
var _camera: Camera3D
var _inventory: Node

# ==================== 状态 ====================
var is_building_mode: bool = false
var _selected_piece_type: int = BuildingSystem.PieceType.WALL
var _selected_tier: int = 0
var _selected_item_id: String = ""

# ==================== 射线/放置状态 ====================
var _target_pos: Vector3 = Vector3.ZERO
var _target_normal: Vector3 = Vector3.ZERO
var _can_place: bool = false
var _can_break: bool = false
var _breaking_pos: Vector3 = Vector3.ZERO
var _break_progress: float = 0.0
var _is_breaking: bool = false

# ==================== 参数 ====================
var build_range: float = 8.0
var break_time: float = 1.5
var ray_length: float = 10.0
var grid_size: float = 1.0

# ==================== 初始化 ====================

func _ready() -> void:
	_building_system = _resolve_building_system()
	
	# 初始化子模块
	ghost = BuildingGhost.new()
	ghost.grid_size = grid_size
	ghost.ghost_alpha = 0.4
	ghost.setup(self)
	
	sfx = BuildingSFX.new()
	add_child(sfx)

func _resolve_building_system() -> BuildingSystem:
	var gm = get_node("/root/GameManager") if has_node("/root/GameManager") else null
	if gm and gm.has_node("BuildingSystem"):
		return gm.get_node("BuildingSystem") as BuildingSystem
	return null

# ==================== 建造模式开关 ====================

func toggle_building_mode(player: Node3D, camera: Camera3D) -> bool:
	if _player:
		_exit_building_mode()
		return false
	_enter_building_mode(player, camera)
	return true

func _enter_building_mode(player: Node3D, camera: Camera3D) -> void:
	_player = player
	_camera = camera
	is_building_mode = true
	
	_building_system = _building_system if _building_system else _resolve_building_system()
	_inventory = get_node("/root/GameManager/Inventory") if has_node("/root/GameManager/Inventory") else null
	
	# 确保方块容器存在
	BuildingVisual.ensure_container(self)
	
	# 默认选中
	_auto_select_building()
	
	ghost.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	building_mode_toggled.emit(true)

func _exit_building_mode() -> void:
	is_building_mode = false
	ghost.hide()
	
	if _is_breaking:
		_cancel_breaking()
	
	if not _is_any_panel_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	building_mode_toggled.emit(false)

# ==================== 每帧更新 ====================

func _process(delta: float) -> void:
	if not is_building_mode or not _player or not _camera:
		return
	
	_update_raycast()
	ghost.update(_target_pos, _can_place)
	
	if _is_breaking:
		_break_progress += delta / break_time
		if _break_progress >= 1.0:
			_do_break()
			_is_breaking = false
			_break_progress = 0.0

func _update_raycast() -> void:
	"""从玩家视角发射射线，检测目标方块位置"""
	var center = _camera.get_viewport().get_visible_rect().size / 2.0
	var from = _camera.project_ray_origin(center)
	var dir = _camera.project_ray_normal(center)
	var to = from + dir * ray_length
	
	var space_state = _player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_player]
	query.collide_with_areas = false
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_pos = result.position
		var normal = result.normal
		var grid_hit = _snap(hit_pos)
		_target_normal = normal
		
		var place_pos = _snap(hit_pos + normal * (grid_size * 0.5))
		_target_pos = place_pos
		
		var dist = _player.global_position.distance_to(place_pos)
		var piece_exists = _building_system and not _building_system.get_piece_at(place_pos).is_empty()
		
		_can_place = dist <= build_range and not piece_exists
		_can_break = dist <= build_range and piece_exists
		_breaking_pos = grid_hit
	else:
		_can_place = false
		_can_break = false
		_target_pos = from + dir * ray_length

func _snap(v: Vector3) -> Vector3:
	if _building_system and _building_system.has_method("_snap_to_grid"):
		return _building_system._snap_to_grid(v)
	return v.snapped(Vector3.ONE)

# ==================== 放置方块 ====================

func try_place() -> bool:
	if not _can_place or not _building_system or _selected_item_id.is_empty():
		return false
	
	if _inventory and not _inventory.has_item(_selected_item_id, 1):
		return false
	
	var result = _building_system.try_place(_selected_piece_type, _selected_tier, _target_pos)
	if result.get("success", false):
		if _inventory:
			_inventory.remove_item(_selected_item_id, 1)
		
		BuildingVisual.create(_selected_piece_type, _selected_tier, _target_pos, self)
		sfx.play("place")
		block_placed.emit(_selected_piece_type, _target_pos)
		return true
	
	return false

# ==================== 破坏方块 ====================

func start_break() -> void:
	if not _can_break or _breaking_pos == Vector3.ZERO:
		return
	_is_breaking = true
	_break_progress = 0.0
	
	var piece = _building_system.get_piece_at(_breaking_pos)
	if not piece.is_empty():
		var tier = piece.get("tier", 0)
		break_time = 1.0 + tier * 0.5

func cancel_break() -> void:
	_cancel_breaking()

func _cancel_breaking() -> void:
	_is_breaking = false
	_break_progress = 0.0

func _do_break() -> void:
	if not _building_system:
		return
	
	var result = _building_system.demolish(_breaking_pos)
	if result.get("success", false):
		BuildingVisual.remove_at(_breaking_pos, self)
		BuildingVisual.spawn_break_particles(_breaking_pos, self)
		sfx.play("break")
		block_broken.emit(_breaking_pos)

# ==================== 方块选择 ====================

func select_building(piece_type: int, item_id: String) -> void:
	_selected_piece_type = piece_type
	_selected_item_id = item_id
	
	if _inventory:
		var item_data = _inventory.get_item_data(item_id)
		if item_data:
			_selected_tier = item_data.get("tier", 0)
	
	ghost.update_shape(piece_type)

func _auto_select_building() -> void:
	if not _inventory:
		return
	
	for i in range(_inventory.get_slot_count()):
		var slot = _inventory.get_slot(i)
		if slot and not slot.item_id.is_empty():
			var item_data = _inventory.get_item_data(slot.item_id)
			if item_data and item_data.get("category", -1) == ItemDatabase.ItemCategory.BUILDING:
				var piece_type = item_data.get("piece_type", BuildingSystem.PieceType.WALL)
				select_building(piece_type, slot.item_id)
				return

# ==================== 鼠标输入 ====================

func _input(event: InputEvent) -> void:
	if not is_building_mode:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		try_place()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			start_break()
		else:
			cancel_break()
	
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_cycle_building(event.button_index == MOUSE_BUTTON_WHEEL_DOWN)

func _cycle_building(forward: bool) -> void:
	if not _inventory:
		return
	
	var building_items: Array[Dictionary] = []
	for i in range(_inventory.get_slot_count()):
		var slot = _inventory.get_slot(i)
		if slot and not slot.item_id.is_empty():
			var item_data = _inventory.get_item_data(slot.item_id)
			if item_data and item_data.get("category", -1) == ItemDatabase.ItemCategory.BUILDING:
				building_items.append({"slot": slot, "data": item_data})
	
	if building_items.is_empty():
		return
	
	var current_idx = -1
	for i in range(building_items.size()):
		if building_items[i].slot.item_id == _selected_item_id:
			current_idx = i
			break
	
	if forward:
		current_idx = (current_idx + 1) % building_items.size()
	else:
		current_idx = (current_idx - 1 + building_items.size()) % building_items.size()
	
	var target = building_items[current_idx]
	var piece_type = target.data.get("piece_type", BuildingSystem.PieceType.WALL)
	select_building(piece_type, target.slot.item_id)

# ==================== 公共接口 ====================

func _is_any_panel_open() -> bool:
	var ui = get_node("/root/UIManager") if has_node("/root/UIManager") else null
	if ui and ui.has_method("is_any_panel_open"):
		return ui.is_any_panel_open()
	return false

func get_break_progress() -> float:
	return _break_progress if _is_breaking else 0.0

func get_selected_info() -> Dictionary:
	return {
		"piece_type": _selected_piece_type,
		"item_id": _selected_item_id,
		"target_pos": _target_pos,
		"can_place": _can_place,
		"can_break": _can_break,
		"break_progress": _break_progress if _is_breaking else 0.0,
	}

func get_building_system() -> BuildingSystem:
	return _building_system
