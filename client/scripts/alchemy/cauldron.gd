extends StaticBody3D
## 丹炉 - 炼丹交互节点
## 玩家靠近按E打开炼丹界面

signal cooking_started(recipe_name: String)
signal cooking_completed(recipe_name: String, result: String)
signal cooking_failed(recipe_name: String)

# ---------- 参数 ----------
@export var cauldron_name: String = "青铜丹炉"
@export var max_temperature: float = 100.0     # 最高温度
@export var cooking_progress: float = 0.0       # 当前进度 0~1

# ---------- 状态 ----------
var is_cooking: bool = false
var current_recipe: Resource
var temperature: float = 50.0                   # 当前温度
var optimal_temp: float = 60.0                  # 最佳温度
var player_in_range: bool = false

@onready var alchemy_system: Node = get_node("/root/Main/AlchemySystem")
@onready var interaction_area: Area3D = $InteractionArea
@onready var fire_particles: GPUParticles3D = $FireParticles

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if not is_cooking:
		return

	# 温度自然变化（趋近室温）
	temperature = move_toward(temperature, 25.0, delta * 2.0)

	# 进度推进（温度越接近最佳温度越快）
	var temp_factor: float = 1.0 - abs(temperature - optimal_temp) / max_temperature
	temp_factor = clamp(temp_factor, 0.1, 1.0)
	cooking_progress += delta * 0.1 * temp_factor

	# 粒子效果随温度变化
	if fire_particles:
		fire_particles.emitting = temperature > 30.0
		fire_particles.speed_scale = temperature / max_temperature

	# 炼制完成
	if cooking_progress >= 1.0:
		complete_cooking()

# ===================== 交互接口 =====================

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		# TODO: 显示交互提示 "按E炼丹"

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func interact(player: Node) -> void:
	"""玩家按E触发"""
	if is_cooking:
		# TODO: 打开炼丹进度UI
		pass
	else:
		# TODO: 打开炼丹配方选择UI
		pass

# ===================== 炼制流程 =====================

func start_cooking(recipe) -> void:
	"""开始炼制（由 AlchemySystem 调用）"""
	if is_cooking:
		return
	is_cooking = true
	cooking_progress = 0.0
	temperature = 50.0
	optimal_temp = 60.0 + randi() % 20 - 10  # 每次配方最佳温度不同，增加趣味
	current_recipe = recipe
	cooking_started.emit(recipe.name)
	# TODO: 播放炼丹动画

func adjust_temperature(amount: float) -> void:
	"""玩家调整火候"""
	if not is_cooking:
		return
	temperature = clamp(temperature + amount, 0.0, max_temperature)

func complete_cooking() -> void:
	"""炼丹完成"""
	is_cooking = false
	if alchemy_system:
		alchemy_system.alchemy_completed.emit(current_recipe.name, current_recipe.result)
	cooking_completed.emit(current_recipe.name, current_recipe.result)
	current_recipe = null
	cooking_progress = 0.0
	# TODO: 弹出丹药获得提示

func cancel_cooking() -> void:
	"""取消炼丹（材料不退）"""
	if is_cooking:
		is_cooking = false
		cooking_progress = 0.0
		cooking_failed.emit(current_recipe.name if current_recipe else "unknown")
		current_recipe = null

# ===================== 存档接口 =====================

func get_save_data() -> Dictionary:
	return {
		"is_cooking": is_cooking,
		"cooking_progress": cooking_progress,
		"temperature": temperature,
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("is_cooking"):
		is_cooking = data.is_cooking
		cooking_progress = data.get("cooking_progress", 0.0)
		temperature = data.get("temperature", 50.0)
