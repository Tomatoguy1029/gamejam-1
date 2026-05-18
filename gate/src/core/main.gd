extends Node

const ENEMY_HEAVY    = preload("res://src/units/enemy/enemy_heavy.tscn")
const ENEMY_SWARM    = preload("res://src/units/enemy/enemy_swarm.tscn")
const ENEMY_DASH     = preload("res://src/units/enemy/enemy_dash.tscn")
const ENEMY_BREAKER  = preload("res://src/units/enemy/enemy_breaker.tscn")
const ENEMY_SUMMONER = preload("res://src/units/enemy/enemy_summoner.tscn")

const ALLY_ATTACKER = preload("res://src/units/ally/ally_attacker.tscn")
const ALLY_TANK     = preload("res://src/units/ally/ally_tank.tscn")
const ALLY_ARCHER   = preload("res://src/units/ally/ally_archer.tscn")

const ALL_DIRS: Array[Vector2] = [
	Vector2(0, -1),           # N
	Vector2(0.707, -0.707),   # NE
	Vector2(1, 0),            # E
	Vector2(0.707, 0.707),    # SE
	Vector2(0, 1),            # S
	Vector2(-0.707, 0.707),   # SW
	Vector2(-1, 0),           # W
	Vector2(-0.707, -0.707),  # NW
]

@onready var units_node: Node2D = $World/Units
@onready var _result_overlay    = $ResultOverlay

var _elapsed: float = 0.0

# ウェーブタイマー（負の値 = 最初の発火まで待つ時間）
var _col_timer:      float = 3.0    # Wave1: 2秒後に最初の列（閾値5.0まで2秒）
var _cls_timer:      float = -5.0   # Wave2
var _mix_col_timer:  float = -4.0   # Wave3 列側
var _mix_cls_timer:  float = -6.0   # Wave3 塊側（少しずらす）
var _spl_main_timer: float = -4.0   # Wave4 主戦線
var _spl_flank_timer:float = -7.0   # Wave4 側面（主戦線から遅れて）
var _chaos_timer:    float = -3.0   # Wave5

var _prev_wave: int = 0
var _last_col_dir: Vector2 = Vector2.ZERO   # 連続で同じ方向にならないよう記録
var _last_cls_dir: Vector2 = Vector2.ZERO

func _wave_id_at(t: float) -> int:
	if t < 12.0: return 1
	if t < 24.0: return 2
	if t < 36.0: return 3
	if t < 50.0: return 4
	return 5

func _ready():
	randomize()
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.game_over.connect(_on_game_over)
	_result_overlay.hide()

func _process(delta):
	if GameManager.current_phase != GameManager.Phase.PLAYING:
		return
	_elapsed += delta

	var wave = _wave_id_at(_elapsed)
	if wave != _prev_wave:
		_on_wave_enter(wave)
		_prev_wave = wave

	match wave:
		1: _wave1(delta)
		2: _wave2(delta)
		3: _wave3(delta)
		4: _wave4(delta)
		5: _wave5(delta)

func _on_wave_enter(wave: int) -> void:
	# 新しいウェーブに入ったときタイマーリセット（少し待ってから始まる）
	match wave:
		2:
			_cls_timer = -2.0    # wave2突入後2秒で最初の塊
		3:
			_mix_col_timer = -3.0
			_mix_cls_timer = -4.5   # 列より1.5秒遅らせて塊を導入
		4:
			_spl_main_timer  = -3.0
			_spl_flank_timer = -4.5  # 主戦線より1.5秒遅らせて側面
		5:
			_chaos_timer = -3.0

# ════════════════════════════════════════════════════════
# Wave 1 (0-12s) — 縦列入門
# ════════════════════════════════════════════════════════
func _wave1(delta: float) -> void:
	_col_timer += delta
	if _col_timer >= 4.5:
		_col_timer = 0.0
		var dir = _random_dir_excluding(_last_col_dir)
		_last_col_dir = dir
		_spawn_line(dir, 5, 50.0, ENEMY_SWARM)

# ════════════════════════════════════════════════════════
# Wave 2 (12-24s) — 塊入門
# ════════════════════════════════════════════════════════
func _wave2(delta: float) -> void:
	_cls_timer += delta
	if _cls_timer >= 4.0:
		_cls_timer = 0.0
		var dir = _random_dir_excluding(_last_cls_dir)
		_last_cls_dir = dir
		_spawn_cluster(dir, 10, 32.0, ENEMY_SWARM)
		_spawn_cluster(dir,  3, 20.0, ENEMY_HEAVY, 0.6)

# ════════════════════════════════════════════════════════
# Wave 3 (24-36s) — 混合
# ════════════════════════════════════════════════════════
func _wave3(delta: float) -> void:
	_mix_col_timer += delta
	if _mix_col_timer >= 3.5:
		_mix_col_timer = 0.0
		var dir = _random_dir_excluding(_last_col_dir)
		_last_col_dir = dir
		_spawn_line(dir, 9, 44.0, ENEMY_SWARM)
		_spawn_line(dir, 3, 66.0, ENEMY_BREAKER, 0.6)

	_mix_cls_timer += delta
	if _mix_cls_timer >= 5.0:
		_mix_cls_timer = 0.0
		var dir2 = _opposite_dir(_last_col_dir)
		_last_cls_dir = dir2
		_spawn_cluster(dir2, 9, 30.0, ENEMY_SWARM)
		_spawn_cluster(dir2, 4, 20.0, ENEMY_HEAVY)

# ════════════════════════════════════════════════════════
# Wave 4 (36-50s) — 挟撃 (Wind/Rain向け)
# ════════════════════════════════════════════════════════
func _wave4(delta: float) -> void:
	# 主戦線
	_spl_main_timer += delta
	if _spl_main_timer >= 3.5:
		_spl_main_timer = 0.0
		var main_dir = _random_dir_excluding(_last_col_dir)
		_last_col_dir = main_dir
		_spawn_line(main_dir, 8, 50.0, ENEMY_HEAVY)
		_spawn_line(main_dir, 3, 72.0, ENEMY_BREAKER, 0.5)

	# 側面: 主戦線と90°ずれた方向からDash高速部隊
	_spl_flank_timer += delta
	if _spl_flank_timer >= 4.0:
		_spl_flank_timer = 0.0
		var flank_dir = _perpendicular_dir(_last_col_dir)
		_last_cls_dir = flank_dir
		_spawn_cluster(flank_dir, 8, 38.0, ENEMY_DASH)
		_spawn_cluster(flank_dir, 4, 24.0, ENEMY_SWARM, 0.3)

# ════════════════════════════════════════════════════════
# Wave 5 (50-60s) — 全方位カオス
# ════════════════════════════════════════════════════════
func _wave5(delta: float) -> void:
	_chaos_timer += delta
	# 徐々に間隔短縮
	var interval = lerp(2.8, 1.7, clampf((_elapsed - 50.0) / 10.0, 0.0, 1.0))
	if _chaos_timer >= interval:
		_chaos_timer = 0.0
		var dir = _random_dir_excluding(_last_col_dir)
		_last_col_dir = dir
		match randi() % 4:
			0:  # 縦列 + Summoner
				_spawn_line(dir, 8, 42.0, ENEMY_SWARM)
				_spawn_single(_random_dir_excluding(dir), ENEMY_SUMMONER)
			1:  # 密集Heavy
				_spawn_cluster(dir, 11, 35.0, ENEMY_HEAVY)
			2:  # 2方向同時Dash
				var dir2 = _perpendicular_dir(dir)
				_spawn_cluster(dir,  5, 28.0, ENEMY_DASH)
				_spawn_cluster(dir2, 5, 28.0, ENEMY_DASH)
			3:  # 列 + 反対から塊
				_spawn_line(_perpendicular_dir(dir), 7, 48.0, ENEMY_SWARM)
				_spawn_cluster(dir, 7, 30.0, ENEMY_HEAVY)

# ════════════════════════════════════════════════════════
# 方向ユーティリティ
# ════════════════════════════════════════════════════════
func _random_dir_excluding(exclude: Vector2) -> Vector2:
	var tries = 0
	while tries < 10:
		var d: Vector2 = ALL_DIRS[randi() % ALL_DIRS.size()]
		if d != exclude:
			return d
		tries += 1
	return ALL_DIRS[randi() % ALL_DIRS.size()]

# 与えられた方向に対してほぼ垂直な方向を返す（挟み撃ち用）
func _perpendicular_dir(dir: Vector2) -> Vector2:
	var idx = ALL_DIRS.find(dir)
	if idx < 0:
		idx = 0
	# 90°ずらす（2ステップ）、さらにランダムに+/-
	var offset = 2 if randi() % 2 == 0 else -2
	return ALL_DIRS[(idx + offset + ALL_DIRS.size()) % ALL_DIRS.size()]

# 反対方向
func _opposite_dir(dir: Vector2) -> Vector2:
	var idx = ALL_DIRS.find(dir)
	if idx < 0: return ALL_DIRS[0]
	return ALL_DIRS[(idx + 4) % ALL_DIRS.size()]

# ════════════════════════════════════════════════════════
# スポーンユーティリティ
# ════════════════════════════════════════════════════════
func _spawn_line(dir: Vector2, count: int, spacing: float,
		scene: PackedScene, delay: float = 0.0) -> void:
	var castle = get_tree().get_first_node_in_group("main_base")
	if not castle: return
	var base = castle.global_position + dir * GameManager.CONFIG.spawn_distance
	var perp = Vector2(-dir.y, dir.x)
	for i in count:
		var offset = perp * (i - (count - 1) * 0.5) * spacing
		var pos    = base + offset + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		if delay > 0.0:
			get_tree().create_timer(delay + i * 0.05).timeout.connect(
				func(): _do_spawn(scene, pos))
		else:
			_do_spawn(scene, pos)

func _spawn_cluster(dir: Vector2, count: int, radius: float,
		scene: PackedScene, delay: float = 0.0) -> void:
	var castle = get_tree().get_first_node_in_group("main_base")
	if not castle: return
	var center = castle.global_position + dir * GameManager.CONFIG.spawn_distance
	for i in count:
		var ang = randf() * TAU
		var pos = center + Vector2(cos(ang), sin(ang)) * randf_range(0.0, radius)
		if delay > 0.0:
			get_tree().create_timer(delay + i * 0.06).timeout.connect(
				func(): _do_spawn(scene, pos))
		else:
			_do_spawn(scene, pos)

func _spawn_single(dir: Vector2, scene: PackedScene) -> void:
	var castle = get_tree().get_first_node_in_group("main_base")
	if not castle: return
	_do_spawn(scene, castle.global_position + dir * GameManager.CONFIG.spawn_distance)

func _do_spawn(scene: PackedScene, pos: Vector2) -> void:
	if GameManager.current_phase != GameManager.Phase.PLAYING:
		return
	var enemy = scene.instantiate()
	units_node.add_child(enemy)
	enemy.global_position = pos

# ════════════════════════════════════════════════════════
# その他
# ════════════════════════════════════════════════════════
func _on_phase_changed(new_phase):
	if new_phase == GameManager.Phase.PLAYING:
		_place_initial_defenders()

func _place_initial_defenders():
	var castle = get_tree().get_first_node_in_group("main_base")
	if castle == null:
		return
	var base  = castle.global_position
	var spots = [
		base + Vector2(-60,  0),
		base + Vector2( 60,  0),
		base + Vector2(  0, -60),
		base + Vector2(-40, -80),
		base + Vector2( 40, -80),
	]
	var scenes = [ALLY_TANK, ALLY_TANK, ALLY_ATTACKER, ALLY_ARCHER, ALLY_ARCHER]
	for i in scenes.size():
		var u = scenes[i].instantiate()
		units_node.add_child(u)
		u.global_position = spots[i]

func _on_game_over(is_win: bool) -> void:
	_result_overlay.show_result(is_win)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		GameManager.reset()
		get_tree().reload_current_scene()
