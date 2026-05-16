# res://data/unit_params.gd
# ユニット共通パラメータ。各ユニットの .tres ファイルで値を設定し Inspector から編集できる。
class_name UnitParams
extends Resource

@export_group("Stats")
@export var cost: int = 0
@export var max_hp: int = 100
@export var speed: float = 100.0
@export var damage: int = 10
@export var attack_range: float = 40.0
@export var attack_interval: float = 1.0
@export var reward: int = 0

@export_group("Special")
## 門への攻撃時のダメージ倍率 (1.0 = 通常, 3.0 = Breaker など)
@export var gate_damage_multiplier: float = 1.0
