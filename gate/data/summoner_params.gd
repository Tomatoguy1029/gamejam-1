# res://data/summoner_params.gd
# 召喚型敵専用パラメータ（UnitParams を継承）
class_name SummonerParams
extends UnitParams

@export_group("Summoner")
## 召喚するユニットを出す間隔（秒）
@export var summon_interval: float = 5.0
## 1回の召喚で出るユニット数
@export var summon_count: int = 2
## 門の手前で停止する距離（px）
@export var stop_dist_from_gate: float = 80.0
