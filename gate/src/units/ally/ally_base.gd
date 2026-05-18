# res://src/units/ally/ally_base.gd
extends "res://src/units/unit_base.gd"

var is_dead: bool = false
var home_position: Vector2  # 配置時の位置を記憶して復活に使う

func _ready():
	super._ready()
	add_to_group("allies")
	home_position = global_position
	GameManager.phase_changed.connect(_on_phase_changed)

func _apply_upgrades():
	pass  # サバイバルモードではアップグレードなし

func _logic(_delta):
	if is_dead:
		return
	_update_target()
	if target and is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= attack_range:
			if can_attack:
				_attack()

func _update_target():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest_dist = INF
	target = null
	for e in enemies:
		var d = global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			target = e

func _attack():
	can_attack = false
	if is_instance_valid(target):
		target.take_damage(damage)
	attack_timer.start()

func _on_death():
	is_dead = true
	hide()
	set_physics_process(false)

func _on_phase_changed(_new_phase):
	pass  # サバイバルモードでは蘇生なし
