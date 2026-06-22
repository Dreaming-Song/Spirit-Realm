extends PopupMenu
## 玩家交互菜单 — 右键/靠近其他玩家时弹出
##
## 选项：交易、组队邀请、关注、表情互动

class_name PlayerInteractionMenu

signal action_selected(target_player_id: String, action: String)

var _target_player_id: String = ""

func _ready() -> void:
	hide()
	
	# 构建菜单
	add_icon_item(null, "🤝 牵手同行", 0)
	add_icon_item(null, "🔗 松开手", 1)
	add_separator()
	add_icon_item(null, "🤝 交易请求", 2)
	add_icon_item(null, "👥 组队邀请", 3)
	add_icon_item(null, "👋 挥手", 4)
	add_icon_item(null, "🙏 作揖", 5)
	add_icon_item(null, "💃 跳舞", 6)
	add_separator()
	add_icon_item(null, "📋 查看信息", 7)
	add_icon_item(null, "🚫 屏蔽玩家", 8)
	
	# 连接选择
	id_pressed.connect(_on_item_selected)

func show_for_player(player_id: String, screen_pos: Vector2) -> void:
	"""在屏幕位置显示交互菜单"""
	_target_player_id = player_id
	
	# 动态更新牵手选项：如果已牵手则显示松开
	var hhm = get_node("/root/HandHoldManager") if has_node("/root/HandHoldManager") else null
	if hhm and hhm.is_holding() and hhm.partner_id == player_id:
		set_item_text(0, "🔗 松开手")
		set_item_disabled(0, false)
		set_item_text(1, "👋 切换为领队")  # 选项2 变成切换
	else:
		set_item_text(0, "🤝 牵手同行")
		set_item_disabled(0, false)
		set_item_text(1, "🔗 松开手")  # 没牵手时禁用
		set_item_disabled(1, true)
	
	position = screen_pos
	popup()
	grab_focus()

func _on_item_selected(id: int) -> void:
	"""菜单项被选择"""
	var actions = ["hold_hand", "release_hand", "trade", "party_invite", 
				   "emote_wave", "emote_bow", "emote_dance", "inspect", "block"]
	if id >= 0 and id < actions.size():
		action_selected.emit(_target_player_id, actions[id])
	hide()
