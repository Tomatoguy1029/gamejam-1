extends CharacterBody2D

## ユニット種別 ID。各 .tscn で "ally_attacker" などの文字列を設定する。
## GameManager.UNIT_CONFIG からパラメータを引く。
@export var unit_id: String = ""

# ---- ランタイム値（_apply_params() で UNIT_CONFIG から展開される） ----
var max_hp: int = 100
var speed: float = 100.0
var damage: int = 10
var attack_range: float = 40.0
var attack_interval: float = 1.0
var reward: int = 0
var gate_damage_multiplier: float = 1.0

var current_hp: int
var target = null
var can_attack: bool = true

@onready var nav_agent    = $NavigationAgent2D
@onready var attack_timer = $AttackTimer
@onready var _damage_label: Label = $Label

# HP バー描画定数
const _BAR_HEIGHT  := 5.0
const _BAR_Y       := -34.0   # ユニット中心から上

func _ready():
	_apply_params()
	attack_timer.wait_time = attack_interval
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	_apply_upgrades()
	current_hp = max_hp
	if _damage_label:
		_damage_label.text = str(damage)

func _apply_params():
	if unit_id.is_empty():
		return
	var p = GameManager.UNIT_CONFIG.get(unit_id)
	if p == null:
		push_warning("UNIT_CONFIG にキーが見つかりません: " + unit_id)
		return
	max_hp                 = p.max_hp
	speed                  = p.speed
	damage                 = p.damage
	attack_range           = p.attack_range
	attack_interval        = p.attack_interval
	reward                 = p.reward
	gate_damage_multiplier = p.gate_damage_multiplier

func _apply_upgrades():
	pass

func _draw():
	# HPバーの幅は max_hp に比例（30〜80px にクランプ）
	var bar_w := clampf(max_hp * 0.4, 30.0, 80.0)
	var bx    := -bar_w * 0.5

	# 背景（暗いグレー）
	draw_rect(Rect2(bx, _BAR_Y, bar_w, _BAR_HEIGHT), Color(0.15, 0.15, 0.15, 0.85))

	# 塗り（体力に応じて緑 → 赤）
	var ratio     := float(current_hp) / float(max_hp)
	var bar_color := Color(0.1, 0.85, 0.1) if ratio > 0.3 else Color(0.85, 0.2, 0.1)
	draw_rect(Rect2(bx, _BAR_Y, bar_w * ratio, _BAR_HEIGHT), bar_color)

func _physics_process(_delta):
	if GameManager.current_phase != GameManager.Phase.DEFENDING:
		return
	_logic(_delta)

func _logic(_delta):
	pass

func _move(target_pos):
	nav_agent.target_position = target_pos
	velocity = global_position.direction_to(nav_agent.get_next_path_position()) * speed
	move_and_slide()

func _on_attack_timer_timeout():
	can_attack = true

func take_damage(amount: int):
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		_on_death()
	else:
		queue_redraw()

func _on_death():
	queue_free()
