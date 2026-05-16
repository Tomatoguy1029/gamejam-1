extends Control

func _on_start_button_pressed():
	GameManager.start_game()
	queue_free()
