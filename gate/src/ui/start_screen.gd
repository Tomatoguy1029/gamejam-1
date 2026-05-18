# res://src/ui/start_screen.gd
extends Control

@onready var _title_label: Label  = $VBox/TitleLabel
@onready var _sub_label:   Label  = $VBox/SubLabel
@onready var _start_btn:   Button = $VBox/StartButton
@onready var _bg:          ColorRect = $Bg

# ── テキストシーケンス ──────────────────────────────────────
const INTRO_LINES: Array[String] = [
	"This castle is on the verge of falling...",
	"But don't worry.",
	"Let's cheat just a little to save it.",
]
const LINE_DURATION: float = 1.4

# ── イントロアニメーション（敵ドット） ──────────────────────
const ANIM_DURATION: float = 3.0   # アニメーション時間(秒)
const DOT_COUNT:     int   = 48    # 敵ドット数

# ドット: { pos: Vector2, dir: Vector2, speed: float }
var _dots: Array = []

# ── 状態マシン ──────────────────────────────────────────────
enum State { ANIM, TEXT, READY }
var _state:      State = State.ANIM
var _timer:      float = 0.0
var _line_index: int   = 0

func _ready():
	_start_btn.pressed.connect(_on_start_button_pressed)
	if GameManager.first_run:
		_enter_anim()
	else:
		_enter_ready()

# ── ANIM フェーズ ──────────────────────────────────────────
func _enter_anim() -> void:
	_state = State.ANIM
	_timer = 0.0
	_title_label.text = ""
	_sub_label.text   = ""
	_start_btn.hide()
	_bg.color = Color(0.02, 0.02, 0.06, 0.85)
	_dots.clear()
	var vp = get_viewport_rect()
	var cx = vp.size.x * 0.5
	var cy = vp.size.y * 0.5
	for i in DOT_COUNT:
		var angle = randf() * TAU
		var dist  = randf_range(vp.size.length() * 0.45, vp.size.length() * 0.55)
		var pos   = Vector2(cx + cos(angle) * dist, cy + sin(angle) * dist)
		var dir   = (Vector2(cx, cy) - pos).normalized()
		_dots.append({ "pos": pos, "dir": dir, "speed": randf_range(100.0, 220.0) })
	queue_redraw()

func _update_anim(delta: float) -> void:
	var vp = get_viewport_rect()
	var cx = vp.size.x * 0.5
	var cy = vp.size.y * 0.5
	var center = Vector2(cx, cy)
	for dot in _dots:
		dot["pos"] += dot["dir"] * dot["speed"] * delta
	# アニメーション終了 → テキストフェーズへ
	_timer += delta
	# 終盤でタイトル文字をフェードイン
	var fade = clampf((_timer - ANIM_DURATION * 0.6) / (ANIM_DURATION * 0.4), 0.0, 1.0)
	_title_label.text = "This castle is on the verge of falling..."
	_title_label.modulate.a = fade
	if _timer >= ANIM_DURATION:
		_enter_text()
	queue_redraw()

# ── TEXT フェーズ ──────────────────────────────────────────
func _enter_text() -> void:
	_state      = State.TEXT
	_timer      = 0.0
	_line_index = 0
	_title_label.modulate.a = 1.0
	_title_label.text = INTRO_LINES[0]
	_sub_label.text   = ""
	_start_btn.hide()
	_dots.clear()
	queue_redraw()

func _update_text(delta: float) -> void:
	if _line_index >= INTRO_LINES.size() - 1:
		return
	_timer += delta
	if _timer >= LINE_DURATION:
		_timer      = 0.0
		_line_index += 1
		_title_label.text = INTRO_LINES[_line_index]
		if _line_index == INTRO_LINES.size() - 1:
			_sub_label.text = "1:Earthcrack  2:Meteor  3:Tornado  4:Wind  5:Rain"
			_start_btn.show()

# ── READY フェーズ（リスタート時） ─────────────────────────
func _enter_ready() -> void:
	_state = State.READY
	_bg.color = Color(0.02, 0.02, 0.06, 0.85)
	_title_label.modulate.a = 1.0
	_title_label.text = "Ready"
	_sub_label.text   = "1:Earthcrack  2:Meteor  3:Tornado  4:Wind  5:Rain"
	_start_btn.show()
	_dots.clear()

# ── メインループ ───────────────────────────────────────────
func _process(delta):
	match _state:
		State.ANIM:  _update_anim(delta)
		State.TEXT:  _update_text(delta)
		State.READY: pass

# ── 描画（イントロアニメ用） ──────────────────────────────
func _draw():
	if _dots.is_empty():
		return
	var vp  = get_viewport_rect()
	var cx  = vp.size.x * 0.5
	var cy  = vp.size.y * 0.5
	var t   = clampf(_timer / ANIM_DURATION, 0.0, 1.0)
	# ドット描画
	for dot in _dots:
		var dist = dot["pos"].distance_to(Vector2(cx, cy))
		var a    = clampf(dist / 60.0, 0.3, 1.0)
		var r    = lerp(6.0, 3.0, t)
		draw_circle(dot["pos"], r, Color(0.9, 0.15, 0.1, a))
	# 中心の城マーカー
	draw_circle(Vector2(cx, cy), 18.0, Color(0.3, 0.5, 1.0, 0.9))
	draw_arc(Vector2(cx, cy), 32.0, 0, TAU, 32, Color(0.5, 0.7, 1.0, 0.6), 2.0)

# ── ボタン ────────────────────────────────────────────────
func _on_start_button_pressed():
	GameManager.start_game()
	queue_free()
