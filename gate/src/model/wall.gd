# res://src/model/wall.gd
# 全壁が GameManager.base_hp を共有する
extends StaticBody2D

func _ready():
	add_to_group("walls")
	GameManager.base_hp_changed.connect(_on_hp_changed)

func take_damage(amount: int) -> void:
	GameManager.take_base_damage(amount)

func get_target_position() -> Vector2:
	return global_position

func _on_hp_changed(hp: int) -> void:
	queue_redraw()

func _draw() -> void:
	var ratio = float(GameManager.base_hp) / float(GameManager.CONFIG.base_hp)
	# 壁の色：HPに応じて茶色→赤→ほぼ消える
	var col = Color(0.45, 0.32, 0.18).lerp(Color(0.7, 0.1, 0.05), 1.0 - ratio)
	col.a   = 0.4 + ratio * 0.6
	var s = $CollisionShape2D.shape
	var half = s.size * 0.5 if s is RectangleShape2D else Vector2(20, 20)
	draw_rect(Rect2(-half, half * 2.0), col)
	# ひび割れ表現：HP低いほど線を増やす
	var crack_col = Color(0.1, 0.05, 0.0, 0.6 * (1.0 - ratio))
	if ratio < 0.7:
		draw_line(Vector2(-half.x * 0.3, -half.y), Vector2(half.x * 0.1, half.y), crack_col, 2.0)
	if ratio < 0.4:
		draw_line(Vector2(half.x * 0.3, -half.y), Vector2(-half.x * 0.1, half.y * 0.5), crack_col, 2.0)
		draw_line(Vector2(-half.x * 0.5, 0), Vector2(half.x * 0.5, half.y * 0.3), crack_col, 1.5)
