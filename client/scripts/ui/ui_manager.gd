extends CanvasLayer
## UI主管理器 — 管理所有界面面板的打开/关闭/切换
##
## 快捷键映射：
##   I — 背包
##   C — 修行/技能
##   B — 建造模式
##   TAB — 合成菜单
##   M — 地图
##   ESC — 暂停菜单
##   H — 帮助/教程

class_name UIManager

# ==================== 面板引用 ====================
@onready var hud: Control = $HUD
@onready var inventory_panel: Control = $InventoryPanel
@onready var crafting_panel: Control = $CraftingPanel
@onready var cultivation_panel: Control = $CultivationPanel
@onready var building_panel: Control = $BuildingPanel if has_node("BuildingPanel") else _create_building_panel()
@onready var building_mode: Node = null  # 由 _ready 从 PlayerController 获取引用
@onready var map_panel: Control = $MapPanel
@onready var pause_menu: Control = $PauseMenu
@onready var settings_panel: Control = $SettingsPanel if has_node("SettingsPanel") else _create_settings_panel()
@onready var help_panel: Control = $HelpPanel
@onready var dialog_panel: Control = $DialogPanel
@onready var dialogue_panel_script: Node = $DialoguePanel if has_node("DialoguePanel") else _create_dialogue_panel()
@onready var chat_panel: Control = $ChatPanel if has_node("ChatPanel") else _create_chat_panel()
@onready var player_interaction_menu: Control = $PlayerInteractionMenu if has_node("PlayerInteractionMenu") else _create_interaction_menu()
@onready var emote_wheel: Control = $EmoteWheel if has_node("EmoteWheel") else _create_emote_wheel()
@onready var block_selector: Control = $BlockSelector if has_node("BlockSelector") else _create_block_selector()

# ==================== 打开面板 ====================
var _open_panels: Array[String] = []  # 已打开的面板名栈

# ==================== 信号 ====================
signal panel_opened(panel_name: String)
signal panel_closed(panel_name: String)

func _ready() -> void:
	# 默认隐藏所有面板
	_close_all()
	if settings_panel:
		settings_panel.visible = false
		settings_panel.back_pressed.connect(_on_settings_back)
	if dialogue_panel_script:
		dialogue_panel_script.visible = false
		dialogue_panel_script.dialogue_ended.connect(_on_dialogue_ended)
	if chat_panel:
		chat_panel.visible = false
	if player_interaction_menu:
		player_interaction_menu.visible = false
	if emote_wheel:
		emote_wheel.visible = false
	
	# 获取建造模式引用（由 PlayerController 创建）
	var player = get_node("/root/GameManager/Player") if has_node("/root/GameManager/Player") else null
	if player and player.has_node("BuildingMode"):
		building_mode = player.get_node("BuildingMode")
	
	# 创建建造模式 HUD（覆盖层，显示当前方块 + 破坏进度）
	_create_building_hud()

## 🔧 动态创建设置面板（无需场景预制体）
## 创建最小建造面板（降级方案 — MC风格下几乎不用）
func _create_building_panel() -> Control:
	var panel = Panel.new()
	panel.name = "BuildingPanel"
	panel.visible = false
	panel.size = Vector2(400, 300)
	panel.position = Vector2(200, 200)
	add_child(panel)
	return panel

## 创建建造模式 HUD 覆盖层
func _create_building_hud() -> void:
	var hud = preload("res://scripts/ui/building_hud.gd").new()
	hud.name = "BuildingHUD"
	hud.visible = false
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)

## 创建方块选择器面板
func _create_block_selector() -> Control:
	var selector = preload("res://scripts/ui/block_selector.gd").new()
	selector.name = "BlockSelector"
	selector.visible = false
	selector.block_selected.connect(_on_block_selected)
	selector.selector_closed.connect(_on_selector_closed)
	add_child(selector)
	return selector

func _create_settings_panel() -> Control:
	var panel = preload("res://scripts/ui/settings_panel.gd").new()
	panel.name = "SettingsPanel"
	panel.visible = false
	add_child(panel)
	return panel

func _input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	
	# 快捷键
	if Input.is_action_just_pressed("ui_cancel"):   # ESC
		_toggle_pause()
	elif Input.is_action_just_pressed("toggle_inventory"):  # I / LB
		toggle_panel("inventory")
	elif Input.is_action_just_pressed("toggle_crafting"):   # TAB / RB
		toggle_panel("crafting")
	elif Input.is_action_just_pressed("toggle_cultivation"): # C / Back
		toggle_panel("cultivation")
	elif Input.is_action_just_pressed("toggle_building"):   # B / Start
		_handle_building_toggle()
	elif Input.is_action_just_pressed("toggle_map"):        # M
		toggle_panel("map")
	elif Input.is_action_just_pressed("toggle_help"):       # H
		toggle_panel("help")
	
	# 🔧 手柄 D-pad / B 键导航面板
	if event is InputEventJoypadButton:
		match event.button_index:
			JOY_BUTTON_DPAD_UP:
				_navigate_focus(FOCUS_UP)
			JOY_BUTTON_DPAD_DOWN:
				_navigate_focus(FOCUS_DOWN)
			JOY_BUTTON_DPAD_LEFT:
				_navigate_focus(FOCUS_LEFT)
			JOY_BUTTON_DPAD_RIGHT:
				_navigate_focus(FOCUS_RIGHT)
			JOY_BUTTON_B:  # B 键关闭面板
				if _open_panels.size() > 0:
					var last = _open_panels.back()
					close_panel(last)

# ==================== 面板开关 ====================

func toggle_panel(panel_name: String) -> void:
	if panel_name in _open_panels:
		close_panel(panel_name)
	else:
		open_panel(panel_name)

func open_panel(panel_name: String) -> void:
	match panel_name:
		"inventory":
			_hide_all_except("inventory")
			inventory_panel.visible = true
			_inventory_show()
			
		"crafting":
			_hide_all_except("crafting")
			crafting_panel.visible = true
			_crafting_show()
			
		"cultivation":
			_hide_all_except("cultivation")
			cultivation_panel.visible = true
			_cultivation_show()
			
		"building":
			_hide_all_except("building")
			building_panel.visible = true
			_building_show()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
		"map":
			_hide_all_except("map")
			map_panel.visible = true
			_map_show()
			
		"pause":
			pause_menu.visible = true
			
		"settings":
			_hide_all_except("settings")
			settings_panel.visible = true
			settings_panel._load_current_values()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
		"help":
			help_panel.visible = true
			
		"dialog":
			dialog_panel.visible = true
	
	if not panel_name in _open_panels:
		_open_panels.append(panel_name)
	panel_opened.emit(panel_name)
	
	# 打开面板时显示鼠标
	if _open_panels.size() > 0:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_panel(panel_name: String) -> void:
	match panel_name:
		"inventory":
			inventory_panel.visible = false
		"crafting":
			crafting_panel.visible = false
		"cultivation":
			cultivation_panel.visible = false
		"building":
			building_panel.visible = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		"map":
			map_panel.visible = false
		"pause":
			pause_menu.visible = false
		"settings":
			settings_panel.visible = false
			# 如果是从暂停菜单进来的，回去
			if "pause" in _open_panels:
				pause_menu.visible = true
		"help":
			help_panel.visible = false
		"dialog":
			dialog_panel.visible = false
		"dialogue":
			dialogue_panel_script.visible = false
	
	_open_panels.erase(panel_name)
	panel_closed.emit(panel_name)
	
	# 没有面板打开时隐藏鼠标
	if _open_panels.is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _close_all() -> void:
	for panel in _open_panels.duplicate():
		close_panel(panel)
	
	inventory_panel.visible = false
	crafting_panel.visible = false
	cultivation_panel.visible = false
	building_panel.visible = false
	map_panel.visible = false
	pause_menu.visible = false
	settings_panel.visible = false
	help_panel.visible = false
	dialog_panel.visible = false
	dialogue_panel_script.visible = false
	if chat_panel:
		chat_panel.visible = false
	if player_interaction_menu:
		player_interaction_menu.visible = false
	if emote_wheel:
		emote_wheel.visible = false

## 是否有面板打开（供外部查询，如 BuildingMode 退出时决定鼠标模式）
func is_any_panel_open() -> bool:
	return not _open_panels.is_empty()

func _hide_all_except(keep: String) -> void:
	for panel in _open_panels.duplicate():
		if panel != keep:
			close_panel(panel)

func _toggle_pause() -> void:
	# 如果当前在设置面板，先关设置
	if "settings" in _open_panels:
		close_panel("settings")
		return
	
	if "pause" in _open_panels:
		close_panel("pause")
		var gm = get_node("/root/GameManager")
		if gm:
			gm.toggle_pause()
	else:
		open_panel("pause")
		var gm = get_node("/root/GameManager")
		if gm:
			gm.toggle_pause()

# ==================== 设置面板 ====================

func open_settings() -> void:
	"""从暂停菜单打开设置面板"""
	if "pause" in _open_panels:
		pause_menu.visible = false
	settings_panel.visible = true
	settings_panel._load_current_values()
	if not "settings" in _open_panels:
		_open_panels.append("settings")
	panel_opened.emit("settings")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_settings() -> void:
	"""关闭设置面板"""
	settings_panel.visible = false
	_open_panels.erase("settings")
	panel_closed.emit("settings")
	# 回到暂停菜单
	if "pause" in _open_panels:
		pause_menu.visible = true
	if _open_panels.is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_settings_back() -> void:
	close_settings()

# ==================== 面板数据刷新 ====================

func _inventory_show() -> void:
	"""刷新背包面板"""
	var gm = get_node("/root/GameManager")
	if not gm or not gm.inventory:
		return
	
	# 更新格子
	var slots = gm.inventory.get_all_slots()
	var slot_container = inventory_panel.get_node("GridContainer")
	_clear_grid(slot_container)
	
	for i in range(slots.size()):
		var slot = slots[i]
		var slot_btn = _create_slot_button(i, slot)
		slot_container.add_child(slot_btn)
	
	# 更新装备
	var equip = gm.inventory.get_equipment()
	for slot_name in equip.keys():
		var equip_slot = inventory_panel.get_node("EquipSlots/%s" % slot_name)
		if equip_slot:
			var item = ItemDatabase.get_item(equip[slot_name])
			equip_slot.text = item.get("name", "")

func _crafting_show() -> void:
	"""刷新合成面板 — DST/Terraria风格：靠近工作站自动过滤"""
	# 使用 CraftingPanel 脚本（如果有）
	if crafting_panel.has_method("refresh"):
		crafting_panel.refresh()
		return
	
	# 降级：旧版刷新（如果新脚本未生效）
	var gm = get_node("/root/GameManager")
	if not gm:
		return
	
	var available = gm.crafting.get_available_recipes()
	var container = crafting_panel.get_node("RecipeList")
	_clear_container(container)
	
	# DST风格：按工作站分组显示
	var nearby = gm.crafting.get_nearby_stations() if gm.crafting.has_method("get_nearby_stations") else []
	
	for station in available.keys():
		# 标记附近工作站
		var station_display = station
		if station in nearby:
			station_display = "📍 " + station
		elif station.is_empty():
			station_display = "✋ 徒手"
		else:
			station_display = "🔒 " + station + " (远离)"
		
		var section = Label.new()
		section.text = "▶ %s" % station_display
		section.add_theme_font_size_override("font_size", 18)
		container.add_child(section)
		
		for recipe in available[station]:
			var btn = Button.new()
			btn.text = "%s — %s" % [recipe.data.name, _format_materials(recipe.data.materials)]
			btn.pressed.connect(_on_craft_btn.bind(recipe.id))
			container.add_child(btn)

func _cultivation_show() -> void:
	"""刷新修行面板"""
	var gm = get_node("/root/GameManager")
	if not gm:
		return
	
	var overview = gm.cultivation.get_school_overview()
	var container = cultivation_panel.get_node("SchoolList")
	_clear_container(container)
	
	for school in overview:
		var frame = VBoxContainer.new()
		
		var name_label = Label.new()
		var spec_mark = "★ " if school.is_specialized else ""
		name_label.text = "%s%s (Lv.%d %s) [%s]" % [
			spec_mark, school.name, school.level, school.mastery, school.element
		]
		frame.add_child(name_label)
		
		var skills_label = Label.new()
		skills_label.text = "  技能: %d/%d" % [school.skills_count, school.total_skills]
		frame.add_child(skills_label)
		
		# 加点按钮
		if gm.cultivation.cultivation_points > 0:
			var invest_btn = Button.new()
			invest_btn.text = "投入1点 (+%d)" % gm.cultivation.cultivation_points
			invest_btn.pressed.connect(_on_invest_btn.bind(school.type))
			frame.add_child(invest_btn)
		
		container.add_child(frame)

## 处理 B 键 — MC 风格建造模式 vs 传统面板
func _handle_building_toggle() -> void:
	# 如果方块选择器开着，先关掉
	if block_selector and block_selector.visible:
		block_selector.close()
		return
	
	# 第一优先：使用 BuildingMode（MC风格区块建造）
	if building_mode and building_mode.has_method("toggle_building_mode"):
		if building_mode.is_building_mode:
			# 退出建造模式 → 隐藏预览，恢复输入
			building_mode._exit_building_mode()
			if "building" in _open_panels:
				_open_panels.erase("building")
		else:
			# 进入建造模式
			var player = get_node("/root/GameManager/Player") if has_node("/root/GameManager/Player") else null
			var camera = player.get_node("Camera3D") if player and player.has_node("Camera3D") else null
			if player and camera:
				building_mode._enter_building_mode(player, camera)
				_hide_all_except("")
				_open_panels.append("building")
				
				# 如果背包里没有自动选中方块，打开选择器
				var selected = building_mode.get_selected_info()
				if selected.get("item_id", "").is_empty():
					_open_block_selector()
		return
	
	# 降级：使用传统建筑面板（UI列表式）
	toggle_panel("building")

## 打开方块选择器
func _open_block_selector() -> void:
	if not block_selector:
		return
	var player = get_node("/root/GameManager/Player") if has_node("/root/GameManager/Player") else null
	var inventory = get_node("/root/GameManager/Inventory") if has_node("/root/GameManager/Inventory") else null
	var building_sys = get_node("/root/GameManager/BuildingSystem") if has_node("/root/GameManager/BuildingSystem") else null
	if player and inventory and building_sys and building_mode:
		block_selector.open(player, inventory, building_sys, building_mode)

func _on_block_selected(piece_type: int, item_id: String, tier: int) -> void:
	"""方块选择器选中方块后的处理"""
	pass  # BuildingMode 已经通过 block_selected 信号处理了

func _on_selector_closed() -> void:
	"""方块选择器关闭后的处理"""
	# 如果建造模式是活跃的，恢复鼠标模式
	if building_mode and building_mode.is_building_mode:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _building_show() -> void:
	"""刷新建造面板"""
	var gm = get_node("/root/GameManager")
	if not gm:
		return
	
	var tier = gm.realm.get_build_tier()
	var tier_info = BuildingSystem.get_tier_data(tier)
	
	var info_label = building_panel.get_node("Info")
	if info_label:
		info_label.text = "当前可建: %s (HP: %d)" % [tier_info.name, tier_info.hp]

func _map_show() -> void:
	"""刷新地图面板"""
	var gm = get_node("/root/GameManager")
	if not gm:
		return
	
	var world = gm.world_data
	var spawn = world.get("spawn_point", Vector3.ZERO)
	
	var map_label = map_panel.get_node("Info")
	if map_label:
		map_label.text = "世界种子: %d\n出生点: (%d, %d, %d)" % [
			gm.map_gen.world_seed,
			int(spawn.x), int(spawn.y), int(spawn.z)
		]

# ==================== UI交互回调 ====================

func _on_craft_btn(recipe_id: String) -> void:
	var gm = get_node("/root/GameManager")
	if gm:
		var result = gm.craft_item(recipe_id)
		if result.get("success", false):
			# 刷新合成面板
			_crafting_show()
		else:
			_show_message(result.get("reason", "合成失败"))

func _on_invest_btn(school_type: int) -> void:
	var gm = get_node("/root/GameManager")
	if gm and gm.invest_cultivation(school_type, 1):
		_cultivation_show()

# ==================== 消息提示 ====================

var _message_timer: float = 0.0

func _show_message(text: String) -> void:
	var msg_label = $MessageLabel
	if msg_label:
		msg_label.text = text
		msg_label.visible = true
		_message_timer = 3.0

func _process(delta: float) -> void:
	if _message_timer > 0:
		_message_timer -= delta
		if _message_timer <= 0:
			var msg_label = $MessageLabel
			if msg_label:
				msg_label.visible = false

# ==================== 工具方法 ====================

func _format_materials(materials: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id in materials.keys():
		parts.append("%s ×%d" % [ItemDatabase.get_item_name(item_id), materials[item_id]])
	return ", ".join(parts)

func _clear_grid(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()

## 聚焦指定工作站（由 WorkstationStation 调用）
func focus_station(station_type: int) -> void:
	var station_id = WorkstationStation.STATION_NAMES.get(station_type, "workbench")
	
	# 如果合成面板已打开，刷新
	if "crafting" in _open_panels:
		if crafting_panel.has_method("refresh"):
			crafting_panel.refresh(station_id)
	else:
		# 打开合成面板并聚焦
		open_panel("crafting")
		if crafting_panel.has_method("refresh"):
			crafting_panel.refresh(station_id)
	
	print("🔬 聚焦工作站: %s" % WorkstationStation.STATION_DISPLAY_NAMES.get(station_type, "未知"))

func _clear_container(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()

func _create_slot_button(index: int, slot: Dictionary) -> Button:
	var btn = Button.new()
	if not slot.item_id.is_empty() and slot.count > 0:
		var item = ItemDatabase.get_item(slot.item_id)
		var durability_text = ""
		if slot.durability > 0 and item.has("durability"):
			durability_text = " [%d/%d]" % [slot.durability, item.durability]
		btn.text = "%s ×%d%s" % [item.get("name", slot.item_id), slot.count, durability_text]
		btn.tooltip_text = item.get("desc", "")
	else:
		btn.text = ""
	btn.custom_minimum_size = Vector2(100, 50)
	return btn

# ==================== 手柄导航 ====================

func _navigate_focus(direction: int) -> void:
	"""手柄 D-pad 焦点导航"""
	var focused = get_viewport().gui_get_focus_owner()
	if not focused or not focused.is_inside_tree():
		# 没有焦点，自动聚焦到第一个可聚焦的子节点
		if _open_panels.size() > 0:
			var panel_name = _open_panels.back()
			var panel = get(panel_name + "_panel")
			if panel:
				var first = _find_first_focusable(panel)
				if first:
					first.grab_focus()
		return
	
	var next: Control = null
	match direction:
		FOCUS_DOWN:
			next = focused.find_next_valid_focus()
		FOCUS_UP:
			next = focused.find_prev_valid_focus()
		FOCUS_LEFT:
			next = focused.find_prev_valid_focus()
		FOCUS_RIGHT:
			next = focused.find_next_valid_focus()
	
	if next and next is Control and next.can_focus():
		next.grab_focus()

func _find_first_focusable(parent: Node) -> Control:
	"""递归查找第一个可聚焦的子节点"""
	for child in parent.get_children():
		if child is Control:
			if child.can_focus() and child.visible:
				return child
			var found = _find_first_focusable(child)
			if found:
				return found
	return null

func open_dialogue(npc: Node) -> void:
	"""打开对话面板"""
	# 关闭其他面板
	_hide_all_except("dialogue")
	dialogue_panel_script.visible = true
	dialogue_panel_script.start_dialogue(npc)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if not "dialogue" in _open_panels:
		_open_panels.append("dialogue")

func _on_dialogue_ended() -> void:
	_open_panels.erase("dialogue")
	if _open_panels.is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _create_dialogue_panel() -> Control:
	var panel = preload("res://scripts/ui/dialogue_panel.gd").new()
	panel.name = "DialoguePanel"
	panel.visible = false
	add_child(panel)
	return panel

## 🔧 创建聊天面板
func _create_chat_panel() -> Control:
	var panel = preload("res://scripts/ui/chat_panel.gd").new()
	panel.name = "ChatPanel"
	add_child(panel)
	if panel.has_signal("message_sent"):
		panel.message_sent.connect(_on_chat_message_sent)
	return panel

## 🔧 创建玩家交互菜单
func _create_interaction_menu() -> Control:
	var menu = preload("res://scripts/ui/player_interaction_menu.gd").new()
	menu.name = "PlayerInteractionMenu"
	add_child(menu)
	if menu.has_signal("action_selected"):
		menu.action_selected.connect(_on_player_action_selected)
	return menu

## 🔧 创建表情轮盘
func _create_emote_wheel() -> Control:
	var wheel = preload("res://scripts/ui/emote_wheel.gd").new()
	wheel.name = "EmoteWheel"
	add_child(wheel)
	if wheel.has_signal("emote_selected"):
		wheel.emote_selected.connect(_on_emote_selected)
	return wheel

## 🔧 聊天消息发送回调
func _on_chat_message_sent(message: String) -> void:
	print("💬 聊天: %s" % message)

## 🔧 玩家交互菜单操作回调
func _on_player_action_selected(player_id: String, action: String) -> void:
	"""玩家交互菜单操作"""
	print("🎮 玩家操作: %s → %s" % [action, player_id])
	var spawner = get_node("/root/PlayerSpawner") if has_node("/root/PlayerSpawner") else null
	if spawner and spawner.has_method("interact_with_player"):
		spawner.interact_with_player(player_id, action)

## 🔧 表情轮盘选择回调
func _on_emote_selected(emote_name: String) -> void:
	"""表情动作选择"""
	print("😊 表情: %s" % emote_name)
	var spawner = get_node("/root/PlayerSpawner") if has_node("/root/PlayerSpawner") else null
	if spawner and spawner.has_method("interact_with_player"):
		# 发送表情到所有附近的玩家
		spawner.interact_with_player("", "emote_" + emote_name)

## 🔧 L7: 检查是否有面板打开（供 PlayerController 判断输入阻断）
func is_any_panel_open() -> bool:
	return _open_panels.size() > 0
