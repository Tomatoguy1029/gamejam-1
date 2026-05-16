# res://data/archer_params.gd
# 弓兵専用パラメータ（UnitParams を継承）
class_name ArcherParams
extends UnitParams

@export_group("Archer")
## 攻撃しない最小距離（この距離以内は死角として攻撃対象外）
@export var dead_zone: float = 60.0
