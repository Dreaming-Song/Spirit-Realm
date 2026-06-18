extends CanvasLayer
## 基础 HUD - Phase 2
## 显示血量、法力、法术冷却、灵宠信息

@onready var hp_bar: ProgressBar = $TopBar/HpBar
@onready var mp_bar: ProgressBar = $TopBar/MpBar
@onready var hp_label: Label = $TopBar/HpBar/Label
@onready var mp_label: Label = $TopBar/MpBar/Label
@onready var spell_container: Container = $BottomBar/SpellContainer
@onready var pet_info_label: Label = $TopBar/PetInfo
@onready var interaction_hint: Label = $CenterHint

# 法术槽位 UI 预制体
@onready var spell_slot_scene: PackedScene = preload("res://scenes/ui/spell_slot.tscn")

var player_ref: Node
var magic_system_ref: Node
var pet_ref: Node

func _ready() -> void:
	player_ref = get_tree().get_first_node_in_group("player")
	magic_system_ref = get_node_or_null("/root/Main/MagicSystem")
	pet_ref = get_tree().get_first_node_in_group("pets")

	# 初始化法术槽
	_init_spell_slots()

func _process(_delta: float) -> void:
	if player_ref == null:
		return

	_update_hp_mp()
	_update_spell_cooldowns()
	_update_pet_info()

func _init_spell_slots() -> void:
	"""创建法术快捷键UI"""
	if magic_system_ref == null:
		return
	var spells = magic_system_ref.get_unlocked_spells()
	var keys = ["1", "2", "3", "4", "5"]
	for i in range(spells.size()):
		var slot = spell_slot_scene.instantiate()
		slot.setup(spells[i].name, keys[i], spells[i].type)
		spell_container.add_child(slot)

func _update_hp_mp() -> void:
	"""更新血量和法力条"""
	if player_ref.has_method("get_hp_ratio"):
		hp_bar.value = player_ref.get_hp_ratio() * 100
		hp_label.text = "%d/%d" % [player_ref.get_hp(), player_ref.get_max_hp()]

	if player_ref.has_method("get_mp_ratio"):
		mp_bar.value = player_ref.get_mp_ratio() * 100
		mp_label.text = "%d/%d" % [player_ref.get_mp(), player_ref.get_max_mp()]

func _update_spell_cooldowns() -> void:
	"""更新法术冷却显示"""
	if magic_system_ref == null:
		return
	for slot in spell_container.get_children():
		if slot.has_method("update_cooldown"):
			var ratio = magic_system_ref.get_spell_cooldown_ratio(slot.spell_type)
			slot.update_cooldown(ratio)

func _update_pet_info() -> void:
	"""更新灵宠信息"""
	if pet_ref == null:
		pet_info_label.text = ""
		return
	var info = pet_ref.get_pet_info()
	pet_info_label.text = "%s Lv.%d ❤️%d" % [info.name, info.level, info.loyalty]

func show_interaction_hint(text: String) -> void:
	"""显示交互提示（如"按E炼丹"）"""
	interaction_hint.text = text
	interaction_hint.show()
	await get_tree().create_timer(2.0).timeout
	interaction_hint.hide()

func show_notification(text: String, color: Color = Color.WHITE) -> void:
	"""显示浮动通知"""
	# TODO: 实现通知动画
	pass
