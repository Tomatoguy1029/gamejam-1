extends Control

@onready var _time_label: Label          = $HBoxContainer2/HBoxContainer/TimeLabel
@onready var _hp_bar:     ProgressBar    = $HBoxContainer2/BaseHPBar
@onready var _power_row:  HBoxContainer  = $PowerRow

const POWER_KEYS  := ["1", "2", "3", "4", "5"]
const POWER_NAMES := ["Earthcrack", "Meteor", "Tornado", "Wind", "Rain"]
const POWER_COLS  := [
	Color(0.8, 0.5, 0.1),
	Color(1.0, 0.3, 0.1),
	Color(0.5, 0.8, 1.0),
	Color(0.8, 1.0, 0.5),
	Color(0.3, 0.6, 1.0),
]

var _power_panels:  Array[PanelContainer] = []
var _key_labels:    Array[Label]          = []
var _name_labels:   Array[Label]          = []
var _cd_bars:       Array[ProgressBar]    = []
var _panel_styles:  Array[StyleBoxFlat]   = []   # normal style per slot
var _god_power: Node = null

func _ready():
	GameManager.base_hp_changed.connect(_on_hp_changed)
	GameManager.phase_changed.connect(_on_phase_changed)

	_hp_bar.max_value = GameManager.CONFIG.base_hp
	_hp_bar.value     = GameManager.CONFIG.base_hp
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.55, 0.9, 0.15)
	_hp_bar.add_theme_stylebox_override("fill", fill)

	_build_power_ui()

func _build_power_ui() -> void:
	for i in POWER_KEYS.size():
		var col: Color = POWER_COLS[i]

		# ── パネル ───────────────────────────────────────
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(110, 78)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.06, 0.12, 0.88)
		sb.border_width_left   = 2; sb.border_width_right  = 2
		sb.border_width_top    = 2; sb.border_width_bottom = 2
		sb.border_color = Color(col, 0.5)
		sb.corner_radius_top_left     = 5
		sb.corner_radius_top_right    = 5
		sb.corner_radius_bottom_left  = 5
		sb.corner_radius_bottom_right = 5
		panel.add_theme_stylebox_override("panel", sb)
		_panel_styles.append(sb)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		panel.add_child(vbox)

		# ── キー番号 ────────────────────────────────────
		var key_lbl := Label.new()
		key_lbl.text = POWER_KEYS[i]
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 26)
		key_lbl.modulate = col
		vbox.add_child(key_lbl)
		_key_labels.append(key_lbl)

		# ── 技名 ────────────────────────────────────────
		var name_lbl := Label.new()
		name_lbl.text = POWER_NAMES[i]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.modulate = Color(col, 0.85)
		vbox.add_child(name_lbl)
		_name_labels.append(name_lbl)

		# ── クールダウンバー ──────────────────────────────
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(96, 7)
		bar.max_value = 1.0
		bar.value     = 1.0
		bar.show_percentage = false
		var bfill := StyleBoxFlat.new()
		bfill.bg_color = col
		bar.add_theme_stylebox_override("fill", bfill)
		vbox.add_child(bar)
		_cd_bars.append(bar)

		_power_panels.append(panel)
		_power_row.add_child(panel)

func _on_phase_changed(new_phase):
	if new_phase == GameManager.Phase.PLAYING:
		_god_power = get_tree().get_first_node_in_group("god_power_manager")

func _on_hp_changed(hp):
	_hp_bar.value = hp

func _process(_delta):
	var t = GameManager.get_survival_time_left()
	_time_label.text = "Reinforcements in %ds" % max(0, int(ceil(t)))

	if _god_power == null:
		return
	for i in _cd_bars.size():
		var power_type := i + 1
		var max_cd: float = _get_max_cd(power_type)
		var cd: float     = _god_power.cooldowns.get(power_type, 0.0)
		var ratio      := 1.0 - (cd / max_cd if max_cd > 0 else 1.0)
		_cd_bars[i].value = ratio

		var is_sel: bool = (_god_power.selected == power_type)
		var on_cd: bool  = cd > 0.0
		var col: Color = POWER_COLS[i]
		var sb     := _panel_styles[i]

		if is_sel:
			# 選択中：白枠 + 明るい背景
			sb.bg_color    = Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.95)
			sb.border_color = Color.WHITE
			sb.border_width_left   = 3; sb.border_width_right  = 3
			sb.border_width_top    = 3; sb.border_width_bottom = 3
			_key_labels[i].modulate  = Color.WHITE
			_name_labels[i].modulate = Color.WHITE
		elif on_cd:
			# CD中：暗くグレーアウト
			sb.bg_color    = Color(0.04, 0.04, 0.08, 0.88)
			sb.border_color = Color(col, 0.2)
			sb.border_width_left   = 2; sb.border_width_right  = 2
			sb.border_width_top    = 2; sb.border_width_bottom = 2
			_key_labels[i].modulate  = Color(col, 0.4)
			_name_labels[i].modulate = Color(col, 0.3)
		else:
			# 通常
			sb.bg_color    = Color(0.06, 0.06, 0.12, 0.88)
			sb.border_color = Color(col, 0.55)
			sb.border_width_left   = 2; sb.border_width_right  = 2
			sb.border_width_top    = 2; sb.border_width_bottom = 2
			_key_labels[i].modulate  = col
			_name_labels[i].modulate = Color(col, 0.85)

func _get_max_cd(power_type: int) -> float:
	var cfg = GameManager.CONFIG
	match power_type:
		1: return cfg.earthcrack_cooldown
		2: return cfg.meteor_cooldown
		3: return cfg.tornado_cooldown
		4: return cfg.wind_cooldown
		5: return cfg.rain_cooldown
	return 1.0
