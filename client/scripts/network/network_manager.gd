extends Node
## 联机网络管理器 — 支持 ENet 主机直连（MC风格）和 WebSocket 集中式
##
## 主机直连（默认）：
##   1. 房主进入世界后，点击 Host → ENet 服务器启动
##   2. 其他玩家输入房主 IP:Port → 直接加入
##   3. 房主退出时自动保存世界并关闭服务器

class_name NetworkManager

signal connected()
signal disconnected(reason: String)
signal player_joined(player_id: int, player_name: String)
signal player_left(player_id: int, player_name: String)
signal player_state_received(player_id: int, state: Dictionary)
signal chat_received(player_id: int, message: String)
signal connection_error(message: String)

# ==================== 模式 ====================
enum Mode { NONE, HOST, CLIENT }

# ==================== 配置 ====================
@export var default_port: int = 4242
@export var max_players: int = 4

# ==================== 状态 ====================
var mode: int = Mode.NONE
var player_id: int = 0  # 本机玩家在 ENet 中的 ID
var player_name: String = "道友"
var is_connected: bool = false

func _ready() -> void:
	# 设置高级 API
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ==================== 主机 ====================

func host_game(port: int = default_port, max_clients: int = max_players) -> bool:
	"""创建主机（房主）"""
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, max_clients)
	if err != OK:
		connection_error.emit("创建主机失败: " + str(err))
		return false
	
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	player_id = 1  # 服务器默认 ID 为 1
	is_connected = true
	
	print("🏠 主机创建成功 (port=%d, max=%d)" % [port, max_clients])
	connected.emit()
	return true

# ==================== 加入 ====================

func join_game(ip: String, port: int = default_port) -> bool:
	"""加入主机"""
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		connection_error.emit("连接失败: " + str(err))
		return false
	
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	
	print("🔗 正在连接 %s:%d..." % [ip, port])
	return true

# ==================== 断开 ====================

func leave_game() -> void:
	"""离开游戏"""
	if mode == Mode.HOST:
		print("🏠 主机关闭")
		# 作为主机，通知所有客户端
		rpc("_on_server_shutdown")
	
	multiplayer.multiplayer_peer = null
	mode = Mode.NONE
	is_connected = false
	disconnected.emit("主动离开")

# ==================== ENet 回调 ====================

func _on_peer_connected(id: int) -> void:
	if mode == Mode.HOST:
		player_joined.emit(id, "玩家%d" % id)
		print("👤 玩家加入: ID=%d" % id)
		
		# 向新玩家发送世界信息
		_send_world_info.rpc_id(id)

func _on_peer_disconnected(id: int) -> void:
	player_left.emit(id, "")
	print("👋 玩家离开: ID=%d" % id)
	
	# 如果主机离开（不应该发生），但客户端检测到
	if mode == Mode.CLIENT and id == 1:
		is_connected = false
		disconnected.emit("主机断开连接")

func _on_connected_to_server() -> void:
	"""客户端成功连接主机"""
	mode = Mode.CLIENT
	player_id = multiplayer.get_unique_id()
	is_connected = true
	print("✅ 已连接到主机 (ID=%d)" % player_id)
	connected.emit()

func _on_connection_failed() -> void:
	connection_error.emit("无法连接到主机")
	print("❌ 连接失败")

func _on_server_disconnected() -> void:
	is_connected = false
	disconnected.emit("主机已关闭")
	print("🔌 主机断开连接")

# ==================== RPC: 世界同步 ====================

@rpc("any_peer", "reliable")
func _send_world_info() -> void:
	"""主机向新玩家发送世界信息"""
	var wm = get_node("/root/WorldManager")
	if wm:
		var info = wm.get_world_info(wm.current_world)
		# 发送世界种子等信息
		receive_world_info(info)

@rpc("any_peer", "reliable")
func receive_world_info(info: Dictionary) -> void:
	"""客户端接收世界信息"""
	print("📦 收到世界信息: " + str(info))
	# TODO: 根据世界种子加载地图

# ==================== RPC: 聊天 ====================

@rpc("any_peer", "unreliable", "call_local")
func send_chat(message: String) -> void:
	"""发送聊天消息"""
	var sender = multiplayer.get_remote_sender_id() if mode == Mode.HOST else 1
	if mode == Mode.HOST:
		# 主机转发给所有客户端
		rpc("receive_chat", sender, message)
	else:
		# 客户端发送给主机
		rpc_id(1, "receive_chat", multiplayer.get_unique_id(), message)
	receive_chat(multiplayer.get_unique_id(), message)

@rpc("any_peer", "unreliable")
func receive_chat(sender_id: int, message: String) -> void:
	"""接收聊天消息"""
	chat_received.emit(sender_id, message)

# ==================== RPC: 玩家状态同步 ====================

## 发送本地玩家状态（由 PlayerSpawner 调用）
func send_player_state(x: float, y: float, z: float, rot_x: float, rot_y: float, 
					   hp: float, mp: float, is_flying: bool, is_in_water: bool = false) -> void:
	var state = {
		"x": x, "y": y, "z": z,
		"rot_x": rot_x, "rot_y": rot_y,
		"hp": hp, "mp": mp,
		"is_flying": is_flying,
		"is_in_water": is_in_water
	}
	sync_player_state(state)

@rpc("any_peer", "unreliable")
func sync_player_state(state: Dictionary) -> void:
	"""同步玩家位置/状态"""
	var sender = multiplayer.get_remote_sender_id() if mode == Mode.HOST else multiplayer.get_unique_id()
	
	if mode == Mode.HOST:
		# 主机转发给其他客户端（不包括发送者）
		for pid in multiplayer.get_peers():
			if pid != sender:
				rpc_id(pid, "sync_player_state", state)
	
	player_state_received.emit(sender, state)

# ==================== RPC: 牵手 🤝 ====================

## 发送牵手请求
@rpc("any_peer", "reliable")
func send_hold_request(my_name: String) -> void:
	"""收到牵手请求"""
	var sender = multiplayer.get_remote_sender_id()
	var hhm = get_node("/root/HandHoldManager") if has_node("/root/HandHoldManager") else null
	if hhm:
		hhm._on_hold_request_received(str(sender), my_name)

## 接受牵手（发送方成为领队）
@rpc("any_peer", "reliable")
func send_hold_accept() -> void:
	"""对方接受牵手"""
	var sender = multiplayer.get_remote_sender_id()
	var hhm = get_node("/root/HandHoldManager") if has_node("/root/HandHoldManager") else null
	if hhm:
		hhm._on_hold_accepted(str(sender))

## 拒绝牵手
@rpc("any_peer", "reliable")
func send_hold_reject() -> void:
	"""对方拒绝牵手"""
	var sender = multiplayer.get_remote_sender_id()
	var hhm = get_node("/root/HandHoldManager") if has_node("/root/HandHoldManager") else null
	if hhm:
		hhm._on_hold_rejected(str(sender))

## 松开牵手
@rpc("any_peer", "reliable")
func send_hold_release() -> void:
	"""对方松开手"""
	var sender = multiplayer.get_remote_sender_id()
	var hhm = get_node("/root/HandHoldManager") if has_node("/root/HandHoldManager") else null
	if hhm:
		hhm._on_hold_released(str(sender))

# ==================== 工具 ====================

func get_player_list() -> Array[int]:
	"""获取当前所有在线玩家ID列表"""
	var peers = multiplayer.get_peers()
	var list: Array[int] = []
	list.append(1)  # 主机
	for p in peers:
		list.append(p)
	return list

func is_host() -> bool:
	return mode == Mode.HOST
