# res://src/units/enemy/enemy_base.gd
extends "res://src/units/unit_base.gd"

# 城壁内に入ったら true。一度入ったら門を再ターゲットしない
var _entered_inner: bool = false

func _ready():
	super._ready()
	add_to_group("enemies")

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
	var gate = _find_nearest_gate()

	# 城壁内判定：門が開放 or 破壊済みの状態で y 座標を超えた場合のみ
	if not _entered_inner:
		var gate_passable = (gate == null) or gate.is_open or gate.is_destroyed
		if gate_passable and global_position.y > (gate.global_position.y + 30 if gate else 99999):
			_entered_inner = true

	# 城壁内：本陣を目指しつつ、射程内の味方に反撃
	if _entered_inner:
		var nearest_ally = _find_nearest_ally()
		if nearest_ally and global_position.distance_to(nearest_ally.global_position) <= attack_range:
			target = nearest_ally
			return
		target = get_tree().get_first_node_in_group("main_base")
		return

	# 城壁外ロジック（門が閉じている間はここに来る）

	# 【最優先】攻撃射程内に閉じた門がある → 門を攻撃
	if gate and not gate.is_open and not gate.is_destroyed:
		var gate_pos = gate.get_target_position() if gate.has_method("get_target_position") else gate.global_position
		if global_position.distance_to(gate_pos) <= attack_range:
			target = gate
			return

	# 門が閉じていれば門へ向かう、開いていれば本陣へ
	if gate and not gate.is_open and not gate.is_destroyed:
		target = gate
	else:
		target = get_tree().get_first_node_in_group("main_base")

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
	var nearest_dist = attack_range + 1.0
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
