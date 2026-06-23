extends Node
## 🤝 链式牵手系统 — 光遇式多人牵手火车！
##
## 特性：
##   1. 链式结构：A→B→C→D，无限延伸
##   2. 分支支持：一人可被多人同时牵手（树形）
##   3. 领队移动 → 整列火车顺序跟随
##   4. 中间断开 → 后半段自动独立
##   5. 多根灵力光链 + 脉动特效
##
## 状态模型：
##   my_leader_id        = 前面牵着我的手的人（唯一）
##   my_follower_ids[]   = 后面牵着我的手的人们（可多个）
##
##                   领队A              A是绝对领队
##                  ↗ ↓
##                 B   C              B、C都牵着A
##                ↓                   B又牵着D
##                D
##
## 使用方式：
##   HandHoldManager.request_hold(target_id)     → 牵着target
##   HandHoldManager.release_from_leader()       → 松开前面的人
##   HandHoldManager.release_follower(target_id)  → 松开后面的人
##   HandHoldManager.release_all()               → 全部松开

class_name HandHoldManager

# ==================== 信号 ====================
signal hold_requested(from_id: String, from_name: String)
signal hold_accepted(leader_id: String, follower_id: String)
signal hold_rejected(from_id: String)
signal hold_established(leader_id: String, follower_id: String)  # 连接建立
signal hold_broken(leader_id: String, follower_id: String, reason: String)  # 连接断开
signal chain_updated()  # 整个链条发生变化

# ==================== 牵手状态（每个玩家） ====================
var my_leader_id: String = ""        # 前面牵我的人（最多1个）
var my_leader_name: String = ""      # 前面的人的名字
var my_leader_node: Node3D = null    # 前面的人的RemotePlayer节点

var my_follower_ids: Array[String] = []    # 后面牵着我的人（可多个）
var my_follower_names: Dictionary = {}     # id → name
var my_follower_nodes: Dictionary = {}     # id → RemotePlayer节点

# ==================== 配置 ====================
var max_chain_length: int = 10        # 最大链长（防止递归过深）
var hold_range: float = 25.0          # 最大牵手距离
var follow_distance: float = 2.0      # 跟随者与领队之间的距离
var follow_smoothness: float = 6.0    # 跟随插值速度
var break_timeout: float = 3.0        # 超距几秒后断开
var chain_spacing: float = 1.8        # 链上前后的间距

# ==================== 引用 ====================
var _network: Node = null
var _spawner: Node = null
var _local_player: Node3D = null

# ==================== 视觉 ====================
var _thread_scene: PackedScene = null  # 光链模板
var _threads: Dictionary = {}          # "leader_id→follower_id" → MeshInstance3D
var _break_timers: Dictionary = {}     # "id_pair" → float 超距计时

var _thread_material: Material = null

func _ready() -> void:
	# 自注册
	if not get_node("/root/HandHoldManager"):
		var root = get_tree().root
		if root and not root.has_node("HandHoldManager"):
			root.add_child(self)
	
	_network = get_node("/root/NetworkManager") if has_node("/root/NetworkManager") else null
	_spawner = get_node("/root/PlayerSpawner") if has_node("/root/PlayerSpawner") else null
	_local_player = get_tree().get_first_node_in_group("player")
	
	# 创建光链材质
	_thread_material = StandardMaterial3D.new()
	_thread_material.albedo_color = Color(1.0, 0.5, 0.7, 0.6)
	_thread_material.emission = Color(1.0, 0.3, 0.5)
	_thread_material.emission_energy_multiplier = 2.0
	_thread_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _process(delta: float) -> void:
	# 如果我是跟随者，跟随我的领队
	if my_leader_id != "" and my_leader_node and _local_player:
		_follow_leader(delta)
	
	# 更新所有光链
	_update_all_threads(delta)
	
	# 超距检测
	_check_all_distances(delta)

# ==================== 公共接口 ====================

## 发起牵手请求（我要牵 target_id 的手）
func request_hold(target_id: String, target_name: String) -> bool:
	if not _network or not _network.is_connected:
		print("⚠️ 未连接网络")
		return false
	
	# 检查是否已经牵着
	if my_follower_ids.has(target_id) or my_leader_id == target_id:
		print("⚠️ 已经和 %s 牵手了" % target_name)
		return false
	
	# 检查链长
	if _get_chain_length() >= max_chain_length:
		print("⚠️ 链条太长，不能再增加了")
		return false
	
	# RPC: 发送请求（让对方成为我的跟随者）
	_network.send_hold_request.rpc_id(int(target_id), _network.player_name)
	print("🤝 发起牵手请求 → %s" % target_name)
	return true

## 接受牵手请求（同意让 sender_id 牵我）
func accept_hold_request(sender_id: String) -> void:
	if my_leader_id != "":
		print("⚠️ 我已经有领队了，先松开再接受")
		return
	
	my_leader_id = sender_id
	_find_leader_node()
	
	if _network:
		_network.send_hold_accept.rpc_id(int(sender_id))
	
	hold_established.emit(sender_id, _network.player_id if _network else "")
	chain_updated.emit()
	_create_thread(sender_id, "leader")
	print("🤝 接受牵手！%s 成为我的领队" % sender_id)

## 拒绝牵手请求
func reject_hold_request(sender_id: String) -> void:
	if _network:
		_network.send_hold_reject.rpc_id(int(sender_id))
	hold_rejected.emit(sender_id)
	print("🙅 拒绝牵手")

## 松开前面的领队
func release_leader(reason: String = "主动松开") -> void:
	if my_leader_id == "":
		return
	
	var old_leader = my_leader_id
	
	# 通知对方
	if _network and _network.is_connected:
		_network.send_hold_release.rpc_id(int(my_leader_id))
	
	_remove_thread(my_leader_id, "leader")
	my_leader_id = ""
	my_leader_name = ""
	my_leader_node = null
	
	hold_broken.emit(old_leader, _network.player_id if _network else "", reason)
	chain_updated.emit()
	print("👋 松开领队: %s" % reason)

## 松开某个跟随者
func release_follower(follower_id: String, reason: String = "主动松开") -> void:
	if not my_follower_ids.has(follower_id):
		return
	
	my_follower_ids.erase(follower_id)
	my_follower_names.erase(follower_id)
	my_follower_nodes.erase(follower_id)
	_remove_thread(follower_id, "follower")
	
	# 通知对方
	if _network and _network.is_connected:
		_network.send_hold_release.rpc_id(int(follower_id))
	
	hold_broken.emit(_network.player_id if _network else "", follower_id, reason)
	chain_updated.emit()
	print("👋 松开跟随者 %s: %s" % [follower_id, reason])

## 全部松开
func release_all(reason: String = "全部松开") -> void:
	release_leader(reason)
	# 复制一份遍历，因为 release_follower 会修改数组
	var followers = my_follower_ids.duplicate()
	for fid in followers:
		release_follower(fid, reason)

## 获取完整链信息（调试用）
func get_chain_info() -> Dictionary:
	var chain = []
	var current = _network.player_id if _network else "local"
	chain.append(current)
	
	# 向前找领队
	var visited = {}
	var node_id = my_leader_id
	while node_id != "" and not visited.has(node_id) and visited.size() < max_chain_length:
		visited[node_id] = true
		chain.push_front(node_id)
		var remote = _spawner.get_player_node(node_id) if _spawner else null
		if remote and remote.has_method("get_leader_id"):
			node_id = remote.get_leader_id()
		else:
			break
	
	return {
		"chain": chain,
		"leader": my_leader_id,
		"followers": my_follower_ids.duplicate(),
		"length": chain.size()
	}

# ==================== RPC 回调 ====================

func _on_hold_request_received(from_id: String, from_name: String) -> void:
	hold_requested.emit(from_id, from_name)
	print("📩 收到 %s 的牵手请求" % from_name)

func _on_hold_accepted(follower_id: String) -> void:
	"""对方接受牵手 → 我作为领队"""
	if my_follower_ids.has(follower_id):
		return
	
	my_follower_ids.append(follower_id)
	my_follower_names[follower_id] = "道友"
	_find_follower_node(follower_id)
	
	hold_established.emit(_network.player_id if _network else "", follower_id)
	chain_updated.emit()
	_create_thread(follower_id, "follower")
	print("✅ %s 接受了牵手！（我的跟随者+1）" % follower_id)

func _on_hold_rejected(from_id: String) -> void:
	hold_rejected.emit(from_id)
	print("😅 对方拒绝牵手")

func _on_hold_released(from_id: String) -> void:
	"""对方松开手"""
	if my_leader_id == from_id:
		# 领队松手了
		_remove_thread(from_id, "leader")
		my_leader_id = ""
		my_leader_name = ""
		my_leader_node = null
		hold_broken.emit(from_id, _network.player_id if _network else "", "对方松手")
		chain_updated.emit()
		print("👋 领队 %s 松开了手" % from_id)
	elif my_follower_ids.has(from_id):
		# 跟随者松手了
		my_follower_ids.erase(from_id)
		my_follower_names.erase(from_id)
		my_follower_nodes.erase(from_id)
		_remove_thread(from_id, "follower")
		hold_broken.emit(_network.player_id if _network else "", from_id, "对方松手")
		chain_updated.emit()
		print("👋 跟随者 %s 松开了手" % from_id)

# ==================== 跟随逻辑 ====================

func _follow_leader(delta: float) -> void:
	"""跟随我的领队 — 同步位置 + 状态（飞行/游泳）"""
	if not my_leader_node or not _local_player:
		return
	
	var leader_pos = my_leader_node.global_position
	var leader_basis = my_leader_node.global_transform.basis
	var leader_back = -leader_basis.z.normalized()
	if leader_back.length() < 0.1:
		leader_back = Vector3(0, 0, 1)
	
	# 🎯 计算目标位置（领队身后 follow_distance）
	var target = leader_pos + leader_back * follow_distance
	
	# 🚀 状态同步：复制领队的飞行/游泳状态
	_sync_leader_state()
	
	# 📏 高度同步
	if my_leader_node.is_flying:
		# 飞行中：跟随领队高度，保持队形
		target.y = leader_pos.y
	elif my_leader_node.is_in_water:
		# 水域中：跟随领队高度
		target.y = leader_pos.y
	else:
		# 地面：保持本地水平高度
		target.y = _local_player.global_position.y
	
	# 🏃 平滑插值移动
	_local_player.global_position = _local_player.global_position.lerp(
		target, follow_smoothness * delta
	)
	
	# 面朝领队方向（保持注视）
	var look_dir = (leader_pos - _local_player.global_position).normalized()
	if look_dir.length() > 0.1:
		_local_player.look_at(
			_local_player.global_position + look_dir,
			Vector3.UP
		)

func _sync_leader_state() -> void:
	"""同步领队的飞行/游泳状态到本地玩家"""
	if not my_leader_node or not _local_player:
		return
	
	var local_pc = _local_player
	
	# 🛸 飞行状态同步
	if my_leader_node.is_flying and not local_pc.is_flying:
		local_pc.set_flying_state(true)
	elif not my_leader_node.is_flying and local_pc.is_flying:
		local_pc.set_flying_state(false)
	
	# 🌊 游泳状态同步（通过 is_in_water）
	# 注意：is_in_water 是自动检测的，不需要手动设置
	# 但跟随者进入水域时自动触发 buoyancy

# ==================== 光链管理 ====================

func _create_thread(target_id: String, role: String) -> void:
	"""为连接创建灵力光链"""
	var key = _thread_key(target_id, role)
	if _threads.has(key):
		return
	
	var thread = MeshInstance3D.new()
	thread.name = "ChainThread_%s" % key
	thread.mesh = CylinderMesh.new()
	thread.mesh.top_radius = 0.04
	thread.mesh.bottom_radius = 0.04
	thread.mesh.height = 1.0
	thread.mesh.material = _thread_material
	thread.visible = true
	add_child(thread)
	
	_threads[key] = thread
	_break_timers[key] = 0.0

func _remove_thread(target_id: String, role: String) -> void:
	"""移除灵力光链"""
	var key = _thread_key(target_id, role)
	if _threads.has(key):
		var t = _threads[key]
		if is_instance_valid(t):
			t.queue_free()
		_threads.erase(key)
	_break_timers.erase(key)

func _thread_key(target_id: String, role: String) -> String:
	"""生成光链唯一键"""
	var my_id = _network.player_id if _network else "local"
	if role == "leader":
		return "%s→%s" % [target_id, my_id]  # 领队牵我
	else:
		return "%s→%s" % [my_id, target_id]  # 我牵跟随者

func _update_all_threads(delta: float) -> void:
	"""更新所有光链位置/缩放"""
	for key in _threads.keys():
		var thread = _threads[key]
		if not is_instance_valid(thread):
			continue
		
		var parts = key.split("→")
		if parts.size() != 2:
			continue
		var lid = parts[0]
		var fid = parts[1]
		
		# 获取两端位置
		var start_node = _get_player_node(lid)
		var end_node = _get_player_node(fid)
		
		if not start_node or not end_node:
			thread.visible = false
			continue
		
		var start = start_node.global_position + Vector3(0, 1.2, 0)
		var end = end_node.global_position + Vector3(0, 1.2, 0)
		var mid = (start + end) / 2.0
		var dist = start.distance_to(end)
		
		if dist < 0.1:
			thread.visible = false
			continue
		
		thread.visible = true
		thread.global_position = mid
		thread.look_at(end, Vector3.UP)
		thread.mesh.height = dist
		
		# 脉动效果
		var pulse = 0.04 + sin(Time.get_ticks_msec() * 0.005 + key.hash() * 0.1) * 0.015
		thread.mesh.top_radius = pulse
		thread.mesh.bottom_radius = pulse

# ==================== 超距检测 ====================

func _check_all_distances(delta: float) -> void:
	"""检测所有连接是否超距"""
	if not _local_player:
		return
	
	# 检查领队
	if my_leader_id != "" and my_leader_node:
		var key = _thread_key(my_leader_id, "leader")
		_check_single_distance(my_leader_node, key, delta, func():
			release_leader("距离过远")
		)
	
	# 检查跟随者
	for fid in my_follower_ids:
		var node = my_follower_nodes.get(fid)
		if node:
			var key = _thread_key(fid, "follower")
			_check_single_distance(node, key, delta, func():
				release_follower(fid, "距离过远")
			)

func _check_single_distance(node: Node3D, key: String, delta: float, on_break: Callable) -> void:
	"""检测单个连接的距离"""
	if not _local_player:
		return
	var dist = _local_player.global_position.distance_to(node.global_position)
	
	if dist > hold_range:
		var t = _break_timers.get(key, 0.0) + delta
		_break_timers[key] = t
		if t >= break_timeout:
			on_break.call()
	else:
		_break_timers[key] = 0.0

# ==================== 工具 ====================

func _find_leader_node() -> void:
	"""根据 my_leader_id 查找领队节点"""
	if not _spawner or not _spawner.has_method("get_player_node"):
		return
	my_leader_node = _spawner.get_player_node(my_leader_id)
	# 也存名字
	var remote = my_leader_node
	if remote and remote.has_method("get_display_name"):
		my_leader_name = remote.get_display_name()

func _find_follower_node(follower_id: String) -> void:
	"""查找跟随者节点"""
	if not _spawner or not _spawner.has_method("get_player_node"):
		return
	var node = _spawner.get_player_node(follower_id)
	if node:
		my_follower_nodes[follower_id] = node
		if node.has_method("get_display_name"):
			my_follower_names[follower_id] = node.get_display_name()

func _get_player_node(player_id: String) -> Node3D:
	"""获取任意玩家的节点"""
	if player_id == str(_network.player_id) if _network else "":
		return _local_player
	if player_id == my_leader_id:
		return my_leader_node
	if my_follower_nodes.has(player_id):
		return my_follower_nodes[player_id]
	if _spawner and _spawner.has_method("get_player_node"):
		return _spawner.get_player_node(player_id)
	return null

func _get_chain_length() -> int:
	"""估算当前链长"""
	var count = 1  # 自己
	var node_id = my_leader_id
	var visited = {}
	while node_id != "" and not visited.has(node_id) and count < max_chain_length:
		visited[node_id] = true
		count += 1
		var node = _get_player_node(node_id)
		if node and node.has_method("get_leader_id"):
			node_id = node.get_leader_id()
		else:
			break
	return count

# ==================== 状态查询 ====================

func is_holding() -> bool:
	return my_leader_id != "" or my_follower_ids.size() > 0

func is_leader() -> bool:
	"""我是绝对领队（没人牵我）"""
	return my_leader_id == "" and my_follower_ids.size() > 0

func is_follower() -> bool:
	"""我是跟随者（有人牵我）"""
	return my_leader_id != ""

func is_free() -> bool:
	"""自由状态"""
	return my_leader_id == "" and my_follower_ids.size() == 0

func get_follower_count() -> int:
	return my_follower_ids.size()

func get_chain_members() -> Array[String]:
	"""获取整个链条的所有成员ID（从最前到最后）"""
	var chain = []
	var visited = {}
	
	# 向前找到最前
	var front = my_leader_id
	var front_chain = []
	while front != "" and not visited.has(front) and front_chain.size() < max_chain_length:
		visited[front] = true
		front_chain.push_front(front)
		var node = _get_player_node(front)
		if node and node.has_method("get_leader_id"):
			front = node.get_leader_id()
		else:
			break
	
	chain.append_array(front_chain)
	chain.append(_network.player_id if _network else "local")
	visited[_network.player_id if _network else "local"] = true
	
	# 向后找跟随者（只跟第一条线）
	for fid in my_follower_ids:
		if not visited.has(fid) and chain.size() < max_chain_length:
			chain.append(fid)
			visited[fid] = true
	
	return chain

func get_nearby_free_players(max_distance: float = 10.0) -> Array[Dictionary]:
	"""获取附近可牵手的玩家"""
	if not _spawner or not _spawner.has_method("get_nearby_players"):
		return []
	
	var nearby = _spawner.get_nearby_players(max_distance)
	var result: Array[Dictionary] = []
	var my_id = str(_network.player_id) if _network else ""
	
	for p in nearby:
		if p.player_id == my_id:
			continue
		if p.player_id == my_leader_id:
			continue  # 已经是领队
		if my_follower_ids.has(p.player_id):
			continue  # 已经是跟随者
		result.append(p)
	
	return result
