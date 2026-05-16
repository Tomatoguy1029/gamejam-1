extends Control

func _ready():
	hide()
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.money_changed.connect(_on_money_changed)

	$Panel/VBoxContainer/Button.pressed.connect(_on_upgrade_atk_pressed)
	$Panel/VBoxContainer/Button2.pressed.connect(_on_upgrade_hp_pressed)
	$Panel/VBoxContainer/Button3.pressed.connect(_on_upgrade_speed_pressed)
	# ReadyButton は tscn 側で接続済み

func _on_phase_changed(new_phase):
	# PLACING 以外では非表示。PLACING 時は WaveResult 閉じ後に main.gd から show_after_result() を呼ぶ
	if new_phase != GameManager.Phase.PLACING:
		hide()

## WaveResult が閉じた後に main.gd から呼ばれる
func show_after_result() -> void:
	if GameManager.current_phase == GameManager.Phase.PLACING and GameManager.wave_count > 0:
		_refresh_labels()
		show()

func _on_money_changed(_amount):
	_refresh_labels()

func _refresh_labels():
	var cost = GameManager.CONFIG.upgrade_cost
	$Panel/VBoxContainer/Button.text  = "攻撃力UP  %dG" % cost
	$Panel/VBoxContainer/Button2.text = "HP UP     %dG" % cost
	$Panel/VBoxContainer/Button3.text = "速度UP    %dG" % cost

func _on_ready_button_pressed():
	GameManager.start_defending_phase()

func _on_upgrade_atk_pressed():
	GameManager.buy_upgrade_atk("allies")

func _on_upgrade_hp_pressed():
	GameManager.buy_upgrade_hp("allies")

func _on_upgrade_speed_pressed():
	GameManager.buy_upgrade_atk_speed("allies")
