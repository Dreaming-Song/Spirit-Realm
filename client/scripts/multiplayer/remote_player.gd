extends CharacterBody3D
## 远程玩家 — 其他玩家的视觉表示
##
## 由 PlayerSpawner 自动创建/销毁
## 定期从 NetworkManager 接收位置/状态更新

class_name RemotePlayer

signal interacted(remote_player: Node)  # 本地玩家与此玩家交互

# ==================== 显示 ====================
@onready var name_label: Label3D = $NameLabel
@onready var hp_bar: ProgressBar3D = $HpBar
@onready var chat_bubble: Label3D = $ChatBubble

# ==================== 同步数据 ====================
var remote_player_id: String = ""
var display_name: String = "道友"
var target_position: Vector3
var target_rotation: Vector3
var current_hp: int = 100
var max_hp: int = 100
var current_mp: int = 50
var max_mp: int = 50
var is_flying: bool = false
var is_in_water: bool = false    # 🌊 是否在水中
var is_talking: bool = false

# 插值
var _lerp_speed: float = 10.0

func _ready() -> void:
	add_to_group("remote_players")
	if name_label:
		name_label.text = display_name
	_update_hp_bar()

func _process(delta: float) -> void:
	# 位置插值（平滑移动）
	global_position = global_position.lerp(target_position, _lerp_speed * delta)
	# 旋转插值
	rotation = rotation.lerp(target_rotation, _lerp_speed * delta)

# ==================== 数据更新 ====================

func update_state(state: Dictionary) -> void:
	"""从 NetworkManager 接收状态更新"""
	target_position = Vector3(
		state.get("x", global_position.x),
		state.get("y", global_position.y),
		state.get("z", global_position.z)
	)
	target_rotation = Vector3(
		state.get("rot_x", 0),
		state.get("rot_y", 0),
		0
	)
	
	current_hp = state.get("hp", current_hp)
	max_hp = state.get("max_hp", max_hp)
	current_mp = state.get("mp", current_mp)
	max_hp = state.get("max_mp", max_hp)
	is_flying = state.get("is_flying", false)
	is_in_water = state.get("is_in_water", false)
	
	_update_hp_bar()

func set_display_name(name: String) -> void:
	display_name = name
	if name_label:
		name_label.text = name

func set_chat_text(text: String) -> void:
	"""显示聊天气泡（3秒后消失）"""
	if chat_bubble:
		chat_bubble.text = text
		chat_bubble.visible = true
		# 3秒后隐藏
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(chat_bubble):
			chat_bubble.visible = false

func _update_hp_bar() -> void:
	if hp_bar:
		hp_bar.value = float(current_hp) / float(max(max_hp, 1)) * 100.0

# ==================== 交互检测 ====================

func _on_area_entered(area: Area3D) -> void:
	"""检测本地玩家靠近"""
	var parent = area.get_parent()
	if parent and parent.is_in_group("player"):
		interacted.emit(self)

func get_leader_id() -> String:
	"""获取此远程玩家的领队ID（供 HandHoldManager 链式遍历）"""
	return ""

func get_display_name() -> String:
	return display_name

func get_interaction_info() -> Dictionary:
	return {
		"id": remote_player_id,
		"name": display_name,
		"node": self,
		"hp_ratio": float(current_hp) / max(max_hp, 1),
		"mp_ratio": float(current_mp) / max(max_mp, 1),
		"is_flying": is_flying,
		"is_in_water": is_in_water,
	}
