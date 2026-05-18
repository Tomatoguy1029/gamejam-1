# res://src/ui/result_overlay.gd
extends CanvasLayer

@onready var _title: Label  = $Panel/VBox/Title
@onready var _sub:   Label  = $Panel/VBox/Sub
@onready var _btn:   Button = $Panel/VBox/RetryButton

func _ready():
	hide()
	_btn.pressed.connect(_on_retry)

func show_result(is_win: bool) -> void:
	if is_win:
		_title.text = "Reinforcements arrived!\nThe castle held!"
		_sub.text   = "Your divine power made the difference."
	else:
		_title.text = "The castle has fallen..."
		_sub.text   = "Didn't make it in time."
	show()

func _on_retry() -> void:
	GameManager.reset()
	get_tree().reload_current_scene()
