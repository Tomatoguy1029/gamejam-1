extends Area2D

const BAR_W := 80.0
const BAR_H := 8.0

@export var max_hp: int = 100
var current_hp: int

func _ready():
	add_to_group("main_base")
	current_hp = GameManager.CONFIG.base_hp
	max_hp     = GameManager.CONFIG.base_hp
	body_entered.connect(_on_body_entered)

func get_target_position() -> Vector2:
	return $CollisionShape2D.global_position

func take_damage(amount: int):
	GameManager.take_base_damage(amount)
	current_hp = GameManager.base_hp
	queue_redraw()

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		take_damage(15)
		body.queue_free()

func _draw():
	# 城アイコン（大きめ四角）
	draw_rect(Rect2(-30, -30, 60, 60), Color(0.3, 0.3, 0.8, 0.9))
	draw_rect(Rect2(-30, -30, 60, 60), Color(0.6, 0.6, 1.0), false, 3.0)

	# HPバー
	var ratio = float(GameManager.base_hp) / float(max_hp)
	draw_rect(Rect2(-BAR_W * 0.5, -50, BAR_W, BAR_H), Color(0.15, 0.15, 0.15, 0.9))
	var col = Color(0.1, 0.85, 0.1) if ratio > 0.3 else Color(0.85, 0.2, 0.1)
	draw_rect(Rect2(-BAR_W * 0.5, -50, BAR_W * ratio, BAR_H), col)

func _process(_delta):
	queue_redraw()
