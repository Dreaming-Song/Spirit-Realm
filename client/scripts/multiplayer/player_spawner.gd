extends Node
## 玩家生成器 — 管理其他玩家的 3D 实体
##
## 监听 NetworkManager 信号，自动创建/销毁 RemotePlayer
## 定期同步位置状态

class_name PlayerSpawner

signal local_player_interacted(target_player_id: String, action: String)

# ==================== 配置 ====================
var player_scene: PackedScene = null  # RemotePlayer 场景
var _players: Dictionary = {}  # player_id → RemotePlayer
var _network: Node = null
var _local_player: Node = null

# 本地状态同步间隔
var _sync_timer: float = 0.0
var _sync_interval: float = 0.1  # 每秒10次

func _ready() -> void:
	_network = get_node("/root/NetworkManager") if has_node("/root/NetworkManager") else null
	_local_player = get_tree().get_first_node_in_group("player")
	
	if not _network:
		print("⚠️ PlayerSpawner: 无 NetworkManager，运行在单机模式")
		return
	
	# 连接信号
	_network.player_joined.connect(_on_player_joined)
	_network.player_left.connect(_on_player_left)
	_network.player_state_received.connect(_on_player_state)
	_network.chat_received.connect(_on_chat_received)
	_network.connected.connect(_on_connected)
	
	# 动态创建 RemotePlayer 场景（用脚本实例代替）
	if not player_scene:
		# 用脚本创建，不需要 .tscn 文件
		pass

func _process(delta: float) -> void:
	if not _network or not _network.is_connected:
		return
	
	# 定期发送本地玩家状态
	_sync_timer += delta
	if _sync_timer >= _sync_interval:
		_sync_timer = 0.0
		_send_local_state()

# ==================== 事件处理 ====================

func _on_connected() -> void:
	print("📡 PlayerSpawner: 已连接，等待其他玩家...")

func _on_player_joined(player_id: String) -> void:
	"""有玩家加入房间，创建其视觉实体"""
	if player_id == _network.player_id:
		return  # 自己
	
	if _players.has(player_id):
		return  # 已存在
	
	var remote = _create_remote_player(player_id)
	_players[player_id] = remote
	print("👤 远程玩家已生成: %s" % player_id)

func _on_player_left(player_id: String) -> void:
	"""有玩家离开，销毁实体"""
	if not _players.has(player_id):
		return
	
	var remote = _players[player_id]
	if is_instance_valid(remote):
		remote.queue_free()
	_players.erase(player_id)
	print("👋 远程玩家已移除: %s" % player_id)

func _on_player_state(player_id: String, state: Dictionary) -> void:
	"""接收其他玩家的状态更新"""
	if not _players.has(player_id):
		return
	
	var remote = _players[player_id]
	if is_instance_valid(remote):
		remote.update_state(state)

func _on_chat_received(player_id: String, message: String) -> void:
	"""接收聊天消息，显示聊天气泡"""
	if _players.has(player_id):
		var remote = _players[player_id]
		if is_instance_valid(remote):
			remote.set_chat_text(message)

# ==================== 创建远程玩家 ====================

func _create_remote_player(player_id: String) -> RemotePlayer:
	"""创建远程玩家实体"""
	var remote = RemotePlayer.new()
	remote.name = "RemotePlayer_%s" % player_id
	remote.remote_player_id = player_id
	remote.display_name = player_id
	
	# 加到世界场景
	var world = get_tree().current_scene
	if world:
		world.add_child(remote)
	
	# 添加碰撞和视觉（简化版：胶囊体+标记）
	_add_visual(remote)
	_add_collision(remote)
	
	return remote

func _add_visual(remote: RemotePlayer) -> void:
	"""添加简化视觉（无模型时用标记代替）"""
	# 名称标签
	var label = Label3D.new()
	label.name = "NameLabel"
	label.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.005
	label.font_size = 32
	label.outline_modulate = Color.BLACK
	label.outline_size = 4
	label.position = Vector3(0, 2.5, 0)
	label.modulate = Color(0.3, 0.8, 1.0)
	remote.add_child(label)
	
	# 聊天气泡
	var chat = Label3D.new()
	chat.name = "ChatBubble"
	chat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	chat.pixel_size = 0.004
	chat.font_size = 28
	chat.outline_modulate = Color.BLACK
	chat.outline_size = 3
	chat.position = Vector3(0, 3.2, 0)
	chat.modulate = Color(1, 1, 1)
	chat.visible = false
	remote.add_child(chat)
	
	# HP 条
	var hp_bar = ProgressBar3D.new()
	hp_bar.name = "HpBar"
	hp_bar.position = Vector3(0, 2.2, 0)
	hp_bar.subdivision = 1
	hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_bar.modulate = Color(1, 0.2, 0.2)
	remote.add_child(hp_bar)
	
	# 简易身体标记（立方体 or 圆柱）
	var mesh = MeshInstance3D.new()
	mesh.mesh = CylinderMesh.new()
	mesh.mesh.top_radius = 0.3
	mesh.mesh.bottom_radius = 0.3
	mesh.mesh.height = 1.5
	mesh.position = Vector3(0, 0.75, 0)
	mesh.material_override = StandardMaterial3D.new()
	mesh.material_override.albedo_color = Color(0.3, 0.7, 1.0, 0.8)
	mesh.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	remote.add_child(mesh)
	
	# 头顶标记（箭头/光环）
	var indicator = MeshInstance3D.new()
	indicator.mesh = SphereMesh.new()
	indicator.mesh.radius = 0.1
	indicator.mesh.height = 0.2
	indicator.position = Vector3(0, 2.6, 0)
	indicator.material_override = StandardMaterial3D.new()
	indicator.material_override.albedo_color = Color(1, 0.8, 0.2)
	indicator.material_override.emission = Color(1, 0.8, 0.2)
	indicator.material_override.emission_energy_multiplier = 0.5
	remote.add_child(indicator)
	
	# 设置为 Label3D 的引用
	remote.name_label = label
	remote.chat_bubble = chat
	remote.hp_bar = hp_bar

func _add_collision(remote: RemotePlayer) -> void:
	"""添加碰撞体"""
	var col = CollisionShape3D.new()
	col.shape = CapsuleShape3D.new()
	col.shape.radius = 0.4
	col.shape.height = 1.8
	col.position = Vector3(0, 0.9, 0)
	remote.add_child(col)

# ==================== 本地状态同步 ====================

func _send_local_state() -> void:
	"""发送本地玩家状态给服务端"""
	if not _local_player or not _network:
		return
	
	var pos = _local_player.global_position
	var rot = _local_player.rotation
	
	var hp = _local_player.get("current_hp", 100) if _local_player.has_method("get_hp") else 100
	var mp = _local_player.get("current_mp", 50) if _local_player.has_method("get_mp") else 50
	
	_network.send_player_state(
		pos.x, pos.y, pos.z,
		rot.x, rot.y,
		hp, mp,
		_local_player.is_flying,
		_local_player.is_in_water
	)

# ==================== 玩家交互 ====================

func interact_with_player(player_id: String, action: String) -> void:
	"""与指定玩家互动"""
	var remote = _players.get(player_id)
	if not remote or not is_instance_valid(remote):
		return
	
	match action:
		"trade":
			_send_interaction(player_id, "trade_request")
		"party_invite":
			_send_interaction(player_id, "party_invite")
		"hold_hand":
			_handle_handhold(player_id, remote)
		"release_hand":
			_handle_release_handhold(player_id)
		"follow":
			_send_interaction(player_id, "follow_request")
		"wave":
			_send_interaction(player_id, "emote_wave")
		"bow":
			_send_interaction(player_id, "emote_bow")
		"dance":
			_send_interaction(player_id, "emote_dance")

func _handle_handhold(target_id: String, remote_node: Node) -> void:
	"""处理牵手请求"""
	var hhm = get_node("/root/HandHoldManager") if has_node("/root/HandHoldManager") else null
	if not hhm:
		return
	
	# 获取对方名字
	var target_name = remote_node.get("display_name", "道友") if remote_node else "道友"
	
	# 如果已经牵着这个玩家 → 松开
	if hhm.my_leader_id == target_id:
		hhm.release_leader("用户操作")
		return
	if hhm.my_follower_ids.has(target_id):
		hhm.release_follower(target_id, "用户操作")
		return
	
	hhm.request_hold(target_id, target_name)

func _handle_release_handhold(player_id: String) -> void:
	"""松开手"""
	var hhm = get_node("/root/HandHoldManager") if has_node("/root/HandHoldManager") else null
	if hhm:
		# 如果对方是我的领队 → 松开领队
		# 如果对方是我的跟随者 → 松开具体那个
		if hhm.my_leader_id == player_id:
			hhm.release_leader("用户操作")
		elif hhm.my_follower_ids.has(player_id):
			hhm.release_follower(player_id, "用户操作")
		else:
			hhm.release_all("用户操作")

## 根据ID获取远程玩家节点
func get_player_node(player_id: String) -> Node3D:
	return _players.get(player_id, null)

func _send_interaction(target_id: String, action: String) -> void:
	"""发送交互消息给目标玩家"""
	if not _network:
		return
	_network._send({
		"type": "player_interaction",
		"target_id": target_id,
		"action": action,
		"sender_id": _network.player_id
	})

func get_nearby_players(max_distance: float = 10.0) -> Array[Dictionary]:
	"""获取附近玩家列表"""
	var result: Array[Dictionary] = []
	for pid in _players.keys():
		var remote = _players[pid]
		if not is_instance_valid(remote):
			continue
		# 计算距离（如果本地玩家存在）
		var dist = 0.0
		if _local_player:
			dist = _local_player.global_position.distance_to(remote.global_position)
		if dist <= max_distance:
			result.append({
				"player_id": pid,
				"name": remote.display_name,
				"node": remote,
				"distance": dist,
				"hp": remote.current_hp,
				"max_hp": remote.max_hp,
			})
	
	# 按距离排序
	result.sort_custom(func(a, b): return a.distance < b.distance)
	return result
