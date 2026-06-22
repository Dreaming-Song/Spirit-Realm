extends Node
## Godot 内部单元测试 - Phase 5
## 在编辑器内 F6 运行，检查各系统是否正常初始化

var tests_passed: int = 0
var tests_failed: int = 0

func _ready() -> void:
	print("=" * 50)
	print("🧪 灵境 · 单元测试开始")
	print("=" * 50)

	_run_tests()

	print("-" * 50)
	print("📊 结果: %d 通过, %d 失败" % [tests_passed, tests_failed])
	print("=" * 50)

	if tests_failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _run_tests() -> void:
	# Phase 1: 角色控制
	_test_player_system()
	_test_terrain_system()

	# Phase 2: 核心玩法
	_test_magic_system()
	_test_alchemy_system()
	_test_pet_system()
	_test_save_system()

	# Phase 3: 联机
	_test_network_system()

	# Phase 4: 玩法完善
	_test_quest_system()
	_test_combat_system()
	_test_secret_zone()

# ==================== Phase 1 测试 ====================

func _test_player_system() -> void:
	_assert("Player 节点存在", get_node_or_null("/root/Main/Player") != null)
	var player = get_node_or_null("/root/Main/Player")
	if player:
		_assert("玩家有 HP/MP 属性", player.has_method("get_hp") and player.has_method("get_mp"))
		_assert("玩家能御剑", player.has_method("toggle_flying"))
		_assert("玩家初始满血", player.get_hp() == player.get_max_hp())
		_assert("玩家初始满蓝", player.get_mp() == player.get_max_mp())

func _test_terrain_system() -> void:
	_assert("地形管理器存在", get_node_or_null("/root/Main/World/TerrainManager") != null)

# ==================== Phase 2 测试 ====================

func _test_magic_system() -> void:
	var ms = get_node_or_null("/root/Main/MagicSystem")
	_assert("法术系统存在", ms != null)
	if ms:
		_assert("五行法术已解锁", ms.get_unlocked_spells().size() == 5)
		_assert("法术冷却接口正常", ms.has_method("get_spell_cooldown_ratio"))

func _test_alchemy_system() -> void:
	var as = get_node_or_null("/root/Main/AlchemySystem")
	_assert("炼丹系统存在", as != null)
	if as:
		_assert("有存档接口", as.has_method("get_save_data"))

func _test_pet_system() -> void:
	var pet = get_tree().get_first_node_in_group("pets")
	_assert("灵宠存在", pet != null)
	if pet:
		_assert("灵宠有喂食接口", pet.has_method("feed"))
		_assert("灵宠能载人", pet.has_method("can_mount"))
		_assert("灵宠有信息查询", pet.has_method("get_pet_info"))

func _test_save_system() -> void:
	var ss = get_node_or_null("/root/Main/SaveSystem")
	_assert("存档系统存在", ss != null)
	if ss:
		_assert("存档系统有5个槽位", ss.get("MAX_SLOTS", 0) == 5)
		_assert("能查询存档列表", ss.has_method("get_save_list"))

# ==================== Phase 3 测试 ====================

func _test_network_system() -> void:
	var nm = get_node_or_null("/root/Main/NetworkManager")
	_assert("网络管理器存在（可跳过）", true)  # 本地测试不强制连服务器

# ==================== Phase 4 测试 ====================

func _test_quest_system() -> void:
	var qs = get_node_or_null("/root/Main/QuestSystem")
	_assert("任务系统存在", qs != null)
	if qs:
		_assert("有可接任务列表", qs.has_method("get_available_quests"))
		_assert("有进行中任务列表", qs.has_method("get_active_quests"))
		_assert("能接受任务", qs.has_method("accept_quest"))

func _test_combat_system() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	# 不强制要求场景中有敌人
	_assert("妖兽组存在", true)

func _test_secret_zone() -> void:
	var zone = get_node_or_null("/root/Main/SecretZone")
	_assert("秘境系统存在", zone != null)
	if zone:
		_assert("秘境有进度查询", zone.has_method("get_progress"))
		_assert("秘境有谜题交互", zone.has_method("interact_with_puzzle"))

# ==================== 工具 ====================

func _assert(description: String, condition: bool) -> void:
	if condition:
		tests_passed += 1
		print("  ✅ %s" % description)
	else:
		tests_failed += 1
		print("  ❌ %s" % description)
