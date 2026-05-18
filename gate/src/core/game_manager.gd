extends Node

const CONFIG: GameConfig     = preload("res://data/game_config.tres")
const UNIT_CONFIG: UnitConfig = preload("res://data/unit_config.tres")

signal phase_changed(new_phase)
signal money_changed(amount)
signal base_hp_changed(hp)
signal survival_time_changed(time_left)
signal game_over(is_win)

enum Phase { START, PLAYING, WIN, LOSE }

var current_phase = Phase.START
var money: int
var wave_count: int = 0
var first_run: bool = true   # false after first start_game() call

var base_hp: int:
	set(value):
		base_hp = value
		base_hp_changed.emit(base_hp)

var _survival_time_left: float = 0.0

func _ready():
	money   = CONFIG.initial_money
	base_hp = CONFIG.base_hp

func _process(delta):
	if current_phase != Phase.PLAYING:
		return
	_survival_time_left -= delta
	survival_time_changed.emit(_survival_time_left)
	if _survival_time_left <= 0.0:
		_on_reinforcements_arrived()

func start_game():
	first_run           = false
	money               = CONFIG.initial_money
	base_hp             = CONFIG.base_hp
	wave_count          = 0
	_survival_time_left = CONFIG.survival_time
	current_phase       = Phase.PLAYING
	phase_changed.emit(current_phase)

func _on_reinforcements_arrived():
	current_phase = Phase.WIN
	phase_changed.emit(current_phase)
	game_over.emit(true)

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
		current_phase = Phase.LOSE
		phase_changed.emit(current_phase)
		game_over.emit(false)

func get_survival_time_left() -> float:
	return _survival_time_left

func reset() -> void:
	money               = CONFIG.initial_money
	base_hp             = CONFIG.base_hp
	wave_count          = 0
	_survival_time_left = 0.0
	current_phase       = Phase.START
