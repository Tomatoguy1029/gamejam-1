extends Control

@onready var phase_label: Label      = $HBoxContainer2/HBoxContainer/PhaseLabel
@onready var money_label: Label      = $HBoxContainer2/HBoxContainer/MoneyLabel
@onready var time_label:  Label      = $HBoxContainer2/HBoxContainer/TimeLabel
@onready var hp_bar:      ProgressBar = $HBoxContainer2/BaseHPBar

func _ready():
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.base_hp_changed.connect(_on_hp_changed)

	hp_bar.max_value = GameManager.base_hp
	hp_bar.value     = GameManager.base_hp  # デフォルト100%

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.55, 0.9, 0.15, 1.0)
	hp_bar.add_theme_stylebox_override("fill", fill_style)

func _on_phase_changed(new_phase):
	phase_label.text = "DEFENSE" if new_phase == GameManager.Phase.DEFENDING else "PREPARE"

func _on_money_changed(amount):
	money_label.text = str(amount) + " G"

func _on_hp_changed(hp):
	hp_bar.value = hp

func _process(_delta):
	time_label.text = str(int(GameManager.get_phase_time_left()))
