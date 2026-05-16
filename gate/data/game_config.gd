# res://data/game_config.gd
# ゲーム全体のパラメータ。data/game_config.tres で値を設定し Inspector から編集できる。
class_name GameConfig
extends Resource

@export_group("Economy")
## ゲーム開始時の所持金
@export var initial_money: int = 100
## ウェーブクリア報酬
@export var phase_clear_reward: int = 50
## 各アップグレードのコスト
@export var upgrade_cost: int = 50
## 攻撃力アップグレード量
@export var upgrade_atk_amount: int = 10
## HP アップグレード量
@export var upgrade_hp_amount: int = 30
## 攻撃速度アップグレード量（attack_interval を減らす秒数）
@export var upgrade_interval_amount: float = 0.15

@export_group("Base & Gate")
## 本陣の最大 HP
@export var base_hp: int = 100
## 門の最大 HP
@export var gate_max_hp: int = 500
## 門の HP バーの最大長（ローカル座標 px）
@export var gate_bar_length: float = 60.0

@export_group("Wave")
## 合計ウェーブ数
@export var max_waves: int = 5
## 防衛フェーズの制限時間（秒）
@export var defending_phase_duration: float = 30.0

@export_group("Combat")
## 攻撃間隔の下限（秒）
@export var min_attack_interval: float = 0.2

@export_group("Placement")
## ユニット配置可能エリア（ワールド座標）
@export var placement_bounds: Rect2 = Rect2(-600.0, -600.0, 1200.0, 1200.0)
