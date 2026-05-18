# res://src/units/enemy/enemy_base.gd
extends "res://src/units/unit_base.gd"

# 城壁内に入ったら true。一度入ったら門を再ターゲットしない
var _entered_inner: bool = false

func _ready():
	super._ready()
	add_to_group("enemies")
	# NavigationAgent2D は無効化（全方位直接移動）
	if has_node("NavigationAgent2D"):
		$NavigationAgent2D.set_physics_process(false)

# Nav agent を使わず直接目標へ移動
func _move(target_pos: Vector2) -> void:
	var dir = (target_pos - global_position)
	if dir.length() > 1.0:
		velocity = dir.normalized() * speed
	move_and_slide()

func _logic(_delta):
	_update_target()
	if target and is_instance_valid(target):
		var move_pos = _get_target_move_pos()
		if global_position.distance_to(move_pos) <= attack_range:
			if can_attack:
				_attack()
		_move(move_pos)

func _get_target_move_pos() -> Vector2:
	if not is_instance_valid(target):
		return global_position
	if target.has_method("get_target_position"):
		return target.get_target_position()
	return target.global_position

func _update_target():
	# 壁が残っていれば最近傍の壁へ
	var nearest_wall = _find_nearest_wall()
	if nearest_wall:
		target = nearest_wall
		return
	# 壁が全滅したら射程内の味方 → 本陣
	var nearest_ally = _find_nearest_ally()
	if nearest_ally and global_position.distance_to(nearest_ally.global_position) <= attack_range:
		target = nearest_ally
		return
	target = get_tree().get_first_node_in_group("main_base")

func _find_nearest_wall() -> Node:
	var walls = get_tree().get_nodes_in_group("walls")
	var nearest = null
	var nearest_dist = INF
	for w in walls:
		if not is_instance_valid(w):
			continue
		var d = global_position.distance_to(w.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = w
	return nearest

func _find_nearest_gate() -> Node:
	var gates = get_tree().get_nodes_in_group("gate")
	var nearest = null
	var nearest_dist = INF
	for g in gates:
		if not g.is_destroyed:
			var gpos = g.get_target_position() if g.has_method("get_target_position") else g.global_position
			var d = global_position.distance_to(gpos)
			if d < nearest_dist:
				nearest_dist = d
				nearest = g
	return nearest

func _find_nearest_ally() -> Node:
	var allies = get_tree().get_nodes_in_group("allies")
	var nearest = null
	var nearest_dist = INF
	for a in allies:
		if not a.is_dead:
			var d = global_position.distance_to(a.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = a
	return nearest

func _attack():
	can_attack = false
	if is_instance_valid(target):
		target.take_damage(damage)
	attack_timer.start()

func _on_death():
	if reward > 0:
		GameManager.add_money(reward)
	queue_free()
