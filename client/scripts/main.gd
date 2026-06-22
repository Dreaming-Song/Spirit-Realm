extends Node
## 主游戏管理器
## 启动时初始化所有系统，负责跨模块通信

# 单例
static var instance: Node

# ---------- 系统引用 ----------
@onready var player: CharacterBody3D = $Player
@onready var magic_system: Node = $MagicSystem
@onready var alchemy_system: Node = $AlchemySystem
@onready var save_system: Node = $SaveSystem
@onready var hud: CanvasLayer = $UI/HUD
@onready var terrain: Node3D = $World/TerrainManager

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	print("🌏 灵境 v0.1.0 启动")
	_setup_autoloads()

func _setup_autoloads() -> void:
	"""注册跨场景访问的路径"""
	# 所有系统挂在 Main 节点下，通过 /root/Main/ 访问
	pass

# ===================== 工具方法 =====================

func get_player() -> CharacterBody3D:
	return player

func get_magic_system() -> Node:
	return magic_system

func get_alchemy_system() -> Node:
	return alchemy_system

func get_save_system() -> Node:
	return save_system
