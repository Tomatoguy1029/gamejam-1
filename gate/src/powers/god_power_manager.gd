# res://src/powers/god_power_manager.gd
extends Node2D

enum PowerType { NONE=0, EARTHCRACK=1, METEOR=2, TORNADO=3, WIND=4, RAIN=5 }

const POWER_NAMES := {
	PowerType.EARTHCRACK: "Earthcrack",
	PowerType.METEOR:     "Meteor",
	PowerType.TORNADO:    "Tornado",
	PowerType.WIND:       "Wind",
	PowerType.RAIN:       "Rain",
}
const POWER_COLORS := {
	PowerType.EARTHCRACK: Color(0.6, 0.35, 0.1),
	PowerType.METEOR:     Color(1.0, 0.4, 0.1),
	PowerType.TORNADO:    Color(0.6, 0.85, 1.0),
	PowerType.WIND:       Color(0.8, 1.0, 0.5),
	PowerType.RAIN:       Color(0.3, 0.6, 1.0),
}

var _tex_meteor:     Texture2D = null
var _tex_earthcrack: Texture2D = null
var _tex_tornado:    Texture2D = null

signal power_selected(type: int)

var selected: PowerType = PowerType.NONE
var cooldowns: Dictionary = {}

var _rain_active:       bool    = false
var _rain_remaining:    float   = 0.0
var _rain_drops:        Array   = []
var _rain_slow_applied: bool    = false
var _rain_pos:          Vector2 = Vector2.ZERO
var _rained_enemies:    Array   = []   # 速度を落とした敵を追跡

func _ready():
	for p in PowerType.values():
		if p != PowerType.NONE:
			cooldowns[p] = 0.0
	_load_textures()
	set_process_input(true)

func _load_textures() -> void:
	if ResourceLoader.exists("res://assets/effect_meteor.png"):
		_tex_meteor     = load("res://assets/effect_meteor.png")
	if ResourceLoader.exists("res://assets/effect_earthcrack.png"):
		_tex_earthcrack = load("res://assets/effect_earthcrack.png")
	if ResourceLoader.exists("res://assets/effect_tornado.png"):
		_tex_tornado    = load("res://assets/effect_tornado.png")

func _process(delta):
	if GameManager.current_phase != GameManager.Phase.PLAYING:
		return
	for p in cooldowns:
		cooldowns[p] = max(0.0, cooldowns[p] - delta)
	_update_rain(delta)
	queue_redraw()

func _input(event):
	if GameManager.current_phase != GameManager.Phase.PLAYING:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _select(PowerType.EARTHCRACK)
			KEY_2: _select(PowerType.METEOR)
			KEY_3: _select(PowerType.TORNADO)
			KEY_4: _select(PowerType.WIND)
			KEY_5: _select(PowerType.RAIN)
			KEY_ESCAPE: _select(PowerType.NONE)
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and selected != PowerType.NONE:
		_try_activate(selected, get_global_mouse_position())

func _select(type: PowerType) -> void:
	selected = type
	power_selected.emit(type)
	queue_redraw()

func _try_activate(type: PowerType, pos: Vector2) -> void:
	if cooldowns.get(type, 0.0) > 0.0:
		return
	cooldowns[type] = _get_max_cd(type)
	match type:
		PowerType.EARTHCRACK: _activate_earthcrack(pos)
		PowerType.METEOR:     _activate_meteor(pos)
		PowerType.TORNADO:    _activate_tornado(pos)
		PowerType.WIND:       _activate_wind(pos)
		PowerType.RAIN:       _activate_rain(pos)

# ── 地割れ（縦長楕円判定） ───────────────────────────────
func _activate_earthcrack(pos: Vector2) -> void:
	var cfg = GameManager.CONFIG
	_damage_in_ellipse(pos, cfg.earthcrack_width, cfg.earthcrack_height, cfg.earthcrack_damage)
	var fx := _EarthcrackFX.new(pos, cfg.earthcrack_width, cfg.earthcrack_height, _tex_earthcrack)
	get_tree().current_scene.add_child(fx)

# ── 隕石（右上からスライド） ────────────────────────────
func _activate_meteor(pos: Vector2) -> void:
	var cfg  = GameManager.CONFIG
	var vp   = get_viewport().get_visible_rect()
	var xf   = get_canvas_transform().affine_inverse()
	var start = xf * Vector2(vp.size.x + 120.0, -120.0)
	var fx   := _MeteorProjectileFX.new(
		start, pos, cfg.meteor_delay,
		cfg.meteor_radius, cfg.meteor_damage, _tex_meteor)
	get_tree().current_scene.add_child(fx)

# ── 竜巻 ─────────────────────────────────────────────
func _activate_tornado(pos: Vector2) -> void:
	var cfg = GameManager.CONFIG
	var fx  := _TornadoFX.new(pos, cfg.tornado_radius,
		cfg.tornado_damage, cfg.tornado_speed, cfg.tornado_duration, _tex_tornado)
	get_tree().current_scene.add_child(fx)

# ── 強風（矩形判定 → 画面端まで吹き飛ばし） ─────────────
func _activate_wind(pos: Vector2) -> void:
	var cfg    = GameManager.CONFIG
	var castle = get_tree().get_first_node_in_group("main_base")
	var origin = castle.global_position if castle else Vector2.ZERO
	var hw     = cfg.wind_width  * 0.5
	var hh     = cfg.wind_height * 0.5
	var rect   = Rect2(pos.x - hw, pos.y - hh, cfg.wind_width, cfg.wind_height)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is CharacterBody2D): continue
		if not rect.has_point(enemy.global_position): continue
		var dir = (enemy.global_position - origin).normalized()
		if dir.length_squared() < 0.01: dir = Vector2(1, 0)
		var edge = _ray_to_screen_edge(enemy.global_position, dir)
		enemy.global_position = edge
		enemy.velocity = dir * 200.0   # 端に着いてからも少し流れる
	var fx := _WindFX.new(pos, Vector2(hw, hh))
	get_tree().current_scene.add_child(fx)

# ── 雨（範囲内の敵にのみスロー） ─────────────────────────
func _activate_rain(pos: Vector2) -> void:
	_rain_active    = true
	_rain_pos       = pos
	_rain_remaining = GameManager.CONFIG.rain_duration
	if not _rain_slow_applied:
		_rain_slow_applied = true
		_apply_rain_slow(true)

func _update_rain(delta: float) -> void:
	if not _rain_active:
		return
	_rain_remaining -= delta
	if _rain_remaining <= 0.0:
		_rain_active       = false
		_rain_slow_applied = false
		_apply_rain_slow(false)
	if randi() % 2 == 0:
		var vp = get_viewport().get_visible_rect()
		_rain_drops.append({
			"pos":   Vector2(randf() * vp.size.x, 0),
			"speed": randf_range(700, 1100),
			"alpha": randf_range(0.4, 0.85),
		})
	var vp_h = get_viewport().get_visible_rect().size.y
	for i in range(_rain_drops.size() - 1, -1, -1):
		_rain_drops[i]["pos"].y += _rain_drops[i]["speed"] * delta
		if _rain_drops[i]["pos"].y > vp_h:
			_rain_drops.remove_at(i)

func _apply_rain_slow(enable: bool) -> void:
	var ratio  = GameManager.CONFIG.rain_slow_ratio
	var radius = GameManager.CONFIG.rain_radius
	if enable:
		_rained_enemies.clear()
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.global_position.distance_to(_rain_pos) > radius:
				continue
			_rained_enemies.append(enemy)
			if enemy.has_method("set_speed_multiplier"):
				enemy.set_speed_multiplier(ratio)
			elif "speed" in enemy:
				if not enemy.has_meta("base_speed"):
					enemy.set_meta("base_speed", enemy.speed)
				enemy.speed = enemy.get_meta("base_speed") * ratio
	else:
		for enemy in _rained_enemies:
			if not is_instance_valid(enemy): continue
			if enemy.has_method("set_speed_multiplier"):
				enemy.set_speed_multiplier(1.0)
			elif "speed" in enemy and enemy.has_meta("base_speed"):
				enemy.speed = enemy.get_meta("base_speed")
				enemy.remove_meta("base_speed")
		_rained_enemies.clear()

# ── 共通ユーティリティ ────────────────────────────────
func _damage_in_radius(pos: Vector2, radius: float, dmg: int) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(pos) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg)

func _damage_in_ellipse(pos: Vector2, rw: float, rh: float, dmg: int) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d  = enemy.global_position - pos
		var ex = (d.x / rw) * (d.x / rw)
		var ey = (d.y / rh) * (d.y / rh)
		if ex + ey <= 1.0:
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg)

# 点 from から方向 dir のレイがスクリーン境界と交差する点を返す
func _ray_to_screen_edge(from: Vector2, dir: Vector2) -> Vector2:
	var vp   = get_viewport().get_visible_rect()
	var xf   = get_canvas_transform().affine_inverse()
	var tl   = xf * Vector2.ZERO
	var br   = xf * vp.size
	var mn_x = min(tl.x, br.x); var mx_x = max(tl.x, br.x)
	var mn_y = min(tl.y, br.y); var mx_y = max(tl.y, br.y)
	var best_t = INF
	if dir.x >  0.001:
		var t = (mx_x - from.x) / dir.x
		if t > 0: best_t = min(best_t, t)
	elif dir.x < -0.001:
		var t = (mn_x - from.x) / dir.x
		if t > 0: best_t = min(best_t, t)
	if dir.y >  0.001:
		var t = (mx_y - from.y) / dir.y
		if t > 0: best_t = min(best_t, t)
	elif dir.y < -0.001:
		var t = (mn_y - from.y) / dir.y
		if t > 0: best_t = min(best_t, t)
	if best_t == INF or best_t > 4000:
		return from + dir * 2000.0
	return from + dir * (best_t * 0.97)   # 画面端のほんの手前

func _get_max_cd(type: PowerType) -> float:
	var cfg = GameManager.CONFIG
	match type:
		PowerType.EARTHCRACK: return cfg.earthcrack_cooldown
		PowerType.METEOR:     return cfg.meteor_cooldown
		PowerType.TORNADO:    return cfg.tornado_cooldown
		PowerType.WIND:       return cfg.wind_cooldown
		PowerType.RAIN:       return cfg.rain_cooldown
	return 1.0

# ── プレビュー描画 ─────────────────────────────────────
func _draw():
	if GameManager.current_phase != GameManager.Phase.PLAYING:
		return
	if _rain_active:
		var xf = get_canvas_transform().affine_inverse()
		for drop in _rain_drops:
			var lp = xf * drop["pos"]
			draw_line(lp, lp + Vector2(3, 16),
				Color(0.4, 0.6, 1.0, drop["alpha"]), 1.8)
	if selected == PowerType.NONE:
		return
	var cfg      = GameManager.CONFIG
	var mouse_l  = to_local(get_global_mouse_position())
	var base_col = POWER_COLORS.get(selected, Color.WHITE)
	var on_cd    = cooldowns.get(selected, 0.0) > 0.0
	var fill_a   = 0.10 if on_cd else 0.22
	var border_a = 0.35 if on_cd else 0.85
	match selected:
		PowerType.EARTHCRACK:
			_preview_ellipse(mouse_l, cfg.earthcrack_width, cfg.earthcrack_height,
				Color(base_col, fill_a), Color(base_col, border_a))
		PowerType.WIND:
			var hw = cfg.wind_width  * 0.5
			var hh = cfg.wind_height * 0.5
			draw_rect(Rect2(mouse_l - Vector2(hw, hh), Vector2(hw*2, hh*2)),
				Color(base_col, fill_a))
			draw_rect(Rect2(mouse_l - Vector2(hw, hh), Vector2(hw*2, hh*2)),
				Color(base_col, border_a), false, 2.5)
		PowerType.RAIN:
			draw_circle(mouse_l, cfg.rain_radius, Color(base_col, fill_a))
			draw_arc(mouse_l, cfg.rain_radius, 0, TAU, 48, Color(base_col, border_a), 2.5)
		_:
			var r = _get_preview_radius()
			draw_circle(mouse_l, r, Color(base_col, fill_a))
			draw_arc(mouse_l, r, 0, TAU, 48, Color(base_col, border_a), 2.5)

func _preview_ellipse(center: Vector2, rx: float, ry: float,
		fill_col: Color, border_col: Color) -> void:
	const N := 48
	var pts := PackedVector2Array()
	for i in N:
		var a = i * TAU / N
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, fill_col)
	pts.append(pts[0])
	draw_polyline(pts, border_col, 2.5)

func _get_preview_radius() -> float:
	var cfg = GameManager.CONFIG
	match selected:
		PowerType.METEOR:   return cfg.meteor_radius
		PowerType.TORNADO:  return cfg.tornado_radius
	return 60.0

# ════════════════════════════════════════════════════════
# エフェクトクラス
# ════════════════════════════════════════════════════════

# ── 地割れ ──────────────────────────────────────────────
class _EarthcrackFX extends Node2D:
	var _rw:   float   # 水平半径
	var _rh:   float   # 垂直半径
	var _life: float
	var _max:  float = 2.5
	var _tex:  Texture2D
	var _cracks: Array = []

	func _init(pos, rw, rh, tex):
		global_position = pos; _rw = rw; _rh = rh; _tex = tex; _life = _max
		for i in 14:
			var a    = i * TAU / 14.0 + randf_range(-0.15, 0.15)
			# 楕円上に端点を配置
			var ex   = cos(a) * rw * randf_range(1.1, 1.65)
			var ey   = sin(a) * rh * randf_range(1.1, 1.65)
			var ep   = Vector2(ex, ey)
			var ba1  = a + randf_range(-0.55, 0.55)
			var ba2  = a + randf_range(-0.75, 0.75)
			var m1   = ep * randf_range(0.4, 0.65)
			var m2   = ep * randf_range(0.2, 0.4)
			var br   = (rw + rh) * 0.5  # 枝の長さ基準
			_cracks.append({
				"ep":      ep,
				"mid1":    m1,
				"branch1": m1 + Vector2(cos(ba1), sin(ba1)) * br * randf_range(0.22, 0.48),
				"mid2":    m2,
				"branch2": m2 + Vector2(cos(ba2), sin(ba2)) * br * randf_range(0.15, 0.32),
			})

	func _process(d):
		_life -= d
		if _life <= 0:
			var ground = _EarthcrackGround.new(global_position, _rw, _rh, _cracks)
			get_parent().add_child(ground)
			queue_free()
			return
		queue_redraw()

	func _draw():
		var t = _life / _max
		var avg_r = (_rw + _rh) * 0.5
		# 地面スコーチ（楕円）
		var spts := PackedVector2Array()
		for i in 32:
			var a = i * TAU / 32
			spts.append(Vector2(cos(a) * _rw * 2.2, sin(a) * _rh * 2.2))
		draw_colored_polygon(spts, Color(0.04, 0.02, 0.0, min(t * 2.0, 0.8)))
		if _tex:
			var sz = Vector2(_rw, _rh) * 4.0 * (1.0 + (1.0 - t) * 0.35)
			draw_texture_rect(_tex, Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, t * 0.95))
		else:
			var col = Color(0.12, 0.06, 0.0, t * 0.9)
			for c in _cracks:
				draw_line(Vector2.ZERO, c["ep"],      col, 4.5)
				draw_line(c["mid1"],   c["branch1"],  col, 2.5)
				draw_line(c["mid2"],   c["branch2"],  col, 1.8)
		# 衝撃波リング（外側へ広がる）
		var elapsed = (_max - _life)
		for ring in 3:
			var ring_elapsed = elapsed - ring * 0.3
			if ring_elapsed < 0.0: continue
			var ring_t = clampf(ring_elapsed / 1.8, 0.0, 1.0)
			var ring_r = (_rw + _rh) * 0.5 * (1.5 + ring_t * 5.0)
			var ring_a = (1.0 - ring_t) * 0.65
			if ring_a > 0.01:
				draw_arc(Vector2.ZERO, ring_r, 0, TAU, 64,
					Color(0.75, 0.4, 0.1, ring_a), 4.5 - ring * 0.8)


# ── 隕石（飛翔体） ──────────────────────────────────────
class _MeteorProjectileFX extends Node2D:
	var _start:   Vector2
	var _target:  Vector2
	var _delay:   float
	var _elapsed: float = 0.0
	var _r:       float
	var _dmg:     int
	var _tex:     Texture2D
	var _trail:   Array[Vector2] = []
	var _done:    bool = false

	func _init(start, target, delay, r, dmg, tex):
		global_position = start
		_start = start; _target = target
		_delay = delay; _r = r; _dmg = dmg; _tex = tex

	func _process(d):
		if _done: return
		_elapsed += d
		var p = clampf(_elapsed / _delay, 0.0, 1.0)
		global_position = _start.lerp(_target, p)
		_trail.push_front(global_position)
		if _trail.size() > 28: _trail.pop_back()
		if _elapsed >= _delay:
			_done = true
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.global_position.distance_to(_target) <= _r:
					if enemy.has_method("take_damage"): enemy.take_damage(_dmg)
			var fx   = _MeteorImpactFX.new(_target, _r, _tex)
			var fire = _MeteorGroundFire.new(_target, _r)
			get_parent().add_child(fx)
			get_parent().add_child(fire)
			queue_free()
			return
		queue_redraw()

	func _draw():
		# トレイル
		for i in _trail.size():
			var lp   = to_local(_trail[i])
			var frac = float(i) / _trail.size()
			var a    = (1.0 - frac) * 0.8
			var tr   = max(3.0, _r * 0.65 * (1.0 - frac))
			draw_circle(lp, tr, Color(1.0, lerp(0.85, 0.1, frac), 0.05, a))
		# 火球本体
		if _tex:
			var sz = Vector2(_r, _r) * 2.4
			draw_texture_rect(_tex, Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, 0.95))
		else:
			draw_circle(Vector2.ZERO, _r * 0.7,  Color(1, 0.9, 0.3, 1.0))
			draw_circle(Vector2.ZERO, _r * 0.42, Color(1, 1,   0.9, 1.0))
			for i in 8:
				var ang = i * TAU / 8.0 + _elapsed * 5.0
				draw_circle(
					Vector2(cos(ang), sin(ang)) * _r * 0.55,
					_r * 0.2, Color(1, 0.4, 0.1, 0.85))


# ── 隕石（着弾） ─────────────────────────────────────────
class _MeteorImpactFX extends Node2D:
	var _r:      float
	var _life:   float
	var _max:    float = 3.0
	var _tex:    Texture2D
	var _debris: Array = []

	func _init(pos, r, tex):
		global_position = pos; _r = r; _tex = tex; _life = _max
		for i in 22:
			var ang = randf() * TAU
			var spd = randf_range(120, 420)
			_debris.append({
				"pos":      Vector2.ZERO,
				"vel":      Vector2(cos(ang), sin(ang)) * spd,
				"max_life": randf_range(1.0, 2.6),
				"life":     randf_range(1.0, 2.6),
				"size":     randf_range(4, 10),
			})

	func _process(d):
		_life -= d
		if _life <= 0:
			queue_free()
			return
		for db in _debris:
			db["pos"]  += db["vel"] * d
			db["vel"]  *= 0.92
			db["life"] -= d
		queue_redraw()

	func _draw():
		var t       = _life / _max
		var elapsed = _max - _life
		# スコーチ
		draw_circle(Vector2.ZERO, _r * 2.5, Color(0.04, 0.01, 0.0, min(t * 1.5, 0.75)))
		# テクスチャ or プロシージャル爆発
		if _tex:
			var sz = Vector2(_r, _r) * 4.0 * (1.0 + (1.0 - t) * 1.0)
			draw_texture_rect(_tex, Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, t * 0.95))
		else:
			draw_circle(Vector2.ZERO, _r * (2.0 + (1.0-t)*0.9), Color(1, 0.35, 0.0, t * 0.85))
			draw_circle(Vector2.ZERO, _r * (1.0 + (1.0-t)*0.5), Color(1, 0.85, 0.2, t))
		# 衝撃波リング
		for ring in 4:
			var re = elapsed - ring * 0.25
			if re < 0.0: continue
			var rt    = clampf(re / 1.5, 0.0, 1.0)
			var ring_r = _r * (2.0 + ring * 0.7 + rt * 4.5)
			var ring_a = (1.0 - rt) * 0.75
			if ring_a > 0.01:
				draw_arc(Vector2.ZERO, ring_r, 0, TAU, 64,
					Color(1, 0.55, 0.1, ring_a), 5.0 - ring * 0.6)
		# デブリ
		for db in _debris:
			if db["life"] > 0:
				var da = clampf(db["life"] / db["max_life"], 0.0, 1.0)
				draw_circle(db["pos"], db["size"] * da, Color(1, 0.45, 0.1, da * 0.9))


# ── 竜巻 ─────────────────────────────────────────────────
class _TornadoFX extends Node2D:
	var _r:       float
	var _dmg:     int
	var _spd:     float
	var _dur:     float
	var _elapsed: float = 0.0
	var _dir:     Vector2
	var _tick:    float = 0.0
	var _tex:     Texture2D
	var _debris:  Array = []

	func _init(pos, r, dmg, spd, dur, tex):
		global_position = pos; _r = r; _dmg = dmg; _spd = spd; _dur = dur; _tex = tex
		_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		for i in 16:
			_debris.append({
				"ang":   randf() * TAU,
				"dist":  randf_range(_r * 0.45, _r * 1.15),
				"speed": randf_range(2.5, 6.0),
				"size":  randf_range(3, 8),
			})

	func _process(d):
		_elapsed += d
		if _elapsed >= _dur: queue_free(); return
		global_position += _dir * _spd * d
		_tick += d
		if _tick >= 0.15:
			_tick = 0.0
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(global_position) <= _r:
					if e.has_method("take_damage"): e.take_damage(_dmg)
					if e is CharacterBody2D: e.velocity += _dir * 300.0
		for db in _debris:
			db["ang"] += db["speed"] * d
		queue_redraw()

	func _draw():
		var a    = 1.0 - _elapsed / _dur
		var fade = clampf(a * 1.5, 0.0, 1.0)
		# 地面影
		draw_circle(Vector2.ZERO, _r * 1.4, Color(0.3, 0.55, 0.9, 0.18 * fade))
		if _tex:
			var sz = Vector2(_r, _r) * 3.5
			draw_texture_rect(_tex, Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, a * 0.92))
		else:
			draw_circle(Vector2.ZERO, _r, Color(0.5, 0.8, 1.0, 0.28 * fade))
		# スパイラルリング（5層）
		for ring in 5:
			var frac  = float(ring) / 5.0
			var rr    = _r * (0.25 + frac * 0.9)
			var phase = _elapsed * 4.5 + frac * TAU
			var off   = Vector2(cos(phase), sin(phase)) * _r * 0.14
			draw_arc(off, rr, 0, TAU, 36,
				Color(0.6, 0.88, 1.0, fade * (0.45 + frac * 0.35)), 3.0)
		# 外縁リング
		draw_arc(Vector2.ZERO, _r * 1.2, 0, TAU, 48,
			Color(0.75, 0.92, 1.0, fade * 0.85), 4.5)
		# デブリ粒子
		for db in _debris:
			var dp = Vector2(cos(db["ang"]), sin(db["ang"])) * db["dist"]
			draw_circle(dp, db["size"] * fade, Color(0.88, 0.96, 1.0, fade * 0.85))


# ── 強風 ─────────────────────────────────────────────────
class _WindFX extends Node2D:
	var _life:  float = 1.2
	var _max:   float = 1.2
	var _half:  Vector2   # 矩形の半サイズ
	var _lines: Array = []

	func _init(pos, half_size):
		global_position = pos; _half = half_size
		# 横向きの疾風ライン（矩形内を水平に走る）
		var n = 12
		for i in n:
			var frac = float(i) / (n - 1)
			var y    = lerp(-_half.y, _half.y, frac)
			var x0   = randf_range(-_half.x, -_half.x * 0.5)
			_lines.append({
				"start": Vector2(x0, y + randf_range(-8, 8)),
				"end":   Vector2(_half.x * randf_range(0.8, 1.0), y + randf_range(-8, 8)),
				"width": randf_range(1.5, 4.5),
			})

	func _process(dt):
		_life -= dt
		if _life <= 0: queue_free()
		queue_redraw()

	func _draw():
		var t = _life / _max
		# 矩形枠
		var r = Rect2(-_half, _half * 2.0)
		draw_rect(r, Color(0.8, 1.0, 0.5, t * 0.25))
		draw_rect(r, Color(0.9, 1.0, 0.6, t * 0.7), false, 2.5)
		# 疾風ライン
		for ln in _lines:
			var prog = clampf((_max - _life) / (_max * 0.4), 0.0, 1.0)
			var tip  = ln["start"].lerp(ln["end"], prog)
			draw_line(ln["start"], tip,
				Color(0.85, 1.0, 0.5, t * 0.8), ln["width"])
			draw_line(ln["start"] + Vector2(20, 0), tip,
				Color(1.0, 1.0, 0.7, t * 0.4), ln["width"] * 0.5)


# ── 地割れ跡（永続ヒビ） ──────────────────────────────────
class _EarthcrackGround extends Node2D:
	var _rw:     float
	var _rh:     float
	var _life:   float = 12.0
	var _max:    float = 12.0
	var _tick:   float = 0.0
	var _cracks: Array = []   # {ep, mid1, branch1, mid2, branch2, strength}

	func _init(pos, rw, rh, src_cracks):
		global_position = pos; _rw = rw; _rh = rh
		for c in src_cracks:
			var e = c.duplicate()
			e["strength"] = 1.0
			_cracks.append(e)

	func _process(d):
		_life -= d * 0.12   # 自然減衰は非常に遅い
		if _life <= 0: queue_free(); return
		_tick += d
		if _tick >= 0.35:
			_tick = 0.0
			_check_enemies()
		queue_redraw()

	func _check_enemies():
		var tol = (_rw + _rh) * 0.11   # ヒビ検出幅
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var lp = to_local(enemy.global_position)
			for c in _cracks:
				if c["strength"] <= 0.0: continue
				var cl = _closest_on_seg(Vector2.ZERO, c["ep"], lp)
				if cl.distance_to(lp) <= tol:
					if enemy.has_method("take_damage"):
						enemy.take_damage(25)
					c["strength"] = max(0.0, c["strength"] - 0.35)
					break   # 1敵につき1クラック/tick

	func _closest_on_seg(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
		var ab = b - a
		var len_sq = ab.length_squared()
		if len_sq < 0.001: return a
		var t = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
		return a + ab * t

	func _draw():
		var overall = _life / _max
		for c in _cracks:
			var s = c["strength"] * overall
			if s < 0.02: continue
			var col  = Color(0.07, 0.03, 0.0, s * 0.92)
			var glow = Color(1.0, 0.5, 0.1, s * 0.38)
			draw_line(Vector2.ZERO, c["ep"],    glow, 3.5 * s)
			draw_line(c["mid1"], c["branch1"],  glow, 1.8 * s)
			draw_line(Vector2.ZERO, c["ep"],    col,  4.5 * s + 0.5)
			draw_line(c["mid1"], c["branch1"],  col,  2.5 * s + 0.3)
			draw_line(c["mid2"], c["branch2"],  col,  1.8 * s + 0.2)


# ── 隕石炎上跡（継続ダメージ） ───────────────────────────
class _MeteorGroundFire extends Node2D:
	var _r:         float
	var _life:      float = 6.5
	var _max:       float = 6.5
	var _tick:      float = 0.0
	var _particles: Array = []

	func _init(pos, r):
		global_position = pos; _r = r
		for i in 30:
			_particles.append({
				"ang":   randf() * TAU,
				"dist":  randf_range(0.0, r * 0.88),
				"phase": randf() * TAU,
				"spd":   randf_range(2.5, 6.5),
				"size":  randf_range(8, 30),
			})

	func _process(d):
		_life -= d
		if _life <= 0: queue_free(); return
		_tick += d
		if _tick >= 0.25:
			_tick = 0.0
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.global_position.distance_to(global_position) <= _r:
					if enemy.has_method("take_damage"):
						enemy.take_damage(35)
		for p in _particles:
			p["phase"] += p["spd"] * d
		queue_redraw()

	func _draw():
		var t    = _life / _max
		var fade = clampf(t * 2.5, 0.0, 1.0)
		var rsc  = 0.55 + t * 0.45   # 時間とともに炎が縮む
		# 焦げた地面
		draw_circle(Vector2.ZERO, _r * 1.15, Color(0.06, 0.02, 0.0, 0.7 * t))
		# 危険ゾーンリング
		var pulse = 0.7 + 0.3 * sin(_life * 4.0)
		draw_arc(Vector2.ZERO, _r * rsc, 0, TAU, 48,
			Color(1, 0.3, 0.0, fade * 0.5 * pulse), 3.0)
		# 炎パーティクル
		for p in _particles:
			var pos     = Vector2(cos(p["ang"]), sin(p["ang"])) * p["dist"] * rsc
			var flicker = 0.5 + 0.5 * sin(p["phase"])
			var sz      = p["size"] * flicker * fade * rsc
			if sz < 0.5: continue
			draw_circle(pos, sz,       Color(1.0, 0.3 * flicker, 0.0,  0.7 * fade * flicker))
			draw_circle(pos, sz * 0.5, Color(1.0, 0.85,          0.25, 0.6 * fade * flicker))
