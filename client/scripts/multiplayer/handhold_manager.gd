extends Node
## 🤝 牵手系统 — 好友间手牵手一起走！
##
## 功能：
##   1. 向附近玩家发送牵手请求
##   2. 对方同意后，两人被一条灵力丝线连接
##   3. 发起者（领队）移动时，跟随者自动跟随
##   4. 距离过远或按动作键可松开
##
## 使用方式：
##   HandHoldManager.request_hold(target_id)
##   HandHoldManager.accept_hold(sender_id)
##   HandHoldManager.release_hold()
##
## 视觉特效：
##   - 灵力光链连接两人
##   - 指尖粒子特效
##   - 心形飘浮动画（彩蛋）

class_name HandHoldManager

signal hold_requested(from_id: String, from_name: String)    # 收到牵手请求
signal hold_accepted(from_id: String)                         # 对方接受了
signal hold_rejected(from_id: String)                         # 对方拒绝了
signal hold_started(leader_id: String, follower_id: String)  # 牵手成功
signal hold_ended(reason: String)                            # 牵手断开

# ==================== 状态 ====================s
enum HoldState { IDLE, REQUESTING, HOLDING_LEADER, HOLDING_FOLLOWER }

var state: int = HoldState.IDLE
var partner_id: String = ""          # 对方的玩家ID
var partner_name: String = ""        # 对方的昵称
var partner_node: Node3D = null      # 对方的 RemotePlayer 节点

# ==================== 配置 ====================
var max_hold_distance: float = 20.0  # 超过这个距离自动断开
var follow_smoothness: float = 8.0   # 跟随插值速度
var hold_break_timeout: float = 3.0  # 超出距离几秒后断开

# ==================== 节点引用 ====================
var _network: Node = null
var _spawner: Node = null
var _local_player: Node3D = null
var _break_timer: float = 0.0

# ==================== 视觉特效 ====================
var _thread_node: MeshInstance3D = null  # 灵力光链
var _particle_left: Node3D = null        # 左手粒子
var _particle_right: Node3D = null       # 右手粒子

func _ready() -> void:
	# 自注册到 /root 下（兼容未配置 AutoLoad 的情况）
	if not get_node("/root/HandHoldManager"):
		var root = get_tree().root
		if root and not root.has_node("HandHoldManager"):
			root.add_child(self)
			print("🤝 HandHoldManager 已自注册到场景根")
	
	_network = get_node("/root/NetworkManager") if has_node("/root/NetworkManager") else null
	_spawner = get_node("/root/PlayerSpawner") if has_node("/root/PlayerSpawner") else null
	_local_player = get_tree().get_first_node_in_group("player")
	
	# 创建光链网格
	_thread_node = MeshInstance3D.new()
	_thread_node.name = "HandHoldThread"
	_thread_node.mesh = CylinderMesh.new()
	_thread_node.mesh.top_radius = 0.03
	_thread_node.mesh.bottom_radius = 0.03
	_thread_node.mesh.height = 1.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.8, 0.7)
	mat.emission = Color(1.0, 0.4, 0.6)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_thread_node.mesh.material = mat
	_thread_node.visible = false
	add_child(_thread_node)

func _process(delta: float) -> void:
	if state == HoldState.IDLE:
		return
	
	# 检查距离
	_check_distance(delta)
	
	# 更新光链
	_update_thread(delta)
	
	# 如果我是跟随者，平滑跟随领队
	if state == HoldState.HOLDING_FOLLOWER and partner_node and _local_player:
		var target = partner_node.global_position
		# 跟随在领队身后约 1.5 单位
		var behind = partner_node.global_transform.basis.z * 1.5
		var follow_pos = target - behind + Vector3(0, 0, 0)
		follow_pos.y = _local_player.global_position.y  # 保持高度
		
		_local_player.global_position = _local_player.global_position.lerp(
			follow_pos, follow_smoothness * delta
		)

# ==================== 接口 ====================

## 发起牵手请求（由本地玩家调用）
func request_hold(target_id: String, target_name: String) -> bool:
	if state != HoldState.IDLE:
		print("⚠️ 已在牵手状态中，不能发起新请求")
		return false
	
	if not _network or not _network.is_connected:
		print("⚠️ 未连接网络")
		return false
	
	state = HoldState.REQUESTING
	partner_id = target_id
	partner_name = target_name
	
	# 发送牵手请求 RPC
	_network.send_hold_request.rpc_id(int(target_id), _network.player_name)
	print("🤝 已向 %s 发送牵手请求" % target_name)
	return true

## 接受牵手请求（对方同意了）
func accept_hold(sender_id: String) -> void:
	state = HoldState.HOLDING_FOLLOWER
	partner_id = sender_id
	
	# 获取对方节点
	_find_partner_node()
	
	if _network:
		_network.send_hold_accept.rpc_id(int(sender_id))
	
	hold_started.emit(sender_id, _network.player_id if _network else "local")
	print("🤝 接受牵手！")
	_show_hold_vfx()

## 拒绝牵手请求
func reject_hold(sender_id: String) -> void:
	if _network:
		_network.send_hold_reject.rpc_id(int(sender_id))
	state = HoldState.IDLE
	partner_id = ""
	hold_rejected.emit(sender_id)
	print("🙅 拒绝牵手")

## 松开手
func release_hold(reason: String = "主动松开") -> void:
	if state == HoldState.IDLE:
		return
	
	# 通知对方
	if _network and _network.is_connected:
		_network.send_hold_release.rpc(int(partner_id))
	
	_cleanup_hold()
	hold_ended.emit(reason)
	print("👋 牵手已松开: %s" % reason)

# ==================== RPC 回调（由 NetworkManager 调用） ====================

## 收到别人的牵手请求
func _on_hold_request_received(from_id: String, from_name: String) -> void:
	hold_requested.emit(from_id, from_name)
	# 弹出接受/拒绝 UI（由 UI 层处理）
	print("📩 收到 %s 的牵手请求" % from_name)

## 对方接受了我的请求 → 我成为领队
func _on_hold_accepted(follower_id: String) -> void:
	state = HoldState.HOLDING_LEADER
	partner_id = follower_id
	_find_partner_node()
	
	hold_started.emit(_network.player_id if _network else "local", follower_id)
	print("✅ %s 接受了牵手！（我领队）" % partner_name)
	_show_hold_vfx()

## 对方拒绝了我的请求
func _on_hold_rejected(from_id: String) -> void:
	state = HoldState.IDLE
	partner_id = ""
	hold_rejected.emit(from_id)
	print("😅 %s 拒绝了牵手" % partner_name)

## 对方松手了
func _on_hold_released(from_id: String) -> void:
	_cleanup_hold()
	hold_ended.emit("对方松手")
	print("👋 对方松开了手")

# ==================== 内部方法 ====================

func _find_partner_node() -> void:
	"""根据 partner_id 查找对应的 RemotePlayer 节点"""
	if not _spawner:
		return
	# PlayerSpawner 里维护了 _players 字典
	if _spawner.has_method("get_player_node"):
		partner_node = _spawner.get_player_node(partner_id)
	elif _spawner.get("_players"):
		var players = _spawner.get("_players")
		if players.has(partner_id):
			partner_node = players[partner_id]

func _check_distance(delta: float) -> void:
	"""检查并处理超距断连"""
	if not partner_node or not _local_player:
		return
	
	var dist = _local_player.global_position.distance_to(partner_node.global_position)
	
	if dist > max_hold_distance:
		_break_timer += delta
		if _break_timer >= hold_break_timeout:
			release_hold("距离过远")
	else:
		_break_timer = 0.0

func _update_thread(delta: float) -> void:
	"""更新灵力光链的位置/旋转/缩放"""
	if state == HoldState.IDLE or not partner_node or not _local_player:
		_thread_node.visible = false
		return
	
	_thread_node.visible = true
	
	var start = _local_player.global_position + Vector3(0, 1.2, 0)  # 手的位置
	var end = partner_node.global_position + Vector3(0, 1.2, 0)
	var mid = (start + end) / 2.0
	var dist = start.distance_to(end)
	
	# 计算方向和长度
	var dir = (end - start).normalized()
	_thread_node.global_position = mid
	_thread_node.look_at(end, Vector3.UP)
	_thread_node.mesh.height = dist
	_thread_node.mesh.top_radius = 0.03 + sin(Time.get_ticks_msec() * 0.005) * 0.01  # 脉动效果
	_thread_node.mesh.bottom_radius = _thread_node.mesh.top_radius

func _show_hold_vfx() -> void:
	"""牵手成功时的特效提示"""
	_thread_node.visible = true
	
	# 可以在这里创建心形粒子爆裂效果
	if _local_player and _local_player.has_method("spawn_particles"):
		_local_player.spawn_particles("heart_burst", _local_player.global_position + Vector3(0, 1.5, 0))

func _cleanup_hold() -> void:
	"""清理牵手状态"""
	state = HoldState.IDLE
	partner_id = ""
	partner_name = ""
	partner_node = null
	_thread_node.visible = false
	_break_timer = 0.0

## 获取附近可牵手的玩家列表
func get_holdable_players() -> Array[Dictionary]:
	"""获取附近可以发起牵手请求的玩家"""
	if not _spawner or not _spawner.has_method("get_nearby_players"):
		return []
	
	var nearby = _spawner.get_nearby_players(10.0)
	var result: Array[Dictionary] = []
	
	for p in nearby:
		if state != HoldState.IDLE and p.player_id == partner_id:
			continue  # 已牵手的不重复显示
		if p.player_id == str(_network.player_id) if _network else "":
			continue  # 排除自己
		result.append(p)
	
	return result

## 是否为牵手领队
func is_leader() -> bool:
	return state == HoldState.HOLDING_LEADER

## 是否为跟随者
func is_follower() -> bool:
	return state == HoldState.HOLDING_FOLLOWER

## 是否正在牵手
func is_holding() -> bool:
	return state == HoldState.HOLDING_LEADER or state == HoldState.HOLDING_FOLLOWER
