extends Area2D

@export var max_hp: int = 100
var current_hp: int

func _ready():
	add_to_group("main_base")
	current_hp = max_hp
	body_entered.connect(_on_body_entered)

func get_target_position() -> Vector2:
	return $CollisionShape2D.global_position

func take_damage(amount: int):
	current_hp -= amount
	GameManager.take_base_damage(amount)
	if current_hp <= 0:
		_on_defeat()

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		take_damage(10)
		body.queue_free()

func _on_defeat():
	print("敗北：本陣が破壊されました")
