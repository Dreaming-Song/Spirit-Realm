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
@onready var building_panel: Control = $BuildingPanel
@onready var map_panel: Control = $MapPanel
@onready var pause_menu: Control = $PauseMenu
@onready var help_panel: Control = $HelpPanel
@onready var dialog_panel: Control = $DialogPanel

# ==================== 打开面板 ====================
var _open_panels: Array[String] = []  # 已打开的面板名栈

# ==================== 信号 ====================
signal panel_opened(panel_name: String)
signal panel_closed(panel_name: String)

func _ready() -> void:
	# 默认隐藏所有面板
	_close_all()

func _input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	
	# 快捷键
	if Input.is_action_just_pressed("ui_cancel"):   # ESC
		_toggle_pause()
	elif Input.is_action_just_pressed("toggle_inventory"):  # I
		toggle_panel("inventory")
	elif Input.is_action_just_pressed("toggle_crafting"):   # TAB
		toggle_panel("crafting")
	elif Input.is_action_just_pressed("toggle_cultivation"): # C
		toggle_panel("cultivation")
	elif Input.is_action_just_pressed("toggle_building"):   # B
		toggle_panel("building")
	elif Input.is_action_just_pressed("toggle_map"):        # M
		toggle_panel("map")
	elif Input.is_action_just_pressed("toggle_help"):       # H
		toggle_panel("help")

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
		"help":
			help_panel.visible = false
		"dialog":
			dialog_panel.visible = false
	
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
	help_panel.visible = false
	dialog_panel.visible = false

func _hide_all_except(keep: String) -> void:
	for panel in _open_panels.duplicate():
		if panel != keep:
			close_panel(panel)

func _toggle_pause() -> void:
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
	"""刷新合成面板"""
	var gm = get_node("/root/GameManager")
	if not gm:
		return
	
	var available = gm.crafting.get_available_recipes()
	var container = crafting_panel.get_node("RecipeList")
	_clear_container(container)
	
	for station in available.keys():
		# 合成台分栏
		var section = Label.new()
		section.text = "【%s】" % station
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
		if result.success:
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
	btn.custom_minimum_size = Vector2(80, 40)
	return btn
