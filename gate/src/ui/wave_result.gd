# res://src/ui/wave_result.gd
# Wave クリア時のリザルト画面
# 生存ユニット × 報酬レートを一覧表示し、合計を money に追加する
extends CanvasLayer

signal next_pressed

const UNIT_DISPLAY_NAMES: Dictionary = {
	"ally_attacker": "攻撃兵",
	"ally_tank":     "守備兵",
	"ally_archer":   "弓兵",
}

# ---- ノード参照 ----
@onready var _title_label:  Label          = $Panel/VBox/Title
@onready var _rows_box:     VBoxContainer  = $Panel/VBox/Rows
@onready var _total_label:  Label          = $Panel/VBox/Total
@onready var _next_button:  Button         = $Panel/VBox/NextButton

func _ready():
	_next_button.pressed.connect(_on_next_pressed)
	hide()

## survivors: { unit_id -> { "count": int, "reward": int } }
func show_result(wave_num: int, survivors: Dictionary, survivor_reward: int, clear_reward: int) -> void:
	_title_label.text = "WAVE %d  CLEAR!" % wave_num

	for child in _rows_box.get_children():
		child.queue_free()

	# WAVEクリア報酬
	_add_row("WAVEクリア報酬", "", "+%dG" % clear_reward)

	# 生存ユニット報酬
	if survivors.is_empty():
		_add_row("生存者なし", "", "")
	else:
		for uid in survivors:
			var data: Dictionary = survivors[uid]
			var uname: String    = UNIT_DISPLAY_NAMES.get(uid, uid)
			var cnt: int         = data["count"]
			var rw: int          = data["reward"]
			_add_row(uname, "%d体 × %dG" % [cnt, rw], "+%dG" % (cnt * rw))

	var grand_total: int = clear_reward + survivor_reward
	_total_label.text = "合計   +%dG" % grand_total
	show()

func _add_row(label: String, rate: String, subtotal: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	var lbl := Label.new()
	lbl.text                  = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var rate_lbl := Label.new()
	rate_lbl.text                  = rate
	rate_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rate_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(rate_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text                  = subtotal
	sub_lbl.custom_minimum_size   = Vector2(70, 0)
	sub_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(sub_lbl)

	_rows_box.add_child(hbox)

func _on_next_pressed() -> void:
	hide()
	next_pressed.emit()
