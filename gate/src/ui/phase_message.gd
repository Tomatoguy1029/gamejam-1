extends Control

@onready var main_label:   Label  = $VBox/MainLabel
@onready var hint_label:   Label  = $VBox/HintLabel
@onready var retry_button: Button = $VBox/RetryButton
@onready var hide_timer:   Timer  = $HideTimer

func _ready():
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.game_over.connect(_on_game_over)
	retry_button.pressed.connect(_on_retry_pressed)
	hide()

func _on_phase_changed(new_phase: int):
	retry_button.hide()
	match new_phase:
		GameManager.Phase.PLACING:
			var costs = _get_cost_hint()
			if GameManager.wave_count == 0:
				main_label.text = "PLACE SOLDIERS!!"
				hint_label.text = "%s  |  Click to place  |  Enter: start" % costs
				hide_timer.stop()
				show()
			else:
				# wave クリア後は WaveResult パネルが先に出るので、
				# PhaseMessage は hint のみ・少し遅れて表示
				main_label.text = ""
				hint_label.text = "%s  |  Click to place  |  Enter: next wave" % costs
				hide_timer.stop()
				show()
		GameManager.Phase.DEFENDING:
			main_label.text = "WAVE %d  —  DEFEND!" % GameManager.wave_count
			hint_label.text = "Space: toggle gate"
			show()
			hide_timer.start(2.5)

func _on_game_over(is_win: bool):
	hide_timer.stop()
	retry_button.show()
	if is_win:
		main_label.text = "CLEAR!!"
		hint_label.text = "All waves cleared. Congratulations!"
	else:
		main_label.text = "GAME OVER"
		hint_label.text = "The main base has fallen."
	show()

func _get_cost_hint() -> String:
	var uc = GameManager.UNIT_CONFIG
	var a = uc.get("ally_attacker")
	var t = uc.get("ally_tank")
	var ar = uc.get("ally_archer")
	var ac = a.cost if a else 0
	var tc = t.cost if t else 0
	var arc = ar.cost if ar else 0
	return "1: 攻撃兵 %dG  2: 守備兵 %dG  3: 弓兵 %dG" % [ac, tc, arc]

func _on_retry_pressed():
	get_tree().reload_current_scene()

func _on_hide_timer_timeout():
	hide()
