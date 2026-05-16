# res://src/units/enemy/enemy_breaker.gd
# 門破壊特化型。gate_damage_multiplier 倍のダメージを門に与える。
extends "res://src/units/enemy/enemy_base.gd"

func _attack():
	can_attack = false
	if is_instance_valid(target):
		var multiplier = gate_damage_multiplier if target.is_in_group("gate") else 1.0
		target.take_damage(int(damage * multiplier))
	attack_timer.start()
