# res://data/unit_config.gd
# 全ユニットのパラメータをまとめた単一コンフィグ。
# Inspector でユニット名ごとに展開して編集できる。
class_name UnitConfig
extends Resource

@export_group("Allies")
@export var ally_attacker: UnitParams
@export var ally_tank: UnitParams
@export var ally_archer: ArcherParams

@export_group("Enemies")
@export var enemy_heavy: UnitParams
@export var enemy_swarm: UnitParams
@export var enemy_dash: UnitParams
@export var enemy_breaker: UnitParams
@export var enemy_summoner: SummonerParams
