extends Node
## 系统启动自检器
## 挂载到主场景后，启动时打印所有系统加载状态

func _ready() -> void:
	print("=" * 50)
	print("🏮 远行商人 · 系统自检")
	print("=" * 50)
	
	_check("Player", get_tree().get_first_node_in_group("player"))
	_check("MagicSystem", MagicSystem if has_autoload("MagicSystem") else null)
	_check("AlchemySystem", AlchemySystem if has_autoload("AlchemySystem") else null)
	_check("SaveSystem", SaveSystem if has_autoload("SaveSystem") else null)
	_check("QuestSystem", QuestSystem if has_autoload("QuestSystem") else null)
	_check("NetworkManager", NetworkManager if has_autoload("NetworkManager") else null)
	_check("HandHoldManager", HandHoldManager if has_autoload("HandHoldManager") else null)
	
	print("-" * 50)
	print("✅ 自检完成")
	print("=" * 50)

func _check(name: String, node) -> void:
	if node != null:
		print("  ✅ %s" % name)
	else:
		print("  ⚠️  %s — 未加载（场景中可能没有该节点）" % name)

func has_autoload(name: String) -> bool:
	return has_node("/root/" + name)
