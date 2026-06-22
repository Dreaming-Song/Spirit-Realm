## 方块视觉创建/销毁/粒子效果
## 被 BuildingMode 调用，不包含状态逻辑

class_name BuildingVisual

# 方块包围盒容器在场景树中的名称
const BLOCK_CONTAINER_NAME: String = "BuiltBlocks"

# ==================== 创建方块视觉 ====================

## 在场景中创建完整的方块（StaticBody3D + MeshInstance3D）
static func create(piece_type: int, tier: int, pos: Vector3, parent: Node) -> bool:
	"""返回是否成功创建（不存在重复时返回true）"""
	var container = _ensure_container(parent)
	if not container:
		return false
	
	var block_name = _name_at(pos)
	if container.has_node(block_name):
		return false  # 已存在
	
	var block = StaticBody3D.new()
	block.name = block_name
	block.position = pos + Vector3(0.5, 0.5, 0.5)  # 中心对齐
	
	# 碰撞形状
	var shape := _create_collision_shape(piece_type)
	if shape:
		block.add_child(shape)
	
	# 可视Mesh
	var mesh_instance := _create_mesh_instance(piece_type, tier)
	if mesh_instance:
		block.add_child(mesh_instance)
	
	container.add_child(block)
	block.owner = container.owner if container.owner else block
	return true

static func _create_collision_shape(piece_type: int) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	
	match piece_type:
		BuildingSystem.PieceType.WALL, BuildingSystem.PieceType.DOOR:
			shape.shape = BoxShape3D.new()
			shape.shape.size = Vector3(1.0, 1.0, 0.15)
		BuildingSystem.PieceType.FLOOR:
			shape.shape = BoxShape3D.new()
			shape.shape.size = Vector3(1.0, 0.15, 1.0)
		BuildingSystem.PieceType.FOUNDATION:
			shape.shape = BoxShape3D.new()
			shape.shape.size = Vector3(1.0, 0.3, 1.0)
		BuildingSystem.PieceType.PILLAR:
			shape.shape = CylinderShape3D.new()
			shape.shape.radius = 0.15
			shape.shape.height = 1.0
		BuildingSystem.PieceType.ROOF:
			shape.shape = BoxShape3D.new()
			shape.shape.size = Vector3(1.0, 0.5, 1.0)
		_:
			shape.shape = BoxShape3D.new()
			shape.shape.size = Vector3.ONE
	
	return shape

static func _create_mesh_instance(piece_type: int, tier: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	
	match piece_type:
		BuildingSystem.PieceType.WALL, BuildingSystem.PieceType.DOOR:
			mesh_instance.mesh = BoxMesh.new()
			mesh_instance.mesh.size = Vector3(1.0, 1.0, 0.15)
		BuildingSystem.PieceType.FLOOR:
			mesh_instance.mesh = BoxMesh.new()
			mesh_instance.mesh.size = Vector3(1.0, 0.15, 1.0)
		BuildingSystem.PieceType.ROOF:
			var prism = PrismMesh.new()
			prism.size = Vector3(1.0, 0.5, 1.0)
			mesh_instance.mesh = prism
		BuildingSystem.PieceType.PILLAR:
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.1
			cyl.bottom_radius = 0.15
			cyl.height = 1.0
			mesh_instance.mesh = cyl
		BuildingSystem.PieceType.FOUNDATION:
			mesh_instance.mesh = BoxMesh.new()
			mesh_instance.mesh.size = Vector3(1.0, 0.3, 1.0)
		_:
			mesh_instance.mesh = BoxMesh.new()
			mesh_instance.mesh.size = Vector3.ONE
	
	# 材质
	var mat = _make_material(piece_type, tier)
	if mesh_instance.mesh:
		mesh_instance.mesh.material = mat
	
	return mesh_instance

static func _make_material(piece_type: int, tier: int) -> StandardMaterial3D:
	var tier_data = BuildingSystem.get_tier_data(tier)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = tier_data.color
	mat.albedo_texture = BuildingTextures.generate(piece_type)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	mat.metallic = float(tier) / 8.0 * 0.5
	mat.roughness = 0.8 - float(tier) / 8.0 * 0.4
	return mat

# ==================== 销毁方块视觉 ====================

static func remove_at(pos: Vector3, from: Node) -> void:
	"""移除指定位置的方块场景节点"""
	var container = _find_container(from)
	if not container:
		return
	
	var name = _name_at(pos)
	if container.has_node(name):
		var node = container.get_node(name)
		if is_instance_valid(node):
			node.queue_free()

static func remove_all(from: Node) -> void:
	"""清空所有已建造方块（用于重置场景）"""
	var container = _find_container(from)
	if container and is_instance_valid(container):
		for child in container.get_children():
			child.queue_free()

# ==================== 粒子效果 ====================

static func spawn_break_particles(pos: Vector3, parent: Node) -> void:
	"""破坏粒子：生成6个随机小碎片飞散"""
	var colors = [
		Color(0.6, 0.4, 0.2),
		Color(0.5, 0.35, 0.15),
		Color(0.4, 0.3, 0.1)
	]
	
	for i in range(6):
		var frag = MeshInstance3D.new()
		frag.name = "BreakFragment_%d" % i
		frag.position = pos + Vector3(0.5, 0.5, 0.5)
		
		var box = BoxMesh.new()
		box.size = Vector3(0.08, 0.08, 0.08)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		box.material = mat
		frag.mesh = box
		
		# 随机速度
		var dir = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.3, 1.0),
			randf_range(-1.0, 1.0)
		).normalized() * randf_range(1.5, 3.5)
		
		# 用 TemporaryFragment 处理物理和自销毁
		var temp = Node3D.new()
		temp.name = "TempParticle_%d" % i
		temp.add_child(frag)
		temp.set_script(preload("res://scripts/effects/temporary_fragment.gd"))
		if temp.has_method("init"):
			temp.init(dir, 0.8)
		parent.add_child(temp)

# ==================== 容器管理 ====================

static func ensure_container(root: Node) -> Node:
	"""确保方块容器节点存在并返回"""
	return _ensure_container(root)

static func _find_container(context: Node) -> Node:
	"""从任意节点向上查找容器"""
	if not context or not is_instance_valid(context):
		return null
	var root = context.get_tree().root if context.get_tree() else null
	if root and root.has_node(BLOCK_CONTAINER_NAME):
		return root.get_node(BLOCK_CONTAINER_NAME)
	return null

static func _ensure_container(root: Node) -> Node:
	"""确保容器存在，不存在则创建"""
	var container = _find_container(root)
	if container:
		return container
	
	if not root or not root.get_tree():
		return null
	
	container = Node3D.new()
	container.name = BLOCK_CONTAINER_NAME
	container.top_level = false
	root.get_tree().root.add_child(container)
	return container

# ==================== 工具 ====================

static func _name_at(pos: Vector3) -> String:
	"""将位置转换为唯一节点名"""
	return "Block_%d_%d_%d" % [int(pos.x), int(pos.y), int(pos.z)]
