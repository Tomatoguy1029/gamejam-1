# res://src/units/ally/ally_archer.gd
extends "res://src/units/ally/ally_base.gd"

var dead_zone: float = 60.0

func _apply_params():
	super._apply_params()
	var p = GameManager.UNIT_CONFIG.get("ally_archer")
	if p is ArcherParams:
		dead_zone = p.dead_zone

func _update_target():
	var enemies = get_tree().get_nodes_in_group("enemies")
	target = null
	var min_d = INF
	for e in enemies:
		var d = global_position.distance_to(e.global_position)
		if d > dead_zone and d <= attack_range:
			if d < min_d:
				min_d = d
				target = e

func _logic(_delta):
	_update_target()
	if target and is_instance_valid(target):
		if can_attack:
			_attack()
