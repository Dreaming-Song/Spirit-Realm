## 幽灵预览方块管理
## 负责创建/更新/显示半透明预览方块

class_name BuildingGhost

# ==================== 参数 ====================
var grid_size: float = 1.0
var ghost_alpha: float = 0.4

var _ghost_block: MeshInstance3D = null

var _ghost_material_valid: StandardMaterial3D
var _ghost_material_invalid: StandardMaterial3D

# ==================== 生命周期 ====================

func setup(parent: Node) -> void:
	_create_materials()
	_create_ghost(parent)

func _create_materials() -> void:
	_ghost_material_valid = StandardMaterial3D.new()
	_ghost_material_valid.albedo_color = Color(0.3, 1.0, 0.3, ghost_alpha)
	_ghost_material_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material_valid.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	_ghost_material_invalid = StandardMaterial3D.new()
	_ghost_material_invalid.albedo_color = Color(1.0, 0.3, 0.3, ghost_alpha)
	_ghost_material_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material_invalid.cull_mode = BaseMaterial3D.CULL_DISABLED

func _create_ghost(parent: Node) -> void:
	_ghost_block = MeshInstance3D.new()
	_ghost_block.name = "BuildingGhost"
	_ghost_block.mesh = BoxMesh.new()
	_ghost_block.mesh.size = Vector3.ONE * grid_size
	_ghost_block.mesh.material = _ghost_material_valid
	_ghost_block.visible = false
	parent.add_child(_ghost_block)

# ==================== 更新 ====================

func update(target_pos: Vector3, can_place: bool) -> void:
	if not _ghost_block:
		return
	
	if can_place:
		_ghost_block.global_position = target_pos + Vector3(0.5, 0.5, 0.5) * grid_size
		_ghost_block.visible = true
		_ghost_block.mesh.material = _ghost_material_valid
	else:
		_ghost_block.visible = false

func update_shape(piece_type: int) -> void:
	"""根据方块类型更新预览Mesh形状"""
	if not _ghost_block:
		return
	
	match piece_type:
		BuildingSystem.PieceType.WALL, BuildingSystem.PieceType.DOOR:
			var box = BoxMesh.new()
			box.size = Vector3(1.0, 1.0, 0.15)
			_ghost_block.mesh = box
		BuildingSystem.PieceType.FLOOR:
			var box = BoxMesh.new()
			box.size = Vector3(1.0, 0.15, 1.0)
			_ghost_block.mesh = box
		_:
			var box = BoxMesh.new()
			box.size = Vector3.ONE
			_ghost_block.mesh = box

# ==================== 显示控制 ====================

func show() -> void:
	if _ghost_block:
		_ghost_block.visible = true

func hide() -> void:
	if _ghost_block:
		_ghost_block.visible = false

func is_visible() -> bool:
	return _ghost_block != null and _ghost_block.visible

# ==================== 清理 ====================

func cleanup() -> void:
	if _ghost_block and is_instance_valid(_ghost_block):
		_ghost_block.queue_free()
		_ghost_block = null
