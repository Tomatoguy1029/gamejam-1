extends Node

## ゲーム全体のパラメータ（Inspector で編集可能な .tres）
const CONFIG: GameConfig = preload("res://data/game_config.tres")
const UNIT_CONFIG: UnitConfig = preload("res://data/unit_config.tres")

signal phase_changed(new_phase)
signal money_changed(amount)
signal base_hp_changed(hp)
signal gate_hp_changed(hp)
signal game_over(is_win)

enum Phase { START, PLACING, DEFENDING }

var current_phase = Phase.START
var money: int
var wave_count: int = 0

var base_hp: int:
	set(value):
		base_hp = value
		base_hp_changed.emit(base_hp)

var upgrade_atk: int = 0
var upgrade_hp: int = 0
var upgrade_atk_interval: float = 0.0

@onready var phase_timer = Timer.new()

func _ready():
	money   = CONFIG.initial_money
	base_hp = CONFIG.base_hp
	add_child(phase_timer)
	phase_timer.timeout.connect(_on_phase_timer_timeout)

func start_game():
	start_placing_phase()

func start_placing_phase():
	current_phase = Phase.PLACING
	phase_changed.emit(current_phase)
	if wave_count > 0:
		_grant_phase_reward()
	phase_timer.stop()  # 常に Ready ボタン or Enter で開始

func start_defending_phase():
	current_phase = Phase.DEFENDING
	wave_count += 1
	phase_changed.emit(current_phase)
	phase_timer.start(CONFIG.defending_phase_duration)

func _on_phase_timer_timeout():
	if current_phase == Phase.PLACING:
		start_defending_phase()
	else:
		if wave_count >= CONFIG.max_waves:
			game_over.emit(true)
		else:
			start_placing_phase()

func _grant_phase_reward():
	add_money(CONFIG.phase_clear_reward)

func add_money(amount: int):
	money += amount
	money_changed.emit(money)

func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		money_changed.emit(money)
		return true
	return false

func take_base_damage(amount: int):
	base_hp -= amount
	if base_hp <= 0:
		base_hp = 0
		game_over.emit(false)

func buy_upgrade_atk(group: String) -> bool:
	if not spend_money(CONFIG.upgrade_cost):
		return false
	upgrade_atk += CONFIG.upgrade_atk_amount
	for unit in get_tree().get_nodes_in_group(group):
		unit.damage += CONFIG.upgrade_atk_amount
	return true

func buy_upgrade_hp(group: String) -> bool:
	if not spend_money(CONFIG.upgrade_cost):
		return false
	upgrade_hp += CONFIG.upgrade_hp_amount
	for unit in get_tree().get_nodes_in_group(group):
		unit.current_hp += CONFIG.upgrade_hp_amount
		unit.max_hp     += CONFIG.upgrade_hp_amount
	return true

func buy_upgrade_atk_speed(group: String) -> bool:
	if not spend_money(CONFIG.upgrade_cost):
		return false
	upgrade_atk_interval += CONFIG.upgrade_interval_amount
	for unit in get_tree().get_nodes_in_group(group):
		var new_wait = max(CONFIG.min_attack_interval,
			unit.attack_timer.wait_time - CONFIG.upgrade_interval_amount)
		unit.attack_timer.wait_time = new_wait
	return true

func get_phase_time_left() -> float:
	return phase_timer.time_left
