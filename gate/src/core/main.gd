extends Node

const WAVE_CONFIG_PATH = "res://data/wave_configs.json"
const ALLY_ATTACKER = preload("res://src/units/ally/ally_attacker.tscn")
const ALLY_TANK     = preload("res://src/units/ally/ally_tank.tscn")
const ALLY_ARCHER   = preload("res://src/units/ally/ally_archer.tscn")

# 0=攻撃兵, 1=守備兵, 2=弓兵
var _place_type: int = 0
# 占有済みアーチャースロット（Marker2D → unit）
var _occupied_slots: Dictionary = {}

var _wave_configs: Array = []

# 敵全滅検知用
var _all_enemies_spawned: bool = false
var _remaining_to_spawn:  int  = 0

@onready var units_node: Node2D   = $World/Units
@onready var spawners: Node2D     = $World/Spawners
@onready var archer_slots: Node2D = $World/NavigationRegion2D/ArcherSlots
@onready var _wave_result         = $CanvasLayer/WaveResult
@onready var _shop_ui             = $CanvasLayer/ShopUI

func _ready():
	_load_wave_configs()
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.game_over.connect(_on_game_over)
	_wave_result.next_pressed.connect(_on_wave_result_closed)

func _load_wave_configs():
	var file = FileAccess.open(WAVE_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("wave_configs.json が見つかりません: " + WAVE_CONFIG_PATH)
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("wave_configs.json のパース失敗: " + json.get_error_message())
		return
	_wave_configs = json.get_data()

func _process(_delta):
	if GameManager.current_phase == GameManager.Phase.DEFENDING \
			and _all_enemies_spawned \
			and get_tree().get_nodes_in_group("enemies").is_empty():
		GameManager.start_placing_phase()

func _input(event):
	# ESC でタイトルに戻る（任意フェーズ）
	if event.is_action_pressed("ui_cancel"):
		_return_to_title()
		return

	if GameManager.current_phase != GameManager.Phase.PLACING:
		return

	if event.is_action_pressed("ui_accept"):
		GameManager.start_defending_phase()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _place_type = 0
			KEY_2: _place_type = 1
			KEY_3: _place_type = 2
		return

	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_try_place_unit(units_node.get_global_mouse_position())

func _try_place_unit(world_pos: Vector2):
	var type_ids = ["ally_attacker", "ally_tank", "ally_archer"]
	var p = GameManager.UNIT_CONFIG.get(type_ids[_place_type])
	if p == null:
		return

	if _place_type == 2:
		# 弓兵：空きスロットへスナップ配置
		var slot = _find_free_slot()
		if slot == null:
			print("弓兵スロットが全て埋まっています")
			return
		if not GameManager.spend_money(p.cost):
			print("お金が足りません (%dG 必要)" % p.cost)
			return
		var unit = ALLY_ARCHER.instantiate()
		units_node.add_child(unit)
		unit.global_position = slot.global_position
		_occupied_slots[slot] = unit
	else:
		# 歩兵・守備兵：内陣エリア内にクリック配置
		var bounds = GameManager.CONFIG.placement_bounds
		if not bounds.has_point(world_pos):
			return
		if not GameManager.spend_money(p.cost):
			print("お金が足りません (%dG 必要)" % p.cost)
			return
		var scene = ALLY_ATTACKER if _place_type == 0 else ALLY_TANK
		var unit = scene.instantiate()
		units_node.add_child(unit)
		unit.global_position = world_pos

## 空きアーチャースロット（Marker2D）を返す。全埋まりなら null
func _find_free_slot() -> Marker2D:
	for slot in archer_slots.get_children():
		if slot is Marker2D:
			var occupant = _occupied_slots.get(slot)
			if occupant == null or not is_instance_valid(occupant):
				return slot
	return null

func _return_to_title() -> void:
	GameManager.reset()
	get_tree().reload_current_scene()

func _on_phase_changed(new_phase):
	if new_phase == GameManager.Phase.DEFENDING:
		_all_enemies_spawned = false
		_remaining_to_spawn  = 0
		_spawn_wave(GameManager.wave_count - 1)
	elif new_phase == GameManager.Phase.PLACING:
		# 敵を全て削除
		for enemy in get_tree().get_nodes_in_group("enemies"):
			enemy.queue_free()
		# wave クリア後（初回配置フェーズ以外）にリザルトを表示
		if GameManager.wave_count > 0:
			_show_wave_result()

func _show_wave_result() -> void:
	# 生存している味方ユニットを集計
	var survivors: Dictionary = {}   # { unit_id -> { count, reward } }
	var total_reward: int = 0
	for ally in get_tree().get_nodes_in_group("allies"):
		if ally.has_method("take_damage") and not ally.is_dead:
			var uid: String = ally.unit_id
			var rw: int     = ally.reward
			if uid not in survivors:
				survivors[uid] = { "count": 0, "reward": rw }
			survivors[uid]["count"] += 1
			total_reward += rw

	# 報酬を money に追加
	if total_reward > 0:
		GameManager.add_money(total_reward)

	# 生存ユニットを全て削除（リセット）
	for ally in get_tree().get_nodes_in_group("allies"):
		ally.queue_free()
	_occupied_slots.clear()

	# リザルト画面を表示（waveクリア報酬は GameManager が自動付与）
	_wave_result.show_result(GameManager.wave_count, survivors, total_reward,
			GameManager.CONFIG.phase_clear_reward)

func _on_wave_result_closed() -> void:
	_shop_ui.show_after_result()

func _spawn_wave(phase_index: int):
	if phase_index < 0 or phase_index >= _wave_configs.size():
		push_error("wave_configs の範囲外: " + str(phase_index))
		return
	var config = _wave_configs[phase_index]
	# 全スポーン完了検知用カウンタを初期化
	for group in config["groups"]:
		_remaining_to_spawn += group["count"]
	if _remaining_to_spawn == 0:
		_all_enemies_spawned = true
	for group in config["groups"]:
		_spawn_group_delayed(group["scene"], group["count"], group["interval"],
				group.get("start_delay", 0.0))

func _spawn_group_delayed(scene_path: String, count: int, interval: float, delay: float):
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if GameManager.current_phase != GameManager.Phase.DEFENDING:
		return
	await _spawn_group(scene_path, count, interval)

func _spawn_group(scene_path: String, count: int, interval: float):
	var scene = load(scene_path)
	if scene == null:
		push_error("シーンが見つかりません: " + scene_path)
		_remaining_to_spawn -= count
		if _remaining_to_spawn <= 0:
			_all_enemies_spawned = true
		return
	for i in range(count):
		if GameManager.current_phase != GameManager.Phase.DEFENDING:
			return
		var enemy = scene.instantiate()
		units_node.add_child(enemy)
		var spawn_node = spawners.get_children().pick_random()
		enemy.global_position = spawn_node.global_position
		_remaining_to_spawn -= 1
		if _remaining_to_spawn <= 0:
			_all_enemies_spawned = true
		if i < count - 1:
			await get_tree().create_timer(interval).timeout

func _on_game_over(is_win: bool):
	if is_win:
		print("クリア！")
	else:
		print("敗北…")
