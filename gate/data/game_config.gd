# res://data/game_config.gd
class_name GameConfig
extends Resource

@export_group("Economy")
@export var initial_money: int = 100
@export var phase_clear_reward: int = 50
@export var upgrade_cost: int = 50
@export var upgrade_atk_amount: int = 10
@export var upgrade_hp_amount: int = 30
@export var upgrade_interval_amount: float = 0.15

@export_group("Base & Gate")
@export var base_hp: int = 100
@export var gate_max_hp: int = 500
@export var gate_bar_length: float = 60.0

@export_group("Wave")
@export var max_waves: int = 5
@export var defending_phase_duration: float = 30.0

@export_group("Combat")
@export var min_attack_interval: float = 0.2

@export_group("Placement")
@export var placement_bounds: Rect2 = Rect2(-600.0, -600.0, 1200.0, 1200.0)

@export_group("Survival")
@export var survival_time: float = 60.0
## 敵スポーン間隔（秒）。大きいほど敵が少ない
@export var enemy_spawn_interval: float = 0.9
@export var spawn_distance: float = 700.0

@export_group("God Powers - Earthcrack")
@export var earthcrack_cooldown: float = 3.0
## 水平方向の半径
@export var earthcrack_width:    float = 70.0
## 垂直方向の半径（縦長）
@export var earthcrack_height:   float = 160.0
@export var earthcrack_damage:   int   = 300

@export_group("God Powers - Meteor")
@export var meteor_cooldown: float = 2.0
@export var meteor_radius:   float = 120.0
@export var meteor_damage:   int   = 600
@export var meteor_delay:    float = 1.2

@export_group("God Powers - Tornado")
@export var tornado_cooldown:  float = 0.5
@export var tornado_radius:    float = 70.0
@export var tornado_damage:    int   = 80
@export var tornado_speed:     float = 180.0
@export var tornado_duration:  float = 4.0

@export_group("God Powers - Wind")
@export var wind_cooldown: float = 0.5
## 矩形の幅（水平）
@export var wind_width:    float = 400.0
## 矩形の高さ（垂直）
@export var wind_height:   float = 200.0

@export_group("God Powers - Rain")
@export var rain_cooldown:   float = 0.5
@export var rain_radius:     float = 300.0
@export var rain_slow_ratio: float = 0.35
@export var rain_duration:   float = 5.0
