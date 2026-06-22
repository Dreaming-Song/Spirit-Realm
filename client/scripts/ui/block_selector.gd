extends Control
## 方块选择器 — MC 风格的建造选块面板
##
## 显示所有可用方块，按阶位分类（茅草/木/石/灵/玉晶）
## 点击选择后自动退出面板，进入放置状态
## 按 B / ESC / 右键空白处 关闭

class_name BlockSelector

# ==================== 信号 ====================
signal block_selected(piece_type: int, item_id: String, tier: int)
signal selector_closed()

# ==================== 引用 ====================
var _player: Node3D
var _inventory: Node
var _building_system: BuildingSystem
var _building_mode: BuildingMode

# ==================== 界面元素 ====================
var _bg: ColorRect
var _tab_container: HBoxContainer
var _grid_container: GridContainer
var _info_label: Label
var _close_btn: Button

# ==================== 数据 ====================
var _current_category: int = 0  # 当前选中的分类索引
var _categories: Array[Dictionary] = []  # [{name, color, items: [{piece_type, item_id, tier, name, count}]}]

# ==================== 静态配置 ====================
const CATEGORY_NAMES: Array[String] = ["茅草", "木制", "石制", "灵材", "玉晶"]
const CATEGORY_COLORS: Array[Color] = [
	Color(0.6, 0.5, 0.35),
	Color(0.55, 0.4, 0.2),
	Color(0.5, 0.5, 0.5),
	Color(0.4, 0.6, 1.0),
	Color(0.8, 0.9, 1.0),
]

func _ready() -> void:
	_create_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100

func _create_ui() -> void:
	"""创建面板 UI"""
	# ——— 半透明背景 ———
	_bg = ColorRect.new()
	_bg.name = "BG"
	_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_bg)
	
	# ——— 主面板 ———
	var panel = Panel.new()
	panel.name = "MainPanel"
	panel.size = Vector2(520, 420)
	panel.position = Vector2(100, 60)
	panel.modulate = Color(0.15, 0.12, 0.1, 0.95)
	add_child(panel)
	
	# ——— 标题 ———
	var title = Label.new()
	title.name = "Title"
	title.text = "🏗️ 选择方块"
	title.position = Vector2(16, 12)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_child(title)
	
	# ——— 关闭按钮 ———
	_close_btn = Button.new()
	_close_btn.name = "CloseBtn"
	_close_btn.text = "✕"
	_close_btn.position = Vector2(480, 8)
	_close_btn.custom_minimum_size = Vector2(32, 32)
	_close_btn.pressed.connect(_on_close)
	panel.add_child(_close_btn)
	
	# ——— 分类标签栏 ———
	_tab_container = HBoxContainer.new()
	_tab_container.name = "Tabs"
	_tab_container.position = Vector2(12, 48)
	_tab_container.size = Vector2(496, 36)
	_tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(_tab_container)
	
	# ——— 方块网格 ———
	_grid_container = GridContainer.new()
	_grid_container.name = "BlockGrid"
	_grid_container.position = Vector2(12, 92)
	_grid_container.size = Vector2(496, 280)
	_grid_container.columns = 6
	_grid_container.add_theme_constant_override("h_separation", 8)
	_grid_container.add_theme_constant_override("v_separation", 8)
	panel.add_child(_grid_container)
	
	# ——— 底部信息 ———
	_info_label = Label.new()
	_info_label.name = "Info"
	_info_label.position = Vector2(16, 380)
	_info_label.size = Vector2(480, 30)
	_info_label.add_theme_font_size_override("font_size", 14)
	_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	panel.add_child(_info_label)

# ==================== 打开 / 关闭 ====================

func open(player: Node3D, inventory: Node, building_system: BuildingSystem, building_mode: BuildingMode) -> void:
	"""打开方块选择面板"""
	_player = player
	_inventory = inventory
	_building_system = building_system
	_building_mode = building_mode
	
	# 构建分类数据
	_build_categories()
	
	# 显示并刷新
	visible = true
	_refresh_tabs()
	_select_tab(0)  # 默认选中茅草
	
	# 鼠标可见
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 全屏背景
	_bg.size = get_viewport_rect().size

func close() -> void:
	"""关闭面板"""
	visible = false
	selector_closed.emit()

func _on_close() -> void:
	close()

# ==================== 分类构建 ====================

func _build_categories() -> void:
	"""从背包和配方数据库构建可用方块列表"""
	_categories.clear()
	
	# 默认分类数据
	var category_items = [
		[],  # 茅草 (tier 0)
		[],  # 木制 (tier 1)
		[],  # 石制 (tier 2-3)
		[],  # 灵材 (tier 4-5)
		[],  # 玉晶 (tier 6-7)
	]
	
	# 从背包中收集可建造物品
	if _inventory and _inventory.has_method("get_all_slots"):
		for slot in _inventory.get_all_slots():
			if slot.is_empty():
				continue
			var item_data = _inventory.get_item_data(slot.item_id) if _inventory.has_method("get_item_data") else null
			if not item_data:
				continue
			
			var category = item_data.get("category", -1)
			if category != 0:  # 0 = BUILDING (from ItemDatabase)
				continue
			
			var piece_type = item_data.get("piece_type", BuildingSystem.PieceType.WALL)
			var tier = item_data.get("tier", 0)
			var tier_idx = _tier_to_category(tier)
			
			category_items[tier_idx].append({
				"piece_type": piece_type,
				"item_id": slot.item_id,
				"tier": tier,
				"name": item_data.get("name", slot.item_id),
				"count": slot.count,
			})
	
	# 转换为分类数组
	for i in range(5):
		_categories.append({
			"name": CATEGORY_NAMES[i],
			"color": CATEGORY_COLORS[i],
			"items": category_items[i],
		})

static func _tier_to_category(tier: int) -> int:
	"""等级 → 分类索引"""
	if tier <= 1:
		return 0  # 茅草
	elif tier <= 3:
		return 1  # 木制
	elif tier <= 5:
		return 2  # 石制
	elif tier <= 7:
		return 3  # 灵材
	else:
		return 4  # 玉晶

# ==================== 标签 ====================

func _refresh_tabs() -> void:
	"""刷新分类标签栏"""
	# 清空旧的
	for child in _tab_container.get_children():
		child.queue_free()
	
	for i in range(_categories.size()):
		var cat = _categories[i]
		var btn = Button.new()
		btn.name = "Tab_%d" % i
		btn.text = "%s (%d)" % [cat.name, cat.items.size()]
		btn.custom_minimum_size = Vector2(90, 32)
		btn.disabled = cat.items.size() == 0
		btn.pressed.connect(_select_tab.bind(i))
		btn.toggle_mode = true
		btn.button_group = ButtonGroup.new()
		_tab_container.add_child(btn)

func _select_tab(index: int) -> void:
	"""选中某个分类"""
	_current_category = index
	_refresh_grid(index)
	_refresh_info()
	
	# 高亮选中的 tab
	var tabs = _tab_container.get_children()
	for i in range(tabs.size()):
		if tabs[i] is Button:
			tabs[i].button_pressed = (i == index)

# ==================== 方块网格 ====================

func _refresh_grid(category_index: int) -> void:
	"""刷新方块网格"""
	# 清空旧的
	for child in _grid_container.get_children():
		child.queue_free()
	
	if category_index >= _categories.size():
		return
	
	var items = _categories[category_index].items
	if items.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "该分类下没有可用方块"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty_label.size = Vector2(480, 40)
		_grid_container.add_child(empty_label)
		return
	
	# 如果没有当前网格列数，使用6列
	_grid_container.columns = mini(6, items.size())
	
	for item in items:
		var block_btn = _create_block_button(item)
		_grid_container.add_child(block_btn)

func _create_block_button(item: Dictionary) -> Button:
	"""创建一个方块按钮"""
	var btn = Button.new()
	
	# 方块名 + 数量
	var display_name = item.get("name", "未知")
	var count = item.get("count", 0)
	btn.text = "%s\n×%d" % [display_name, count]
	
	btn.custom_minimum_size = Vector2(72, 72)
	btn.size = Vector2(72, 72)
	btn.tooltip_text = "%s (Lv.%d 放置/破坏)" % [display_name, item.get("tier", 0)]
	
	# 颜色装饰
	var cat_idx = _tier_to_category(item.get("tier", 0))
	if cat_idx < CATEGORY_COLORS.size():
		btn.modulate = CATEGORY_COLORS[cat_idx] * 0.8 + Color.WHITE * 0.2
	
	btn.pressed.connect(_on_block_btn_pressed.bind(item))
	
	return btn

func _on_block_btn_pressed(item: Dictionary) -> void:
	"""点击方块按钮"""
	# 通知 BuildingMode 切换方块
	if _building_mode:
		_building_mode.select_building(item.piece_type, item.item_id)
		block_selected.emit(item.piece_type, item.item_id, item.tier)
		print("🔨 选择方块: %s" % item.name)
	
	# 关闭面板
	close()

# ==================== 信息 ====================

func _refresh_info() -> void:
	"""刷新底部信息"""
	var cat = _categories[_current_category] if _current_category < _categories.size() else null
	if cat:
		var total = cat.items.size()
		var available = 0
		for item in cat.items:
			available += item.get("count", 0)
		_info_label.text = "分类: %s | 种类: %d | 持有方块总数: %d" % [cat.name, total, available]
	else:
		_info_label.text = "请选择方块类型"

# ==================== 输入处理 ====================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# ESC 或 B 关闭面板
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_building"):
		close()
		get_viewport().set_input_as_handled()
	
	# 右键空白处关闭
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		close()
		get_viewport().set_input_as_handled()

# ==================== 自适应 ====================

func _on_viewport_size_changed() -> void:
	if visible:
		_bg.size = get_viewport_rect().size
