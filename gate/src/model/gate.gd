extends StaticBody2D

var max_hp: int
var current_hp: int
var is_open: bool = false
var is_destroyed: bool = false

@onready var collision  = $CollisionShape2D
@onready var hp_fill: Polygon2D = $HPBarNode/HPBarFill

func _ready():
	add_to_group("gate")
	max_hp     = GameManager.CONFIG.gate_max_hp
	current_hp = max_hp
	_update_hp_bar()

func _input(event):
	if GameManager.current_phase != GameManager.Phase.DEFENDING:
		return
	if not is_destroyed and event.is_action_pressed("ui_accept"):
		toggle_gate()

func toggle_gate():
	is_open = !is_open
	collision.set_deferred("disabled", is_open)
	visible = !is_open

func get_target_position() -> Vector2:
	# Gate は 90° 回転済み → CapsuleShape2D の radius が world-Y 方向に展開される
	# collision center は nav メッシュ障害物の内部にあるため、
	# 敵が nav メッシュ上で到達できる上端（radius + バッファ 分だけ上）を返す
	var r: float = (collision.shape.radius if collision.shape is CapsuleShape2D else 0.0) + 15.0
	return collision.global_position + Vector2(0, -r)

func take_damage(amount: int):
	if is_destroyed:
		return
	current_hp -= amount
	GameManager.gate_hp_changed.emit(current_hp)
	_update_hp_bar()
	if current_hp <= 0:
		_destroy()

func _destroy():
	is_destroyed = true
	is_open = true
	current_hp = 0
	collision.set_deferred("disabled", true)
	visible = false
	GameManager.gate_hp_changed.emit(current_hp)

func _update_hp_bar():
	var bar_len = GameManager.CONFIG.gate_bar_length
	var ratio = float(current_hp) / float(max_hp)
	var len = bar_len * ratio
	# local の y 軸方向 → 90°回転後に world の x 方向へ投影される
	hp_fill.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(0, -len),
		Vector2(10, -len),
		Vector2(10, 0)
	])
