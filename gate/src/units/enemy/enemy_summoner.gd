# res://src/units/enemy/enemy_summoner.gd
extends "res://src/units/enemy/enemy_base.gd"

@export var swarm_scene: PackedScene

var summon_interval: float = 5.0
var summon_count: int = 2
var stop_dist_from_gate: float = 80.0

var _at_post: bool = false

@onready var summon_timer = $SummonTimer

func _apply_params():
	super._apply_params()
	var p = GameManager.UNIT_CONFIG.get("enemy_summoner")
	if p is SummonerParams:
		summon_interval     = p.summon_interval
		summon_count        = p.summon_count
		stop_dist_from_gate = p.stop_dist_from_gate

func _ready():
	super._ready()
	summon_timer.wait_time = summon_interval
	summon_timer.start()

func _logic(_delta):
	if _at_post:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var gate = _find_nearest_gate()
	if not is_instance_valid(gate):
		return

	var gate_pos: Vector2 = gate.get_target_position() if gate.has_method("get_target_position") else gate.global_position
	var to_gate = gate_pos - global_position
	var dist = to_gate.length()

	if dist <= stop_dist_from_gate:
		_at_post = true
		velocity = Vector2.ZERO
		move_and_slide()
	else:
		_move(gate_pos - to_gate.normalized() * stop_dist_from_gate)

func _on_summon_timer_timeout():
	if swarm_scene == null or GameManager.current_phase != GameManager.Phase.DEFENDING:
		return
	for i in range(summon_count):
		var s = swarm_scene.instantiate()
		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		get_parent().add_child(s)
		s.global_position = global_position + offset
